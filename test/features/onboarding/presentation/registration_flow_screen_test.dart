import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cringebank/core/telemetry/mocks/mock_telemetry_service.dart';
import 'package:cringebank/core/telemetry/telemetry_providers.dart';
import 'package:cringebank/features/onboarding/application/registration_controller.dart';
import 'package:cringebank/features/onboarding/application/registration_providers.dart';
import 'package:cringebank/screens/registration_flow_screen.dart';
import 'package:cringebank/services/user_service.dart';

class _MockUserService extends Mock implements UserService {}

class _TestRegistrationController extends RegistrationController {
  _TestRegistrationController(RegistrationFlowState initial) : super(
          userService: _MockUserService(),
          telemetry: null,
        ) {
    state = initial;
  }

  @override
  Future<void> initialize() async {}
}

Future<void> _pumpRegistration(
  WidgetTester tester,
  RegistrationFlowState state,
) async {
  final controller = _TestRegistrationController(state);
  final telemetry = MockTelemetryService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        telemetryServiceProvider.overrideWithValue(telemetry),
        registrationControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: RegistrationFlowScreen()),
    ),
  );

  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegistrationFlowScreen', () {
    testWidgets('email adımı form hatalarını gösterir', (tester) async {
      final initial = RegistrationFlowState.initial().copyWith(
        restorationComplete: true,
        email: 'hatali',
        password: '123',
        confirmPassword: '321',
        emailError: 'E-posta adresi geçersiz.',
        passwordError: 'Şifre politikası karşılanamadı.',
        confirmPasswordError: 'Şifreler eşleşmiyor.',
      );

      await _pumpRegistration(tester, initial);

      expect(find.byKey(const ValueKey('emailStep')), findsOneWidget);
      expect(find.text('E-posta adresi geçersiz.'), findsOneWidget);
      expect(find.text('Şifre politikası karşılanamadı.'), findsOneWidget);
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    });

    testWidgets('profil adımı uygun kullanıcı adı mesajını gösterir', (tester) async {
      final initial = RegistrationFlowState.initial().copyWith(
        restorationComplete: true,
        step: RegistrationFlowStep.profile,
        sessionId: 'session-123',
        sessionExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
        username: 'cringe_master',
        usernameTouched: true,
        usernameStatus: UsernameStatus.available,
        acceptTerms: true,
        acceptPrivacy: true,
        marketingOptIn: true,
      );

      await _pumpRegistration(tester, initial);

      expect(find.byKey(const ValueKey('profileStep')), findsOneWidget);
      expect(find.text('Bu kullanıcı adı kullanılabilir!'), findsOneWidget);
      expect(
        find.textContaining('Doğrulama oturumu'),
        findsOneWidget,
      );
    });
  });
}
