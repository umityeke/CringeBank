import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'i_crash_reporting_service.dart';

/// Firebase Crashlytics implementation of crash reporting
///
/// Only used on platforms that support Firebase Crashlytics (Android, iOS)
class FirebaseCrashReportingService implements ICrashReportingService {
  bool _isEnabled = false;

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> initialize() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      _isEnabled = true;
      debugPrint('âü… Firebase Crashlytics initialized successfully');
    } catch (error) {
      debugPrint('âÜ Failed to initialize Firebase Crashlytics: $error');
      _isEnabled = false;
      rethrow;
    }
  }

  @override
  Future<void> setCrashCollectionEnabled(bool enabled) async {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    _isEnabled = enabled;
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    dynamic reason,
    Iterable<DiagnosticsNode> information = const [],
    bool fatal = false,
  }) async {
    if (!_isEnabled) return;

    await FirebaseCrashlytics.instance.recordError(
      exception,
      stackTrace,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }

  @override
  Future<void> recordFatalError(
    dynamic exception,
    StackTrace stackTrace, {
    dynamic reason,
  }) async {
    if (!_isEnabled) return;

    await FirebaseCrashlytics.instance.recordError(
      exception,
      stackTrace,
      reason: reason,
      fatal: true,
    );
  }

  @override
  Future<void> log(String message) async {
    if (!_isEnabled) return;
    await FirebaseCrashlytics.instance.log(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    if (!_isEnabled) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    if (!_isEnabled) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  @override
  Future<void> clearCustomKeys() async {
    if (!_isEnabled) return;
    // Crashlytics doesn't have a clear all method, so we do nothing
  }
}
