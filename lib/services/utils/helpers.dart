import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String capitalizeFirstLetter(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

String randomString({int length = 8}) {
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (index) {
    final randomIndex =
        (characters.length *
                (DateTime.now().microsecondsSinceEpoch % 1000) /
                1000)
            .floor();
    return characters[randomIndex];
  }).join();
}

final RegExp _kWordRegExp = RegExp(r'\b\w+\b');
int getWordCount(String? text) {
  if (text == null || text.isEmpty) return 0;
  return _kWordRegExp.allMatches(text).length;
}

String toProperCase(String text) {
  return text
      .split(' ')
      .map(
        (word) =>
            word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '',
      )
      .join(' ');
}

String formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final now = DateTime.now().toLocal();
  final diff = now.difference(date).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(date);
  return date.year == now.year
      ? DateFormat('MMM dd').format(date)
      : DateFormat('MM/dd/yy').format(date);
}

String getPostAgofromDate(DateTime date) {
  var diff = DateTime.now().toLocal().difference(date);
  if (diff.inDays > 365) {
    return "${(diff.inDays / 365).floor()} years ago";
  } else if (diff.inDays > 30) {
    return "${(diff.inDays / 30).floor()} months ago";
  } else if (diff.inDays > 7) {
    return "${(diff.inDays / 7).floor()} weeks ago";
  } else if (diff.inDays > 0) {
    return "${diff.inDays} days ago";
  } else if (diff.inHours > 0) {
    return "${diff.inHours} hours ago";
  } else if (diff.inMinutes > 0) {
    return "${diff.inMinutes} minutes ago";
  } else {
    return "Just now";
  }
}

String formatDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $hh:$mm';
}

DateTime DBTime() {
  return DateTime.now().toUtc();
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

int? parseInt(dynamic v, int? existing) {
  if (v == null) return existing;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is double) return v.toInt();
  return existing;
}

double? parseDouble(dynamic v, double? existing) {
  if (v == null) return existing;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return existing;
}

bool deepEquals(dynamic a, dynamic b) {
  // Fast identical reference or both null
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;

  // Normalize numeric types (int vs double) treating 1 and 1.0 as equal
  bool _numEquals(dynamic x, dynamic y) {
    if (x is num && y is num) {
      // Avoid precision issues by comparing as double with a tiny tolerance
      final dx = x.toDouble();
      final dy = y.toDouble();
      return (dx - dy).abs() < 1e-9;
    }
    return false;
  }

  // DateTime equality by moment (accounts for timezone differences via UTC)
  if (a is DateTime && b is DateTime) {
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  // Numeric cross-type equality
  if (_numEquals(a, b)) return true;

  // Realm collections or generic Iterables may not be List; normalize
  if (a is Iterable &&
      b is Iterable &&
      a.runtimeType != List &&
      b.runtimeType != List) {
    a = a.toList();
    b = b.toList();
  }

  // Map deep compare
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      if (!deepEquals(a[k], b[k])) return false;
    }
    // Also ensure b doesn't have extra keys (length check already done)
    return true;
  }

  // List / Iterable ordered deep compare
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  // Fallback to == (covers primitives & objects implementing ==)
  return a == b;
}

Map<String, dynamic> diff(Map<String, dynamic> old, Map<String, dynamic> now) {
  final delta = <String, dynamic>{};
  for (final entry in now.entries) {
    final k = entry.key;
    final newVal = entry.value;
    final oldVal = old[k];
    if (!deepEquals(oldVal, newVal)) {
      delta[k] = newVal;
    }
  }
  // Include removed keys (present in old, absent in now) as nulls so backend can delete.
  // If backend does not accept null-for-delete semantics, remove this block.
  for (final k in old.keys) {
    if (!now.containsKey(k)) {
      delta[k] = null; // mark deletion
    }
  }
  return delta;
}
