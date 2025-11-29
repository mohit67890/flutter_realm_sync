import 'package:realm_flutter_vector_db/realm_vector_db.dart';

part 'SyncDBCache.realm.dart';

@RealmModel()
@MapTo('dbcache')
class _SyncDBCache {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String uid;
  late String collection;
  late String entityId;
  late String diffJson;
  late String newJson;

  late String operation; // e.g., 'inserted', 'modified', 'deleted'

  DateTime? createdAt;
}
