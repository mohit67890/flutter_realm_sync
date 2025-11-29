import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/utils/helpers.dart';
part 'Goal.realm.dart';

@RealmModel()
@MapTo('goals')
class $Goal {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String userId;
  late String title;
  String? description;
  DateTime? createdAt;
  DateTime? targetDate;
  double progress = 0.0;
  double stepProgress = 0.01;
  String status = 'active'; // enum
  String? emotionTag;
  List<String> linkedJournalIds = [];
  String? relatedConstellationId;
  int importance = 3;
  String category = 'personal';
  String colorHex = '#FFFFFF';
  double skyX = 0.5;
  double skyY = 0.5;

  @MapTo('sync_update_db')
  bool sync_update_db = false;
  List<double> embedding = [];

  String visibility = 'private';
  DateTime? achievedAt;
  List<String> reflectionNotes = [];
  double motivationLevel = 0.7;
  DateTime? updatedAt;

  @MapTo('sync_updated_at')
  int? sync_updated_at; // UTC milliseconds for sync conflict resolution

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      "id": id,
      'userId': userId,
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'targetDate': targetDate,
      'progress': progress,
      'stepProgress': stepProgress,
      'status': status,
      'emotionTag': emotionTag,
      'linkedJournalIds': linkedJournalIds,
      'relatedConstellationId': relatedConstellationId,
      'importance': importance,
      'category': category,
      'colorHex': colorHex,
      'skyX': skyX,
      'skyY': skyY,
      'embedding': embedding,
      'sync_update_db': sync_update_db,
      'visibility': visibility,
      'achievedAt': achievedAt,
      'reflectionNotes': reflectionNotes,
      'motivationLevel': motivationLevel,
      'updatedAt': updatedAt,
    };
  }
}

// Goal from json

Goal goalFromJson(Map<String, dynamic> json) {
  return Goal(
    json['_id'] ?? json['id'] as String,
    json['userId'] as String,
    json['title'] as String,
    description: json['description'] as String?,
    createdAt: json['createdAt'] != null ? parseDate(json['createdAt']) : null,
    targetDate:
        json['targetDate'] != null ? parseDate(json['targetDate']) : null,
    progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    stepProgress: (json['stepProgress'] as num?)?.toDouble() ?? 0.01,
    status: json['status'] as String? ?? 'active',
    emotionTag: json['emotionTag'] as String?,
    linkedJournalIds:
        (json['linkedJournalIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    relatedConstellationId: json['relatedConstellationId'] as String?,
    importance: json['importance'] as int? ?? 3,
    sync_update_db: json['updateDB'] as bool? ?? false,
    category: json['category'] as String? ?? 'personal',
    colorHex: json['colorHex'] as String? ?? '#FFFFFF',
    skyX: (json['skyX'] as num?)?.toDouble() ?? 0.5,
    skyY: (json['skyY'] as num?)?.toDouble() ?? 0.5,
    visibility: json['visibility'] as String? ?? 'private',
    achievedAt:
        json['achievedAt'] != null ? parseDate(json['achievedAt']) : null,
    reflectionNotes:
        (json['reflectionNotes'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    motivationLevel: (json['motivationLevel'] as num?)?.toDouble() ?? 0.7,
    updatedAt: json['updatedAt'] != null ? parseDate(json['updatedAt']) : null,
    embedding:
        (json['embedding'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [],
  );
}
