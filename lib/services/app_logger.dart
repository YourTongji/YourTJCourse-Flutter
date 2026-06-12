import 'package:flutter/foundation.dart';

import 'log_writer.dart';

class AppLogger {
  AppLogger._();

  static bool _enabled = true;

  static void setEnabled(bool enabled) { _enabled = enabled; }

  static void info(String message, {String? tag}) {
    if (!_enabled) return;
    if (kDebugMode) debugPrint(_format('INFO', tag, message));
    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'info',
      'type': 'general',
      'message': message,
      'tag': ?tag,
    });
  }

  static void warning(String message, {String? tag}) {
    if (!_enabled) return;
    if (kDebugMode) debugPrint(_format('WARN', tag, message));
    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'warning',
      'type': 'general',
      'message': message,
      'tag': ?tag,
    });
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    if (kDebugMode) {
      debugPrint(_format('ERROR', tag, message));
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  StackTrace: $stackTrace');
    }
    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'error',
      'type': 'general',
      'message': message,
      'tag': ?tag,
      'error': ?error?.toString(),
      'stackTrace': ?stackTrace?.toString(),
    });
  }

  static String _format(String level, String? tag, String message) {
    return tag != null ? '[$tag] $message' : '[$level] $message';
  }
}
