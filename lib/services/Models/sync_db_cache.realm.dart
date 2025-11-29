// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_db_cache.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class SyncDBCache extends _SyncDBCache
    with RealmEntity, RealmObjectBase, RealmObject {
  SyncDBCache(
    String id,
    String uid,
    String collection,
    String entityId,
    String diffJson,
    String newJson,
    String operation, {
    DateTime? createdAt,
  }) {
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'uid', uid);
    RealmObjectBase.set(this, 'collection', collection);
    RealmObjectBase.set(this, 'entityId', entityId);
    RealmObjectBase.set(this, 'diffJson', diffJson);
    RealmObjectBase.set(this, 'newJson', newJson);
    RealmObjectBase.set(this, 'operation', operation);
    RealmObjectBase.set(this, 'createdAt', createdAt);
  }

  SyncDBCache._();

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
  String get diffJson =>
      RealmObjectBase.get<String>(this, 'diffJson') as String;
  @override
  set diffJson(String value) => RealmObjectBase.set(this, 'diffJson', value);

  @override
  String get newJson => RealmObjectBase.get<String>(this, 'newJson') as String;
  @override
  set newJson(String value) => RealmObjectBase.set(this, 'newJson', value);

  @override
  String get operation =>
      RealmObjectBase.get<String>(this, 'operation') as String;
  @override
  set operation(String value) => RealmObjectBase.set(this, 'operation', value);

  @override
  DateTime? get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime?;
  @override
  set createdAt(DateTime? value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  Stream<RealmObjectChanges<SyncDBCache>> get changes =>
      RealmObjectBase.getChanges<SyncDBCache>(this);

  @override
  Stream<RealmObjectChanges<SyncDBCache>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<SyncDBCache>(this, keyPaths);

  @override
  SyncDBCache freeze() => RealmObjectBase.freezeObject<SyncDBCache>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'uid': uid.toEJson(),
      'collection': collection.toEJson(),
      'entityId': entityId.toEJson(),
      'diffJson': diffJson.toEJson(),
      'newJson': newJson.toEJson(),
      'operation': operation.toEJson(),
      'createdAt': createdAt.toEJson(),
    };
  }

  static EJsonValue _toEJson(SyncDBCache value) => value.toEJson();
  static SyncDBCache _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        '_id': EJsonValue id,
        'uid': EJsonValue uid,
        'collection': EJsonValue collection,
        'entityId': EJsonValue entityId,
        'diffJson': EJsonValue diffJson,
        'newJson': EJsonValue newJson,
        'operation': EJsonValue operation,
      } =>
        SyncDBCache(
          fromEJson(id),
          fromEJson(uid),
          fromEJson(collection),
          fromEJson(entityId),
          fromEJson(diffJson),
          fromEJson(newJson),
          fromEJson(operation),
          createdAt: fromEJson(ejson['createdAt']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(SyncDBCache._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, SyncDBCache, 'dbcache', [
      SchemaProperty(
        'id',
        RealmPropertyType.string,
        mapTo: '_id',
        primaryKey: true,
      ),
      SchemaProperty('uid', RealmPropertyType.string),
      SchemaProperty('collection', RealmPropertyType.string),
      SchemaProperty('entityId', RealmPropertyType.string),
      SchemaProperty('diffJson', RealmPropertyType.string),
      SchemaProperty('newJson', RealmPropertyType.string),
      SchemaProperty('operation', RealmPropertyType.string),
      SchemaProperty('createdAt', RealmPropertyType.timestamp, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
