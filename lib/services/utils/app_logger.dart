import 'dart:developer' as dev;

class AppLogger {
  static final RegExp _email = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _phone = RegExp(
    r'(?<!\d)(?:\+\d{1,3}[ -]?)?(?:\d[ -]?){7,14}\d(?!\d)',
  );
  static final RegExp _bearer = RegExp(r'Bearer\s+[A-Za-z0-9\-_.]+');

  static String _redact(String? input) {
    if (input == null) return 'null';
    var out = input;
    out = out.replaceAllMapped(_email, (_) => '<redacted-email>');
    out = out.replaceAllMapped(_phone, (_) => '<redacted-phone>');
    out = out.replaceAllMapped(_bearer, (_) => 'Bearer <redacted>');
    return out;
  }

  static void log(
    String? message, {
    bool isError = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final safeMsg = _redact(message);
    final safeErr = error is String ? _redact(error) : error;

    if (!isError) {
      dev.log("✓ $safeMsg", error: safeErr, stackTrace: stackTrace);
    } else {
      dev.log("✖ $safeMsg", error: safeErr, stackTrace: stackTrace);
    }
  }
}
