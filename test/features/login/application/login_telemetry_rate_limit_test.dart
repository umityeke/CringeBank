import 'package:cringebank/core/config/feature_flags.dart';
import 'package:cringebank/core/telemetry/telemetry_service.dart';
import 'package:cringebank/core/telemetry/telemetry_utils.dart';
import 'package:cringebank/features/login/application/login_controller.dart';
import 'package:cringebank/features/login/data/mocks/mock_login_service.dart';
import 'package:cringebank/features/login/domain/models/login_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingTelemetryService implements TelemetryService {
  final List<TelemetryEvent> events = [];

  @override
  Future<void> record(TelemetryEvent event) async {
    events.add(event);
  }
}

LoginController _buildController({
  required TelemetryService telemetry,
  FeatureFlags featureFlags = const FeatureFlags(),
}) {
  return LoginController(
    MockLoginService(),
    now: () => DateTime.utc(2025, 10, 20, 12),
    deviceInfo: const DeviceInfo(deviceIdHash: 'device-hash', isTrusted: false),
    sessionBuilder: () => const SessionMetadata(
      ipHash: 'ip-hash',
      userAgent: 'test-agent',
      locale: 'tr-TR',
      timeZone: 'UTC+03:00',
    ),
    telemetry: telemetry,
    featureFlags: featureFlags,
  );
}

void main() {
  group('LoginController telemetry and rate limit', () {
    test('successful credentials emit login telemetry events', () async {
      final telemetry = _RecordingTelemetryService();
      final controller = _buildController(telemetry: telemetry);

      controller.updateIdentifier('user@cringe.bank');
      controller.updatePassword('CorrectPass123!');

      await controller.submitCredentials();

      final events = telemetry.events;
      final attemptEvents =
          events.where((event) => event.name == TelemetryEventName.loginAttempt).toList();
      final successEvents =
          events.where((event) => event.name == TelemetryEventName.loginSuccess).toList();

      expect(attemptEvents, hasLength(2));
      expect(successEvents, hasLength(1));

      expect(attemptEvents.first.attributes['status'], 'pending');
      expect(attemptEvents.last.attributes['status'], 'success');

      final identifierHash = hashIdentifier('user@cringe.bank');
      expect(successEvents.single.attributes['identifierHash'], identifierHash);
      expect(successEvents.single.attributes['method'], 'emailPassword');
    });

    test('third failed credential attempt enforces captcha and logs telemetry', () async {
      final telemetry = _RecordingTelemetryService();
      final controller = _buildController(
        telemetry: telemetry,
        featureFlags: const FeatureFlags(enforceCaptchaAfterThreeFails: true),
      );

      controller.updateIdentifier('user@cringe.bank');

      for (var i = 0; i < 3; i++) {
        controller.updatePassword('WrongPass$i!');
        await controller.submitCredentials();
      }

      expect(controller.state.failedAttempts, 3);
      expect(controller.state.captchaRequired, isTrue);

      final captchaEvents =
          telemetry.events.where((event) => event.name == TelemetryEventName.captchaRequired).toList();
      expect(captchaEvents, hasLength(1));
      expect(captchaEvents.single.attributes['failedAttempts'], 3);

      final lastFailure = telemetry.events
          .where((event) => event.name == TelemetryEventName.loginFailure)
          .last;
      expect(lastFailure.attributes['captchaRequired'], true);
      expect(lastFailure.attributes['failedAttempts'], 3);

      final identifierHash = hashIdentifier('user@cringe.bank');
      expect(captchaEvents.single.attributes['identifierHash'], identifierHash);
    });
  });
}
