// ignore: file_names

enum MongoDBType { mongoGet, mongoUpsert, mongoPush, mongoUpdate, mongoDelete }

extension MongoDBTypeExtension on MongoDBType {
  String toValue() {
    switch (this) {
      case MongoDBType.mongoGet:
        return 'mongoGet';
      case MongoDBType.mongoUpsert:
        return 'mongoUpsert';
      case MongoDBType.mongoPush:
        return 'mongoPush';

      case MongoDBType.mongoUpdate:
        return 'mongoUpdate';
      case MongoDBType.mongoDelete:
        return 'mongoDelete';
    }
  }
}

extension ServerSyncExtension on Map<String, dynamic> {
  // Prepare a map for wire/server: convert DateTime -> {type: 'date', value: iso}
  Map<String, dynamic> toServerMap() {
    final Map<String, dynamic> data = Map<String, dynamic>.from(this);

    Map<String, dynamic> _wrapDate(DateTime dt) => {
      'type': 'date',
      'value': dt.toIso8601String(),
    };

    // Top-level DateTime values
    for (final key in List<dynamic>.from(data.keys)) {
      final value = data[key];
      if (value is DateTime) {
        data[key as String] = _wrapDate(value);
      }
    }

    // Nested lastMessageAt map entries
    if (data.containsKey('lastMessageAt') && data['lastMessageAt'] is Map) {
      final src = Map<String, dynamic>.from(data['lastMessageAt'] as Map);
      final Map<String, dynamic> wrapped = <String, dynamic>{};
      src.forEach((k, v) {
        if (v is DateTime) {
          wrapped[k] = _wrapDate(v);
        } else {
          wrapped[k] = v;
        }
      });
      data['lastMessageAt'] = wrapped;
    }

    return data;
  }
}
