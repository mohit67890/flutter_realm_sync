// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ChatRoom.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class ChatUser extends $ChatUser
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  ChatUser(
    String id, {
    String? userId,
    DateTime? updatedOn,
    String? name,
    String? image,
    String? emotion,
    String? thought,
    String? summary,
    String? revealStatus,
    String? firebaseToken,
    bool isSynced = false,
    bool isTyping = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<ChatUser>({
        'isSynced': false,
        'isTyping': false,
      });
    }
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'userId', userId);
    RealmObjectBase.set(this, 'updatedOn', updatedOn);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'image', image);
    RealmObjectBase.set(this, 'emotion', emotion);
    RealmObjectBase.set(this, 'thought', thought);
    RealmObjectBase.set(this, 'summary', summary);
    RealmObjectBase.set(this, 'revealStatus', revealStatus);
    RealmObjectBase.set(this, 'firebaseToken', firebaseToken);
    RealmObjectBase.set(this, 'isSynced', isSynced);
    RealmObjectBase.set(this, 'isTyping', isTyping);
  }

  ChatUser._();

  @override
  String get id => RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  String? get userId => RealmObjectBase.get<String>(this, 'userId') as String?;
  @override
  set userId(String? value) => RealmObjectBase.set(this, 'userId', value);

  @override
  DateTime? get updatedOn =>
      RealmObjectBase.get<DateTime>(this, 'updatedOn') as DateTime?;
  @override
  set updatedOn(DateTime? value) =>
      RealmObjectBase.set(this, 'updatedOn', value);

  @override
  String? get name => RealmObjectBase.get<String>(this, 'name') as String?;
  @override
  set name(String? value) => RealmObjectBase.set(this, 'name', value);

  @override
  String? get image => RealmObjectBase.get<String>(this, 'image') as String?;
  @override
  set image(String? value) => RealmObjectBase.set(this, 'image', value);

  @override
  String? get emotion =>
      RealmObjectBase.get<String>(this, 'emotion') as String?;
  @override
  set emotion(String? value) => RealmObjectBase.set(this, 'emotion', value);

  @override
  String? get thought =>
      RealmObjectBase.get<String>(this, 'thought') as String?;
  @override
  set thought(String? value) => RealmObjectBase.set(this, 'thought', value);

  @override
  String? get summary =>
      RealmObjectBase.get<String>(this, 'summary') as String?;
  @override
  set summary(String? value) => RealmObjectBase.set(this, 'summary', value);

  @override
  String? get revealStatus =>
      RealmObjectBase.get<String>(this, 'revealStatus') as String?;
  @override
  set revealStatus(String? value) =>
      RealmObjectBase.set(this, 'revealStatus', value);

  @override
  String? get firebaseToken =>
      RealmObjectBase.get<String>(this, 'firebaseToken') as String?;
  @override
  set firebaseToken(String? value) =>
      RealmObjectBase.set(this, 'firebaseToken', value);

  @override
  bool get isSynced => RealmObjectBase.get<bool>(this, 'isSynced') as bool;
  @override
  set isSynced(bool value) => RealmObjectBase.set(this, 'isSynced', value);

  @override
  bool get isTyping => RealmObjectBase.get<bool>(this, 'isTyping') as bool;
  @override
  set isTyping(bool value) => RealmObjectBase.set(this, 'isTyping', value);

  @override
  Stream<RealmObjectChanges<ChatUser>> get changes =>
      RealmObjectBase.getChanges<ChatUser>(this);

  @override
  Stream<RealmObjectChanges<ChatUser>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<ChatUser>(this, keyPaths);

  @override
  ChatUser freeze() => RealmObjectBase.freezeObject<ChatUser>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'userId': userId.toEJson(),
      'updatedOn': updatedOn.toEJson(),
      'name': name.toEJson(),
      'image': image.toEJson(),
      'emotion': emotion.toEJson(),
      'thought': thought.toEJson(),
      'summary': summary.toEJson(),
      'revealStatus': revealStatus.toEJson(),
      'firebaseToken': firebaseToken.toEJson(),
      'isSynced': isSynced.toEJson(),
      'isTyping': isTyping.toEJson(),
    };
  }

  static EJsonValue _toEJson(ChatUser value) => value.toEJson();
  static ChatUser _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'_id': EJsonValue id} => ChatUser(
        fromEJson(id),
        userId: fromEJson(ejson['userId']),
        updatedOn: fromEJson(ejson['updatedOn']),
        name: fromEJson(ejson['name']),
        image: fromEJson(ejson['image']),
        emotion: fromEJson(ejson['emotion']),
        thought: fromEJson(ejson['thought']),
        summary: fromEJson(ejson['summary']),
        revealStatus: fromEJson(ejson['revealStatus']),
        firebaseToken: fromEJson(ejson['firebaseToken']),
        isSynced: fromEJson(ejson['isSynced'], defaultValue: false),
        isTyping: fromEJson(ejson['isTyping'], defaultValue: false),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(ChatUser._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, ChatUser, 'chatusers', [
      SchemaProperty(
        'id',
        RealmPropertyType.string,
        mapTo: '_id',
        primaryKey: true,
      ),
      SchemaProperty('userId', RealmPropertyType.string, optional: true),
      SchemaProperty('updatedOn', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('name', RealmPropertyType.string, optional: true),
      SchemaProperty('image', RealmPropertyType.string, optional: true),
      SchemaProperty('emotion', RealmPropertyType.string, optional: true),
      SchemaProperty('thought', RealmPropertyType.string, optional: true),
      SchemaProperty('summary', RealmPropertyType.string, optional: true),
      SchemaProperty('revealStatus', RealmPropertyType.string, optional: true),
      SchemaProperty('firebaseToken', RealmPropertyType.string, optional: true),
      SchemaProperty('isSynced', RealmPropertyType.bool),
      SchemaProperty('isTyping', RealmPropertyType.bool),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class ChatRoom extends _ChatRoom
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  ChatRoom(
    String id,
    String from,
    String to, {
    String? name,
    String? text,
    String? image,
    String? account,
    int? fromUnreadCount = 0,
    int? toUnreadCount = 0,
    String? status,
    bool isBanned = false,
    bool isLeft = false,
    bool fromMuted = false,
    bool toMuted = false,
    Iterable<String> members = const [],
    Iterable<String> journalIds = const [],
    Iterable<String> deletedMembers = const [],
    bool isFromTyping = false,
    bool isToTyping = false,
    DateTime? time,
    DateTime? updatedAt,
    DateTime? lastMessageSyncTime,
    DateTime? startTime,
    DateTime? endTime,
    String? journalId,
    String? emotion,
    String? privacy,
    String? messageBy,
    String? lastMessage,
    String? lastMessageId,
    bool isMuted = false,
    bool updateDB = false,
    String? type,
    String? duration,
    bool fromSynced = false,
    bool toSynced = false,
    Map<String, bool> syncMap = const {},
    Map<String, ChatUser?> users = const {},
    Map<String, DateTime?> lastMessageAt = const {},
    String? revealRequestBy,
    String? revealRequestTo,
    DateTime? revealRequestTime,
    String? revealStatus,
    String? revealMessage,
    int? syncUpdatedAt,
    bool syncUpdateDb = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<ChatRoom>({
        'fromUnreadCount': 0,
        'toUnreadCount': 0,
        'isBanned': false,
        'isLeft': false,
        'fromMuted': false,
        'toMuted': false,
        'isFromTyping': false,
        'isToTyping': false,
        'isMuted': false,
        'updateDB': false,
        'fromSynced': false,
        'toSynced': false,
        'sync_update_db': false,
      });
    }
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'text', text);
    RealmObjectBase.set(this, 'image', image);
    RealmObjectBase.set(this, 'from', from);
    RealmObjectBase.set(this, 'to', to);
    RealmObjectBase.set(this, 'account', account);
    RealmObjectBase.set(this, 'fromUnreadCount', fromUnreadCount);
    RealmObjectBase.set(this, 'toUnreadCount', toUnreadCount);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'isBanned', isBanned);
    RealmObjectBase.set(this, 'isLeft', isLeft);
    RealmObjectBase.set(this, 'fromMuted', fromMuted);
    RealmObjectBase.set(this, 'toMuted', toMuted);
    RealmObjectBase.set<RealmList<String>>(
      this,
      'members',
      RealmList<String>(members),
    );
    RealmObjectBase.set<RealmList<String>>(
      this,
      'journalIds',
      RealmList<String>(journalIds),
    );
    RealmObjectBase.set<RealmList<String>>(
      this,
      'deletedMembers',
      RealmList<String>(deletedMembers),
    );
    RealmObjectBase.set(this, 'isFromTyping', isFromTyping);
    RealmObjectBase.set(this, 'isToTyping', isToTyping);
    RealmObjectBase.set(this, 'time', time);
    RealmObjectBase.set(this, 'updatedAt', updatedAt);
    RealmObjectBase.set(this, 'lastMessageSyncTime', lastMessageSyncTime);
    RealmObjectBase.set(this, 'startTime', startTime);
    RealmObjectBase.set(this, 'endTime', endTime);
    RealmObjectBase.set(this, 'journalId', journalId);
    RealmObjectBase.set(this, 'emotion', emotion);
    RealmObjectBase.set(this, 'privacy', privacy);
    RealmObjectBase.set(this, 'messageBy', messageBy);
    RealmObjectBase.set(this, 'lastMessage', lastMessage);
    RealmObjectBase.set(this, 'lastMessageId', lastMessageId);
    RealmObjectBase.set(this, 'isMuted', isMuted);
    RealmObjectBase.set(this, 'updateDB', updateDB);
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set(this, 'duration', duration);
    RealmObjectBase.set(this, 'fromSynced', fromSynced);
    RealmObjectBase.set(this, 'toSynced', toSynced);
    RealmObjectBase.set<RealmMap<bool>>(
      this,
      'syncMap',
      RealmMap<bool>(syncMap),
    );
    RealmObjectBase.set<RealmMap<ChatUser?>>(
      this,
      'users',
      RealmMap<ChatUser?>(users),
    );
    RealmObjectBase.set<RealmMap<DateTime?>>(
      this,
      'lastMessageAt',
      RealmMap<DateTime?>(lastMessageAt),
    );
    RealmObjectBase.set(this, 'revealRequestBy', revealRequestBy);
    RealmObjectBase.set(this, 'revealRequestTo', revealRequestTo);
    RealmObjectBase.set(this, 'revealRequestTime', revealRequestTime);
    RealmObjectBase.set(this, 'revealStatus', revealStatus);
    RealmObjectBase.set(this, 'revealMessage', revealMessage);
    RealmObjectBase.set(this, 'sync_updated_at', syncUpdatedAt);
    RealmObjectBase.set(this, 'sync_update_db', syncUpdateDb);
  }

  ChatRoom._();

  @override
  String get id => RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  String? get name => RealmObjectBase.get<String>(this, 'name') as String?;
  @override
  set name(String? value) => RealmObjectBase.set(this, 'name', value);

  @override
  String? get text => RealmObjectBase.get<String>(this, 'text') as String?;
  @override
  set text(String? value) => RealmObjectBase.set(this, 'text', value);

  @override
  String? get image => RealmObjectBase.get<String>(this, 'image') as String?;
  @override
  set image(String? value) => RealmObjectBase.set(this, 'image', value);

  @override
  String get from => RealmObjectBase.get<String>(this, 'from') as String;
  @override
  set from(String value) => RealmObjectBase.set(this, 'from', value);

  @override
  String get to => RealmObjectBase.get<String>(this, 'to') as String;
  @override
  set to(String value) => RealmObjectBase.set(this, 'to', value);

  @override
  String? get account =>
      RealmObjectBase.get<String>(this, 'account') as String?;
  @override
  set account(String? value) => RealmObjectBase.set(this, 'account', value);

  @override
  int? get fromUnreadCount =>
      RealmObjectBase.get<int>(this, 'fromUnreadCount') as int?;
  @override
  set fromUnreadCount(int? value) =>
      RealmObjectBase.set(this, 'fromUnreadCount', value);

  @override
  int? get toUnreadCount =>
      RealmObjectBase.get<int>(this, 'toUnreadCount') as int?;
  @override
  set toUnreadCount(int? value) =>
      RealmObjectBase.set(this, 'toUnreadCount', value);

  @override
  String? get status => RealmObjectBase.get<String>(this, 'status') as String?;
  @override
  set status(String? value) => RealmObjectBase.set(this, 'status', value);

  @override
  bool get isBanned => RealmObjectBase.get<bool>(this, 'isBanned') as bool;
  @override
  set isBanned(bool value) => RealmObjectBase.set(this, 'isBanned', value);

  @override
  bool get isLeft => RealmObjectBase.get<bool>(this, 'isLeft') as bool;
  @override
  set isLeft(bool value) => RealmObjectBase.set(this, 'isLeft', value);

  @override
  bool get fromMuted => RealmObjectBase.get<bool>(this, 'fromMuted') as bool;
  @override
  set fromMuted(bool value) => RealmObjectBase.set(this, 'fromMuted', value);

  @override
  bool get toMuted => RealmObjectBase.get<bool>(this, 'toMuted') as bool;
  @override
  set toMuted(bool value) => RealmObjectBase.set(this, 'toMuted', value);

  @override
  RealmList<String> get members =>
      RealmObjectBase.get<String>(this, 'members') as RealmList<String>;
  @override
  set members(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmList<String> get journalIds =>
      RealmObjectBase.get<String>(this, 'journalIds') as RealmList<String>;
  @override
  set journalIds(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmList<String> get deletedMembers =>
      RealmObjectBase.get<String>(this, 'deletedMembers') as RealmList<String>;
  @override
  set deletedMembers(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  bool get isFromTyping =>
      RealmObjectBase.get<bool>(this, 'isFromTyping') as bool;
  @override
  set isFromTyping(bool value) =>
      RealmObjectBase.set(this, 'isFromTyping', value);

  @override
  bool get isToTyping => RealmObjectBase.get<bool>(this, 'isToTyping') as bool;
  @override
  set isToTyping(bool value) => RealmObjectBase.set(this, 'isToTyping', value);

  @override
  DateTime? get time =>
      RealmObjectBase.get<DateTime>(this, 'time') as DateTime?;
  @override
  set time(DateTime? value) => RealmObjectBase.set(this, 'time', value);

  @override
  DateTime? get updatedAt =>
      RealmObjectBase.get<DateTime>(this, 'updatedAt') as DateTime?;
  @override
  set updatedAt(DateTime? value) =>
      RealmObjectBase.set(this, 'updatedAt', value);

  @override
  DateTime? get lastMessageSyncTime =>
      RealmObjectBase.get<DateTime>(this, 'lastMessageSyncTime') as DateTime?;
  @override
  set lastMessageSyncTime(DateTime? value) =>
      RealmObjectBase.set(this, 'lastMessageSyncTime', value);

  @override
  DateTime? get startTime =>
      RealmObjectBase.get<DateTime>(this, 'startTime') as DateTime?;
  @override
  set startTime(DateTime? value) =>
      RealmObjectBase.set(this, 'startTime', value);

  @override
  DateTime? get endTime =>
      RealmObjectBase.get<DateTime>(this, 'endTime') as DateTime?;
  @override
  set endTime(DateTime? value) => RealmObjectBase.set(this, 'endTime', value);

  @override
  String? get journalId =>
      RealmObjectBase.get<String>(this, 'journalId') as String?;
  @override
  set journalId(String? value) => RealmObjectBase.set(this, 'journalId', value);

  @override
  String? get emotion =>
      RealmObjectBase.get<String>(this, 'emotion') as String?;
  @override
  set emotion(String? value) => RealmObjectBase.set(this, 'emotion', value);

  @override
  String? get privacy =>
      RealmObjectBase.get<String>(this, 'privacy') as String?;
  @override
  set privacy(String? value) => RealmObjectBase.set(this, 'privacy', value);

  @override
  String? get messageBy =>
      RealmObjectBase.get<String>(this, 'messageBy') as String?;
  @override
  set messageBy(String? value) => RealmObjectBase.set(this, 'messageBy', value);

  @override
  String? get lastMessage =>
      RealmObjectBase.get<String>(this, 'lastMessage') as String?;
  @override
  set lastMessage(String? value) =>
      RealmObjectBase.set(this, 'lastMessage', value);

  @override
  String? get lastMessageId =>
      RealmObjectBase.get<String>(this, 'lastMessageId') as String?;
  @override
  set lastMessageId(String? value) =>
      RealmObjectBase.set(this, 'lastMessageId', value);

  @override
  bool get isMuted => RealmObjectBase.get<bool>(this, 'isMuted') as bool;
  @override
  set isMuted(bool value) => RealmObjectBase.set(this, 'isMuted', value);

  @override
  bool get updateDB => RealmObjectBase.get<bool>(this, 'updateDB') as bool;
  @override
  set updateDB(bool value) => RealmObjectBase.set(this, 'updateDB', value);

  @override
  String? get type => RealmObjectBase.get<String>(this, 'type') as String?;
  @override
  set type(String? value) => RealmObjectBase.set(this, 'type', value);

  @override
  String? get duration =>
      RealmObjectBase.get<String>(this, 'duration') as String?;
  @override
  set duration(String? value) => RealmObjectBase.set(this, 'duration', value);

  @override
  bool get fromSynced => RealmObjectBase.get<bool>(this, 'fromSynced') as bool;
  @override
  set fromSynced(bool value) => RealmObjectBase.set(this, 'fromSynced', value);

  @override
  bool get toSynced => RealmObjectBase.get<bool>(this, 'toSynced') as bool;
  @override
  set toSynced(bool value) => RealmObjectBase.set(this, 'toSynced', value);

  @override
  RealmMap<bool> get syncMap =>
      RealmObjectBase.get<bool>(this, 'syncMap') as RealmMap<bool>;
  @override
  set syncMap(covariant RealmMap<bool> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmMap<ChatUser?> get users =>
      RealmObjectBase.get<ChatUser?>(this, 'users') as RealmMap<ChatUser?>;
  @override
  set users(covariant RealmMap<ChatUser?> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmMap<DateTime?> get lastMessageAt =>
      RealmObjectBase.get<DateTime?>(this, 'lastMessageAt')
          as RealmMap<DateTime?>;
  @override
  set lastMessageAt(covariant RealmMap<DateTime?> value) =>
      throw RealmUnsupportedSetError();

  @override
  String? get revealRequestBy =>
      RealmObjectBase.get<String>(this, 'revealRequestBy') as String?;
  @override
  set revealRequestBy(String? value) =>
      RealmObjectBase.set(this, 'revealRequestBy', value);

  @override
  String? get revealRequestTo =>
      RealmObjectBase.get<String>(this, 'revealRequestTo') as String?;
  @override
  set revealRequestTo(String? value) =>
      RealmObjectBase.set(this, 'revealRequestTo', value);

  @override
  DateTime? get revealRequestTime =>
      RealmObjectBase.get<DateTime>(this, 'revealRequestTime') as DateTime?;
  @override
  set revealRequestTime(DateTime? value) =>
      RealmObjectBase.set(this, 'revealRequestTime', value);

  @override
  String? get revealStatus =>
      RealmObjectBase.get<String>(this, 'revealStatus') as String?;
  @override
  set revealStatus(String? value) =>
      RealmObjectBase.set(this, 'revealStatus', value);

  @override
  String? get revealMessage =>
      RealmObjectBase.get<String>(this, 'revealMessage') as String?;
  @override
  set revealMessage(String? value) =>
      RealmObjectBase.set(this, 'revealMessage', value);

  @override
  int? get syncUpdatedAt =>
      RealmObjectBase.get<int>(this, 'sync_updated_at') as int?;
  @override
  set syncUpdatedAt(int? value) =>
      RealmObjectBase.set(this, 'sync_updated_at', value);

  @override
  bool get syncUpdateDb =>
      RealmObjectBase.get<bool>(this, 'sync_update_db') as bool;
  @override
  set syncUpdateDb(bool value) =>
      RealmObjectBase.set(this, 'sync_update_db', value);

  @override
  Stream<RealmObjectChanges<ChatRoom>> get changes =>
      RealmObjectBase.getChanges<ChatRoom>(this);

  @override
  Stream<RealmObjectChanges<ChatRoom>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<ChatRoom>(this, keyPaths);

  @override
  ChatRoom freeze() => RealmObjectBase.freezeObject<ChatRoom>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'name': name.toEJson(),
      'text': text.toEJson(),
      'image': image.toEJson(),
      'from': from.toEJson(),
      'to': to.toEJson(),
      'account': account.toEJson(),
      'fromUnreadCount': fromUnreadCount.toEJson(),
      'toUnreadCount': toUnreadCount.toEJson(),
      'status': status.toEJson(),
      'isBanned': isBanned.toEJson(),
      'isLeft': isLeft.toEJson(),
      'fromMuted': fromMuted.toEJson(),
      'toMuted': toMuted.toEJson(),
      'members': members.toEJson(),
      'journalIds': journalIds.toEJson(),
      'deletedMembers': deletedMembers.toEJson(),
      'isFromTyping': isFromTyping.toEJson(),
      'isToTyping': isToTyping.toEJson(),
      'time': time.toEJson(),
      'updatedAt': updatedAt.toEJson(),
      'lastMessageSyncTime': lastMessageSyncTime.toEJson(),
      'startTime': startTime.toEJson(),
      'endTime': endTime.toEJson(),
      'journalId': journalId.toEJson(),
      'emotion': emotion.toEJson(),
      'privacy': privacy.toEJson(),
      'messageBy': messageBy.toEJson(),
      'lastMessage': lastMessage.toEJson(),
      'lastMessageId': lastMessageId.toEJson(),
      'isMuted': isMuted.toEJson(),
      'updateDB': updateDB.toEJson(),
      'type': type.toEJson(),
      'duration': duration.toEJson(),
      'fromSynced': fromSynced.toEJson(),
      'toSynced': toSynced.toEJson(),
      'syncMap': syncMap.toEJson(),
      'users': users.toEJson(),
      'lastMessageAt': lastMessageAt.toEJson(),
      'revealRequestBy': revealRequestBy.toEJson(),
      'revealRequestTo': revealRequestTo.toEJson(),
      'revealRequestTime': revealRequestTime.toEJson(),
      'revealStatus': revealStatus.toEJson(),
      'revealMessage': revealMessage.toEJson(),
      'sync_updated_at': syncUpdatedAt.toEJson(),
      'sync_update_db': syncUpdateDb.toEJson(),
    };
  }

  static EJsonValue _toEJson(ChatRoom value) => value.toEJson();
  static ChatRoom _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'_id': EJsonValue id, 'from': EJsonValue from, 'to': EJsonValue to} =>
        ChatRoom(
          fromEJson(id),
          fromEJson(from),
          fromEJson(to),
          name: fromEJson(ejson['name']),
          text: fromEJson(ejson['text']),
          image: fromEJson(ejson['image']),
          account: fromEJson(ejson['account']),
          fromUnreadCount: fromEJson(ejson['fromUnreadCount'], defaultValue: 0),
          toUnreadCount: fromEJson(ejson['toUnreadCount'], defaultValue: 0),
          status: fromEJson(ejson['status']),
          isBanned: fromEJson(ejson['isBanned'], defaultValue: false),
          isLeft: fromEJson(ejson['isLeft'], defaultValue: false),
          fromMuted: fromEJson(ejson['fromMuted'], defaultValue: false),
          toMuted: fromEJson(ejson['toMuted'], defaultValue: false),
          members: fromEJson(ejson['members'], defaultValue: const []),
          journalIds: fromEJson(ejson['journalIds'], defaultValue: const []),
          deletedMembers: fromEJson(
            ejson['deletedMembers'],
            defaultValue: const [],
          ),
          isFromTyping: fromEJson(ejson['isFromTyping'], defaultValue: false),
          isToTyping: fromEJson(ejson['isToTyping'], defaultValue: false),
          time: fromEJson(ejson['time']),
          updatedAt: fromEJson(ejson['updatedAt']),
          lastMessageSyncTime: fromEJson(ejson['lastMessageSyncTime']),
          startTime: fromEJson(ejson['startTime']),
          endTime: fromEJson(ejson['endTime']),
          journalId: fromEJson(ejson['journalId']),
          emotion: fromEJson(ejson['emotion']),
          privacy: fromEJson(ejson['privacy']),
          messageBy: fromEJson(ejson['messageBy']),
          lastMessage: fromEJson(ejson['lastMessage']),
          lastMessageId: fromEJson(ejson['lastMessageId']),
          isMuted: fromEJson(ejson['isMuted'], defaultValue: false),
          updateDB: fromEJson(ejson['updateDB'], defaultValue: false),
          type: fromEJson(ejson['type']),
          duration: fromEJson(ejson['duration']),
          fromSynced: fromEJson(ejson['fromSynced'], defaultValue: false),
          toSynced: fromEJson(ejson['toSynced'], defaultValue: false),
          syncMap: fromEJson(ejson['syncMap'], defaultValue: const {}),
          users: fromEJson(ejson['users'], defaultValue: const {}),
          lastMessageAt: fromEJson(
            ejson['lastMessageAt'],
            defaultValue: const {},
          ),
          revealRequestBy: fromEJson(ejson['revealRequestBy']),
          revealRequestTo: fromEJson(ejson['revealRequestTo']),
          revealRequestTime: fromEJson(ejson['revealRequestTime']),
          revealStatus: fromEJson(ejson['revealStatus']),
          revealMessage: fromEJson(ejson['revealMessage']),
          syncUpdatedAt: fromEJson(ejson['sync_updated_at']),
          syncUpdateDb: fromEJson(ejson['sync_update_db'], defaultValue: false),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(ChatRoom._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, ChatRoom, 'chatrooms', [
      SchemaProperty(
        'id',
        RealmPropertyType.string,
        mapTo: '_id',
        primaryKey: true,
      ),
      SchemaProperty('name', RealmPropertyType.string, optional: true),
      SchemaProperty('text', RealmPropertyType.string, optional: true),
      SchemaProperty('image', RealmPropertyType.string, optional: true),
      SchemaProperty('from', RealmPropertyType.string),
      SchemaProperty('to', RealmPropertyType.string),
      SchemaProperty('account', RealmPropertyType.string, optional: true),
      SchemaProperty('fromUnreadCount', RealmPropertyType.int, optional: true),
      SchemaProperty('toUnreadCount', RealmPropertyType.int, optional: true),
      SchemaProperty('status', RealmPropertyType.string, optional: true),
      SchemaProperty('isBanned', RealmPropertyType.bool),
      SchemaProperty('isLeft', RealmPropertyType.bool),
      SchemaProperty('fromMuted', RealmPropertyType.bool),
      SchemaProperty('toMuted', RealmPropertyType.bool),
      SchemaProperty(
        'members',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty(
        'journalIds',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty(
        'deletedMembers',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty('isFromTyping', RealmPropertyType.bool),
      SchemaProperty('isToTyping', RealmPropertyType.bool),
      SchemaProperty('time', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('updatedAt', RealmPropertyType.timestamp, optional: true),
      SchemaProperty(
        'lastMessageSyncTime',
        RealmPropertyType.timestamp,
        optional: true,
      ),
      SchemaProperty('startTime', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('endTime', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('journalId', RealmPropertyType.string, optional: true),
      SchemaProperty('emotion', RealmPropertyType.string, optional: true),
      SchemaProperty('privacy', RealmPropertyType.string, optional: true),
      SchemaProperty('messageBy', RealmPropertyType.string, optional: true),
      SchemaProperty('lastMessage', RealmPropertyType.string, optional: true),
      SchemaProperty('lastMessageId', RealmPropertyType.string, optional: true),
      SchemaProperty('isMuted', RealmPropertyType.bool),
      SchemaProperty('updateDB', RealmPropertyType.bool),
      SchemaProperty('type', RealmPropertyType.string, optional: true),
      SchemaProperty('duration', RealmPropertyType.string, optional: true),
      SchemaProperty('fromSynced', RealmPropertyType.bool),
      SchemaProperty('toSynced', RealmPropertyType.bool),
      SchemaProperty(
        'syncMap',
        RealmPropertyType.bool,
        collectionType: RealmCollectionType.map,
      ),
      SchemaProperty(
        'users',
        RealmPropertyType.object,
        optional: true,
        linkTarget: 'chatusers',
        collectionType: RealmCollectionType.map,
      ),
      SchemaProperty(
        'lastMessageAt',
        RealmPropertyType.timestamp,
        optional: true,
        collectionType: RealmCollectionType.map,
      ),
      SchemaProperty(
        'revealRequestBy',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'revealRequestTo',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty(
        'revealRequestTime',
        RealmPropertyType.timestamp,
        optional: true,
      ),
      SchemaProperty('revealStatus', RealmPropertyType.string, optional: true),
      SchemaProperty('revealMessage', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'syncUpdatedAt',
        RealmPropertyType.int,
        mapTo: 'sync_updated_at',
        optional: true,
      ),
      SchemaProperty(
        'syncUpdateDb',
        RealmPropertyType.bool,
        mapTo: 'sync_update_db',
      ),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
