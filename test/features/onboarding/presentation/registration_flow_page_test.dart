import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cringebank/features/onboarding/application/registration_controller.dart'
    show RegistrationController, RegistrationFlowStep, UsernameStatus;
import 'package:cringebank/features/onboarding/application/registration_providers.dart';
import 'package:cringebank/features/onboarding/presentation/pages/registration_flow_page.dart';
import 'package:cringebank/services/user_service.dart';

class _MockUserService extends Mock implements UserService {}

Widget _buildTestApp({
  required RegistrationController controller,
  GoRouter? router,
}) {
  final appRouter = router ??
      GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const RegistrationFlowPage(),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Feed Page')),
            ),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      registrationControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp.router(
      routerConfig: appRouter,
    ),
  );
}

void main() {
  group('RegistrationFlowPage widget tests', () {
    testWidgets('gerekli sözleşmeler işaretlenmezse kullanıcıya uyarı gösterilir',
        (tester) async {
  final controller = RegistrationController(userService: _MockUserService());
      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();

      controller.state = controller.state.copyWith(
        step: RegistrationFlowStep.profile,
        email: 'test@example.com',
        password: 'Password123',
        confirmPassword: 'Password123',
        sessionId: 'session-123',
        username: 'cringetest',
        usernameStatus: UsernameStatus.available,
        acceptTerms: false,
        acceptPrivacy: true,
      );

      await tester.pump();

  await tester.ensureVisible(find.text('Kaydı Tamamla'));
  await tester.tap(find.text('Kaydı Tamamla'), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Devam etmek için zorunlu alanları doldurun'),
        findsOneWidget,
      );
    });

    testWidgets('kayıt başarıyla tamamlandığında feed sayfasına yönlendirir',
        (tester) async {
  final controller = RegistrationController(userService: _MockUserService());
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const RegistrationFlowPage(),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Feed Page')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(controller: controller, router: router));
      await tester.pump();

      controller.state = controller.state.copyWith(
        step: RegistrationFlowStep.success,
        requiresRegistration: false,
      );

      await tester.pump();
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Feed Page'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/feed');
    });

    testWidgets('yasaklı kullanıcı adı girildiğinde uyarı mesajı görünür',
        (tester) async {
      final controller = RegistrationController(userService: _MockUserService());

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();

      controller.state = controller.state.copyWith(
        step: RegistrationFlowStep.profile,
        sessionId: 'session-123',
      );

      await tester.pump();

      controller.updateUsername('adminmaster');

      await tester.pump();

      expect(
        find.text('Bu kullanıcı adı yasaklı listede. Lütfen farklı bir isim seç.'),
        findsWidgets,
      );
    });
  });
}
