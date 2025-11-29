import 'package:realm_flutter_vector_db/realm_vector_db.dart';
part 'ManyRelationship.realm.dart';

@RealmModel()
class _Person {
  @PrimaryKey()
  late ObjectId id;
  late String firstName;
  late String lastName;
  late int? age;
}

@RealmModel()
class _Scooter {
  @PrimaryKey()
  late ObjectId id;

  late String name;
  late _Person? owner;

  @MapTo('sync_updated_at')
  int? syncUpdatedAt;

  @MapTo('sync_update_db')
  bool syncUpdateDb = false;
}

@RealmModel()
class _ScooterShop {
  @PrimaryKey()
  late ObjectId id;

  late String name;
  late List<_Scooter> scooters;

  @MapTo('sync_updated_at')
  int? syncUpdatedAt;

  @MapTo('sync_update_db')
  bool syncUpdateDb = false;
}
