import 'package:cringebank/services/messaging_feature_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagingFeatureConfig.fromSnapshot', () {
    test('applies defaults when fields missing', () {
      final config = MessagingFeatureConfig.fromSnapshot(const {});
      expect(config.doubleWriteEnabled, isFalse);
      expect(config.sqlReadEnabled, isFalse);
      expect(config.latencyThresholdMs, greaterThanOrEqualTo(50));
      expect(config.latencyThresholdMs, lessThanOrEqualTo(5000));
    });

    test('parses boolean and numeric overrides', () {
      final config = MessagingFeatureConfig.fromSnapshot(const {
        'doubleWriteEnabled': true,
        'sqlReadEnabled': 'TRUE',
        'latencyThresholdMs': '450',
      });

      expect(config.doubleWriteEnabled, isTrue);
      expect(config.sqlReadEnabled, isTrue);
      expect(config.latencyThresholdMs, 450);
    });

    test('clamps latency threshold to safe bounds', () {
      final configLow = MessagingFeatureConfig.fromSnapshot(const {
        'latencyThresholdMs': 10,
      });
      final configHigh = MessagingFeatureConfig.fromSnapshot(const {
        'latencyThresholdMs': 8000,
      });

      expect(configLow.latencyThresholdMs, 50);
      expect(configHigh.latencyThresholdMs, 5000);
    });
  });
}
