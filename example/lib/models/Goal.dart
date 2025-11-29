import 'package:realm_flutter_vector_db/realm_vector_db.dart';
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

  List<double> embedding = [];

  String visibility = 'private';
  DateTime? achievedAt;

  DateTime? updatedAt;

  @MapTo('sync_update_db')
  bool sync_update_db = false;

  @MapTo('sync_updated_at')
  int? sync_updated_at; // UTC milliseconds for sync conflict resolution
}

// Goal from json
