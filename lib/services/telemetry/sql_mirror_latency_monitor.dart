import 'dart:async';
import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../utils/platform_info.dart';

@immutable
class SqlMirrorLatencyStats {
  const SqlMirrorLatencyStats({
    required this.samples,
    required this.overThresholdCount,
    required this.lastLatencyMs,
    required this.thresholdMs,
    required this.lastOperation,
    required this.lastWithinThreshold,
  });

  final int samples;
  final int overThresholdCount;
  final int lastLatencyMs;
  final int thresholdMs;
  final String lastOperation;
  final bool lastWithinThreshold;

  static SqlMirrorLatencyStats initial() {
    // Use default threshold to avoid Firebase dependency during initialization
    const threshold =
        200; // MessagingFeatureFlags.defaultSqlMirrorLatencyThresholdMs
    return SqlMirrorLatencyStats(
      samples: 0,
      overThresholdCount: 0,
      lastLatencyMs: 0,
      thresholdMs: threshold,
      lastOperation: '',
      lastWithinThreshold: true,
    );
  }

  SqlMirrorLatencyStats copyWith({
    int? samples,
    int? overThresholdCount,
    int? lastLatencyMs,
    int? thresholdMs,
    String? lastOperation,
    bool? lastWithinThreshold,
  }) {
    return SqlMirrorLatencyStats(
      samples: samples ?? this.samples,
      overThresholdCount: overThresholdCount ?? this.overThresholdCount,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      thresholdMs: thresholdMs ?? this.thresholdMs,
      lastOperation: lastOperation ?? this.lastOperation,
      lastWithinThreshold: lastWithinThreshold ?? this.lastWithinThreshold,
    );
  }
}

class SqlMirrorLatencyMonitor {
  SqlMirrorLatencyMonitor._();

  static final SqlMirrorLatencyMonitor instance = SqlMirrorLatencyMonitor._();

  static final bool _supportsCrashlytics = PlatformInfo.supportsCrashlytics;

  final ValueNotifier<SqlMirrorLatencyStats> statsNotifier = ValueNotifier(
    SqlMirrorLatencyStats.initial(),
  );

  FirebaseCrashlytics? get _crashlytics =>
      _supportsCrashlytics ? FirebaseCrashlytics.instance : null;

  void record({required String operation, required int elapsedMs}) {
    final currentStats = statsNotifier.value;
    final threshold = currentStats.thresholdMs;
    final withinThreshold = elapsedMs <= threshold;

    final nextStats = currentStats.copyWith(
      samples: currentStats.samples + 1,
      overThresholdCount:
          currentStats.overThresholdCount + (withinThreshold ? 0 : 1),
      lastLatencyMs: elapsedMs,
      thresholdMs: threshold,
      lastOperation: operation,
      lastWithinThreshold: withinThreshold,
    );

    statsNotifier.value = nextStats;

    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      final payload = jsonEncode(<String, Object?>{
        'operation': operation,
        'elapsedMs': elapsedMs,
        'thresholdMs': threshold,
        'withinThreshold': withinThreshold,
        'samples': nextStats.samples,
        'overThresholdCount': nextStats.overThresholdCount,
      });

      crashlytics.log('sql_mirror_latency $payload');
      unawaited(crashlytics.setCustomKey('sql_mirror_last_ms', elapsedMs));
      unawaited(crashlytics.setCustomKey('sql_mirror_threshold_ms', threshold));
      unawaited(
        crashlytics.setCustomKey(
          'sql_mirror_within_threshold',
          withinThreshold,
        ),
      );

      if (!withinThreshold) {
        unawaited(
          crashlytics.recordError(
            TimeoutException(
              'SQL mirror latency exceeded threshold',
              Duration(milliseconds: threshold),
            ),
            null,
            reason: 'sql_mirror_latency_threshold_exceeded',
            information: [
              {'operation': operation},
              {'elapsedMs': elapsedMs},
              {'thresholdMs': threshold},
            ],
            fatal: false,
          ),
        );
      }
    } else {
      debugPrint(
        'sql_mirror_latency operation=$operation elapsed=${elapsedMs}ms '
        'threshold=${threshold}ms within=$withinThreshold',
      );
    }
  }
}
