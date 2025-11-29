// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_outbox_patch.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class SyncOutboxPatch extends _SyncOutboxPatch
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  SyncOutboxPatch(
    String id,
    String uid,
    String collection,
    String entityId,
    String payloadJson, {
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int attempts = 0,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<SyncOutboxPatch>({
        'attempts': 0,
      });
    }
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'uid', uid);
    RealmObjectBase.set(this, 'collection', collection);
    RealmObjectBase.set(this, 'entityId', entityId);
    RealmObjectBase.set(this, 'payloadJson', payloadJson);
    RealmObjectBase.set(this, 'createdAt', createdAt);
    RealmObjectBase.set(this, 'lastAttemptAt', lastAttemptAt);
    RealmObjectBase.set(this, 'attempts', attempts);
  }

  SyncOutboxPatch._();

  @override
  String get id => RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  String get uid => RealmObjectBase.get<String>(this, 'uid') as String;
  @override
  set uid(String value) => RealmObjectBase.set(this, 'uid', value);

  @override
  String get collection =>
      RealmObjectBase.get<String>(this, 'collection') as String;
  @override
  set collection(String value) =>
      RealmObjectBase.set(this, 'collection', value);

  @override
  String get entityId =>
      RealmObjectBase.get<String>(this, 'entityId') as String;
  @override
  set entityId(String value) => RealmObjectBase.set(this, 'entityId', value);

  @override
  String get payloadJson =>
      RealmObjectBase.get<String>(this, 'payloadJson') as String;
  @override
  set payloadJson(String value) =>
      RealmObjectBase.set(this, 'payloadJson', value);

  @override
  DateTime? get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime?;
  @override
  set createdAt(DateTime? value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  DateTime? get lastAttemptAt =>
      RealmObjectBase.get<DateTime>(this, 'lastAttemptAt') as DateTime?;
  @override
  set lastAttemptAt(DateTime? value) =>
      RealmObjectBase.set(this, 'lastAttemptAt', value);

  @override
  int get attempts => RealmObjectBase.get<int>(this, 'attempts') as int;
  @override
  set attempts(int value) => RealmObjectBase.set(this, 'attempts', value);

  @override
  Stream<RealmObjectChanges<SyncOutboxPatch>> get changes =>
      RealmObjectBase.getChanges<SyncOutboxPatch>(this);

  @override
  Stream<RealmObjectChanges<SyncOutboxPatch>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<SyncOutboxPatch>(this, keyPaths);

  @override
  SyncOutboxPatch freeze() =>
      RealmObjectBase.freezeObject<SyncOutboxPatch>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'uid': uid.toEJson(),
      'collection': collection.toEJson(),
      'entityId': entityId.toEJson(),
      'payloadJson': payloadJson.toEJson(),
      'createdAt': createdAt.toEJson(),
      'lastAttemptAt': lastAttemptAt.toEJson(),
      'attempts': attempts.toEJson(),
    };
  }

  static EJsonValue _toEJson(SyncOutboxPatch value) => value.toEJson();
  static SyncOutboxPatch _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        '_id': EJsonValue id,
        'uid': EJsonValue uid,
        'collection': EJsonValue collection,
        'entityId': EJsonValue entityId,
        'payloadJson': EJsonValue payloadJson,
      } =>
        SyncOutboxPatch(
          fromEJson(id),
          fromEJson(uid),
          fromEJson(collection),
          fromEJson(entityId),
          fromEJson(payloadJson),
          createdAt: fromEJson(ejson['createdAt']),
          lastAttemptAt: fromEJson(ejson['lastAttemptAt']),
          attempts: fromEJson(ejson['attempts'], defaultValue: 0),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(SyncOutboxPatch._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      SyncOutboxPatch,
      'outbox',
      [
        SchemaProperty(
          'id',
          RealmPropertyType.string,
          mapTo: '_id',
          primaryKey: true,
        ),
        SchemaProperty('uid', RealmPropertyType.string),
        SchemaProperty('collection', RealmPropertyType.string),
        SchemaProperty('entityId', RealmPropertyType.string),
        SchemaProperty('payloadJson', RealmPropertyType.string),
        SchemaProperty(
          'createdAt',
          RealmPropertyType.timestamp,
          optional: true,
        ),
        SchemaProperty(
          'lastAttemptAt',
          RealmPropertyType.timestamp,
          optional: true,
        ),
        SchemaProperty('attempts', RealmPropertyType.int),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
