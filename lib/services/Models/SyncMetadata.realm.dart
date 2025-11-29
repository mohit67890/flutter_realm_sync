// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SyncMetadata.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class SyncMetadata extends _SyncMetadata
    with RealmEntity, RealmObjectBase, RealmObject {
  SyncMetadata(
    String collectionName,
    int lastRemoteTimestamp, {
    DateTime? lastUpdated,
  }) {
    RealmObjectBase.set(this, '_id', collectionName);
    RealmObjectBase.set(this, 'lastRemoteTimestamp', lastRemoteTimestamp);
    RealmObjectBase.set(this, 'lastUpdated', lastUpdated);
  }

  SyncMetadata._();

  @override
  String get collectionName =>
      RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set collectionName(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  int get lastRemoteTimestamp =>
      RealmObjectBase.get<int>(this, 'lastRemoteTimestamp') as int;
  @override
  set lastRemoteTimestamp(int value) =>
      RealmObjectBase.set(this, 'lastRemoteTimestamp', value);

  @override
  DateTime? get lastUpdated =>
      RealmObjectBase.get<DateTime>(this, 'lastUpdated') as DateTime?;
  @override
  set lastUpdated(DateTime? value) =>
      RealmObjectBase.set(this, 'lastUpdated', value);

  @override
  Stream<RealmObjectChanges<SyncMetadata>> get changes =>
      RealmObjectBase.getChanges<SyncMetadata>(this);

  @override
  Stream<RealmObjectChanges<SyncMetadata>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<SyncMetadata>(this, keyPaths);

  @override
  SyncMetadata freeze() => RealmObjectBase.freezeObject<SyncMetadata>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': collectionName.toEJson(),
      'lastRemoteTimestamp': lastRemoteTimestamp.toEJson(),
      'lastUpdated': lastUpdated.toEJson(),
    };
  }

  static EJsonValue _toEJson(SyncMetadata value) => value.toEJson();
  static SyncMetadata _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        '_id': EJsonValue collectionName,
        'lastRemoteTimestamp': EJsonValue lastRemoteTimestamp,
      } =>
        SyncMetadata(
          fromEJson(collectionName),
          fromEJson(lastRemoteTimestamp),
          lastUpdated: fromEJson(ejson['lastUpdated']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(SyncMetadata._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      SyncMetadata,
      'sync_metadata',
      [
        SchemaProperty(
          'collectionName',
          RealmPropertyType.string,
          mapTo: '_id',
          primaryKey: true,
        ),
        SchemaProperty('lastRemoteTimestamp', RealmPropertyType.int),
        SchemaProperty(
          'lastUpdated',
          RealmPropertyType.timestamp,
          optional: true,
        ),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
