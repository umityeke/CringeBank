import 'package:cringebank/core/config/feature_flags.dart';
import 'package:cringebank/core/session/session_bootstrap.dart';
import 'package:cringebank/core/session/session_controller.dart';
import 'package:cringebank/core/session/session_providers.dart';
import 'package:cringebank/core/session/session_refresh_service.dart';
import 'package:cringebank/features/login/application/login_controller.dart';
import 'package:cringebank/features/login/application/login_providers.dart';
import 'package:cringebank/features/login/data/mocks/mock_login_service.dart';
import 'package:cringebank/features/login/domain/models/login_models.dart';
import 'package:cringebank/features/login/presentation/pages/login_flow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NoopSessionRefreshCoordinator implements SessionRefreshCoordinator {
  @override
  void clear() {}

  @override
  void dispose() {}

  @override
  Future<void> forceRefresh() async {}

  @override
  void registerSession({
    required String identifier,
    required SessionBootstrapData session,
  }) {}
}

final _noopSessionRefreshCoordinator = _NoopSessionRefreshCoordinator();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginFlowPage golden', () {
    testWidgets('credentials görünümü', (tester) async {
      final binding = tester.view;
      binding.physicalSize = const Size(1080, 1920);
      binding.devicePixelRatio = 1.0;
      addTearDown(() {
        binding.resetPhysicalSize();
        binding.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final flags = const FeatureFlags(
        loginWithPhone: false,
        magicLinkLogin: false,
        webauthnPasskey: false,
        requireMfaForAdmins: false,
        enforceCaptchaAfterThreeFails: false,
      );

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        featureFlags: flags,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const LoginFlowPage(),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(flags),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_flow_credentials.png'),
      );
    });

    testWidgets('kilit ekranı görünümü', (tester) async {
      final binding = tester.view;
      binding.physicalSize = const Size(1080, 1920);
      binding.devicePixelRatio = 1.0;
      addTearDown(() {
        binding.resetPhysicalSize();
        binding.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final flags = const FeatureFlags(
        loginWithPhone: false,
        magicLinkLogin: false,
        webauthnPasskey: false,
        requireMfaForAdmins: false,
        enforceCaptchaAfterThreeFails: false,
      );

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        featureFlags: flags,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.locked,
        lockInfo: LockInfo(
          until: DateTime.utc(2025, 10, 20, 12, 30),
          reason: 'rate_limit',
          remainingAttempts: 0,
        ),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const LoginFlowPage(),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(flags),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_flow_locked.png'),
      );
    });
  });
}
