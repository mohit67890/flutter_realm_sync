import 'dart:async';

import '../RealmSync.dart';
import '../Models/sync_metadata.dart';
import '../utils/app_logger.dart';
import 'sync_historic_changes.dart';

/// Extension methods on RealmSync for fetching historical changes.
extension RealmSyncHistoricExtension on RealmSync {
  /// Fetch (and optionally apply) historic changes for a collection using the
  /// server's `sync:get_changes` endpoint.
  ///
  /// Mirrors live sync conflict logic:
  /// - skips remote change if local `sync_updated_at >= remote.timestamp`
  /// - applies delete vs upsert accordingly
  ///
  /// When [applyLocally] is true and changes were applied, also persists the
  /// latest remote timestamp to `SyncMetadata` to keep continuity with the
  /// existing timestamp tracking used by automatic reconnect logic.
  Future<HistoricChangesResult> fetchHistoricChanges(
    String collectionName, {
    int? since,
    int limit = 500,
    String? filterExpr,
    List<dynamic>? args,
    bool applyLocally = true,
  }) async {
    // Locate the collection config
    final config = configs.firstWhere(
      (c) => c.collectionName == collectionName,
      orElse:
          () =>
              throw StateError(
                'RealmSync: unknown collection "$collectionName"',
              ),
    );

    final helper = SyncHistoricChanges(
      socket: socket,
      realm: realm,
      userId: userId,
    );

    final result = await helper.getChangesFor(
      config: config,
      since: since,
      limit: limit,
      filterExpr: filterExpr,
      args: args,
      applyLocally: applyLocally,
    );

    if (applyLocally && result.latestTimestamp > (since ?? 0)) {
      // Persist latest remote timestamp even if no changes applied
      // This ensures we track the sync point correctly for collections
      // where changes were skipped due to conflicts
      try {
        realm.write(() {
          realm.add(
            SyncMetadata(
              result.collectionName,
              result.latestTimestamp,
              lastUpdated: DateTime.now().toUtc(),
            ),
            update: true,
          );
        });
      } catch (e) {
        AppLogger.log(
          'RealmSyncHistoricExtension: failed to persist timestamp for ${result.collectionName}: $e',
        );
      }
    }

    return result;
  }

  /// Fetch historic changes for ALL configured collections.
  ///
  /// For each collection:
  /// - Determines the starting timestamp: [sinceOverrides[collection]] if provided,
  ///   else the currently tracked in-memory `_lastRemoteTsByCollection[collection]`,
  ///   else 0.
  /// - Issues a `sync:get_changes` ACK call.
  /// - Optionally applies them locally (conflict logic identical to live sync).
  /// - Persists latest timestamp if changes applied and [applyLocally] is true.
  ///
  /// Returns a map keyed by collection name with each `HistoricChangesResult`.
  Future<Map<String, HistoricChangesResult>> fetchAllHistoricChanges({
    Map<String, int>? sinceOverrides,
    int limit = 500,
    bool applyLocally = true,
    bool skipEmptyCollections = false,
  }) async {
    final helper = SyncHistoricChanges(
      socket: socket,
      realm: realm,
      userId: userId,
    );

    final Map<String, HistoricChangesResult> results = {};

    // Process sequentially to avoid overwhelming server with simultaneous ACKs
    for (final cfg in configs) {
      final collection = cfg.collectionName;
      final since =
          sinceOverrides != null && sinceOverrides.containsKey(collection)
              ? sinceOverrides[collection]
              : lastRemoteTimestamp(collection);

      final r = await helper.getChangesFor(
        config: cfg,
        since: since,
        limit: limit,
        applyLocally: applyLocally,
      );

      if (skipEmptyCollections && r.appliedCount == 0 && r.skippedCount == 0) {
        continue;
      }

      // Persist timestamp if applied locally and timestamp advanced
      // Note: We persist even if appliedCount=0 but skipped changes, because
      // the server's latestTimestamp still represents the current sync point
      if (applyLocally && r.latestTimestamp > (since ?? 0)) {
        try {
          realm.write(() {
            realm.add(
              SyncMetadata(
                r.collectionName,
                r.latestTimestamp,
                lastUpdated: DateTime.now().toUtc(),
              ),
              update: true,
            );
          });
        } catch (e) {
          AppLogger.log(
            'RealmSyncHistoricExtension: failed to persist timestamp for ${r.collectionName}: $e',
          );
        }
      }

      results[collection] = r;
    }

    return results;
  }
}
