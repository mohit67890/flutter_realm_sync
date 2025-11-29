import 'package:realm_flutter_vector_db/realm_vector_db.dart';

part 'SyncMetadata.realm.dart';

/// Stores sync metadata for each collection to enable efficient historical sync.
/// Tracks the last remote timestamp received from the server, allowing the client
/// to request only changes that occurred after the last successful sync.
@RealmModel()
@MapTo('sync_metadata')
class _SyncMetadata {
  @PrimaryKey()
  @MapTo('_id')
  late String collectionName;

  /// Last remote timestamp (UTC milliseconds) synced from server.
  /// Used in sync:get_changes requests to fetch only newer changes.
  late int lastRemoteTimestamp;

  /// When this metadata was last updated
  DateTime? lastUpdated;
}
