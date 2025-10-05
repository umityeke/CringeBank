import 'dart:async';
import 'package:flutter/foundation.dart';
import 'i_crash_reporting_service.dart';

/// Null implementation of crash reporting service
///
/// Used on platforms that don't support crash reporting (Web, Windows, Linux)
/// Provides a safe no-op implementation.
class NullCrashReportingService implements ICrashReportingService {
  @override
  bool get isEnabled => false;

  @override
  Future<void> initialize() async {
    debugPrint('„️ Crash reporting not available on this platform');
  }

  @override
  Future<void> setCrashCollectionEnabled(bool enabled) async {
    // No-op
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    dynamic reason,
    Iterable<DiagnosticsNode> information = const [],
    bool fatal = false,
  }) async {
    // Log to console for debugging
    debugPrint('š️ Error (not reported): $exception');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Future<void> recordFatalError(
    dynamic exception,
    StackTrace stackTrace, {
    dynamic reason,
  }) async {
    // Log to console for debugging
    debugPrint('?Ÿ’€ Fatal error (not reported): $exception');
    debugPrint('Stack trace: $stackTrace');
  }

  @override
  Future<void> log(String message) async {
    debugPrint('ğ“ Log (not reported): $message');
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    // No-op
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    // No-op
  }

  @override
  Future<void> clearCustomKeys() async {
    // No-op
  }
}
