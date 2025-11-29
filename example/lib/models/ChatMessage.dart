import 'package:realm_flutter_vector_db/realm_vector_db.dart';
part 'ChatMessage.realm.dart';

@RealmModel()
@MapTo('chat_messages')
class _ChatMessage {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String text;
  late String senderName;
  late String senderId;
  late DateTime timestamp;

  @MapTo('sync_updated_at')
  int? syncUpdatedAt;

  @MapTo('sync_update_db')
  bool syncUpdateDb = false;
}
