// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ManyRelationship.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class Person extends _Person with RealmEntity, RealmObjectBase, RealmObject {
  Person(ObjectId id, String firstName, String lastName, {int? age}) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'firstName', firstName);
    RealmObjectBase.set(this, 'lastName', lastName);
    RealmObjectBase.set(this, 'age', age);
  }

  Person._();

  @override
  ObjectId get id => RealmObjectBase.get<ObjectId>(this, 'id') as ObjectId;
  @override
  set id(ObjectId value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get firstName =>
      RealmObjectBase.get<String>(this, 'firstName') as String;
  @override
  set firstName(String value) => RealmObjectBase.set(this, 'firstName', value);

  @override
  String get lastName =>
      RealmObjectBase.get<String>(this, 'lastName') as String;
  @override
  set lastName(String value) => RealmObjectBase.set(this, 'lastName', value);

  @override
  int? get age => RealmObjectBase.get<int>(this, 'age') as int?;
  @override
  set age(int? value) => RealmObjectBase.set(this, 'age', value);

  @override
  Stream<RealmObjectChanges<Person>> get changes =>
      RealmObjectBase.getChanges<Person>(this);

  @override
  Stream<RealmObjectChanges<Person>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Person>(this, keyPaths);

  @override
  Person freeze() => RealmObjectBase.freezeObject<Person>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'firstName': firstName.toEJson(),
      'lastName': lastName.toEJson(),
      'age': age.toEJson(),
    };
  }

  static EJsonValue _toEJson(Person value) => value.toEJson();
  static Person _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'firstName': EJsonValue firstName,
        'lastName': EJsonValue lastName,
      } =>
        Person(
          fromEJson(id),
          fromEJson(firstName),
          fromEJson(lastName),
          age: fromEJson(ejson['age']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Person._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Person, 'Person', [
      SchemaProperty('id', RealmPropertyType.objectid, primaryKey: true),
      SchemaProperty('firstName', RealmPropertyType.string),
      SchemaProperty('lastName', RealmPropertyType.string),
      SchemaProperty('age', RealmPropertyType.int, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class Scooter extends _Scooter with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  Scooter(
    ObjectId id,
    String name, {
    Person? owner,
    int? syncUpdatedAt,
    bool syncUpdateDb = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<Scooter>({
        'sync_update_db': false,
      });
    }
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'owner', owner);
    RealmObjectBase.set(this, 'sync_updated_at', syncUpdatedAt);
    RealmObjectBase.set(this, 'sync_update_db', syncUpdateDb);
  }

  Scooter._();

  @override
  ObjectId get id => RealmObjectBase.get<ObjectId>(this, 'id') as ObjectId;
  @override
  set id(ObjectId value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  Person? get owner => RealmObjectBase.get<Person>(this, 'owner') as Person?;
  @override
  set owner(covariant Person? value) =>
      RealmObjectBase.set(this, 'owner', value);

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
  Stream<RealmObjectChanges<Scooter>> get changes =>
      RealmObjectBase.getChanges<Scooter>(this);

  @override
  Stream<RealmObjectChanges<Scooter>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Scooter>(this, keyPaths);

  @override
  Scooter freeze() => RealmObjectBase.freezeObject<Scooter>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'name': name.toEJson(),
      'owner': owner.toEJson(),
      'sync_updated_at': syncUpdatedAt.toEJson(),
      'sync_update_db': syncUpdateDb.toEJson(),
    };
  }

  static EJsonValue _toEJson(Scooter value) => value.toEJson();
  static Scooter _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'id': EJsonValue id, 'name': EJsonValue name} => Scooter(
        fromEJson(id),
        fromEJson(name),
        owner: fromEJson(ejson['owner']),
        syncUpdatedAt: fromEJson(ejson['sync_updated_at']),
        syncUpdateDb: fromEJson(ejson['sync_update_db'], defaultValue: false),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Scooter._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Scooter, 'Scooter', [
      SchemaProperty('id', RealmPropertyType.objectid, primaryKey: true),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty(
        'owner',
        RealmPropertyType.object,
        optional: true,
        linkTarget: 'Person',
      ),
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

class ScooterShop extends _ScooterShop
    with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  ScooterShop(
    ObjectId id,
    String name, {
    Iterable<Scooter> scooters = const [],
    int? syncUpdatedAt,
    bool syncUpdateDb = false,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<ScooterShop>({
        'sync_update_db': false,
      });
    }
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set<RealmList<Scooter>>(
      this,
      'scooters',
      RealmList<Scooter>(scooters),
    );
    RealmObjectBase.set(this, 'sync_updated_at', syncUpdatedAt);
    RealmObjectBase.set(this, 'sync_update_db', syncUpdateDb);
  }

  ScooterShop._();

  @override
  ObjectId get id => RealmObjectBase.get<ObjectId>(this, 'id') as ObjectId;
  @override
  set id(ObjectId value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  RealmList<Scooter> get scooters =>
      RealmObjectBase.get<Scooter>(this, 'scooters') as RealmList<Scooter>;
  @override
  set scooters(covariant RealmList<Scooter> value) =>
      throw RealmUnsupportedSetError();

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
  Stream<RealmObjectChanges<ScooterShop>> get changes =>
      RealmObjectBase.getChanges<ScooterShop>(this);

  @override
  Stream<RealmObjectChanges<ScooterShop>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<ScooterShop>(this, keyPaths);

  @override
  ScooterShop freeze() => RealmObjectBase.freezeObject<ScooterShop>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'name': name.toEJson(),
      'scooters': scooters.toEJson(),
      'sync_updated_at': syncUpdatedAt.toEJson(),
      'sync_update_db': syncUpdateDb.toEJson(),
    };
  }

  static EJsonValue _toEJson(ScooterShop value) => value.toEJson();
  static ScooterShop _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'id': EJsonValue id, 'name': EJsonValue name} => ScooterShop(
        fromEJson(id),
        fromEJson(name),
        scooters: fromEJson(ejson['scooters']),
        syncUpdatedAt: fromEJson(ejson['sync_updated_at']),
        syncUpdateDb: fromEJson(ejson['sync_update_db'], defaultValue: false),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(ScooterShop._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      ScooterShop,
      'ScooterShop',
      [
        SchemaProperty('id', RealmPropertyType.objectid, primaryKey: true),
        SchemaProperty('name', RealmPropertyType.string),
        SchemaProperty(
          'scooters',
          RealmPropertyType.object,
          linkTarget: 'Scooter',
          collectionType: RealmCollectionType.list,
        ),
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
