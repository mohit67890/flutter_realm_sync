import 'package:realm_flutter_vector_db/realm_vector_db.dart';

part 'sync_outbox_patch.realm.dart';

@RealmModel()
@MapTo('outbox')
class _SyncOutboxPatch {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String uid;
  late String collection;
  late String entityId;
  late String payloadJson;

  DateTime? createdAt;
  DateTime? lastAttemptAt;
  int attempts = 0;
}
