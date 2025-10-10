import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../utils/platform_info.dart';

/// Centralized telemetry helper for measuring Cloud Function call latency
/// and piping the result into Crashlytics custom logs/keys.
class CallableLatencyTracker {
  CallableLatencyTracker._();

  static final bool _supportsCrashlytics = PlatformInfo.supportsCrashlytics;
  static FirebaseCrashlytics? get _crashlytics =>
      _supportsCrashlytics ? FirebaseCrashlytics.instance : null;

  /// Executes the provided [action] while measuring latency. The duration is
  /// recorded in Crashlytics (if available) to make latency regression tracking
  /// easier without adding manual logging to every call site.
  static Future<T> run<T>({
    required String functionName,
    required Future<T> Function() action,
    Object? payload,
    String category = 'callable',
    void Function(int elapsedMs)? onMeasured,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await action();
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      await _recordLatency(
        functionName: functionName,
        elapsedMs: elapsedMs,
        success: true,
        category: category,
        payload: payload,
      );
      onMeasured?.call(elapsedMs);
      return result;
    } catch (error, stack) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      await _recordLatency(
        functionName: functionName,
        elapsedMs: elapsedMs,
        success: false,
        category: category,
        payload: payload,
        error: error,
        stackTrace: stack,
      );
      onMeasured?.call(elapsedMs);
      rethrow;
    }
  }

  static Future<void> _recordLatency({
    required String functionName,
    required int elapsedMs,
    required bool success,
    required String category,
    Object? payload,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final crashlytics = _crashlytics;
    final payloadKeys = _extractPayloadKeys(payload);
    final logEntry = jsonEncode(<String, Object?>{
      'function': functionName,
      'category': category,
      'elapsedMs': elapsedMs,
      'success': success,
      if (payloadKeys != null) 'payloadKeys': payloadKeys,
      if (!success && error != null) 'errorType': error.runtimeType.toString(),
    });

    try {
      if (crashlytics != null) {
        // Log the latency event for aggregated dashboarding in Crashlytics.
        crashlytics.log('callable_latency $logEntry');
        unawaited(crashlytics.setCustomKey('last_callable_name', functionName));
        unawaited(
          crashlytics.setCustomKey('last_callable_latency_ms', elapsedMs),
        );
        unawaited(crashlytics.setCustomKey('last_callable_success', success));

        if (!success && error != null) {
          // Record the error context once; higher-level services may still report
          // their own errors, but capturing it here guarantees visibility.
          await crashlytics.recordError(
            error,
            stackTrace,
            reason: 'callable_latency_failure',
            fatal: false,
          );
        }
        return;
      }
    } catch (telemetryError, telemetryStack) {
      debugPrint(
        'callable_latency tracker error while reporting: $telemetryError',
      );
      debugPrint('$telemetryStack');
    }

    // Fallback to debug logging for platforms without Crashlytics support
    // (web/desktop) or if Crashlytics reporting fails. This keeps parity for
    // local debugging sessions.
    debugPrint(
      'callable_latency => function=$functionName elapsed=${elapsedMs}ms '
      'success=$success category=$category payloadKeys=${payloadKeys ?? 'n/a'}',
    );
  }

  static List<String>? _extractPayloadKeys(Object? payload) {
    if (payload is Map) {
      final keys = payload.keys
          .whereType<Object>()
          .map((key) => key.toString())
          .where((key) => key.isNotEmpty)
          .take(20)
          .toList();
      if (keys.isNotEmpty) {
        return keys;
      }
    }
    return null;
  }
}

extension LatencyInstrumentedFunctions on FirebaseFunctions {
  Future<HttpsCallableResult<R>> callWithLatency<R>(
    String name, {
    Object? payload,
    HttpsCallableOptions? options,
    String category = 'callable',
    void Function(int elapsedMs)? onMeasured,
  }) {
    final callable = httpsCallable(name, options: options);
    final effectivePayload = payload;

    return CallableLatencyTracker.run<HttpsCallableResult<R>>(
      functionName: name,
      category: category,
      payload: effectivePayload,
      onMeasured: onMeasured,
      action: () => callable.call(effectivePayload),
    );
  }
}
