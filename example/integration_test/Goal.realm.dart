// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Goal.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class Goal extends $Goal with RealmEntity, RealmObjectBase, RealmObject {
  static var _defaultsSet = false;

  Goal(
    String id,
    String userId,
    String title, {
    String? description,
    DateTime? createdAt,
    DateTime? targetDate,
    double progress = 0.0,
    double stepProgress = 0.01,
    String status = 'active',
    String? emotionTag,
    Iterable<String> linkedJournalIds = const [],
    String? relatedConstellationId,
    int importance = 3,
    String category = 'personal',
    String colorHex = '#FFFFFF',
    double skyX = 0.5,
    double skyY = 0.5,
    bool sync_update_db = false,
    Iterable<double> embedding = const [],
    String visibility = 'private',
    DateTime? achievedAt,
    Iterable<String> reflectionNotes = const [],
    double motivationLevel = 0.7,
    DateTime? updatedAt,
    int? sync_updated_at,
  }) {
    if (!_defaultsSet) {
      _defaultsSet = RealmObjectBase.setDefaults<Goal>({
        'progress': 0.0,
        'stepProgress': 0.01,
        'status': 'active',
        'importance': 3,
        'category': 'personal',
        'colorHex': '#FFFFFF',
        'skyX': 0.5,
        'skyY': 0.5,
        'sync_update_db': false,
        'visibility': 'private',
        'motivationLevel': 0.7,
      });
    }
    RealmObjectBase.set(this, '_id', id);
    RealmObjectBase.set(this, 'userId', userId);
    RealmObjectBase.set(this, 'title', title);
    RealmObjectBase.set(this, 'description', description);
    RealmObjectBase.set(this, 'createdAt', createdAt);
    RealmObjectBase.set(this, 'targetDate', targetDate);
    RealmObjectBase.set(this, 'progress', progress);
    RealmObjectBase.set(this, 'stepProgress', stepProgress);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'emotionTag', emotionTag);
    RealmObjectBase.set<RealmList<String>>(
      this,
      'linkedJournalIds',
      RealmList<String>(linkedJournalIds),
    );
    RealmObjectBase.set(this, 'relatedConstellationId', relatedConstellationId);
    RealmObjectBase.set(this, 'importance', importance);
    RealmObjectBase.set(this, 'category', category);
    RealmObjectBase.set(this, 'colorHex', colorHex);
    RealmObjectBase.set(this, 'skyX', skyX);
    RealmObjectBase.set(this, 'skyY', skyY);
    RealmObjectBase.set(this, 'sync_update_db', sync_update_db);
    RealmObjectBase.set<RealmList<double>>(
      this,
      'embedding',
      RealmList<double>(embedding),
    );
    RealmObjectBase.set(this, 'visibility', visibility);
    RealmObjectBase.set(this, 'achievedAt', achievedAt);
    RealmObjectBase.set<RealmList<String>>(
      this,
      'reflectionNotes',
      RealmList<String>(reflectionNotes),
    );
    RealmObjectBase.set(this, 'motivationLevel', motivationLevel);
    RealmObjectBase.set(this, 'updatedAt', updatedAt);
    RealmObjectBase.set(this, 'sync_updated_at', sync_updated_at);
  }

  Goal._();

  @override
  String get id => RealmObjectBase.get<String>(this, '_id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, '_id', value);

  @override
  String get userId => RealmObjectBase.get<String>(this, 'userId') as String;
  @override
  set userId(String value) => RealmObjectBase.set(this, 'userId', value);

  @override
  String get title => RealmObjectBase.get<String>(this, 'title') as String;
  @override
  set title(String value) => RealmObjectBase.set(this, 'title', value);

  @override
  String? get description =>
      RealmObjectBase.get<String>(this, 'description') as String?;
  @override
  set description(String? value) =>
      RealmObjectBase.set(this, 'description', value);

  @override
  DateTime? get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime?;
  @override
  set createdAt(DateTime? value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  DateTime? get targetDate =>
      RealmObjectBase.get<DateTime>(this, 'targetDate') as DateTime?;
  @override
  set targetDate(DateTime? value) =>
      RealmObjectBase.set(this, 'targetDate', value);

  @override
  double get progress =>
      RealmObjectBase.get<double>(this, 'progress') as double;
  @override
  set progress(double value) => RealmObjectBase.set(this, 'progress', value);

  @override
  double get stepProgress =>
      RealmObjectBase.get<double>(this, 'stepProgress') as double;
  @override
  set stepProgress(double value) =>
      RealmObjectBase.set(this, 'stepProgress', value);

  @override
  String get status => RealmObjectBase.get<String>(this, 'status') as String;
  @override
  set status(String value) => RealmObjectBase.set(this, 'status', value);

  @override
  String? get emotionTag =>
      RealmObjectBase.get<String>(this, 'emotionTag') as String?;
  @override
  set emotionTag(String? value) =>
      RealmObjectBase.set(this, 'emotionTag', value);

  @override
  RealmList<String> get linkedJournalIds =>
      RealmObjectBase.get<String>(this, 'linkedJournalIds')
          as RealmList<String>;
  @override
  set linkedJournalIds(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  String? get relatedConstellationId =>
      RealmObjectBase.get<String>(this, 'relatedConstellationId') as String?;
  @override
  set relatedConstellationId(String? value) =>
      RealmObjectBase.set(this, 'relatedConstellationId', value);

  @override
  int get importance => RealmObjectBase.get<int>(this, 'importance') as int;
  @override
  set importance(int value) => RealmObjectBase.set(this, 'importance', value);

  @override
  String get category =>
      RealmObjectBase.get<String>(this, 'category') as String;
  @override
  set category(String value) => RealmObjectBase.set(this, 'category', value);

  @override
  String get colorHex =>
      RealmObjectBase.get<String>(this, 'colorHex') as String;
  @override
  set colorHex(String value) => RealmObjectBase.set(this, 'colorHex', value);

  @override
  double get skyX => RealmObjectBase.get<double>(this, 'skyX') as double;
  @override
  set skyX(double value) => RealmObjectBase.set(this, 'skyX', value);

  @override
  double get skyY => RealmObjectBase.get<double>(this, 'skyY') as double;
  @override
  set skyY(double value) => RealmObjectBase.set(this, 'skyY', value);

  @override
  bool get sync_update_db =>
      RealmObjectBase.get<bool>(this, 'sync_update_db') as bool;
  @override
  set sync_update_db(bool value) =>
      RealmObjectBase.set(this, 'sync_update_db', value);

  @override
  RealmList<double> get embedding =>
      RealmObjectBase.get<double>(this, 'embedding') as RealmList<double>;
  @override
  set embedding(covariant RealmList<double> value) =>
      throw RealmUnsupportedSetError();

  @override
  String get visibility =>
      RealmObjectBase.get<String>(this, 'visibility') as String;
  @override
  set visibility(String value) =>
      RealmObjectBase.set(this, 'visibility', value);

  @override
  DateTime? get achievedAt =>
      RealmObjectBase.get<DateTime>(this, 'achievedAt') as DateTime?;
  @override
  set achievedAt(DateTime? value) =>
      RealmObjectBase.set(this, 'achievedAt', value);

  @override
  RealmList<String> get reflectionNotes =>
      RealmObjectBase.get<String>(this, 'reflectionNotes') as RealmList<String>;
  @override
  set reflectionNotes(covariant RealmList<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  double get motivationLevel =>
      RealmObjectBase.get<double>(this, 'motivationLevel') as double;
  @override
  set motivationLevel(double value) =>
      RealmObjectBase.set(this, 'motivationLevel', value);

  @override
  DateTime? get updatedAt =>
      RealmObjectBase.get<DateTime>(this, 'updatedAt') as DateTime?;
  @override
  set updatedAt(DateTime? value) =>
      RealmObjectBase.set(this, 'updatedAt', value);

  @override
  int? get sync_updated_at =>
      RealmObjectBase.get<int>(this, 'sync_updated_at') as int?;
  @override
  set sync_updated_at(int? value) =>
      RealmObjectBase.set(this, 'sync_updated_at', value);

  @override
  Stream<RealmObjectChanges<Goal>> get changes =>
      RealmObjectBase.getChanges<Goal>(this);

  @override
  Stream<RealmObjectChanges<Goal>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Goal>(this, keyPaths);

  @override
  Goal freeze() => RealmObjectBase.freezeObject<Goal>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      '_id': id.toEJson(),
      'userId': userId.toEJson(),
      'title': title.toEJson(),
      'description': description.toEJson(),
      'createdAt': createdAt.toEJson(),
      'targetDate': targetDate.toEJson(),
      'progress': progress.toEJson(),
      'stepProgress': stepProgress.toEJson(),
      'status': status.toEJson(),
      'emotionTag': emotionTag.toEJson(),
      'linkedJournalIds': linkedJournalIds.toEJson(),
      'relatedConstellationId': relatedConstellationId.toEJson(),
      'importance': importance.toEJson(),
      'category': category.toEJson(),
      'colorHex': colorHex.toEJson(),
      'skyX': skyX.toEJson(),
      'skyY': skyY.toEJson(),
      'sync_update_db': sync_update_db.toEJson(),
      'embedding': embedding.toEJson(),
      'visibility': visibility.toEJson(),
      'achievedAt': achievedAt.toEJson(),
      'reflectionNotes': reflectionNotes.toEJson(),
      'motivationLevel': motivationLevel.toEJson(),
      'updatedAt': updatedAt.toEJson(),
      'sync_updated_at': sync_updated_at.toEJson(),
    };
  }

  static EJsonValue _toEJson(Goal value) => value.toEJson();
  static Goal _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        '_id': EJsonValue id,
        'userId': EJsonValue userId,
        'title': EJsonValue title,
      } =>
        Goal(
          fromEJson(id),
          fromEJson(userId),
          fromEJson(title),
          description: fromEJson(ejson['description']),
          createdAt: fromEJson(ejson['createdAt']),
          targetDate: fromEJson(ejson['targetDate']),
          progress: fromEJson(ejson['progress'], defaultValue: 0.0),
          stepProgress: fromEJson(ejson['stepProgress'], defaultValue: 0.01),
          status: fromEJson(ejson['status'], defaultValue: 'active'),
          emotionTag: fromEJson(ejson['emotionTag']),
          linkedJournalIds: fromEJson(
            ejson['linkedJournalIds'],
            defaultValue: const [],
          ),
          relatedConstellationId: fromEJson(ejson['relatedConstellationId']),
          importance: fromEJson(ejson['importance'], defaultValue: 3),
          category: fromEJson(ejson['category'], defaultValue: 'personal'),
          colorHex: fromEJson(ejson['colorHex'], defaultValue: '#FFFFFF'),
          skyX: fromEJson(ejson['skyX'], defaultValue: 0.5),
          skyY: fromEJson(ejson['skyY'], defaultValue: 0.5),
          sync_update_db: fromEJson(
            ejson['sync_update_db'],
            defaultValue: false,
          ),
          embedding: fromEJson(ejson['embedding'], defaultValue: const []),
          visibility: fromEJson(ejson['visibility'], defaultValue: 'private'),
          achievedAt: fromEJson(ejson['achievedAt']),
          reflectionNotes: fromEJson(
            ejson['reflectionNotes'],
            defaultValue: const [],
          ),
          motivationLevel: fromEJson(
            ejson['motivationLevel'],
            defaultValue: 0.7,
          ),
          updatedAt: fromEJson(ejson['updatedAt']),
          sync_updated_at: fromEJson(ejson['sync_updated_at']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Goal._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, Goal, 'goals', [
      SchemaProperty(
        'id',
        RealmPropertyType.string,
        mapTo: '_id',
        primaryKey: true,
      ),
      SchemaProperty('userId', RealmPropertyType.string),
      SchemaProperty('title', RealmPropertyType.string),
      SchemaProperty('description', RealmPropertyType.string, optional: true),
      SchemaProperty('createdAt', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('targetDate', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('progress', RealmPropertyType.double),
      SchemaProperty('stepProgress', RealmPropertyType.double),
      SchemaProperty('status', RealmPropertyType.string),
      SchemaProperty('emotionTag', RealmPropertyType.string, optional: true),
      SchemaProperty(
        'linkedJournalIds',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty(
        'relatedConstellationId',
        RealmPropertyType.string,
        optional: true,
      ),
      SchemaProperty('importance', RealmPropertyType.int),
      SchemaProperty('category', RealmPropertyType.string),
      SchemaProperty('colorHex', RealmPropertyType.string),
      SchemaProperty('skyX', RealmPropertyType.double),
      SchemaProperty('skyY', RealmPropertyType.double),
      SchemaProperty('sync_update_db', RealmPropertyType.bool),
      SchemaProperty(
        'embedding',
        RealmPropertyType.double,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty('visibility', RealmPropertyType.string),
      SchemaProperty('achievedAt', RealmPropertyType.timestamp, optional: true),
      SchemaProperty(
        'reflectionNotes',
        RealmPropertyType.string,
        collectionType: RealmCollectionType.list,
      ),
      SchemaProperty('motivationLevel', RealmPropertyType.double),
      SchemaProperty('updatedAt', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('sync_updated_at', RealmPropertyType.int, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
