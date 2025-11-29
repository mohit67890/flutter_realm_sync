import 'dart:convert';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/SyncDBCache.dart';
import 'package:flutter_realm_sync/services/utils/helpers.dart';
import 'package:flutter_realm_sync/services/utils/json_canonical.dart';
import 'RealmJson.dart';

/// Extension to provide convenience methods for Realm operations with automatic
/// sync_updated_at timestamp management and DBCache diff tracking.
///
/// The extensions now automatically create DBCache entries with computed diffs,
/// which SyncHelper consumes to avoid redundant diff computation and ensure
/// no unnecessary server updates are made when data hasn't actually changed.
extension RealmSyncExtensions on Realm {
  /// Performs a write operation on a specific object and automatically updates
  /// its sync_updated_at field, marks it for sync, and creates a DBCache entry
  /// with the computed diff.
  ///
  /// This ensures SyncHelper can use pre-computed diffs and avoid sending
  /// updates when no actual changes were made.
  ///
  /// Usage:
  /// ```dart
  /// realm.writeWithSync(goal, userId: 'user-123', collectionName: 'goals', () {
  ///   goal.title = "Updated title";
  ///   // sync_updated_at is set, diff is computed and cached
  /// });
  /// ```
  T writeWithSync<T extends RealmObject>(
    T obj, {
    required String userId,
    required String collectionName,
    required void Function() writeCallback,
  }) {
    return write(() {
      // Capture old state before modification
      Map<String, dynamic> oldData = {};
      try {
        oldData = RealmJson.toJsonWith(obj, null);
      } catch (e) {
        // Serialization failed, skip diff caching
      }

      // Apply user's modifications
      writeCallback();

      // Update sync metadata
      obj.updateSyncTimestamp();
      obj.markForSync();

      // Capture new state and compute diff
      try {
        final newData = RealmJson.toJsonWith(obj, null);
        final entityId = _extractEntityId(obj);

        if (entityId != null) {
          final isInsert = oldData.isEmpty;
          // For inserts, store full data; for updates, store diff
          final diffData = isInsert ? newData : diff(oldData, newData);

          // Only create DBCache if there are actual changes
          if (diffData.isNotEmpty) {
            final key = '$userId|$collectionName|$entityId';
            final dbCache = SyncDBCache(
              key,
              userId,
              collectionName,
              entityId,
              jsonEncode(canonicalizeMap(diffData)),
              jsonEncode(canonicalizeMap(newData)),
              isInsert ? 'inserted' : 'modified',
              createdAt: DateTime.now(),
            );
            add<SyncDBCache>(dbCache, update: true);
          }
        }
      } catch (e) {
        // Log diff caching failures for debugging
        try {
          // Avoid importing AppLogger to keep extensions lightweight
          // ignore: avoid_print
          print(
            'DBCache creation failed for $collectionName|${_extractEntityId(obj)}: $e',
          );
        } catch (_) {}
      }

      return obj;
    });
  }

  /// Helper to extract entity ID from a RealmObject
  String? _extractEntityId(RealmObject obj) {
    try {
      // Try common ID field names
      final dynamic id = RealmObjectBase.get(obj, '_id');
      if (id != null) return id.toString();
    } catch (e) {
      // _id not found, try id
      try {
        final dynamic id = RealmObjectBase.get(obj, 'id');
        if (id != null) return id.toString();
      } catch (e) {
        // Neither _id nor id found
      }
    }
    return null;
  }

  /// Performs a write operation on multiple objects and automatically updates
  /// their sync_updated_at fields, marks them for sync, and creates DBCache entries.
  ///
  /// Usage:
  /// ```dart
  /// realm.writeWithSyncMultiple(
  ///   [goal1, goal2],
  ///   userId: 'user-123',
  ///   collectionName: 'goals',
  ///   () {
  ///     goal1.title = "Updated 1";
  ///     goal2.title = "Updated 2";
  ///     // sync_updated_at is automatically set for both
  ///   },
  /// );
  /// ```
  void writeWithSyncMultiple(
    List<RealmObject> objects, {
    required String userId,
    required String collectionName,
    required void Function() writeCallback,
  }) {
    write(() {
      // Capture old states for all objects
      final oldStates = <RealmObject, Map<String, dynamic>>{};
      for (final obj in objects) {
        try {
          oldStates[obj] = RealmJson.toJsonWith(obj, null);
        } catch (e) {
          // Serialization failed, skip
        }
      }

      // Apply user's modifications
      writeCallback();

      // Update sync metadata and create DBCache entries
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final obj in objects) {
        obj.updateSyncTimestamp(timestampOverride: now);
        obj.markForSync();

        // Create DBCache entry
        try {
          final newData = RealmJson.toJsonWith(obj, null);
          final entityId = _extractEntityId(obj);

          if (entityId != null) {
            final oldData = oldStates[obj] ?? {};
            final isInsert = oldData.isEmpty;
            // For inserts, store full data; for updates, store diff
            final diffData = isInsert ? newData : diff(oldData, newData);

            // Only create DBCache if there are actual changes
            if (diffData.isNotEmpty) {
              final key = '$userId|$collectionName|$entityId';
              final dbCache = SyncDBCache(
                key,
                userId,
                collectionName,
                entityId,
                jsonEncode(canonicalizeMap(diffData)),
                jsonEncode(canonicalizeMap(newData)),
                isInsert ? 'inserted' : 'modified',
                createdAt: DateTime.now(),
              );
              add<SyncDBCache>(dbCache, update: true);
            }
          }
        } catch (e) {
          // Log diff caching failures for debugging
          try {
            // ignore: avoid_print
            print(
              'DBCache creation failed for $collectionName|${_extractEntityId(obj)}: $e',
            );
          } catch (_) {}
        }
      }
    });
  }

  /// Deletes an object and creates a DBCache entry to track the deletion
  /// for syncing with the server.
  ///
  /// Usage:
  /// ```dart
  /// realm.deleteWithSync(
  ///   goal,
  ///   userId: 'user-123',
  ///   collectionName: 'goals',
  /// );
  /// ```
  void deleteWithSync<T extends RealmObject>(
    T obj, {
    required String userId,
    required String collectionName,
  }) {
    write(() {
      // Capture state before deletion and serialize immediately
      // to avoid RealmList references becoming invalid after deletion
      String? serializedData;
      String? entityId;

      try {
        final json = RealmJson.toJsonWith(obj, null);
        // Serialize immediately while object is still valid
        // This deep-copies the data and avoids holding RealmList references
        serializedData = jsonEncode(canonicalizeMap(json));
        entityId = _extractEntityId(obj);
      } catch (e) {
        // Continue with deletion even if we can't capture state
      }

      // Delete the object
      delete(obj);

      // Create DBCache entry for deletion tracking
      if (entityId != null && serializedData != null) {
        try {
          final key = '$userId|$collectionName|$entityId';
          final dbCache = SyncDBCache(
            key,
            userId,
            collectionName,
            entityId,
            jsonEncode({}), // No diff for deletion
            serializedData, // Already serialized before deletion
            'deleted',
            createdAt: DateTime.now(),
          );
          add<SyncDBCache>(dbCache, update: true);
        } catch (e) {
          // Log DBCache creation failures for debugging
          try {
            // ignore: avoid_print
            print(
              'DBCache creation failed for deletion $collectionName|$entityId: $e',
            );
          } catch (_) {}
        }
      }
    });
  }
}

/// Extension for individual RealmObject instances
extension RealmObjectSyncExtensions on RealmObject {
  /// Updates sync_updated_at field if it exists on this object.
  /// Must be called within a write transaction.
  ///
  /// Usage:
  /// ```dart
  /// realm.write(() {
  ///   goal.title = "Updated";
  ///   goal.updateSyncTimestamp();
  /// });
  /// ```
  ///
  /// Or with a specific timestamp:
  /// ```dart
  /// realm.write(() {
  ///   goal.title = "Updated";
  ///   goal.updateSyncTimestamp(timestampOverride: customTimestamp);
  /// });
  /// ```
  void updateSyncTimestamp({int? timestampOverride}) {
    if (!realm.isInTransaction) {
      throw RealmException(
        'updateSyncTimestamp must be called within a write transaction',
      );
    }

    try {
      // Try to set sync_updated_at using dynamic access
      final timestamp =
          timestampOverride ?? DateTime.now().millisecondsSinceEpoch;
      RealmObjectBase.set(this, 'sync_updated_at', timestamp);
    } catch (e) {
      // Silently ignore if sync_updated_at doesn't exist
      // This allows models without the field to use the extension safely
    }
  }

  /// Marks this object for sync by setting sync_update_db flag to true.
  /// Must be called within a write transaction.
  ///
  /// This is automatically called by writeWithSync(), but can be used manually:
  /// ```dart
  /// realm.write(() {
  ///   goal.title = "Updated";
  ///   goal.markForSync(); // Mark for sync
  /// });
  /// ```
  void markForSync() {
    if (!realm.isInTransaction) {
      throw RealmException(
        'markForSync must be called within a write transaction',
      );
    }

    try {
      // Try to set sync_update_db flag using dynamic access
      RealmObjectBase.set(this, 'sync_update_db', true);
    } catch (e) {
      // Silently ignore if sync_update_db doesn't exist
      // This allows models without the field to use the extension safely
    }
  }

  /// Clears the sync flag after successful sync.
  /// Must be called within a write transaction.
  void clearSyncFlag() {
    if (!realm.isInTransaction) {
      throw RealmException(
        'clearSyncFlag must be called within a write transaction',
      );
    }

    try {
      RealmObjectBase.set(this, 'sync_update_db', false);
    } catch (e) {
      // Silently ignore if sync_update_db doesn't exist
    }
  }
}
