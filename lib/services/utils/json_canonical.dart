import 'dart:convert';

/// Canonical JSON serialization helpers to ensure complex Dart values
/// (DateTime, enums, Iterables, nested Maps) are converted into a structure
/// accepted by jsonEncode. This prevents runtime errors like:
///   Converting object to an encodable object failed: Instance of 'DateTime'
///
/// Strategy:
/// - DateTime  -> ISO 8601 UTC string
/// - Enum      -> enum.name (Dart 2.17+) fallback to toString().split('.').last
/// - Iterable  -> List after recursively canonicalizing elements
/// - Map       -> New Map&lt;String,dynamic&gt; with canonicalized values
/// - num/bool/String/null left as-is
/// - Objects exposing toJson() => call and canonicalize result
/// - Fallback -> value.toString()
///
/// NOTE: If you rely on server-side typed date restoration, wrap ISO strings
/// yourself earlier (e.g. {'type':'date','value': isoString}). This helper
/// keeps it simple and lossless for ordering and diffing.

Object? _canonicalizeValue(Object? value) {
  if (value == null) return null;
  if (value is num || value is String || value is bool) return value;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Enum) {
    // Dart >=2.17 has .name; keep concise identifier
    try {
      return (value as dynamic).name;
    } catch (_) {
      final s = value.toString();
      final idx = s.indexOf('.');
      return idx == -1 ? s : s.substring(idx + 1);
    }
  }
  if (value is Iterable) {
    return value.map(_canonicalizeValue).toList();
  }
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k.toString()] = _canonicalizeValue(v);
    });
    return out;
  }
  // Custom object with toJson
  try {
    final dynamic dyn = value;
    if (dyn.toJson is Function) {
      final jsonMap = dyn.toJson();
      if (jsonMap is Map) return _canonicalizeValue(jsonMap);
    }
  } catch (_) {}
  // Fallback textual form
  return value.toString();
}

/// Returns a deep-canonicalized Map suitable for safe jsonEncode.
Map<String, dynamic> canonicalizeMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((k, v) {
    out[k] = _canonicalizeValue(v);
  });
  return out;
}

/// Convenience: produce a JSON string directly.
String encodeCanonical(Map<String, dynamic> input) =>
    jsonEncode(canonicalizeMap(input));
