import 'dart:async';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:socket_io_client/socket_io_client.dart';

import '../RealmSync.dart';
import '../utils/AppLogger.dart';
import 'RealmJson.dart';

/// Result summary for a historic change fetch.
class HistoricChangesResult {
  final String collectionName;
  final int requestedSince;
  final int
  latestTimestamp; // server-reported latest timestamp (may be same as requestedSince)
  final int appliedCount; // number of changes applied locally
  final int skippedCount; // skipped due to conflict (local newer/equal)
  final List<String> appliedIds;
  final List<Map<String, dynamic>>
  rawChanges; // original changes returned by server

  HistoricChangesResult({
    required this.collectionName,
    required this.requestedSince,
    required this.latestTimestamp,
    required this.appliedCount,
    required this.skippedCount,
    required this.appliedIds,
    required this.rawChanges,
  });
}

/// Helper to retrieve (and optionally apply) historical changes for a given SyncCollectionConfig.
///
/// This utility performs a `sync:get_changes` ACK call to the sync server and
/// returns a structured summary. If [applyLocally] is true, changes are merged
/// into the provided Realm instance using the same conflict rules as live sync:
/// - skip if local `sync_updated_at >= remote.timestamp`
/// - delete if operation == 'delete'
/// - upsert otherwise
///
/// NOTE: For deserialization it prefers `config.fromServerMap`; if absent it
/// falls back to RealmJson with `propertyNames` + `create` factory. If neither
/// is available an error is thrown.
class SyncHistoricChanges {
  final Socket socket;
  final Realm realm;
  final String userId;

  SyncHistoricChanges({
    required this.socket,
    required this.realm,
    required this.userId,
  });

  Future<HistoricChangesResult> getChangesFor<T extends RealmObject>({
    required SyncCollectionConfig<T> config,
    int? since,
    int limit = 500,
    String? filterExpr,
    List<dynamic>? args,
    bool applyLocally = true,
  }) async {
    final collection = config.collectionName;
    final requestSince = since ?? 0;
    final payload = <String, dynamic>{
      'userId': userId,
      'collection': collection,
      'since': requestSince,
      'limit': limit,
      if (filterExpr != null) 'filter': filterExpr,
      if (args != null) 'args': args,
    };

    AppLogger.log(
      'HistoricChanges: requesting changes for $collection since=$requestSince limit=$limit',
    );
    late final dynamic ack;
    try {
      ack = await socket.emitWithAckAsync('sync:get_changes', payload);
    } catch (e) {
      throw StateError(
        'HistoricChanges: socket ACK failed for $collection: $e',
      );
    }

    if (ack == null || ack is String && ack.toLowerCase() == 'error') {
      throw StateError(
        'HistoricChanges: server returned error for $collection: $ack',
      );
    }
    if (ack is! Map) {
      throw StateError(
        'HistoricChanges: unexpected ACK shape (expected Map) for $collection: $ack',
      );
    }

    final map = Map<String, dynamic>.from(ack);
    final changesRaw = (map['changes'] as List?)?.cast<Map>() ?? const <Map>[];
    final latestTs =
        (map['latestTimestamp'] is int)
            ? map['latestTimestamp'] as int
            : requestSince;

    final List<Map<String, dynamic>> rawList =
        changesRaw.map((m) => Map<String, dynamic>.from(m)).toList();

    final List<String> appliedIds = <String>[];
    int applied = 0;
    int skipped = 0;

    if (applyLocally && rawList.isNotEmpty) {
      realm.write(() {
        for (final c in rawList) {
          final op = c['operation']?.toString();
          final remoteTs =
              (c['timestamp'] is int)
                  ? c['timestamp'] as int
                  : DateTime.now().toUtc().millisecondsSinceEpoch;
          final docId = c['documentId']?.toString();
          final coll = c['collection']?.toString();
          if (op == null ||
              docId == null ||
              coll == null ||
              coll != collection) {
            continue; // skip malformed or different collection
          }

          // Find existing object by scanning config.results (consistent with RealmSync's approach)
          RealmObject? existing;
          for (final obj in config.results) {
            try {
              final objId = Function.apply(config.idSelector as Function, [
                obj,
              ]);
              if (objId == docId) {
                existing = obj;
                break;
              }
            } catch (_) {}
          }

          int? localTs;
          if (existing != null) {
            try {
              final dyn = existing as dynamic;
              final v = dyn.sync_updated_at;
              if (v is int) localTs = v;
            } catch (_) {}
          }
          if (localTs != null && localTs >= remoteTs) {
            skipped++;
            continue; // conflict: keep local
          }

          if (op == 'delete') {
            if (existing != null) {
              realm.delete(existing);
            }
            applied++;
            appliedIds.add(docId);
            continue;
          }

          // Upsert path
          final data = Map<String, dynamic>.from((c['data'] as Map?) ?? {});
          data['_id'] = docId;
          data['sync_updated_at'] = remoteTs;

          RealmObject newObj;
          if (config.fromServerMap != null) {
            newObj = config.fromServerMap!(data);
          } else {
            // RealmJson fallback requires propertyNames + create
            if (config.propertyNames == null || config.create == null) {
              throw StateError(
                'HistoricChanges: config for $collection missing fromServerMap or propertyNames/create for fallback',
              );
            }
            final creator = () => config.create!();
            newObj = RealmJson.fromJsonWith<RealmObject>(
              data,
              creator,
              config.propertyNames!,
              embeddedCreators: config.embeddedCreators,
            );
          }
          realm.add(newObj, update: true);
          applied++;
          appliedIds.add(docId);
        }
      });
    }

    AppLogger.log(
      'HistoricChanges: collection=$collection applied=$applied skipped=$skipped latestTimestamp=$latestTs',
    );

    return HistoricChangesResult(
      collectionName: collection,
      requestedSince: requestSince,
      latestTimestamp: latestTs,
      appliedCount: applied,
      skippedCount: skipped,
      appliedIds: appliedIds,
      rawChanges: rawList,
    );
  }
}
