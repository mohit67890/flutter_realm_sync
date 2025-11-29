import 'package:realm_flutter_vector_db/realm_vector_db.dart';
part 'ChatRoom.realm.dart';

@RealmModel()
@MapTo('chatusers')
class $ChatUser {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String? userId;
  late DateTime? updatedOn;

  late String? name;
  late String? image;
  late String? emotion;
  late String? thought;
  late String? summary;

  late String? revealStatus;

  late String? firebaseToken;
  bool isSynced = false;
  bool isTyping = false;
}

@RealmModel()
@MapTo('chatrooms')
class _ChatRoom {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String? name;
  late String? text;
  late String? image;
  late String from;
  late String to;
  late String? account;
  late int? fromUnreadCount = 0;
  late int? toUnreadCount = 0;

  late String? status;

  late bool isBanned = false;
  late bool isLeft = false;
  late bool fromMuted = false;
  late bool toMuted = false;

  List<String> members = [];
  List<String> journalIds = [];
  List<String> deletedMembers = [];

  late bool isFromTyping = false;
  late bool isToTyping = false;

  late DateTime? time;
  late DateTime? updatedAt;
  late DateTime? lastMessageSyncTime;

  late DateTime? startTime;
  late DateTime? endTime;

  late String? journalId;
  late String? emotion;
  late String? privacy;

  late String? messageBy;

  late String? lastMessage;
  late String? lastMessageId;

  bool isMuted = false;
  bool updateDB = false;

  late String? type;
  late String? duration;

  bool fromSynced = false;
  bool toSynced = false;
  Map<String, bool> syncMap = {};
  Map<String, $ChatUser?> users = {};

  Map<String, DateTime?> lastMessageAt = {};

  late String? revealRequestBy;
  late String? revealRequestTo;
  late DateTime? revealRequestTime;
  late String? revealStatus;
  late String? revealMessage;

  @MapTo('sync_updated_at')
  int? syncUpdatedAt;

  @MapTo('sync_update_db')
  bool syncUpdateDb = false;
}
