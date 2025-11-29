/// Rehydrate canonical JSON diff maps back into richer Dart types where possible.
/// This is primarily used after reading `DBCache.diffJson`, which was serialized
/// with `canonicalizeMap` (that converts DateTime -> ISO8601 string, enums -> name, etc.).
///
/// We *heuristically* convert ISO8601 UTC strings back to DateTime for a known
/// set of field names OR for any value that matches the pattern when
/// `aggressive` is true. This avoids losing date semantics before sending
/// patches through `toServerMap()` which expects genuine DateTime objects to
/// wrap them in the backend date envelope.
///
/// If you later adopt sentinel-wrapped dates (e.g. {'__t':'dt','v':iso}), you
/// can update this logic to detect that instead of heuristics.
// NOTE: Keep lightweight; avoid adding heavy deps just for parsing.
final _isoUtcRegex = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z');

/// Field names commonly representing dates.
const Set<String> kLikelyDateKeys = <String>{
  'createdAt',
  'updatedAt',
  'achievedAt',
  'targetDate',
  'lastAttemptAt',
  'startDate',
  'endDate',
  'deletedAt',
  'timestamp',
};

Object? _rehydrateValue(Object? v, {bool aggressive = false, String? key}) {
  if (v is Map) {
    return rehydratePatch(Map<String, dynamic>.from(v), aggressive: aggressive);
  }
  if (v is List) {
    return v.map((e) => _rehydrateValue(e, aggressive: aggressive)).toList();
  }
  if (v is String) {
    final looksDate = _isoUtcRegex.hasMatch(v);
    final byKey = key != null && kLikelyDateKeys.contains(key);
    if (looksDate && (aggressive || byKey)) {
      try {
        return DateTime.parse(v).toUtc();
      } catch (_) {}
    }
  }
  return v; // primitive or unchanged
}

/// Rehydrate a diff patch map recursively.
Map<String, dynamic> rehydratePatch(
  Map<String, dynamic> patch, {
  bool aggressive = false,
}) {
  final out = <String, dynamic>{};
  patch.forEach((k, v) {
    out[k] = _rehydrateValue(v, aggressive: aggressive, key: k);
  });
  return out;
}
