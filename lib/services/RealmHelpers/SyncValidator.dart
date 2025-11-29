import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/RealmSync.dart';

/// Ensures a config and its models can participate in bi-directional sync.
class SyncValidator {
  /// Validate the configuration for required mappers or RealmJson fallback inputs.
  static void validateConfig<T extends RealmObject>(
    SyncCollectionConfig<T> cfg,
  ) {
    final hasCustomFrom = cfg.fromServerMap != null;
    final hasRealmJsonBasics = cfg.propertyNames != null;
    final hasCreate = cfg.create != null;

    // toSyncMap and propertyNames are OPTIONAL
    // RealmJson.toJsonWith() can auto-detect properties or use toEJson() when propertyNames is null

    // For deserialization (inbound sync), we need either:
    // 1. Custom fromServerMap, OR
    // 2. propertyNames + create() for RealmJson fallback
    if (!hasCustomFrom && (!hasRealmJsonBasics || !hasCreate)) {
      throw StateError(
        'SyncCollectionConfig(${cfg.collectionName}) requires either fromServerMap or both propertyNames and create() for deserializing inbound changes',
      );
    }

    // If propertyNames is provided, validate it includes critical sync fields
    if (hasRealmJsonBasics) {
      final names = cfg.propertyNames!;
      final hasId = names.contains('id') || names.contains('_id');
      final hasUpdatedTs = names.contains('sync_updated_at');
      final hasSyncFlag = names.contains('sync_update_db');

      if (!hasId) {
        throw StateError(
          'SyncCollectionConfig(${cfg.collectionName}) propertyNames must include either "id" or "_id" for identification.',
        );
      }
      if (!hasUpdatedTs) {
        throw StateError(
          'SyncCollectionConfig(${cfg.collectionName}) propertyNames must include "sync_updated_at" (UTC millis) for conflict resolution.',
        );
      }
      if (!hasSyncFlag) {
        throw StateError(
          'SyncCollectionConfig(${cfg.collectionName}) propertyNames must include "sync_update_db" (boolean) for sync loop prevention.',
        );
      }
    }

    // Note: toSyncMap and propertyNames validation is skipped due to Dart's type system limitations
    // RealmJson automatically tries toEJson() first, then auto-detection, then explicit propertyNames
    // If custom toSyncMap is provided, we trust it includes '_id', 'sync_updated_at', and 'sync_update_db'
  }

  /// Validate that at least one model in the results contains listed properties.
  /// Uses dynamic access via RealmObjectBase.get and tolerates optional/nullable fields.
  static void validateSampleModels<T extends RealmObject>(
    SyncCollectionConfig<T> cfg,
  ) {
    if (cfg.propertyNames == null || cfg.results.isEmpty) return;
    final List<String> names = cfg.propertyNames!;
    // Take a small sample to validate
    final int sampleCount = cfg.results.length < 5 ? cfg.results.length : 5;

    // Validate at least one sample has all required fields
    bool foundValidSample = false;

    for (int i = 0; i < sampleCount; i++) {
      final obj = cfg.results[i];
      bool sampleValid = true;

      // Check all propertyNames exist
      for (final name in names) {
        try {
          RealmObjectBase.get(obj, name);
        } catch (e) {
          sampleValid = false;
          break;
        }
      }

      if (!sampleValid) continue;

      // Additional runtime checks: id selector must resolve to non-empty id
      try {
        final idValue = cfg.idSelector(cfg.results[i]);
        if (idValue.isEmpty) {
          throw StateError(
            'idSelector returned empty id for a model in collection "${cfg.collectionName}".',
          );
        }
      } catch (e) {
        throw StateError(
          'idSelector failed to resolve a valid id for collection "${cfg.collectionName}": $e',
        );
      }

      // sync_updated_at must be present and must be an int
      try {
        final updated = RealmObjectBase.get(obj, 'sync_updated_at');
        if (updated != null && updated is! int) {
          throw StateError(
            'Property "sync_updated_at" must be an int (UTC millis) on collection "${cfg.collectionName}".',
          );
        }
      } catch (e) {
        throw StateError(
          'Realm model for collection "${cfg.collectionName}" is missing required property "sync_updated_at". '
          'This field is required for conflict resolution and must be an int (UTC millis).',
        );
      }

      // sync_update_db must be present (critical for loop prevention)
      try {
        final syncFlag = RealmObjectBase.get(obj, 'sync_update_db');
        if (syncFlag != null && syncFlag is! bool) {
          throw StateError(
            'Property "sync_update_db" must be a bool on collection "${cfg.collectionName}".',
          );
        }
      } catch (e) {
        throw StateError(
          'Collection "${cfg.collectionName}": Models must have a "sync_update_db" boolean field '
          '(with @MapTo(\'sync_update_db\') annotation) for proper sync loop prevention. '
          'This field is automatically managed by writeWithSync() and markForSync() methods.',
        );
      }

      // All checks passed for this sample
      foundValidSample = true;
      break;
    }

    if (!foundValidSample) {
      throw StateError(
        'Realm model for collection "${cfg.collectionName}" is missing one or more required properties from propertyNames.',
      );
    }
  }
}
