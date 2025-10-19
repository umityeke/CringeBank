import 'package:cringebank/services/telemetry/sql_mirror_latency_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // Reset stats before each test
    SqlMirrorLatencyMonitor.instance.statsNotifier.value =
        SqlMirrorLatencyStats(
          samples: 0,
          overThresholdCount: 0,
          lastLatencyMs: 0,
          thresholdMs: 200,
          lastOperation: '',
          lastWithinThreshold: true,
        );
  });

  test('records latency samples and thresholds', () {
    final monitor = SqlMirrorLatencyMonitor.instance;

    monitor.record(operation: 'dm.message.create', elapsedMs: 150);

    final first = monitor.statsNotifier.value;
    expect(first.samples, 1);
    expect(first.overThresholdCount, 0);
    expect(first.lastLatencyMs, 150);
    expect(first.lastWithinThreshold, isTrue);

    monitor.record(operation: 'follow.edge.update', elapsedMs: 350);

    final second = monitor.statsNotifier.value;
    expect(second.samples, 2);
    expect(second.overThresholdCount, 1);
    expect(second.lastLatencyMs, 350);
    expect(second.lastWithinThreshold, isFalse);
    expect(second.lastOperation, 'follow.edge.update');
  });
}
