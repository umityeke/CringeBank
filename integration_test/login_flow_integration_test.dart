import 'package:cringebank/core/config/feature_flags.dart';
import 'package:cringebank/core/session/session_bootstrap.dart';
import 'package:cringebank/core/session/session_controller.dart';
import 'package:cringebank/core/session/session_providers.dart';
import 'package:cringebank/core/session/session_refresh_service.dart';
import 'package:cringebank/features/login/application/login_controller.dart';
import 'package:cringebank/features/login/application/login_providers.dart';
import 'package:cringebank/features/login/data/mocks/mock_login_service.dart';
import 'package:cringebank/features/login/presentation/pages/login_flow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

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

final _NoopSessionRefreshCoordinator _noopSessionRefreshCoordinator =
    _NoopSessionRefreshCoordinator();

const FeatureFlags _testFeatureFlags = FeatureFlags(
  loginWithPhone: false,
  magicLinkLogin: false,
  webauthnPasskey: false,
  requireMfaForAdmins: false,
  enforceCaptchaAfterThreeFails: false,
);

Widget _buildLoginTestApp({
  required LoginController controller,
  required SessionController session,
  required GoRouter router,
  FeatureFlags flags = _testFeatureFlags,
}) {
  return ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith((ref) => session),
      featureFlagsProvider.overrideWithValue(flags),
      loginControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Finder _findTextFieldByHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login flow integration', () {
    testWidgets('email/password girisi feed sayfasina yönlendirir', (tester) async {
      final loginService = MockLoginService();
      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);
      final controller = LoginController(
        loginService,
        sessionController: session,
        featureFlags: _testFeatureFlags,
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
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Feed Page')),
            ),
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildLoginTestApp(
          controller: controller,
          session: session,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        _findTextFieldByHint('E-posta adresini veya kullanici adini gir'),
        'user@cringe.bank',
      );
      await tester.pump();
      await tester.enterText(
        _findTextFieldByHint('Sifreni gir'),
        'CorrectPass123!',
      );
      await tester.pump();

      await tester.tap(find.text('Giris yap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(session.state.isAuthenticated, isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/feed');
      expect(find.text('Feed Page'), findsOneWidget);
    });

    testWidgets('hatali parola backend mesajini snackbar ile gösterir', (tester) async {
      final loginService = MockLoginService();
      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);
      final controller = LoginController(
        loginService,
        sessionController: session,
        featureFlags: _testFeatureFlags,
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
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Feed Page')),
            ),
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildLoginTestApp(
          controller: controller,
          session: session,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        _findTextFieldByHint('E-posta adresini veya kullanici adini gir'),
        'user@cringe.bank',
      );
      await tester.enterText(
        _findTextFieldByHint('Sifreni gir'),
        'YanlisParola!1',
      );
      await tester.pump();

      await tester.tap(find.text('Giris yap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Kullanıcı adı veya parola hatalı.'), findsOneWidget);
      expect(session.state.isAuthenticated, isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });
}
