import 'dart:async';

import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'Models/sync_metadata.dart';
import 'RealmHelpers/realm_json.dart';
import 'RealmHelpers/sync_validator.dart';
import 'sync_helper.dart';
import 'utils/app_logger.dart';

/// Configuration for a single collection/model to be synced between Realm and MongoDB.
///
/// This class defines how a Realm collection should sync with the server, including
/// serialization, conflict resolution, and custom processing logic.
///
/// ## Minimum Required Configuration (4 fields)
///
/// ```dart
/// SyncCollectionConfig<ChatMessage>(
///   results: realm.all<ChatMessage>(),           // Required: What to sync
///   collectionName: 'chat_messages',             // Required: MongoDB collection name
///   idSelector: (obj) => obj.id,                 // Required: How to get object ID
///   needsSync: (obj) => obj.syncUpdateDb,        // Required: When to sync
/// )
/// ```
///
/// ## Automatic Behaviors (Zero Configuration Needed)
///
/// - **Serialization**: Automatically uses generated `toEJson()` from `.realm.dart` files
/// - **Nested Objects**: All relationships (to-one, to-many, embedded) serialize recursively
/// - **Conflict Resolution**: Last-write-wins based on `sync_updated_at` timestamps
/// - **Sanitization**: Removes internal 'sync_update_db' field before sending to server
/// - **Flag Management**: Automatically clears `syncUpdateDb` flag after successful sync
///
/// ## Optional Customization
///
/// ### Custom Serialization
/// ```dart
/// toSyncMap: (obj) => {'_id': obj.id, 'custom': obj.computed},
/// fromServerMap: (map) => MyModel(map['_id'], custom: map['custom']),
/// ```
///
/// ### Pre-Processing Hook (NEW!)
/// ```dart
/// emitPreProcessor: (rawJson) {
///   rawJson['clientVersion'] = '1.0.0';
///   rawJson['deviceId'] = DeviceInfo.id;
///   return rawJson;
/// },
/// ```
///
/// ### Lifecycle Callbacks
/// ```dart
/// applyAckSuccess: (obj) => print('Synced: ${obj.id}'),
/// applyNoDiff: (obj) => print('No changes: ${obj.id}'),
/// ```
///
/// ### Custom Sanitization
/// ```dart
/// sanitize: (map) {
///   map.remove('localOnlyField');
///   return map;
/// },
/// ```
///
/// ## Schema Hints (Rarely Needed)
///
/// Only required if auto-detection fails or for advanced nested object scenarios:
/// ```dart
/// propertyNames: ['id', 'name', 'timestamp', 'sync_updated_at'],
/// embeddedProperties: {'user': ['id', 'name']},
/// embeddedCreators: {'user': (map) => User(map['id'], map['name'])},
/// create: () => MyModel('', '', DateTime.now()),
/// ```
class SyncCollectionConfig<T extends RealmObject> {
  /// The Realm query results to sync. Changes to these objects trigger sync operations.
  ///
  /// Example: `realm.all<ChatMessage>()` or `realm.query<Task>('status == "pending"')`
  final RealmResults<T> results;

  /// MongoDB collection name where data will be synced.
  ///
  /// Must match the collection name on your MongoDB Atlas/server.
  final String collectionName;

  /// Function to extract the unique identifier from a model instance.
  ///
  /// Example: `(obj) => obj.id` or `(obj) => obj.documentId.toString()`
  final String Function(dynamic model) idSelector;

  /// Predicate function to determine if an object needs syncing.
  ///
  /// This is called to filter which objects trigger sync operations. Common patterns:
  /// - Flag-based: `(obj) => obj.syncUpdateDb` (explicit control)
  /// - Always sync: `(obj) => true` (sync every change)
  /// - Conditional: `(obj) => obj.status == 'published'` (business logic)
  ///
  /// **Important**: Return `true` to trigger sync, `false` to skip.
  final bool Function(dynamic model) needsSync;

  /// Optional custom function to serialize objects before sending to server.
  ///
  /// If not provided, uses generated `toEJson()` from `.realm.dart` files.
  /// Use this when you need computed fields or custom transformations.
  ///
  /// Example:
  /// ```dart
  /// toSyncMap: (obj) => {
  ///   '_id': obj.id,
  ///   'displayName': '${obj.firstName} ${obj.lastName}',
  ///   'timestamp': obj.createdAt.toIso8601String(),
  /// }
  /// ```
  final Map<String, dynamic> Function(dynamic model)? toSyncMap;

  /// Optional custom function to deserialize server data into Realm objects.
  ///
  /// If not provided, uses generated `fromEJson()` from `.realm.dart` files.
  /// Use this for custom field mapping or data transformation.
  ///
  /// Example:
  /// ```dart
  /// fromServerMap: (map) => ChatMessage(
  ///   map['_id'],
  ///   map['text'],
  ///   map['sender_name'],
  ///   map['sender_id'],
  ///   DateTime.parse(map['timestamp']),
  /// )
  /// ```
  final RealmObject Function(Map<String, dynamic> serverMap)? fromServerMap;

  /// Optional list of property names for schema introspection fallback.
  ///
  /// Rarely needed - only use if auto-detection fails. Should include all fields
  /// needed for sync, especially 'id'/'_id' and 'sync_updated_at'.
  final List<String>? propertyNames;

  /// Optional nested object property mapping for custom serialization.
  ///
  /// Maps parent property names to their child property lists.
  /// Only needed for complex nested scenarios not handled by `toEJson()`.
  final Map<String, List<String>>? embeddedProperties;

  /// Optional factory functions for creating embedded/nested objects.
  ///
  /// Maps property names to functions that create instances from maps.
  /// Only needed when `fromEJson()` can't handle your nested objects.
  final Map<String, dynamic Function(Map<String, dynamic>)>? embeddedCreators;

  /// Optional factory function to create empty model instances.
  ///
  /// Only needed as fallback when `fromEJson()` is unavailable.
  final T Function()? create;

  /// Internal decoder function that preserves generic type T.
  ///
  /// Automatically set to use `fromServerMap` or `fromEJson<T>()`.
  /// You typically don't need to provide this - it's auto-configured.
  final RealmObject Function(Map<String, dynamic> data)? decode;

  /// Optional callback invoked after successful sync acknowledgment from server.
  ///
  /// Called within a write transaction, so you can safely modify the object.
  /// The `syncUpdateDb` flag is automatically cleared - use this for additional logic.
  ///
  /// Example:
  /// ```dart
  /// applyAckSuccess: (obj) {
  ///   obj.lastSyncedAt = DateTime.now();
  ///   print('Successfully synced: ${obj.id}');
  /// }
  /// ```
  final void Function(dynamic model)? applyAckSuccess;

  /// Optional callback when no changes detected (diff was empty).
  ///
  /// Called within a write transaction. The `syncUpdateDb` flag is automatically
  /// cleared - use this for logging or custom state management.
  ///
  /// Example:
  /// ```dart
  /// applyNoDiff: (obj) {
  ///   print('No changes to sync for: ${obj.id}');
  /// }
  /// ```
  final void Function(dynamic model)? applyNoDiff;

  /// Optional function to sanitize data before sending to server.
  ///
  /// Default behavior removes 'sync_update_db' field. Provide custom implementation
  /// to remove additional local-only fields or transform data.
  ///
  /// Example:
  /// ```dart
  /// sanitize: (map) {
  ///   final clean = Map<String, dynamic>.from(map);
  ///   clean.remove('sync_update_db');
  ///   clean.remove('localCacheData');
  ///   clean.remove('uiStateFlags');
  ///   return clean;
  /// }
  /// ```
  final Map<String, dynamic> Function(Map<String, dynamic>)? sanitize;

  /// Optional pre-processor to modify payload before emitting to server.
  ///
  /// Called just before `socket.emit()` with the complete payload. Perfect for:
  /// - Adding client metadata (app version, device ID, platform)
  /// - Injecting authentication tokens or signatures
  /// - Transforming fields for backend compatibility
  /// - Adding analytics or tracking tags
  ///
  /// **Applied to all operations**: batch changes, individual upserts, and deletes.
  ///
  /// Example:
  /// ```dart
  /// emitPreProcessor: (rawJson) {
  ///   rawJson['clientVersion'] = '2.1.0';
  ///   rawJson['deviceId'] = DeviceInfo.deviceId;
  ///   rawJson['platform'] = Platform.operatingSystem;
  ///   rawJson['timestamp'] = DateTime.now().toIso8601String();
  ///
  ///   // Transform batch operations
  ///   if (rawJson['changes'] is List) {
  ///     for (var change in rawJson['changes']) {
  ///       change['source'] = 'mobile-app';
  ///     }
  ///   }
  ///
  ///   return rawJson;
  /// }
  /// ```
  final Map<String, dynamic> Function(Map<String, dynamic> rawJson)? emitPreProcessor;

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
    this.emitPreProcessor,
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

/// Event emitted when a sync operation completes for an object.
///
/// Contains information about which object was synced and provides
/// access to the updated Realm object instance.
class SyncObjectEvent {
  /// The MongoDB collection name where the object was synced.
  final String collectionName;

  /// The unique identifier of the synced object.
  final String id;

  /// The actual Realm object instance that was synced.
  final RealmObject object;

  SyncObjectEvent(this.collectionName, this.id, this.object);
}

/// Real-time bidirectional sync engine between Realm database and MongoDB Atlas.
///
/// This is the main entry point for sync functionality. It manages multiple collections,
/// handles conflict resolution, coordinates with the server via Socket.IO, and provides
/// a unified stream of all sync events.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Initialize Realm with sync models
/// final realm = Realm(Configuration.local([
///   ChatMessage.schema,
///   SyncMetadata.schema,
///   SyncDBCache.schema,
///   SyncOutboxPatch.schema,
/// ]));
///
/// // 2. Connect Socket.IO
/// final socket = IO.io('http://your-server:3000', ...);
/// socket.connect();
///
/// // 3. Create RealmSync instance
/// final realmSync = RealmSync(
///   realm: realm,
///   socket: socket,
///   userId: 'user-123',
///   configs: [
///     SyncCollectionConfig<ChatMessage>(
///       results: realm.all<ChatMessage>(),
///       collectionName: 'chat_messages',
///       idSelector: (obj) => obj.id,
///       needsSync: (obj) => obj.syncUpdateDb,
///     ),
///   ],
/// );
///
/// // 4. Start syncing
/// realmSync.start();
///
/// // 5. Write data with sync
/// realm.writeWithSync(message, () {
///   message.text = "Hello!";
///   message.syncUpdateDb = true;
/// });
/// realmSync.syncObject('chat_messages', message.id);
/// ```
///
/// ## Features
///
/// - **Automatic Conflict Resolution**: Last-write-wins based on UTC timestamps
/// - **Offline Support**: Changes queue locally and sync when online
/// - **Batch Operations**: Intelligent batching reduces network overhead
/// - **Historic Sync**: Catch up on missed changes after being offline
/// - **Change Stream**: Monitor all sync events via `changes` stream
/// - **Manual Sync**: Force sync specific objects with `syncObject()`
///
/// ## Important Notes
///
/// - **userId is required** for security and multi-user isolation
/// - **Include sync models** in Realm config: SyncMetadata, SyncDBCache, SyncOutboxPatch
/// - **Set sync_updated_at** timestamps using `writeWithSync()` helper
/// - **Call start()** after construction to begin syncing
/// - **Call dispose()** when done to cleanup resources
class RealmSync {
  /// The Realm database instance containing collections to sync.
  final Realm realm;

  /// Socket.IO connection to the sync server.
  ///
  /// Should be connected before calling `start()`. The sync engine
  /// listens for 'sync:bootstrap', 'sync:changes', and 'connect' events.
  final Socket socket;

  /// Unique identifier for the current user.
  ///
  /// Required for:
  /// - Server-side security and data isolation
  /// - Multi-user conflict resolution
  /// - Tracking who made which changes
  /// - Outbox persistence per user
  ///
  /// **Important**: Cannot be empty - will throw ArgumentError if empty.
  final String userId;

  /// List of collection configurations defining what and how to sync.
  ///
  /// Each config specifies one Realm collection/model to sync with MongoDB.
  /// Multiple collections can sync simultaneously with independent configurations.
  final List<SyncCollectionConfig> configs;

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

  /// Stream of all sync events across all collections.
  ///
  /// Listen to this stream to monitor when objects are synced to the server.
  /// Each event contains the collection name, object ID, and the Realm object instance.
  ///
  /// Example:
  /// ```dart
  /// realmSync.changes.listen((event) {
  ///   print('Synced ${event.collectionName}: ${event.id}');
  ///   // Access the actual object: event.object
  /// });
  /// ```
  Stream<SyncObjectEvent> get changes => _controller.stream;

  /// Subscribe to server-side filtered updates for a collection.
  ///
  /// This tells the server to only send changes matching the specified filter,
  /// reducing network traffic and improving performance. The filter should match
  /// your local Realm query to ensure consistency.
  ///
  /// **Parameters:**
  /// - `collectionName`: The MongoDB collection to subscribe to
  /// - `filterExpr`: Realm Query Language filter (e.g., 'status == \$0 AND userId == \$1')
  /// - `args`: Values for filter placeholders in order
  ///
  /// Example:
  /// ```dart
  /// // Subscribe to only active tasks for current user
  /// realmSync.subscribe(
  ///   'tasks',
  ///   filterExpr: 'status == \$0 AND ownerId == \$1',
  ///   args: ['active', currentUserId],
  /// );
  /// ```
  ///
  /// **Important**: Call this before or after `start()`. Server will only send
  /// changes matching this filter for the specified collection.
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

  /// Unsubscribe from server-side filtered updates for a collection.
  ///
  /// Removes the filter subscription, causing the server to stop sending
  /// filtered updates for this collection. The collection will still sync
  /// normally based on local changes.
  ///
  /// Example:
  /// ```dart
  /// realmSync.unsubscribe('tasks');
  /// ```
  void unsubscribe(String collectionName) {
    _subscriptionsByCollection.remove(collectionName);
    socket.emit('sync:unsubscribe', {'collection': collectionName});
  }

  /// Start the sync engine and begin synchronizing all configured collections.
  ///
  /// This method:
  /// 1. Validates all collection configurations
  /// 2. Creates sync helpers for each collection
  /// 3. Hydrates the persistent outbox (restores pending changes)
  /// 4. Queues initial sync for objects marked as needing sync
  /// 5. Sets up Socket.IO event listeners for server updates
  /// 6. Starts monitoring local Realm changes
  ///
  /// **Call this once after construction.** Subsequent calls are ignored.
  ///
  /// Example:
  /// ```dart
  /// final realmSync = RealmSync(realm: realm, socket: socket, ...);
  /// realmSync.start(); // Start syncing
  ///
  /// // Now write data and it will sync automatically
  /// realm.writeWithSync(message, () {
  ///   message.text = "Hello!";
  ///   message.syncUpdateDb = true;
  /// });
  /// ```
  ///
  /// **Important**: Ensure Socket.IO is connected before calling `start()`,
  /// or sync operations will queue until connection is established.
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
        emitPreProcessor: cfg.emitPreProcessor,
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

  /// Manually trigger immediate sync for a specific object.
  ///
  /// Use this when you need to force sync without waiting for the automatic
  /// change listener. Common scenarios:
  /// - After batch writes where change listeners may not fire
  /// - When `needsSync` predicate is complex and you want explicit control
  /// - For critical updates that must sync immediately
  ///
  /// **Sends complete object data** (not just diffs) to ensure accuracy.
  ///
  /// Example:
  /// ```dart
  /// // Create and sync a message
  /// realm.write(() {
  ///   final message = ChatMessage('id-123', 'Hello', ...);
  ///   message.syncUpdateDb = true;
  ///   realm.add(message);
  /// });
  /// realmSync.syncObject('chat_messages', 'id-123');
  /// ```
  ///
  /// **Parameters:**
  /// - `collectionName`: MongoDB collection name (must match config)
  /// - `objectId`: The unique ID of the object to sync
  ///
  /// **Note**: Object must exist in the configured `RealmResults` for this collection.
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
  ///
  /// Convenience method to sync multiple objects at once. Each object
  /// is synced independently with full data (not diffs).
  ///
  /// Example:
  /// ```dart
  /// realmSync.syncObjects('chat_messages', ['id-1', 'id-2', 'id-3']);
  /// ```
  ///
  /// **Parameters:**
  /// - `collectionName`: MongoDB collection name
  /// - `objectIds`: List of object IDs to sync
  void syncObjects(String collectionName, List<String> objectIds) {
    for (final id in objectIds) {
      syncObject(collectionName, id);
    }
  }

  /// Get the last remote timestamp for a collection.
  ///
  /// This is the UTC millisecond timestamp of the most recent change received
  /// from the server for this collection. Used internally for historic sync
  /// to request only changes since this timestamp.
  ///
  /// Returns `0` if no remote changes have been received yet.
  ///
  /// Example:
  /// ```dart
  /// final lastSync = realmSync.lastRemoteTimestamp('chat_messages');
  /// print('Last synced at: ${DateTime.fromMillisecondsSinceEpoch(lastSync)}');
  /// ```
  int lastRemoteTimestamp(String collectionName) {
    return _lastRemoteTsByCollection[collectionName] ?? 0;
  }

  /// Clean up all resources and stop syncing.
  ///
  /// Call this when you're done with sync (e.g., on app shutdown or user logout).
  /// This method:
  /// - Cancels all change listeners
  /// - Disposes all sync helpers
  /// - Closes the change event stream
  /// - Clears internal state
  ///
  /// **Important**: After calling `dispose()`, this RealmSync instance cannot
  /// be reused. Create a new instance if you need to sync again.
  ///
  /// Example:
  /// ```dart
  /// // On logout or app shutdown
  /// realmSync.dispose();
  /// realm.close();
  /// socket.dispose();
  /// ```
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
