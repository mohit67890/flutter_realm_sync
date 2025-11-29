import 'dart:async';

import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'Models/SyncMetadata.dart';
import 'RealmHelpers/RealmJson.dart';
import 'RealmHelpers/SyncValidator.dart';
import 'SyncHelper.dart';
import 'utils/AppLogger.dart';

/// Configuration for one collection/model to be synced.
///
/// **Minimum Required Configuration (4 fields):**
/// - `results`: RealmResults to sync
/// - `collectionName`: MongoDB collection name
/// - `idSelector`: Function to extract ID from model
/// - `needsSync`: Predicate to determine if model needs syncing
///
/// **Automatic Behaviors:**
/// - **Serialization**: Automatically uses the best available method:
///   1. Custom `toSyncMap` if provided by user
///   2. Generated `toEJson()` from `.realm.dart` files (handles nested objects perfectly)
///   3. Schema introspection fallback
/// - **Nested Objects**: All RealmObject relationships (to-one, to-many, embedded)
///   are automatically serialized recursively without any configuration
/// - **Sanitization**: Removes 'sync_update_db' field by default
/// - **Flag Management**: Automatically clears syncUpdateDb after successful sync
///
/// **Optional Customization:**
/// - Custom serialization: `toSyncMap`, `fromServerMap`
/// - Schema hints: `propertyNames`, `embeddedProperties` (rarely needed)
/// - Additional callbacks: `applyAckSuccess`, `applyNoDiff`, `sanitize`
class SyncCollectionConfig<T extends RealmObject> {
  final RealmResults<T> results;
  final String collectionName;
  // Use dynamic parameter types to avoid contravariance issues at runtime
  final String Function(dynamic model) idSelector;
  final bool Function(dynamic model) needsSync;

  // Optional custom mappers; if absent, RealmJson is used.
  final Map<String, dynamic> Function(dynamic model)? toSyncMap;
  // Return type is covariant; subtype (e.g., ChatMessage) works for RealmObject
  final RealmObject Function(Map<String, dynamic> serverMap)? fromServerMap;

  // RealmJson fallback configuration (optional - auto-detects from schema if not provided)
  final List<String>? propertyNames;
  final Map<String, List<String>>? embeddedProperties;
  final Map<String, dynamic Function(Map<String, dynamic>)>? embeddedCreators;
  final T Function()? create;
  // Decoder that captures generic T at construction time to avoid type erasure issues
  // If not provided, defaults to: fromServerMap ?? RealmJson.fromEJsonMap<T>(...)
  final RealmObject Function(Map<String, dynamic> data)? decode;

  /// Optional callback after successful sync acknowledgment.
  /// Note: syncUpdateDb flag is automatically cleared - this is for additional custom logic.
  final void Function(dynamic model)? applyAckSuccess;

  /// Optional callback when no changes were detected during sync.
  /// Note: syncUpdateDb flag is automatically cleared - this is for additional custom logic.
  final void Function(dynamic model)? applyNoDiff;

  /// Optional data sanitizer before sending to server.
  /// Default: removes 'sync_update_db' field.
  final Map<String, dynamic> Function(Map<String, dynamic>)? sanitize;

  SyncCollectionConfig({
    required this.results,
    required this.collectionName,
    required this.idSelector,
    required this.needsSync,
    this.toSyncMap,
    this.fromServerMap,
    this.propertyNames,
    this.embeddedProperties,
    this.embeddedCreators,
    this.create,
    this.applyAckSuccess,
    this.applyNoDiff,
    this.sanitize,
    RealmObject Function(Map<String, dynamic> data)? decode,
  }) : decode = decode ?? ((Map<String, dynamic> map) {
          if (fromServerMap != null) {
            return fromServerMap(map);
          }
          return RealmJson.fromEJsonMap<T>(
            map,
            create: create,
            propertyNames: propertyNames,
            embeddedCreators: embeddedCreators,
          );
        });
}

/// Unified change event emitted by MultiRealmSync for any synced collection.
class SyncObjectEvent {
  final String collectionName;
  final String id;
  final RealmObject object; // concrete instance

  SyncObjectEvent(this.collectionName, this.id, this.object);
}

/// Manages multiple collection sync helpers & merges their change streams into a single broadcast stream.
class RealmSync {
  final Realm realm;
  final Socket socket;
  final String userId; // Unique user identifier for sync attribution
  final List<SyncCollectionConfig> configs; // erased generics for storage

  final Map<String, SyncHelper> _helpers = {}; // collectionName -> helper
  final Map<String, StreamSubscription> _subscriptions =
      {}; // collectionName -> sub
  final StreamController<SyncObjectEvent> _controller =
      StreamController<SyncObjectEvent>.broadcast();
  final Map<String, int> _lastRemoteTsByCollection = {}; // UTC millis
  bool _started = false;
  // Track active subscriptions per collection: filter expr + args
  final Map<String, Map<String, dynamic>> _subscriptionsByCollection = {};

  // Flag to prevent change listeners from triggering during server updates
  // This eliminates unnecessary computeDiff/cancelForId calls when applying
  // changes received from the server
  bool _isApplyingServerUpdate = false;

  RealmSync({
    required this.realm,
    required this.socket,
    required this.userId,
    required List<SyncCollectionConfig> configs,
  }) : configs = List<SyncCollectionConfig>.from(configs) {
    if (userId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'userId cannot be empty - required for sync attribution and security',
      );
    }
    // Load persisted sync timestamps from Realm
    _loadPersistedTimestamps();
  }

  Stream<SyncObjectEvent> get changes => _controller.stream;

  // Subscribe to server updates for a collection with a filter matching client RealmResults.
  // filterExpr: Realm Query Language string (e.g., 'status == $0 AND ownerId == $1')
  // args: values for placeholders
  void subscribe(
    String collectionName, {
    required String filterExpr,
    List<dynamic> args = const [],
  }) {
    _subscriptionsByCollection[collectionName] = {
      'filter': filterExpr,
      'args': args,
    };
    socket.emit('sync:subscribe', {
      'collection': collectionName,
      'filter': filterExpr,
      'args': args,
    });
  }

  void unsubscribe(String collectionName) {
    _subscriptionsByCollection.remove(collectionName);
    socket.emit('sync:unsubscribe', {'collection': collectionName});
  }

  void start() {
    if (_started) return;

    for (final cfg in configs) {
      // Comprehensive validation before starting sync
      SyncValidator.validateConfig(cfg);
      SyncValidator.validateSampleModels(cfg);

      // Build helper per collection
      final helper = SyncHelper(
        realm: realm,
        socket: socket,
        userId: userId,
        collectionName: cfg.collectionName,
        toSyncMapForId: (String id) {
          // Linear scan to find object by id (safe for all types)
          // Use dynamic invocation to bypass generic type constraints
          String idFromModel(dynamic model) {
            try {
              return Function.apply(cfg.idSelector as Function, [model]);
            } catch (e) {
              // Fallback: assume the model has an id property and convert to string
              final id = (model as dynamic).id;
              return id is String ? id : id.toString();
            }
          }

          for (final m in cfg.results) {
            if (idFromModel(m) == id) {
              // Prefer user-provided mapper
              if (cfg.toSyncMap != null) {
                return cfg.toSyncMap!(m as dynamic);
              }

              // RealmJson now automatically tries toEJson() first, then falls back
              final result = RealmJson.toJsonWith(
                m,
                cfg.propertyNames,
                embeddedProperties: cfg.embeddedProperties,
              );
              AppLogger.log(
                'toSyncMapForId($id) returning: ${result.keys.toList()}',
              );
              return result;
            }
          }
          return null;
        },
        sanitize:
            cfg.sanitize ??
            (Map<String, dynamic> src) {
              final out = Map<String, dynamic>.from(src);
              out.remove('sync_update_db');
              return out;
            },
        onAckSuccess: (String id) {
          realm.write(() {
            for (final m in cfg.results) {
              // Use Function.apply to bypass type checking
              final objId = Function.apply(cfg.idSelector as Function, [m]);
              if (objId == id) {
                // Call user-provided callback first if present
                cfg.applyAckSuccess?.call(m as dynamic);
                // Automatically clear sync_update_db flag if it exists
                _clearSyncFlag(m);
                break;
              }
            }
          });
        },
        onNoDiff: (String id) {
          realm.write(() {
            for (final m in cfg.results) {
              // Use Function.apply to bypass type checking
              final objId = Function.apply(cfg.idSelector as Function, [m]);
              if (objId == id) {
                // Call user-provided callback first if present
                cfg.applyNoDiff?.call(m as dynamic);
                // Automatically clear sync_update_db flag if it exists
                _clearSyncFlag(m);
                break;
              }
            }
          });
        },
      );

      _helpers[cfg.collectionName] = helper;

      // Outbox hydration + initial flush
      helper.initOutbox().then((_) => helper.flushAllPending());

      // Queue full sync for existing items needing sync
      for (final m in cfg.results) {
        try {
          // Use Function.apply to bypass type checking
          final needsSync =
              Function.apply(cfg.needsSync as Function, [m]) as bool;

          if (needsSync) {
            final id = Function.apply(cfg.idSelector as Function, [m]);
            helper.scheduleFullSync(id);
          }
        } catch (e) {
          AppLogger.log('${cfg.collectionName} Error queueing sync: $e');
        }
      }

      // Listen for changes in this collection
      final sub = cfg.results.changes.listen(
        (changes) {
          AppLogger.log(
            '${cfg.collectionName} results.changes fired: ${changes.results.length} items, _isApplyingServerUpdate=$_isApplyingServerUpdate',
          );
          // Skip processing if we're applying server updates
          // This prevents unnecessary computeDiff and cancelForId calls
          if (_isApplyingServerUpdate) return;

          // Note: Due to Dart's type erasure with List<SyncCollectionConfig>,
          // we need to be careful with type conversions here
          for (final m in changes.results) {
            try {
              // Use Function.apply to bypass type checking
              final needsSync =
                  Function.apply(cfg.needsSync as Function, [m]) as bool;

              if (needsSync) {
                final id = Function.apply(cfg.idSelector as Function, [m]);

                // Note: sync_updated_at should be set by user in their write() block
                // We can't update it here as we're in a change notification callback

                AppLogger.log(
                  '${cfg.collectionName} needsSync=true for $id, calling computeAndScheduleDiff',
                );
                helper.computeAndScheduleDiff(id, cfg.collectionName);
                _controller.add(SyncObjectEvent(cfg.collectionName, id, m));
                AppLogger.log('${cfg.collectionName} queued partial sync $id');
              } else {
                AppLogger.log(
                  '${cfg.collectionName} needsSync=false for item, skipping',
                );
              }
            } catch (e) {
              AppLogger.log(
                '${cfg.collectionName} Error processing change: $e',
              );
            }
          }
        },
        onError: (error) {
          AppLogger.log(
            '${cfg.collectionName} Sync Error: $error',
            error: error,
            isError: true,
          );
        },
        onDone: () {
          AppLogger.log('${cfg.collectionName} Sync Done');
        },
      );
      _subscriptions[cfg.collectionName] = sub;
    }

    // Inbound: bootstrap initial data
    socket.on('sync:bootstrap', (payload) {
      try {
        final collection = payload['collection'] as String?;
        final data = payload['data'] as List<dynamic>?;
        if (collection == null || data == null) return;
        final cfg = configs.firstWhere(
          (c) => c.collectionName == collection,
          orElse: () => throw StateError('Unknown collection: $collection'),
        );
        final helper = _helpers[collection];
        if (helper == null) return;

        // Set flag to prevent change listeners from triggering syncs
        _isApplyingServerUpdate = true;
        try {
          // Apply all bootstrap objects in a single transaction; defer timestamp persistence
          realm.write(() {
            for (final d in data) {
              final map = Map<String, dynamic>.from(d as Map);
              final id = (map['_id'] ?? map['id']).toString();
              // Ensure UTC updated marker
              final ts =
                  map['sync_updated_at'] is int
                      ? (map['sync_updated_at'] as int)
                      : DateTime.now().toUtc().millisecondsSinceEpoch;
              map['_id'] = id;
              map['sync_updated_at'] = ts;
                // Use config-captured decoder (preserves generic T)
                final RealmObject obj = cfg.decode!(map);
              realm.add(obj, update: true);
              helper.cancelForId(id);
              helper.setBaselineFromModel(id);
              final newTs = _max(_lastRemoteTsByCollection[collection], ts);
              _lastRemoteTsByCollection[collection] = newTs;
            }
          });
          // Persist latest timestamp AFTER write transaction
          final latest = _lastRemoteTsByCollection[collection];
          if (latest != null) {
            _persistTimestamp(collection, latest);
          }
        } finally {
          _isApplyingServerUpdate = false;
        }
      } catch (e) {
        AppLogger.log('bootstrap apply error: $e', error: e, isError: true);
      }
    });

    // Inbound: apply server changes with conflict management (UTC millis)
    socket.on('sync:changes', (raw) {
      try {
        final list = (raw as List).cast<Map>();

        // Set flag to prevent change listeners from triggering syncs
        _isApplyingServerUpdate = true;
        try {
          final Set<String> touchedCollections = <String>{};
          realm.write(() {
            for (final c in list) {
              final collection = c['collection']?.toString();
              final id = c['documentId']?.toString();
              final op = c['operation']?.toString();
              final ts =
                  c['timestamp'] is int
                      ? (c['timestamp'] as int)
                      : DateTime.now().toUtc().millisecondsSinceEpoch;
              if (collection == null || id == null || op == null) continue;
              final cfg = configs.firstWhere(
                (cfg) => cfg.collectionName == collection,
                orElse:
                    () => throw StateError('Unknown collection: $collection'),
              );
              final helper = _helpers[collection];
              if (helper == null) continue;

              // Conflict: skip if local newer/equal
              // Find existing object by scanning the results (type-safe approach)
              RealmObject? existing;
              for (final obj in cfg.results) {
                // Use dynamic invocation to bypass type checking
                final objId = Function.apply(cfg.idSelector as Function, [obj]);
                if (objId == id) {
                  existing = obj;
                  break;
                }
              }
              final localTs = _readUpdatedAt(existing);
              if (localTs != null && localTs >= ts) {
                final newTs = _max(_lastRemoteTsByCollection[collection], ts);
                _lastRemoteTsByCollection[collection] = newTs;
                touchedCollections.add(collection);
                continue;
              }

              if (op == 'delete') {
                if (existing != null) {
                  realm.delete(existing);
                }
                helper.cancelForId(id);
              } else {
                final data = Map<String, dynamic>.from(
                  (c['data'] as Map?) ?? {},
                );
                data['_id'] = id;
                data['sync_updated_at'] = ts; // UTC millis
                final RealmObject obj = cfg.decode!(data);
                realm.add(obj, update: true);
                helper.cancelForId(id);
                helper.setBaselineFromModel(id);
              }

              final newTs = _max(_lastRemoteTsByCollection[collection], ts);
              _lastRemoteTsByCollection[collection] = newTs;
              touchedCollections.add(collection);
            }
          });
          // Persist timestamps outside the write transaction
          for (final col in touchedCollections) {
            final latest = _lastRemoteTsByCollection[col];
            if (latest != null) {
              _persistTimestamp(col, latest);
            }
          }
        } finally {
          _isApplyingServerUpdate = false;
        }
      } catch (e) {
        AppLogger.log('sync:changes apply error: $e', error: e, isError: true);
      }
    });

    // Optionally on reconnect: request missed changes since lastRemoteTs
    socket.on('connect', (_) {
      for (final cfg in configs) {
        final since = _lastRemoteTsByCollection[cfg.collectionName] ?? 0;
        final sub = _subscriptionsByCollection[cfg.collectionName];
        socket.emitWithAck(
          'sync:get_changes',
          {
            'userId': userId, // pass authenticated userId for server scoping
            'collection': cfg.collectionName,
            'since': since,
            'limit': 500,
            if (sub != null) 'filter': sub['filter'],
            if (sub != null) 'args': sub['args'],
          },
          ack: (resp) {
            try {
              final map = (resp as Map?) ?? const {};
              final changes = (map['changes'] as List?) ?? const [];
              final latest = map['latestTimestamp'] as int?;
              if (latest != null) {
                final newTs = _max(
                  _lastRemoteTsByCollection[cfg.collectionName],
                  latest,
                );
                _lastRemoteTsByCollection[cfg.collectionName] = newTs;
              }
              // Apply changes locally without re-emitting
              final Set<String> touchedCollections = <String>{};
              realm.write(() {
                for (final c in changes.cast<Map>()) {
                  final collection = c['collection']?.toString();
                  final id = c['documentId']?.toString();
                  final op = c['operation']?.toString();
                  final ts =
                      c['timestamp'] is int
                          ? (c['timestamp'] as int)
                          : DateTime.now().toUtc().millisecondsSinceEpoch;
                  if (collection == null || id == null || op == null) continue;
                  final cfg2 = configs.firstWhere(
                    (cfgx) => cfgx.collectionName == collection,
                    orElse:
                        () =>
                            throw StateError('Unknown collection: $collection'),
                  );
                  final helper2 = _helpers[collection];
                  if (helper2 == null) continue;

                  // Find existing object by scanning the results (type-safe approach)
                  RealmObject? existing;
                  for (final obj in cfg2.results) {
                    // Use dynamic invocation to bypass type checking
                    final objId = Function.apply(cfg2.idSelector as Function, [
                      obj,
                    ]);
                    if (objId == id) {
                      existing = obj;
                      break;
                    }
                  }
                  final localTs = _readUpdatedAt(existing);
                  if (localTs != null && localTs >= ts) {
                    final newTs = _max(
                      _lastRemoteTsByCollection[collection],
                      ts,
                    );
                    _lastRemoteTsByCollection[collection] = newTs;
                    touchedCollections.add(collection);
                    continue;
                  }

                  if (op == 'delete') {
                    if (existing != null) {
                      realm.delete(existing);
                    }
                    helper2.cancelForId(id);
                  } else {
                    final data = Map<String, dynamic>.from(
                      (c['data'] as Map?) ?? {},
                    );
                    data['_id'] = id;
                    data['sync_updated_at'] = ts; // UTC millis
                    final RealmObject obj = cfg2.decode!(data);
                    realm.add(obj, update: true);
                    helper2.cancelForId(id);
                    helper2.setBaselineFromModel(id);
                  }

                  final newTs = _max(_lastRemoteTsByCollection[collection], ts);
                  _lastRemoteTsByCollection[collection] = newTs;
                  touchedCollections.add(collection);
                }
              });
              // Persist timestamps after write
              for (final col in touchedCollections) {
                final ts = _lastRemoteTsByCollection[col];
                if (ts != null) {
                  _persistTimestamp(col, ts);
                }
              }
            } catch (_) {}
          },
        );
      }
    });

    _started = true;
  }

  /// Manually trigger sync for a specific object ID in a collection.
  /// This is useful when you need to force an immediate sync without waiting
  /// for the automatic results.changes listener (which may not fire for property changes).
  ///
  /// Uses scheduleFullSync to ensure complete data is sent. This is safer than
  /// computeAndScheduleDiff for manually triggered syncs since the timing of the
  /// trigger relative to the write operation can affect diff computation accuracy.
  void syncObject(String collectionName, String objectId) {
    final helper = _helpers[collectionName];
    if (helper == null) {
      AppLogger.log(
        'RealmSync: no helper found for collection $collectionName',
      );
      return;
    }
    AppLogger.log(
      'RealmSync: manually triggering full sync for $collectionName/$objectId',
    );
    helper.scheduleFullSync(objectId);
  }

  /// Manually trigger sync for multiple objects in a collection.
  void syncObjects(String collectionName, List<String> objectIds) {
    for (final id in objectIds) {
      syncObject(collectionName, id);
    }
  }

  /// Public accessor for the last remote timestamp tracked for a collection.
  /// Returns 0 if no timestamp has been recorded yet.
  int lastRemoteTimestamp(String collectionName) {
    return _lastRemoteTsByCollection[collectionName] ?? 0;
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    for (final helper in _helpers.values) {
      helper.dispose();
    }
    _subscriptions.clear();
    _helpers.clear();
    _controller.close();
    _started = false;
  }

  /// Load persisted sync timestamps from Realm on initialization
  void _loadPersistedTimestamps() {
    try {
      final allMetadata = realm.all<SyncMetadata>();
      for (final meta in allMetadata) {
        _lastRemoteTsByCollection[meta.collectionName] =
            meta.lastRemoteTimestamp;
      }
      if (allMetadata.isNotEmpty) {
        AppLogger.log(
          'RealmSync: Loaded ${allMetadata.length} persisted sync timestamps',
        );
      }
    } catch (e) {
      AppLogger.log('RealmSync: Failed to load persisted timestamps: $e');
    }
  }

  /// Persist sync timestamp to Realm for a collection
  void _persistTimestamp(String collectionName, int timestamp) {
    try {
      realm.write(() {
        realm.add(
          SyncMetadata(
            collectionName,
            timestamp,
            lastUpdated: DateTime.now().toUtc(),
          ),
          update: true,
        );
      });
    } catch (e) {
      AppLogger.log(
        'RealmSync: Failed to persist timestamp for $collectionName: $e',
      );
    }
  }

  // Removed unsafe timestamp persistence helper; timestamps are now persisted
  // outside write transactions after aggregation to avoid nested/write state errors.

  int _max(int? a, int b) => (a == null) ? b : (a > b ? a : b);

  int? _readUpdatedAt(RealmObject? obj) {
    if (obj == null) return null;
    try {
      final dyn = obj as dynamic;
      final v = dyn.sync_updated_at; // assumes model field exists
      if (v is int) return v;
    } catch (_) {}
    return null;
  }

  /// Automatically clear sync_update_db flag if it exists on the object
  void _clearSyncFlag(RealmObject obj) {
    try {
      final dynamic dyn = obj;
      if (dyn.sync_update_db == true) {
        dyn.sync_update_db = false;
      }
    } catch (_) {
      // Field doesn't exist or can't be set - ignore
    }
  }
}
