import 'dart:async';
import 'dart:convert';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/SyncDBCache.dart';
import 'package:flutter_realm_sync/services/Models/EnumTypes.dart';
import 'package:flutter_realm_sync/services/Models/SyncOutboxPatch.dart';
import 'package:flutter_realm_sync/services/utils/MongoOperations.dart';
import 'package:flutter_realm_sync/services/utils/diff_rehydrate.dart';
import 'package:flutter_realm_sync/services/utils/helpers.dart';
import 'package:flutter_realm_sync/services/utils/json_canonical.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:uuid/uuid.dart' as uuid;

import 'utils/AppLogger.dart';

/// A reusable helper to manage partial patch diffs, debouncing, retries, and flushing per-id.
///
/// Usage:
/// - Provide how to fetch a model's sync map by id (toSyncMapForId)
/// - Optionally provide a sanitizer to strip local-only fields
/// - Optionally handle onAckSuccess to update local state (e.g., clear update flags)
class SyncHelper {
  // Global registry to allow SocketController to flush all helpers on reconnect
  static final Set<SyncHelper> _instances = <SyncHelper>{};
  final Realm realm;
  final Socket socket;

  final String collectionName;
  final Duration debounceDelay;

  // Callbacks
  final Map<String, dynamic>? Function(String id) toSyncMapForId;
  final Map<String, dynamic> Function(Map<String, dynamic>) sanitize;
  final void Function(String id)? onAckSuccess;
  final void Function(String id)? onNoDiff;
  final Map<String, dynamic> Function(Map<String, dynamic> rawJson)? emitPreProcessor;

  // State maps
  final Map<String, Map<String, dynamic>> _lastSyncedById = {};
  final Map<String, Map<String, dynamic>> _pendingPatchById = {};
  // Stable patch identifiers for idempotency / retry dedupe
  final Map<String, String> _patchIdById = {};
  // Track entity ids pending deletion (takes precedence over patches)
  final Set<String> _pendingDeleteIds = <String>{};
  final Map<String, Timer?> _debouncers = {};
  final Map<String, bool> _inFlightById = {};
  final Map<String, int> _retryCountById = {};
  final Map<String, Timer?> _retryTimersById = {};
  Timer? _heartbeatTimer;
  final Duration _heartbeatInterval = const Duration(seconds: 5);
  final Duration _ackTimeout = const Duration(seconds: 12);
  bool _outboxLoaded = false;
  final String userId; // Unique user identifier from authentication

  // Batching configuration and state
  final bool enableBatching;
  final Duration batchWindow;
  Timer? _batchTimer;
  final Set<String> _batchPendingIds = {};
  static const int _maxBatchSize = 50; // Maximum items per batch

  MongoOperations mongoOperations = MongoOperations();

  SyncHelper({
    required this.realm,
    required this.socket,
    required this.userId,
    required this.collectionName,
    required this.toSyncMapForId,
    Map<String, dynamic> Function(Map<String, dynamic>)? sanitize,
    this.onAckSuccess,
    this.onNoDiff,
    this.emitPreProcessor,
    this.debounceDelay = const Duration(milliseconds: 250),
    this.enableBatching = true,
    this.batchWindow = const Duration(milliseconds: 300),
  }) : sanitize = sanitize ?? ((m) => m) {
    if (userId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'userId cannot be empty - required for sync attribution',
      );
    }
    // Register instance for global coordination
    _instances.add(this);
  }

  void _ensureHeartbeat() {
    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) async {
      // If socket is available, try flushing any pending ids immediately
      if (socket.connected) {
        // Skip work when nothing is pending
        if (_pendingPatchById.isEmpty && _pendingDeleteIds.isEmpty) {
          return;
        }
        await flushAllPending();
      }
    });
  }

  Future<void> initOutbox() async {
    if (_outboxLoaded) return;
    await cleanupOutbox(); // Remove expired entries before hydration
    await _hydrateOutbox();
    await _processDBCacheDeletions(); // Process deletion markers from deleteWithSync()
    _outboxLoaded = true;
  }

  /// Process DBCache entries with operation='deleted' created by deleteWithSync()
  Future<void> _processDBCacheDeletions() async {
    try {
      final deletionMarkers = realm.query<SyncDBCache>(
        "uid == \$0 AND collection == \$1 AND operation == 'deleted'",
        [userId, collectionName],
      );

      for (final marker in deletionMarkers) {
        final entityId = marker.entityId;
        if (entityId.isNotEmpty && !_pendingDeleteIds.contains(entityId)) {
          _pendingDeleteIds.add(entityId);
          _patchIdById[entityId] ??= _generatePatchId();
          AppLogger.log(
            'SyncHelper: picked up DBCache deletion marker for $collectionName:$entityId',
          );
        }

        // Remove the marker after processing
        try {
          realm.write(() => realm.delete(marker));
        } catch (e) {
          AppLogger.log('Failed to delete DBCache deletion marker: $e');
        }
      }

      if (_pendingDeleteIds.isNotEmpty) {
        AppLogger.log(
          'SyncHelper: processed ${_pendingDeleteIds.length} DBCache deletion markers for $collectionName',
        );
      }
    } catch (e) {
      AppLogger.log(
        'SyncHelper: failed to process DBCache deletions: $e',
        error: e,
        isError: true,
      );
    }
  }

  Future<void> _hydrateOutbox() async {
    try {
      final results = realm.query<SyncOutboxPatch>(
        'uid == \$0 AND collection == \$1',
        [userId, collectionName],
      );
      _pendingPatchById.clear();
      _pendingDeleteIds.clear();
      for (final p in results) {
        try {
          final map = jsonDecode(p.payloadJson);
          if (map is Map<String, dynamic>) {
            final op = (map['operation'] ?? map['type'])?.toString();
            if (op == 'delete') {
              _pendingDeleteIds.add(p.entityId);
            } else {
              _pendingPatchById[p.entityId] = map;
            }
            // Restore patchId if present for stable retries
            final restoredId = map['patchId'];
            if (restoredId is String && restoredId.isNotEmpty) {
              _patchIdById[p.entityId] = restoredId;
            }
          }
        } catch (e) {
          AppLogger.log('Outbox decode failed for ${p.entityId}: $e');
        }
      }
      if (_pendingPatchById.isNotEmpty) {
        AppLogger.log(
          'SyncHelper: restored ${_pendingPatchById.length} outbox entries for $collectionName',
        );
      }
      if (_pendingDeleteIds.isNotEmpty) {
        AppLogger.log(
          'SyncHelper: restored ${_pendingDeleteIds.length} delete outbox entries for $collectionName',
        );
      }
    } catch (e) {
      AppLogger.log(
        'SyncHelper: outbox hydrate error: $e',
        error: e,
        isError: true,
      );
    }
  }

  Future<void> _persistOutbox() async {
    try {
      // Upsert one OutboxPatch doc per entity id with current pending diff
      for (final entry in _pendingPatchById.entries) {
        final entityId = entry.key;
        final payload = entry.value;
        if (payload.isEmpty && !_pendingDeleteIds.contains(entityId)) {
          final existing = realm.find<SyncOutboxPatch>(
            '${userId}|${collectionName}|${entityId}',
          );
          if (existing != null) {
            realm.write(() => realm.delete(existing));
          }
          continue;
        }
        final id = '${userId}|${collectionName}|${entityId}';
        // Ensure patchId present in payload before persisting
        final patchId = _patchIdById[entityId];
        if (patchId != null) {
          payload['patchId'] = patchId;
        }
        final canonicalPayload = canonicalizeMap(payload);
        final jsonStr = jsonEncode(canonicalPayload);
        realm.write(() {
          realm.add(
            SyncOutboxPatch(
              id,
              userId,
              collectionName,
              entityId,
              jsonStr,
              createdAt: DateTime.now().toUtc(),
              lastAttemptAt: DateTime.now().toUtc(),
            ),
            update: true,
          );
        });
      }

      // Persist pending deletes as well
      for (final entityId in _pendingDeleteIds) {
        final id = '${userId}|${collectionName}|${entityId}';
        final patchId = _patchIdById[entityId];
        final deletePayload = canonicalizeMap({
          'operation': 'delete',
          if (patchId != null) 'patchId': patchId,
        });
        final jsonStr = jsonEncode(deletePayload);
        realm.write(() {
          realm.add(
            SyncOutboxPatch(
              id,
              userId,
              collectionName,
              entityId,
              jsonStr,
              createdAt: DateTime.now().toUtc(),
              lastAttemptAt: DateTime.now().toUtc(),
            ),
            update: true,
          );
        });
      }
    } catch (e) {
      AppLogger.log(
        'SyncHelper: outbox persist error: $e',
        error: e,
        isError: true,
      );
    }
  }

  // Public API
  void setEmptyBaseline(String id) {
    _lastSyncedById[id] = <String, dynamic>{};
  }

  void setBaselineFromModel(String id) {
    final map = toSyncMapForId(id);
    if (map != null) {
      _lastSyncedById[id] = sanitize(map);
    }
  }

  void scheduleFullSync(String id) {
    final map = toSyncMapForId(id);
    if (map == null) return;
    final full = sanitize(map);
    _schedule(id, full);
  }

  /// Directly schedule an arbitrary patch for the given entity id.
  /// This bypasses diffing and writes to the outbox immediately
  /// (debounced before network send). Safe to call repeatedly; patches will be
  /// merged and deduped.
  void schedulePatch(String id, Map<String, dynamic> patch) {
    if (patch.isEmpty) return;
    _schedule(id, patch);
  }

  /// Compute diff vs baseline and schedule if non-empty. If empty, calls onNoDiff.
  void computeAndScheduleDiff(String id, String collectionName) {
    final map = toSyncMapForId(id);
    if (map == null) return;
    final current = sanitize(map);

    Map<String, dynamic> last = _lastSyncedById[id] ?? <String, dynamic>{};

    Map<String, dynamic> patch = {};

    // collectionType & userProvider are non-null by signature; always attempt cached diff first
    final key = '$userId|${collectionName}|$id';
    final dbCache = realm.find<SyncDBCache>(key);
    if (dbCache != null) {
      try {
        final raw = jsonDecode(dbCache.diffJson) as Map<String, dynamic>;
        patch = rehydratePatch(raw);
        // Diff consumed: remove the cache entry so we don't resend stale patches after baseline update.
        try {
          realm.write(() {
            realm.delete(dbCache);
          });
        } catch (e) {
          AppLogger.log(
            'SyncHelper: failed to delete consumed DBCache $key: $e',
          );
        }
      } catch (e) {
        // Malformed JSON in DBCache, fall back to computing diff
        AppLogger.log(
          'SyncHelper: malformed DBCache $key, recomputing diff: $e',
        );
        patch = diff(last, current);
        // Clean up corrupted entry
        try {
          realm.write(() => realm.delete(dbCache));
        } catch (_) {}
      }
    } else {
      // Fallback to computing on the fly if cache not present
      patch = diff(last, current);
    }

    // Create a check if there already same thing exists in queue or outbox patch and we dont overflow the queue

    if (patch.isEmpty) {
      if (onNoDiff != null) onNoDiff!(id);
      return;
    }

    _schedule(id, patch);
  }

  // Internal mechanics
  void _schedule(String id, Map<String, dynamic> patch) {
    // If a delete is already pending for this id, ignore update patches
    if (_pendingDeleteIds.contains(id)) {
      return;
    }
    // Dedupe: if incoming patch adds no new or changed keys compared to existing pending patch, skip.
    final existing = _pendingPatchById[id];
    if (existing != null && _isDuplicatePatch(existing, patch)) {
      // Nothing new to schedule; avoid extra debounce/outbox persist spam.
      return;
    }
    final merged = Map<String, dynamic>.from(existing ?? <String, dynamic>{});
    merged.addAll(patch);
    _pendingPatchById[id] = merged;
    // Assign patchId if not already present for this entity
    _patchIdById[id] ??= _generatePatchId();

    if (enableBatching) {
      // Add to batch and schedule batch flush
      _batchPendingIds.add(id);
      _scheduleBatchFlush();
    } else {
      // Original behavior: individual debounced flush
      _debouncers[id]?.cancel();
      _debouncers[id] = Timer(debounceDelay, () => _flush(id));
    }

    _ensureHeartbeat();

    // Persist outbox after scheduling a new/updated patch
    // Fire and forget to avoid blocking UI thread
    unawaited(_persistOutbox());
  }

  /// Schedule a batch flush to combine multiple changes into a single server call
  void _scheduleBatchFlush() {
    _batchTimer?.cancel();
    _batchTimer = Timer(batchWindow, () => _flushBatch());
    AppLogger.log(
      'SyncHelper: batch timer scheduled for ${batchWindow.inMilliseconds}ms, pending: ${_pendingPatchById.length} patches, ${_pendingDeleteIds.length} deletes',
    );
  }

  /// Flush all pending changes in a single batch
  Future<void> _flushBatch() async {
    AppLogger.log(
      'SyncHelper: _flushBatch called, _batchPendingIds.length=${_batchPendingIds.length}, socket.connected=${socket.connected}',
    );
    if (_batchPendingIds.isEmpty) return;

    // Take a snapshot of pending IDs and clear the set
    final idsToFlush = Set<String>.from(_batchPendingIds);
    _batchPendingIds.clear();
    AppLogger.log('SyncHelper: flushing batch of ${idsToFlush.length} items');

    // If batch is too large, split it
    if (idsToFlush.length > _maxBatchSize) {
      final chunks = <Set<String>>[];
      final idsList = idsToFlush.toList();
      for (var i = 0; i < idsList.length; i += _maxBatchSize) {
        final end =
            (i + _maxBatchSize < idsList.length)
                ? i + _maxBatchSize
                : idsList.length;
        chunks.add(Set<String>.from(idsList.sublist(i, end)));
      }

      // Flush each chunk
      for (final chunk in chunks) {
        await _flushBatchChunk(chunk);
      }
    } else {
      await _flushBatchChunk(idsToFlush);
    }
  }

  /// Flush a chunk of changes in a single batch operation
  Future<void> _flushBatchChunk(Set<String> ids) async {
    if (ids.isEmpty) return;
    if (socket.connected == false) {
      // Reschedule individual flushes on reconnect
      for (final id in ids) {
        _scheduleRetry(id);
      }
      return;
    }

    final changes = <Map<String, dynamic>>[];
    final upsertIds = <String>[];
    final deleteIds = <String>[];

    for (final id in ids) {
      // Separate deletes from upserts
      if (_pendingDeleteIds.contains(id)) {
        deleteIds.add(id);
        continue;
      }

      if (_inFlightById[id] == true) continue; // Skip if already in flight

      final Map<String, dynamic> toSendRaw = Map<String, dynamic>.from(
        _pendingPatchById[id] ?? {},
      );
      if (toSendRaw.isEmpty) continue;

      final patchId = _patchIdById[id];
      if (patchId != null) {
        toSendRaw['patchId'] = patchId;
      }

      final toSend = toSendRaw.toServerMap();
      toSend['_id'] = id;
      toSend['sync_updated_at'] ??= DBTime().toUtc().millisecondsSinceEpoch;

      changes.add({
        'operation': 'upsert',
        'collectionName': collectionName,
        'documentId': id,
        'data': toSend,
        'patchId': patchId,
      });
      upsertIds.add(id);
    }

    // Handle deletes
    for (final id in deleteIds) {
      if (_inFlightById[id] == true) continue;

      final patchId = _patchIdById[id];
      changes.add({
        'operation': 'delete',
        'collectionName': collectionName,
        'documentId': id,
        'patchId': patchId,
      });
    }

    if (changes.isEmpty) return;

    // Mark all as in-flight
    for (final id in ids) {
      _inFlightById[id] = true;
    }

    try {
      AppLogger.log(
        'SyncHelper: emitting sync:changeBatch with ${changes.length} changes to socket (connected=${socket.connected})',
      );
      // Prepare payload
      Map<String, dynamic> payload = {
        'changes': changes,
      };
      // Apply pre-processor if provided
      if (emitPreProcessor != null) {
        payload = emitPreProcessor!(payload);
      }
      // Emit batch to server
      final ackFuture = socket.emitWithAckAsync('sync:changeBatch', payload);

      final timed = await Future.any([
        ackFuture,
        Future.delayed(_ackTimeout, () => '__timeout__'),
      ]);

      final res = timed;
      final success = (res != null && res != '__timeout__');

      if (success && res is Map) {
        // Process individual acks
        final results = res['results'] as List?;
        if (results != null) {
          for (var i = 0; i < results.length && i < changes.length; i++) {
            final result = results[i] as Map?;
            final change = changes[i];
            final id = change['documentId'] as String;
            final itemSuccess = result?['success'] == true;

            if (itemSuccess) {
              if (change['operation'] == 'delete') {
                _pendingDeleteIds.remove(id);
              } else {
                if (onAckSuccess != null) onAckSuccess!(id);
                setBaselineFromModel(id);
                _pendingPatchById[id] = {};
              }
              _retryCountById[id] = 0;
              _patchIdById.remove(id);

              // Remove outbox entry
              try {
                final key = '${userId}|${collectionName}|$id';
                final existing = realm.find<SyncOutboxPatch>(key);
                if (existing != null) {
                  realm.write(() => realm.delete(existing));
                }
              } catch (e) {
                AppLogger.log('Outbox delete on batch ack failed: $e');
              }
            } else {
              _scheduleRetry(id);
            }
            _inFlightById[id] = false;
          }
        }
        AppLogger.log('SyncHelper: batch of ${changes.length} changes synced');
      } else {
        // Batch failed, schedule individual retries
        for (final id in ids) {
          _scheduleRetry(id);
          _inFlightById[id] = false;
        }
        AppLogger.log('SyncHelper: batch sync failed or timed out');
      }

      unawaited(_persistOutbox());
    } catch (e) {
      AppLogger.log('SyncHelper batch error: $e', error: e, isError: true);
      for (final id in ids) {
        _scheduleRetry(id);
        _inFlightById[id] = false;
      }
    }
  }

  /// Schedule a deletion for the given entity id. This will take precedence
  /// over any pending patches for the same id and will be persisted in outbox.
  void scheduleDelete(String id) {
    // Mark delete and clear any pending patch
    _pendingDeleteIds.add(id);
    _pendingPatchById[id] = <String, dynamic>{};
    _patchIdById[id] ??= _generatePatchId();

    _debouncers[id]?.cancel();
    _debouncers[id] = Timer(debounceDelay, () => _flushDelete(id));

    _ensureHeartbeat();
    unawaited(_persistOutbox());
  }

  Future<void> _flush(String id) async {
    // If a delete is pending, prefer delete flow
    if (_pendingDeleteIds.contains(id)) {
      await _flushDelete(id);
      return;
    }

    if (socket.connected == false) {
      AppLogger.log('SyncHelper: socket null or unauthenticated');
      _scheduleRetry(id);
      return;
    }

    // Build raw patch first (without date wrapping) so we can inject mandatory fields
    final Map<String, dynamic> toSendRaw = Map<String, dynamic>.from(
      _pendingPatchById[id] ?? {},
    );
    // Ensure patchId travels with payload
    final patchId = _patchIdById[id];
    if (patchId != null) {
      toSendRaw['patchId'] = patchId;
    }
    // For chatrooms, always include mandatory identity fields used by backend auth/routing

    final toSend = toSendRaw.toServerMap();
    if (toSend.isEmpty) return;
    if (_inFlightById[id] == true) {
      _schedule(id, {});
      return;
    }

    // Ensure required identifiers aligned with server expectations
    toSend['_id'] = id;
    toSend['sync_updated_at'] ??= DBTime().toUtc().millisecondsSinceEpoch;

    Map<String, dynamic> payload = mongoOperations.upsertOperation(
      collectionName,
      toSend,
    );
    if (patchId != null) {
      payload['patchId'] = patchId; // top-level for server idempotency ease
    }
    final update = payload['update'];
    if (update is Map<String, dynamic>) {
      payload['update'] = update.toServerMap();
      // Propagate user identity for server-side attribution/scoping
      payload['update']['userId'] = userId;
    }

    _inFlightById[id] = true;
    bool success = false;
    try {
      // Apply pre-processor if provided
      if (emitPreProcessor != null) {
        payload = emitPreProcessor!(payload);
      }
      // Impose an ack timeout so we don't hang indefinitely
      final ackFuture = socket.emitWithAckAsync(
        MongoDBType.mongoUpsert.toValue(),
        payload,
      );
      final timed = await Future.any([
        ackFuture,
        Future.delayed(_ackTimeout, () => '__timeout__'),
      ]);
      final res = timed;
      success =
          (res == null) ? false : (res.toString().toLowerCase() != 'error');
      if (res == '__timeout__') success = false;

      if (success) {
        if (onAckSuccess != null) onAckSuccess!(id);
        setBaselineFromModel(id);
        _pendingPatchById[id] = {};
        _retryCountById[id] = 0;
        _patchIdById.remove(id); // Clear patchId after successful ack
        AppLogger.log('SyncHelper ack($collectionName:$id): ${res ?? 'null'}');
        // Remove outbox entry for this entityId
        try {
          final key = '${userId}|${collectionName}|$id';
          final existing = realm.find<SyncOutboxPatch>(key);
          if (existing != null) {
            realm.write(() => realm.delete(existing));
          }
        } catch (e) {
          AppLogger.log('Outbox delete on ack failed: $e');
        }
        unawaited(_persistOutbox());
      } else {
        AppLogger.log(
          'SyncHelper: server returned error or no ack for $collectionName:$id',
        );
      }
    } catch (e) {
      AppLogger.log('SyncHelper error: $e', error: e, isError: true);
    } finally {
      _inFlightById[id] = false;
      if (success) {
        if ((_pendingPatchById[id] ?? {}).isNotEmpty) {
          Future.microtask(() => _flush(id));
        }
      } else {
        _scheduleRetry(id);
      }
    }
  }

  Future<void> _flushDelete(String id) async {
    if (!_pendingDeleteIds.contains(id)) return;
    if (_inFlightById[id] == true) {
      // reschedule after debounce window
      _debouncers[id]?.cancel();
      _debouncers[id] = Timer(debounceDelay, () => _flushDelete(id));
      return;
    }

    if (socket.connected == false) {
      AppLogger.log('SyncHelper(delete): socket null or unauthenticated');
      _scheduleRetry(id);
      return;
    }

    var payload = mongoOperations.deleteOperation(collectionName, {
      '_id': id,
      // Propagate user identity for server-side attribution/scoping
      'userId': userId,
    });
    final patchId = _patchIdById[id];
    if (patchId != null) {
      payload['patchId'] = patchId;
    }

    _inFlightById[id] = true;
    bool success = false;
    try {
      // Apply pre-processor if provided
      if (emitPreProcessor != null) {
        payload = emitPreProcessor!(payload);
      }
      final ackFuture = socket.emitWithAckAsync(
        MongoDBType.mongoDelete.toValue(),
        payload,
      );
      final timed = await Future.any([
        ackFuture,
        Future.delayed(_ackTimeout, () => '__timeout__'),
      ]);
      final res = timed;
      success =
          (res == null) ? false : (res.toString().toLowerCase() != 'error');
      if (res == '__timeout__') success = false;

      if (success) {
        _pendingDeleteIds.remove(id);
        _pendingPatchById[id] = {};
        _retryCountById[id] = 0;
        _patchIdById.remove(id);
        AppLogger.log(
          'SyncHelper delete ack($collectionName:$id): ${res ?? 'null'}',
        );
        // Remove outbox entry for this entityId
        try {
          final key = '${userId}|${collectionName}|$id';
          final existing = realm.find<SyncOutboxPatch>(key);
          if (existing != null) {
            realm.write(() => realm.delete(existing));
          }
        } catch (e) {
          AppLogger.log('Outbox delete on ack failed: $e');
        }
        unawaited(_persistOutbox());
      } else {
        AppLogger.log(
          'SyncHelper: server returned error or no ack for delete $collectionName:$id',
        );
      }
    } catch (e) {
      AppLogger.log('SyncHelper delete error: $e', error: e, isError: true);
    } finally {
      _inFlightById[id] = false;
      if (!success) {
        _scheduleRetry(id);
      }
    }
  }

  // Public: try to flush all pending patches immediately (used on reconnect)
  Future<void> flushAllPending() async {
    // Copy keys to avoid mutation during iteration
    final patchIds = List<String>.from(_pendingPatchById.keys);
    for (final id in patchIds) {
      if ((_pendingPatchById[id] ?? {}).isEmpty) continue;
      if (_pendingDeleteIds.contains(id)) continue; // delete takes precedence
      if (_inFlightById[id] == true) continue;
      await _flush(id);
    }

    // Flush deletes last
    final deleteIds = List<String>.from(_pendingDeleteIds);
    for (final id in deleteIds) {
      if (_inFlightById[id] == true) continue;
      await _flushDelete(id);
    }
  }

  void _scheduleRetry(String id) {
    _retryTimersById[id]?.cancel();
    final count = (_retryCountById[id] ?? 0) + 1;
    _retryCountById[id] = count;

    int delayMs;
    
    if (socket.connected) {
      // Socket is connected - use aggressive retry with shorter exponential backoff
      // This handles transient server errors, rate limits, or processing delays
      final base = 500; // 500ms base when connected
      delayMs = base * (1 << (count - 1));
      if (delayMs > 10000) delayMs = 10000; // Cap at 10s when connected
      
      // Add small jitter to prevent thundering herd
      final jitter = (delayMs * 0.15).toInt();
      delayMs = delayMs + (DBTime().millisecond % (jitter + 1)) - (jitter ~/ 2);
      if (delayMs < 500) delayMs = 500;
    } else {
      // Socket is disconnected - use conservative backoff to avoid wasting resources
      // The heartbeat will trigger flushAllPending() once reconnected anyway
      final base = 2000; // 2s base when disconnected
      delayMs = base * (1 << (count - 1));
      if (delayMs > 60000) delayMs = 60000; // Cap at 60s when disconnected
      
      // Larger jitter for disconnected state
      final jitter = (delayMs * 0.2).toInt();
      delayMs = delayMs + (DBTime().millisecond % (jitter + 1)) - (jitter ~/ 2);
      if (delayMs < 2000) delayMs = 2000;
    }

    AppLogger.log(
      'SyncHelper: retry #$count for $collectionName:$id in ${delayMs}ms (socket ${socket.connected ? "connected" : "disconnected"})',
    );
    
    _retryTimersById[id] = Timer(Duration(milliseconds: delayMs), () {
      if (_inFlightById[id] == true) return;
      
      // Recheck socket connection before retry attempt
      if (!socket.connected) {
        AppLogger.log(
          'SyncHelper: retry for $collectionName:$id skipped - socket disconnected',
        );
        _scheduleRetry(id); // Reschedule with disconnected backoff
        return;
      }
      
      if (_pendingDeleteIds.contains(id)) {
        _flushDelete(id);
      } else if ((_pendingPatchById[id] ?? {}).isNotEmpty) {
        _flush(id);
      }
    });
  }

  // Utilities
  void cancelForId(String id) {
    _debouncers[id]?.cancel();
    _retryTimersById[id]?.cancel();
    _inFlightById[id] = false;
    _pendingPatchById[id] = {};
    _pendingDeleteIds.remove(id);
    _patchIdById.remove(id);
  }

  /// Cleanup expired or over-attempted outbox entries
  /// TTL: 48 hours, Max attempts: 100
  Future<void> cleanupOutbox() async {
    try {
      const maxTtlMs = 48 * 60 * 60 * 1000; // 48 hours
      const maxAttempts = 100;
      final now = DateTime.now();
      final cutoffTime = now.subtract(Duration(milliseconds: maxTtlMs));

      final expired = realm.query<SyncOutboxPatch>(
        'uid == \$0 AND collection == \$1 AND (createdAt < \$2 OR attempts >= \$3)',
        [userId, collectionName, cutoffTime, maxAttempts],
      );

      if (expired.isNotEmpty) {
        realm.write(() {
          for (final entry in expired) {
            AppLogger.log(
              'Outbox cleanup: removing ${entry.entityId} (age: ${now.difference(entry.createdAt ?? now).inHours}h, attempts: ${entry.attempts})',
            );
            realm.delete(entry);
          }
        });
        AppLogger.log(
          'Outbox cleanup: removed ${expired.length} expired entries for $collectionName',
        );
      }
    } catch (e) {
      AppLogger.log('Outbox cleanup failed: $e');
    }
  }

  void dispose() {
    try {
      _heartbeatTimer?.cancel();
      _batchTimer?.cancel();
    } catch (_) {}
    for (final t in _debouncers.values) {
      t?.cancel();
    }
    for (final t in _retryTimersById.values) {
      t?.cancel();
    }
    _debouncers.clear();
    _retryTimersById.clear();
    _batchPendingIds.clear();
    // Unregister instance
    _instances.remove(this);
  }

  // Simple random patch id (could switch to UUID or content hash later)
  String _generatePatchId() {
    // Using UUID v4 for strong uniqueness across devices and sessions.
    return const uuid.Uuid().v4();
  }

  // -------- Duplicate Patch Helpers --------
  bool _isDuplicatePatch(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    if (incoming.isEmpty) return true; // treat empty as duplicate / no-op
    // Every key & value in incoming must exist unchanged in existing.
    for (final entry in incoming.entries) {
      if (!existing.containsKey(entry.key)) return false;
      if (!deepEquals(existing[entry.key], entry.value)) return false;
    }
    return true;
  }

  // Flush all helpers' outboxes (used on socket connect/reconnect)
  Future<void> flushAllOutboxes() async {
    if (_instances.isEmpty) return;

    for (final helper in _instances) {
      try {
        await helper.initOutbox();
        await helper.flushAllPending();
      } catch (e) {
        AppLogger.log(
          'SyncHelper.flushAllOutboxes error: $e',
          error: e,
          isError: true,
        );
      }
    }
  }
}
