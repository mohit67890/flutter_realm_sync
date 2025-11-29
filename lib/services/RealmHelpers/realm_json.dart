import 'dart:convert';
import 'dart:typed_data';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';

/// JSON <-> RealmObject serialization helpers with automatic nested object support.
///
/// **Serialization Strategy (in order of preference):**
/// 1. **Generated toEJson()** - Best option, automatically handles all nested RealmObjects
/// 2. **Schema introspection** - Auto-detects properties when toEJson() unavailable
/// 3. **Explicit property lists** - Manual specification for edge cases
///
/// **Deserialization Strategy:**
/// 1. **fromEJsonMap&lt;T&gt;()** - Recommended, uses generated fromEJson() for automatic nested object handling
/// 2. **fromJsonWith&lt;T&gt;()** - Manual deserialization with explicit property lists
///
/// **Round-Trip Serialization:**
/// ```dart
/// // Initialize schemas
/// ChatUser.schema;
/// ChatRoom.schema;
///
/// // Serialize
/// final json = RealmJson.toJsonWith(chatRoom, null);
///
/// // Deserialize (round-trip)
/// final restored = RealmJson.fromEJsonMap<ChatRoom>(json);
/// ```
///
/// Supported types:
/// - Primitives: String, int, double, bool
/// - DateTime (UTC converted to/from ISO-8601)
/// - ObjectId, Uuid (string representation)
/// - Decimal128 (string representation)
/// - Uint8List (base64 encoding)
/// - RealmValue (mixed type with type metadata)
/// - Collections: RealmList, RealmSet, RealmMap
/// - Relationships: Embedded objects, to-one, to-many (fully recursive)
/// - Backlinks are automatically skipped during serialization
class RealmJson {
  /// Serialize a RealmObject into JSON using the provided property names.
  ///
  /// For embedded objects or relationships, provide nested property maps.
  /// Backlinks are automatically excluded.
  ///
  /// If propertyNames is empty or null, will auto-detect properties from schema.
  ///
  /// Example:
  /// ```dart
  /// final json = RealmJson.toJsonWith(
  ///   person,
  ///   ['name', 'age', 'address'],
  ///   embeddedProperties: {'address': ['street', 'city']}
  /// );
  /// ```
  static Map<String, dynamic> toJsonWith(
    RealmObject obj,
    List<String>? propertyNames, {
    Map<String, List<String>>? embeddedProperties,
  }) {
    // FIRST: Try to use generated toEJson() method (most robust, handles nested objects)
    final ejsonResult = _tryToEJson(obj);
    if (ejsonResult != null) {
      return ejsonResult;
    }

    // FALLBACK: Auto-detect properties if not provided
    if (propertyNames == null || propertyNames.isEmpty) {
      return _autoSerialize(obj, embeddedProperties);
    }

    // FALLBACK: Manual property list serialization
    final Map<String, dynamic> out = <String, dynamic>{};

    for (final name in propertyNames) {
      try {
        final v = RealmObjectBase.get(obj, name);

        // Handle embedded objects with nested property lists
        if (v is RealmObject && embeddedProperties?.containsKey(name) == true) {
          out[name] = toJsonWith(
            v,
            embeddedProperties![name]!,
            embeddedProperties: embeddedProperties,
          );
        } else {
          out[name] = _toJsonValue(v, embeddedProperties);
        }
      } catch (_) {
        // Property doesn't exist or is a backlink - skip it
      }
    }

    // Try common id conventions
    for (final idKey in const ['_id', 'id']) {
      try {
        final v = RealmObjectBase.get(obj, idKey);
        if (v != null) {
          out['_id'] = _toJsonValue(v, embeddedProperties);
          break;
        }
      } catch (_) {}
    }

    return out;
  }

  /// Try to serialize using generated toEJson() method.
  /// Returns null if toEJson() is not available or fails.
  /// Converts EJson format (with MongoDB decorators) to plain JSON.
  static Map<String, dynamic>? _tryToEJson(RealmObject obj) {
    try {
      final dynamic dyn = obj;
      final ejson = dyn.toEJson();
      if (ejson is Map<String, dynamic>) {
        return _ejsonToPlain(ejson);
      }
    } catch (_) {
      // toEJson() not available or failed
    }
    return null;
  }

  /// Convert EJson format to plain JSON by unwrapping MongoDB extended JSON types.
  /// Handles: $oid, $numberInt, $numberDouble, $date, $numberLong, $binary, $uuid, etc.
  static dynamic _ejsonToPlain(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      // Handle MongoDB extended JSON types - convert to plain values
      if (value.containsKey('\$oid')) {
        return value['\$oid'].toString();
      }
      if (value.containsKey('\$numberInt')) {
        final val = value['\$numberInt'];
        return val is String ? int.tryParse(val) ?? val : val;
      }
      if (value.containsKey('\$numberLong')) {
        // $numberLong represents a large integer, NOT a DateTime
        // DateTime uses {$date: {$numberLong: ...}} (handled separately below)
        final val = value['\$numberLong'];
        return val is String ? int.tryParse(val) ?? val : val;
      }
      if (value.containsKey('\$numberDouble')) {
        final val = value['\$numberDouble'];
        return val is String ? double.tryParse(val) ?? val : val;
      }
      if (value.containsKey('\$date')) {
        final val = value['\$date'];
        // $date can contain a nested $numberLong with milliseconds
        if (val is Map && val.containsKey('\$numberLong')) {
          final innerVal = val['\$numberLong'];
          final millis = innerVal is String ? int.tryParse(innerVal) : innerVal;
          if (millis is int) {
            return DateTime.fromMillisecondsSinceEpoch(
              millis,
              isUtc: true,
            ).toIso8601String();
          }
        }
        // Convert to ISO string if numeric value directly
        if (val is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            val.toInt(),
            isUtc: true,
          ).toIso8601String();
        }
        return val;
      }
      if (value.containsKey('\$binary')) {
        return value['\$binary'];
      }
      if (value.containsKey('\$uuid')) {
        return value['\$uuid'].toString();
      }

      // Regular map - convert recursively
      return value.map((k, v) => MapEntry(k.toString(), _ejsonToPlain(v)));
    }

    if (value is List) {
      return value.map(_ejsonToPlain).toList();
    }

    return value;
  }

  /// Deserialize a RealmObject from JSON using generated fromEJson() method.
  ///
  /// This is the recommended deserialization method as it:
  /// - Automatically handles nested RealmObjects
  /// - Supports both plain JSON and MongoDB extended JSON (EJson) format
  /// - Matches the capabilities of toEJson() for round-trip serialization
  /// - Handles all Realm types including DateTime, ObjectId, collections, etc.
  ///
  /// **Important**: Schema must be initialized before calling this method:
  /// ```dart
  /// ChatUser.schema;
  /// ChatRoom.schema;
  ///
  /// final room = RealmJson.fromEJsonMap<ChatRoom>(jsonData);
  /// ```
  ///
  /// Accepts plain JSON (from MongoDB or RealmJson.toJsonWith):
  /// - `{"updatedOn": "2025-11-28T14:30:04.025Z"}` → automatically converts to EJson
  ///
  /// Falls back to `fromJsonWith` if `fromEJson()` is not available.
  static T fromEJsonMap<T extends RealmObject>(
    Map<String, dynamic> json, {
    T Function()? create,
    List<String>? propertyNames,
    Map<String, dynamic Function(Map<String, dynamic>)>? embeddedCreators,
  }) {
    try {
      // Convert plain JSON to EJson format (reverse of _ejsonToPlain)
      final ejsonData = _plainToEJson(json);

      // Use generated fromEJson() function from realm_common
      // This is a global function that requires schema registration
      return fromEJson<T>(ejsonData);
    } catch (e) {
      // Attempt a second pass: if id/_id are hex or UUID strings, encode to extended EJSON
      try {
        final adjusted = _withIdAsExtendedJson(json);
        final ejsonData2 = _plainToEJson(adjusted);
        return fromEJson<T>(ejsonData2);
      } catch (_) {
        // Fall back to manual deserialization if hints are provided
        if (create != null && propertyNames != null) {
          return fromJsonWith<T>(
            json,
            create,
            propertyNames,
            embeddedCreators: embeddedCreators,
          );
        }
        rethrow;
      }
    }
  }

  /// If the JSON contains `id` or `_id` as 24-hex or UUID strings, wrap them
  /// into Extended JSON objects so `fromEJson<T>` can decode ObjectId/Uuid types.
  /// Keeps other keys unchanged. Only transforms top-level `id`/`_id` keys.
  static Map<String, dynamic> _withIdAsExtendedJson(
    Map<String, dynamic> src,
  ) {
    final out = Map<String, dynamic>.from(src);
    for (final key in const ['_id', 'id']) {
      final val = out[key];
      if (val is String) {
        // ObjectId (24 hex chars)
        if (val.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val)) {
          out[key] = {'\$oid': val};
          continue;
        }
        // UUID (standard format)
        if (RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          caseSensitive: false,
        ).hasMatch(val)) {
          out[key] = {'\$uuid': val};
          continue;
        }
      }
    }
    return out;
  }

  /// Convert plain JSON to EJson format (reverse of _ejsonToPlain).
  /// Detects and converts special types:
  /// - ISO-8601 strings → {$date: {$numberLong: "..."}}
  /// - 24-char hex strings → {$oid: "..."}
  /// - UUID strings → {$uuid: "..."}
  static dynamic _plainToEJson(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      // Try to parse as DateTime (ISO-8601)
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return {
          '\$date': {
            '\$numberLong': dt.toUtc().millisecondsSinceEpoch.toString(),
          },
        };
      }

      return value;
    }

    if (value is num || value is bool) return value;

    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _plainToEJson(v)));
    }

    if (value is List) {
      return value.map(_plainToEJson).toList();
    }

    return value;
  }

  /// Hydrate a RealmObject from JSON using explicit property names.
  ///
  /// **Note**: Consider using `fromEJson()` instead for automatic nested object handling.
  ///
  /// Provide `create` to construct a new instance of T.
  /// For embedded objects, provide nested creators.
  ///
  /// Example:
  /// ```dart
  /// final person = RealmJson.fromJsonWith<Person>(
  ///   json,
  ///   () => Person(ObjectId(), '', 0),
  ///   ['name', 'age', 'address'],
  ///   embeddedCreators: {
  ///     'address': (json) => Address(json['street'], json['city'])
  ///   }
  /// );
  /// ```
  static T fromJsonWith<T extends RealmObject>(
    Map<String, dynamic> json,
    T Function() create,
    List<String> propertyNames, {
    Map<String, dynamic Function(Map<String, dynamic>)>? embeddedCreators,
  }) {
    final obj = create();

    for (final name in propertyNames) {
      if (!json.containsKey(name)) continue;

      try {
        final jsonValue = json[name];

        // Handle embedded objects
        if (embeddedCreators?.containsKey(name) == true &&
            jsonValue is Map<String, dynamic>) {
          final embedded = embeddedCreators![name]!(jsonValue);
          RealmObjectBase.set(obj, name, embedded);
        } else {
          RealmObjectBase.set(
            obj,
            name,
            _fromJsonValue(jsonValue, embeddedCreators),
          );
        }
      } catch (_) {
        // Property conversion failed - skip it
      }
    }

    // Handle _id/id mapping
    final id = json['_id'] ?? json['id'];
    if (id != null) {
      try {
        RealmObjectBase.set(obj, 'id', _fromJsonValue(id, embeddedCreators));
      } catch (_) {
        try {
          RealmObjectBase.set(obj, '_id', _fromJsonValue(id, embeddedCreators));
        } catch (_) {}
      }
    }

    return obj;
  }

  // ---------- Serialization helpers ----------

  /// Auto-serialize a RealmObject by introspecting its schema
  static Map<String, dynamic> _autoSerialize(
    RealmObject obj,
    Map<String, List<String>>? embeddedProperties,
  ) {
    final Map<String, dynamic> out = {};

    try {
      final schema = obj.objectSchema;

      for (final prop in schema) {
        // Skip backlinks (but NOT forward relationships or collections we want to serialize)
        // Backlinks have linkOriginProperty set
        try {
          if (prop.linkOriginProperty != null) {
            continue; // This is a backlink, skip it
          }
        } catch (_) {}

        try {
          final value = RealmObjectBase.get(obj, prop.name);

          // Handle embedded objects
          if (value is RealmObject &&
              embeddedProperties?.containsKey(prop.name) == true) {
            out[prop.name] = toJsonWith(
              value,
              embeddedProperties![prop.name],
              embeddedProperties: embeddedProperties,
            );
          } else {
            out[prop.name] = _toJsonValue(value, embeddedProperties);
          }
        } catch (_) {
          // Skip properties that can't be read
        }
      }

      // Add _id if available
      try {
        final id = RealmObjectBase.get(obj, 'id');
        if (id != null && !out.containsKey('_id')) {
          out['_id'] = _toJsonValue(id, embeddedProperties);
        }
      } catch (_) {}
    } catch (e) {
      // Schema introspection failed, return empty
    }

    return out;
  }

  static dynamic _toJsonValue(
    dynamic value,
    Map<String, List<String>>? embeddedProps,
  ) {
    if (value == null) return null;

    // Primitives
    if (value is String || value is num || value is bool) return value;

    // DateTime - always UTC ISO-8601
    if (value is DateTime) return value.toUtc().toIso8601String();

    // ObjectId, Uuid - string representation
    if (value is ObjectId) return value.toString();
    if (value is Uuid) return value.toString();

    // Decimal128 - string representation to preserve precision
    if (value is Decimal128) return value.toString();

    // Uint8List - base64 encoding
    if (value is Uint8List) {
      return {'type': 'binary', 'data': base64Encode(value)};
    }

    // RealmValue - mixed type with metadata
    if (value is RealmValue) {
      return _realmValueToJson(value);
    }

    // RealmObject - try to auto-serialize embedded objects
    // Check if value has objectSchema property (duck typing for RealmObject)
    try {
      final objectSchema = (value as dynamic).objectSchema;
      if (objectSchema != null) {
        // Attempt to extract all accessible properties from the RealmObject
        // This handles embedded objects automatically without explicit property lists
        final Map<String, dynamic> objMap = {};

        // Get properties list - the correct API varies by Realm version
        final properties = (objectSchema as dynamic).properties ?? [];

        for (final prop in properties) {
          // Skip backlinks and computed properties
          if (prop.linkTarget != null && !prop.collectionType.isNone) {
            continue; // Skip to-many relationships and backlinks
          }

          try {
            // Use dynamic property access since we don't have RealmObjectBase in scope
            final propValue = (value as dynamic)[prop.name];

            // Recursively handle embedded objects (check if propValue has objectSchema)
            try {
              final nestedSchema = (propValue as dynamic).objectSchema;
              if (nestedSchema != null) {
                // Check if this is from embeddedProps hints
                if (embeddedProps?.containsKey(prop.name) == true) {
                  objMap[prop.name] = toJsonWith(
                    propValue,
                    embeddedProps![prop.name]!,
                    embeddedProperties: embeddedProps,
                  );
                } else {
                  // Auto-serialize embedded object
                  objMap[prop.name] = _toJsonValue(propValue, embeddedProps);
                }
              } else {
                objMap[prop.name] = _toJsonValue(propValue, embeddedProps);
              }
            } catch (_) {
              // Not a RealmObject, just serialize normally
              objMap[prop.name] = _toJsonValue(propValue, embeddedProps);
            }
          } catch (_) {
            // Skip properties that can't be read
          }
        }

        return objMap;
      }
    } catch (_) {
      // Not a RealmObject or detection failed, continue to other checks
    }

    // Collections - RealmList, RealmSet, native collections
    if (value is Iterable) {
      return value.map((e) => _toJsonValue(e, embeddedProps)).toList();
    }

    // RealmMap or native Map - handle RealmObject values
    if (value is Map) {
      return value.map((k, v) {
        // Check if value is a RealmObject by testing for objectSchema
        try {
          final vSchema = (v as dynamic).objectSchema;
          if (vSchema != null) {
            // This is a RealmObject
            if (embeddedProps != null) {
              // Try to find matching embedded property config
              for (final entry in embeddedProps.entries) {
                try {
                  return MapEntry(
                    k.toString(),
                    toJsonWith(
                      v,
                      entry.value,
                      embeddedProperties: embeddedProps,
                    ),
                  );
                } catch (_) {
                  continue;
                }
              }
            }
            // No embeddedProps or no match - use full auto-serialization
            return MapEntry(
              k.toString(),
              toJsonWith(v, null, embeddedProperties: embeddedProps),
            );
          }
        } catch (_) {}
        // Not a RealmObject or no config, serialize normally
        return MapEntry(k.toString(), _toJsonValue(v, embeddedProps));
      });
    }

    // Fallback for unknown types
    return value.toString();
  }

  static Map<String, dynamic> _realmValueToJson(RealmValue rv) {
    final val = rv.value;

    if (val == null) return {'type': 'null', 'value': null};
    if (val is String) return {'type': 'string', 'value': val};
    if (val is int) return {'type': 'int', 'value': val};
    if (val is double) return {'type': 'double', 'value': val};
    if (val is bool) return {'type': 'bool', 'value': val};
    if (val is DateTime)
      return {'type': 'date', 'value': val.toUtc().toIso8601String()};
    if (val is ObjectId) return {'type': 'objectId', 'value': val.toString()};
    if (val is Uuid) return {'type': 'uuid', 'value': val.toString()};
    if (val is Decimal128)
      return {'type': 'decimal128', 'value': val.toString()};
    if (val is Uint8List) return {'type': 'binary', 'value': base64Encode(val)};

    // Collections within RealmValue
    if (val is List) {
      return {
        'type': 'list',
        'value':
            val.map((e) => e is RealmValue ? _realmValueToJson(e) : e).toList(),
      };
    }
    if (val is Map) {
      return {
        'type': 'map',
        'value': val.map(
          (k, v) => MapEntry(
            k.toString(),
            v is RealmValue ? _realmValueToJson(v) : v,
          ),
        ),
      };
    }

    return {'type': 'unknown', 'value': val.toString()};
  }

  // ---------- Deserialization helpers ----------

  static dynamic _fromJsonValue(
    dynamic value,
    Map<String, dynamic Function(Map<String, dynamic>)>? embeddedCreators,
  ) {
    if (value == null) return null;

    // Direct primitives
    if (value is String) {
      // Try to parse special string formats

      // DateTime ISO-8601
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt.toUtc();

      // ObjectId (24 hex chars)
      if (value.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(value)) {
        try {
          return ObjectId.fromHexString(value);
        } catch (_) {}
      }

      // Uuid (standard UUID format)
      if (RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        caseSensitive: false,
      ).hasMatch(value)) {
        try {
          return Uuid.fromString(value);
        } catch (_) {}
      }

      // Decimal128
      try {
        return Decimal128.parse(value);
      } catch (_) {}

      // Plain string
      return value;
    }

    if (value is num || value is bool) return value;

    // Structured types with metadata
    if (value is Map<String, dynamic>) {
      final type = value['type'] as String?;

      if (type == 'binary' && value['data'] is String) {
        return base64Decode(value['data']);
      }

      if (type == 'date' && value['value'] is String) {
        return DateTime.parse(value['value']).toUtc();
      }

      if (type == 'objectId' && value['value'] is String) {
        return ObjectId.fromHexString(value['value']);
      }

      if (type == 'uuid' && value['value'] is String) {
        return Uuid.fromString(value['value']);
      }

      if (type == 'decimal128' && value['value'] is String) {
        return Decimal128.parse(value['value']);
      }

      // RealmValue reconstruction
      if (type != null && value.containsKey('value')) {
        return _jsonToRealmValue(value);
      }

      // Plain map (for RealmMap properties)
      return value.map(
        (k, v) => MapEntry(k, _fromJsonValue(v, embeddedCreators)),
      );
    }

    // Arrays (for RealmList/RealmSet)
    if (value is List) {
      return value.map((e) => _fromJsonValue(e, embeddedCreators)).toList();
    }

    return value;
  }

  static RealmValue _jsonToRealmValue(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final val = json['value'];

    switch (type) {
      case 'null':
        return RealmValue.nullValue();
      case 'string':
        return RealmValue.from(val);
      case 'int':
        return RealmValue.from(val);
      case 'double':
        return RealmValue.from(val);
      case 'bool':
        return RealmValue.from(val);
      case 'date':
        return RealmValue.from(DateTime.parse(val).toUtc());
      case 'objectId':
        return RealmValue.from(ObjectId.fromHexString(val));
      case 'uuid':
        return RealmValue.from(Uuid.fromString(val));
      case 'decimal128':
        return RealmValue.from(Decimal128.parse(val));
      case 'binary':
        return RealmValue.from(base64Decode(val));
      case 'list':
        if (val is List) {
          return RealmValue.from(
            val
                .map(
                  (e) =>
                      e is Map<String, dynamic> && e['type'] != null
                          ? _jsonToRealmValue(e)
                          : RealmValue.from(e),
                )
                .toList(),
          );
        }
        break;
      case 'map':
        if (val is Map) {
          return RealmValue.from(
            val.map(
              (k, v) => MapEntry(
                k.toString(),
                v is Map<String, dynamic> && v['type'] != null
                    ? _jsonToRealmValue(v)
                    : RealmValue.from(v),
              ),
            ),
          );
        }
        break;
    }

    return RealmValue.nullValue();
  }
}
