import 'dart:async';
import 'package:flutter/foundation.dart';

/// Abstract interface for crash reporting services
///
/// Provides a platform-agnostic API for crash reporting.
/// Implementations can be Firebase Crashlytics, Sentry, or null implementations.
abstract class ICrashReportingService {
  /// Initialize the crash reporting service
  Future<void> initialize();

  /// Enable or disable crash reporting collection
  Future<void> setCrashCollectionEnabled(bool enabled);

  /// Check if crash reporting is enabled
  bool get isEnabled;

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    dynamic reason,
    Iterable<DiagnosticsNode> information = const [],
    bool fatal = false,
  });

  /// Record a fatal error
  Future<void> recordFatalError(
    dynamic exception,
    StackTrace stackTrace, {
    dynamic reason,
  });

  /// Log a message
  Future<void> log(String message);

  /// Set user identifier
  Future<void> setUserIdentifier(String identifier);

  /// Set custom key-value pair
  Future<void> setCustomKey(String key, Object value);

  /// Clear custom keys
  Future<void> clearCustomKeys();
}
