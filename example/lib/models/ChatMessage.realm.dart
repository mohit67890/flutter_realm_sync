// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ChatMessage.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class ChatMessage extends _ChatMessage
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  ChatMessage(
    String id,
    String text,
    String senderName,
    String senderId,
    DateTime timestamp, {
    int? syncUpdatedAt,
    bool syncUpdateDb = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<ChatMessage>({
        'sync_update_db': false,
      });
    }
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'text', text);
    RealmObjectBase.set(this, 'senderName', senderName);
    RealmObjectBase.set(this, 'senderId', senderId);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'sync_updated_at', syncUpdatedAt);
    RealmObjectBase.set(this, 'sync_update_db', syncUpdateDb);
  }

  ChatMessage._();

  @override
  String get id => RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  String get text => RealmObjectBase.get<String>(this, 'text') as String;
  @override
  set text(String value) => RealmObjectBase.set(this, 'text', value);

  @override
  String get senderName =>
      RealmObjectBase.get<String>(this, 'senderName') as String;
  @override
  set senderName(String value) =>
      RealmObjectBase.set(this, 'senderName', value);

  @override
  String get senderId =>
      RealmObjectBase.get<String>(this, 'senderId') as String;
  @override
  set senderId(String value) => RealmObjectBase.set(this, 'senderId', value);

  @override
  DateTime get timestamp =>
      RealmObjectBase.get<DateTime>(this, 'timestamp') as DateTime;
  @override
  set timestamp(DateTime value) =>
      RealmObjectBase.set(this, 'timestamp', value);

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
  Stream<RealmObjectChanges<ChatMessage>> get changes =>
      RealmObjectBase.getChanges<ChatMessage>(this);

  @override
  Stream<RealmObjectChanges<ChatMessage>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<ChatMessage>(this, keyPaths);

  @override
  ChatMessage freeze() => RealmObjectBase.freezeObject<ChatMessage>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'text': text.toEJson(),
      'senderName': senderName.toEJson(),
      'senderId': senderId.toEJson(),
      'timestamp': timestamp.toEJson(),
      'sync_updated_at': syncUpdatedAt.toEJson(),
      'sync_update_db': syncUpdateDb.toEJson(),
    };
  }

  static EJsonValue _toEJson(ChatMessage value) => value.toEJson();
  static ChatMessage _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        '_id': EJsonValue id,
        'text': EJsonValue text,
        'senderName': EJsonValue senderName,
        'senderId': EJsonValue senderId,
        'timestamp': EJsonValue timestamp,
      } =>
        ChatMessage(
          fromEJson(id),
          fromEJson(text),
          fromEJson(senderName),
          fromEJson(senderId),
          fromEJson(timestamp),
          syncUpdatedAt: fromEJson(ejson['sync_updated_at']),
          syncUpdateDb: fromEJson(ejson['sync_update_db'], defaultValue: false),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(ChatMessage._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      ChatMessage,
      'chat_messages',
      [
        SchemaProperty(
          'id',
          RealmPropertyType.string,
          mapTo: '_id',
          primaryKey: true,
        ),
        SchemaProperty('text', RealmPropertyType.string),
        SchemaProperty('senderName', RealmPropertyType.string),
        SchemaProperty('senderId', RealmPropertyType.string),
        SchemaProperty('timestamp', RealmPropertyType.timestamp),
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
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
