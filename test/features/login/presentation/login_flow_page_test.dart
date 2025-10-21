import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'package:cringebank/shared/widgets/app_button.dart';

class _NoopSessionRefreshCoordinator implements SessionRefreshCoordinator {
  @override
  void registerSession({
    required String identifier,
    required SessionBootstrapData session,
  }) {}

  @override
  Future<void> forceRefresh() async {}

  @override
  void clear() {}

  @override
  void dispose() {}
}

final _noopSessionRefreshCoordinator = _NoopSessionRefreshCoordinator();

void main() {
  FlutterExceptionHandler? originalOnError;

  setUp(() {
    // Ignore RenderFlex overflow errors triggered by compact test viewport
    originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      final isRenderFlexOverflow =
          exception is FlutterError &&
          exception.diagnostics.any(
            (diag) => '${diag.value}'.contains('A RenderFlex overflowed'),
          );
      if (isRenderFlexOverflow) {
        return;
      }
      if (originalOnError != null) {
        originalOnError!(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  group('LoginFlowPage', () {
    testWidgets('credentials adımı kilit ve rate-limit mesajlarını gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        lockInfo: LockInfo(
          until: DateTime.now().add(const Duration(minutes: 1)),
          reason: 'rate_limit',
          remainingAttempts: 1,
        ),
        failedAttempts: 2,
        captchaRequired: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Hesabin kilitlendi'), findsOneWidget);
      expect(
        find.textContaining('Giris denemeleri gecici olarak durduruldu'),
        findsOneWidget,
      );
    });

    testWidgets(
      'kilit adımı süresi dolduğunda yeniden deneme uyarısı gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.locked,
          lockInfo: LockInfo(
            until: DateTime.now(),
            reason: 'test_lock',
            remainingAttempts: 0,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.textContaining('otomatik olarak acilacak'), findsOneWidget);
        expect(
          find.text('Kalan deneme hakki: 0. Nedeni: test_lock.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'telefon ve sihirli bağlantı kapalıysa yalnızca e-posta seçeneği görünür',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        const flags = FeatureFlags(
          loginWithPhone: false,
          magicLinkLogin: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(flags),
              loginControllerProvider.overrideWith((ref) {
                return LoginController(
                  MockLoginService(),
                  sessionController: session,
                  featureFlags: flags,
                  sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
                );
              }),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.byIcon(Icons.alternate_email), findsOneWidget);
      },
    );

    testWidgets('captcha zorunlu olduğunda captcha alanı görünür', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(captchaRequired: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Guvenlik dogrulamasi'), findsOneWidget);
      expect(find.text('Ek guvenlik dogrulamasi'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets(
      'super admin için remember me kapalı mesajı gösterilir ve kutu pasifleşir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          rememberMeForcedOff: true,
          roles: const {LoginAccountRole.superAdmin},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(
          find.text('Bu cihazda oturum bilgilerini saklayamazsin.'),
          findsOneWidget,
        );
        final rememberCheckbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(rememberCheckbox.onChanged, isNull);
      },
    );

    testWidgets(
      'success adımı cihaz doğrulaması gerektiriyorsa uyarı metni gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.success,
          requiresDeviceVerification: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Hos geldin'), findsOneWidget);
        expect(
          find.text('Yardimci olabilecegimiz bir sey varsa bize bildir.'),
          findsOneWidget,
        );
        expect(
          find.text('Giris basariyla tamamlandi. Yonlendiriliyorsun...'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'success adımı doğrulama gerekmiyorsa başarılı mesajını gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.success,
          requiresDeviceVerification: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Hos geldin'), findsOneWidget);
        expect(
          find.text('Yardimci olabilecegimiz bir sey varsa bize bildir.'),
          findsOneWidget,
        );
        expect(
          find.text('Giris basariyla tamamlandi. Yonlendiriliyorsun...'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.byType(AppButton), findsNothing);
      },
    );

    testWidgets('başarılı giriş feed rotasına yönlendirir', (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginFlowPage(),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(
              body: Center(
                child: Text('Feed sayfası', key: ValueKey('feed_page')),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      controller.state = controller.state.copyWith(
        step: LoginStep.success,
        requiresDeviceVerification: false,
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('feed_page')), findsOneWidget);
    });

    testWidgets('success adımı yalnızca yönlendirme beklemesini gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(step: LoginStep.success);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Hos geldin'), findsOneWidget);
      expect(
        find.text('Giris basariyla tamamlandi. Yonlendiriliyorsun...'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('kilit adımındaki tekrar dene butonu akışı sıfırlar', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.locked,
        lockInfo: LockInfo(
          until: DateTime.now().add(const Duration(minutes: 5)),
          reason: 'test_lock',
          remainingAttempts: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Giris ekranina don'));
      await tester.pumpAndSettle();

      expect(controller.state.step, LoginStep.credentials);
      expect(find.text('E-posta veya kullanici adi'), findsOneWidget);
    });

    testWidgets('global errorMessage SnackBar üzerinden gösterilir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      controller.state = controller.state.copyWith(
        errorMessage: 'Genel bir hata oluştu',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Genel bir hata oluştu'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('yeni cihaz uyarısı SnackBar ile kullanıcıya sunulur', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      controller.state = controller.state.copyWith(
        requiresDeviceVerification: true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'Yeni bir cihazdan giris yaptin. Guvenlik icin e-postandaki dogrulamayi tamamlaman gerekiyor.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'credentials adımı yeni cihaz doğrulaması gerektiğinde uyarı kartı gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          requiresVerification: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(
                const FeatureFlags(enforceCaptchaAfterThreeFails: true),
              ),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dogrulama bekleniyor'), findsOneWidget);
        expect(
          find.text(
            'Hesabini dogrulaman gerekiyor. Lutfen e-postandaki baglantiyi kontrol et.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'OTP adımı cooldown sırasında sayaç etiketi görünür ve doğrulama butonu beklemede kalır',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.otp,
          otp: controller.state.otp.copyWith(
            attemptsRemaining: 2,
            resendAvailableAt: DateTime.now().add(const Duration(seconds: 45)),
            channel: MfaChannel.smsOtp,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(
          find.text('SMS uzerinden bir kod gonderdik. Kod 6 haneli.'),
          findsOneWidget,
        );
        expect(find.text('OTP deneme limitine yaklastin'), findsOneWidget);
        expect(
          find.text(
            '2 deneme hakkin kaldi. Limit asilirsa hesap gecici olarak kilitlenebilir.',
          ),
          findsOneWidget,
        );
        expect(find.text('OTP yeniden gonderme siniri'), findsOneWidget);
        expect(find.textContaining('Yeniden gondermek icin'), findsOneWidget);

        final otpField = tester.widget<TextField>(find.byType(TextField));
        expect(otpField.enabled, isTrue);

        final verifyButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Kodu dogrula'),
        );
        expect(verifyButton.onPressed, isNull);

        final resendButton = tester.widget<TextButton>(
          find.ancestor(
            of: find.textContaining('Yeniden gondermek icin'),
            matching: find.byType(TextButton),
          ),
        );
        expect(resendButton.onPressed, isNull);
      },
    );

    testWidgets('OTP adımı yüklenirken alan ve butonlar pasifleşir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.otp,
        isLoading: true,
        otp: controller.state.otp.copyWith(
          resendAvailableAt: null,
          attemptsRemaining: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final otpFieldFinder = find.byType(TextField);
      expect(otpFieldFinder, findsOneWidget);
      final otpField = tester.widget<TextField>(otpFieldFinder);
      expect(otpField.enabled, isFalse);

  final verifyFinder = find.byType(AppButton);
      expect(verifyFinder, findsOneWidget);
  final verifyButton = tester.widget<AppButton>(verifyFinder);
      expect(verifyButton.onPressed, isNull);
      expect(
        find.descendant(
          of: verifyFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      final resendButtonFinder = find.ancestor(
        of: find.text('Kodu yeniden gonder'),
        matching: find.byType(TextButton),
      );
      expect(resendButtonFinder, findsOneWidget);
      final resendButton = tester.widget<TextButton>(resendButtonFinder);
      expect(resendButton.onPressed, isNull);
    });

    testWidgets('TOTP adımı alan ve bilgilendirmeleri gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.totp,
        totp: controller.state.totp.copyWith(
          attemptsRemaining: 3,
          deviceName: 'MacBook',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'Authenticator uygulamandaki kodu gir. Kod 30 saniyede bir yenilenir.',
        ),
        findsOneWidget,
      );
      final totpFieldFinder = find.byType(TextField);
      expect(totpFieldFinder, findsOneWidget);
      final totpField = tester.widget<TextField>(totpFieldFinder);
      expect(totpField.enabled, isTrue);
      expect(find.text('Dogrulama deneme limitine yaklastin'), findsOneWidget);
      expect(
        find.text(
          '3 deneme hakkin kaldi. Limit asilirsa hesap kilitlenebilir.',
        ),
        findsOneWidget,
      );

  final verifyFinder = find.widgetWithText(AppButton, 'Kodu dogrula');
      expect(verifyFinder, findsOneWidget);
  final verifyButton = tester.widget<AppButton>(verifyFinder);
      expect(verifyButton.onPressed, isNull);
      expect(
        find.descendant(
          of: verifyFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('TOTP adımı yüklenirken alan ve buton pasifleşir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.totp,
        isLoading: true,
        totp: controller.state.totp.copyWith(attemptsRemaining: 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final totpFieldFinder = find.byType(TextField);
      expect(totpFieldFinder, findsOneWidget);
      final totpField = tester.widget<TextField>(totpFieldFinder);
      expect(totpField.enabled, isFalse);

  final verifyFinder = find.byType(AppButton);
      expect(verifyFinder, findsOneWidget);
  final verifyButton = tester.widget<AppButton>(verifyFinder);
      expect(verifyButton.onPressed, isNull);
      expect(
        find.descendant(
          of: verifyFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Passkey adımı challenge hazır olduğunda kullanıcıyı yönlendirir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passkey,
          availableMfaChannels: const [MfaChannel.passkey, MfaChannel.smsOtp],
          passkey: controller.state.passkey.copyWith(
            challengeId: 'challenge-123',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(
          find.text(
            'Passkey dogrulamasi icin guvenilen cihazinda biometrik onayi tamamla.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Dogrulama bekleniyor (challenge challenge-123).'),
          findsOneWidget,
        );

        final startFinder = find.widgetWithText(
          AppButton,
          'Passkey dogrulamasini baslat',
        );
        expect(startFinder, findsOneWidget);
        final startButton = tester.widget<AppButton>(startFinder);
        expect(startButton.onPressed, isNotNull);

        final fallbackFinder = find.ancestor(
          of: find.text('SMS ile dogrula'),
          matching: find.byType(TextButton),
        );
        expect(fallbackFinder, findsOneWidget);
        final fallbackButton = tester.widget<TextButton>(fallbackFinder);
        expect(fallbackButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Passkey adımı yüklenirken aksiyonlar pasifleşir ve spinner görünür',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passkey,
          isLoading: true,
          availableMfaChannels: const [MfaChannel.passkey, MfaChannel.emailOtp],
          passkey: controller.state.passkey.copyWith(
            challengeId: 'challenge-xyz',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

  final startFinder = find.byType(AppButton);
        expect(startFinder, findsOneWidget);
  final startButton = tester.widget<AppButton>(startFinder);
        expect(startButton.onPressed, isNull);

        final fallbackFinder = find.ancestor(
          of: find.text('E-posta ile dogrula'),
          matching: find.byType(TextButton),
        );
        expect(fallbackFinder, findsOneWidget);
        final fallbackButton = tester.widget<TextButton>(fallbackFinder);
        expect(fallbackButton.onPressed, isNull);

        expect(
          find.descendant(
            of: startFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Passkey adımı hata mesajını gösterir ve aksiyonlar etkin kalır',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passkey,
          availableMfaChannels: const [MfaChannel.passkey, MfaChannel.totp],
          passkey: controller.state.passkey.copyWith(
            challengeId: 'challenge-err',
            errorMessage: 'Doğrulama başarısız oldu',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Doğrulama başarısız oldu'), findsOneWidget);

        final startFinder = find.widgetWithText(
          AppButton,
          'Passkey dogrulamasini baslat',
        );
        expect(startFinder, findsOneWidget);
        final startButton = tester.widget<AppButton>(startFinder);
        expect(startButton.onPressed, isNotNull);

        final fallbackFinder = find.ancestor(
          of: find.text('Authenticator ile dogrula'),
          matching: find.byType(TextButton),
        );
        expect(fallbackFinder, findsOneWidget);
        final fallbackButton = tester.widget<TextButton>(fallbackFinder);
        expect(fallbackButton.onPressed, isNotNull);
      },
    );

    testWidgets('MFA seçim adımı kanalları listeler ve aktif butonlar sunar', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.mfaSelection,
        availableMfaChannels: const [
          MfaChannel.smsOtp,
          MfaChannel.emailOtp,
          MfaChannel.totp,
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final smsFinder = find.ancestor(
        of: find.text('SMS'),
        matching: find.byType(InkWell),
      );
      expect(smsFinder, findsOneWidget);
      final smsTile = tester.widget<InkWell>(smsFinder);
      expect(smsTile.onTap, isNotNull);

      final emailFinder = find.ancestor(
        of: find.text('E-posta'),
        matching: find.byType(InkWell),
      );
      expect(emailFinder, findsOneWidget);
      final emailTile = tester.widget<InkWell>(emailFinder);
      expect(emailTile.onTap, isNotNull);

      final totpFinder = find.ancestor(
        of: find.text('Authenticator'),
        matching: find.byType(InkWell),
      );
      expect(totpFinder, findsOneWidget);
      final totpTile = tester.widget<InkWell>(totpFinder);
      expect(totpTile.onTap, isNotNull);

      final backFinder = find.widgetWithText(
        TextButton,
        'Kimlik bilgilerine geri don',
      );
      expect(backFinder, findsOneWidget);
      final backButton = tester.widget<TextButton>(backFinder);
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets('MFA seçim adımı yüklenirken kanal butonları pasifleşir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.mfaSelection,
        isLoading: true,
        availableMfaChannels: const [MfaChannel.smsOtp, MfaChannel.emailOtp],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final smsFinder = find.ancestor(
        of: find.text('SMS'),
        matching: find.byType(InkWell),
      );
      expect(smsFinder, findsOneWidget);
      final smsTile = tester.widget<InkWell>(smsFinder);
      expect(smsTile.onTap, isNull);

      final emailFinder = find.ancestor(
        of: find.text('E-posta'),
        matching: find.byType(InkWell),
      );
      expect(emailFinder, findsOneWidget);
      final emailTile = tester.widget<InkWell>(emailFinder);
      expect(emailTile.onTap, isNull);

      final backFinder = find.widgetWithText(
        TextButton,
        'Kimlik bilgilerine geri don',
      );
      expect(backFinder, findsOneWidget);
      final backButton = tester.widget<TextButton>(backFinder);
      expect(backButton.onPressed, isNull);
    });

    testWidgets('MFA seçim adımı sms seçildiğinde OTP adımına geçer', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final service = MockLoginService();
      final controller = LoginController(
        service,
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.mfaSelection,
        availableMfaChannels: const [MfaChannel.smsOtp, MfaChannel.totp],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();

      expect(controller.state.step, LoginStep.otp);
      expect(controller.state.otp.channel, MfaChannel.smsOtp);
      expect(controller.state.isLoading, isFalse);
      expect(find.text('Tek kullanimlik kod'), findsOneWidget);
    });

    testWidgets('MFA seçim adımı totp seçildiğinde TOTP adımına geçer', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.mfaSelection,
        availableMfaChannels: const [MfaChannel.smsOtp, MfaChannel.totp],
        totp: controller.state.totp.copyWith(
          code: '998877',
          attemptsRemaining: 1,
        ),
        errorMessage: 'Önceki hata',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Authenticator'));
      await tester.pumpAndSettle();

      expect(controller.state.step, LoginStep.totp);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.totp.code, '');
      expect(controller.state.totp.attemptsRemaining, 5);
    });

    testWidgets('Magic link adımı sayaç ve butonları etkin gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.magicLink,
        credentials: controller.state.credentials.copyWith(
          identifier: ' user@example.com ',
        ),
        magicLink: controller.state.magicLink.copyWith(
          resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'E-postana bir baglanti gonderdik. Baglantiyi acarak girisi tamamla.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Yeniden gondermek icin'), findsOneWidget);

        final confirmFinder = find.widgetWithText(
          AppButton,
        'Baglantiyi onayladim',
      );
      expect(confirmFinder, findsOneWidget);
        final confirmButton = tester.widget<AppButton>(confirmFinder);
      expect(confirmButton.onPressed, isNotNull);

      final resendFinder = find.ancestor(
        of: find.textContaining('Yeniden gondermek icin'),
        matching: find.byType(TextButton),
      );
      expect(resendFinder, findsOneWidget);
      final resendButton = tester.widget<TextButton>(resendFinder);
      expect(resendButton.onPressed, isNull);

      final backFinder = find.widgetWithText(
        TextButton,
        'Kimlik bilgilerine geri don',
      );
      expect(backFinder, findsOneWidget);
      final backButton = tester.widget<TextButton>(backFinder);
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets('Magic link adımı yüklenirken butonlar pasifleşir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.magicLink,
        isLoading: true,
        credentials: controller.state.credentials.copyWith(
          identifier: 'user@example.com',
        ),
        magicLink: controller.state.magicLink.copyWith(
          resendAvailableAt: DateTime.now().add(const Duration(seconds: 10)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

  final confirmFinder = find.byType(AppButton);
      expect(confirmFinder, findsOneWidget);
  final confirmButton = tester.widget<AppButton>(confirmFinder);
      expect(confirmButton.onPressed, isNull);
      expect(
        find.descendant(
          of: confirmFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      final resendFinder = find.ancestor(
        of: find.textContaining('Yeniden gonder'),
        matching: find.byType(TextButton),
      );
      expect(resendFinder, findsOneWidget);
      final resendButton = tester.widget<TextButton>(resendFinder);
      expect(resendButton.onPressed, isNull);

      final backFinder = find.ancestor(
        of: find.text('Kimlik bilgilerine geri don'),
        matching: find.byType(TextButton),
      );
      expect(backFinder, findsOneWidget);
      final backButton = tester.widget<TextButton>(backFinder);
      expect(backButton.onPressed, isNull);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Magic link adımı hata mesajını gösterir', (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.magicLink,
        credentials: controller.state.credentials.copyWith(
          identifier: 'user@example.com',
        ),
        magicLink: controller.state.magicLink.copyWith(
          errorMessage: 'Bağlantı süresi doldu',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Bağlantı süresi doldu'), findsOneWidget);
        final confirmFinder = find.widgetWithText(
          AppButton,
        'Baglantiyi onayladim',
      );
      expect(confirmFinder, findsOneWidget);
        final confirmButton = tester.widget<AppButton>(confirmFinder);
      expect(confirmButton.onPressed, isNotNull);

      final resendFinder = find.ancestor(
        of: find.text('Baglantiyi yeniden gonder'),
        matching: find.byType(TextButton),
      );
      expect(resendFinder, findsOneWidget);
      final resendButton = tester.widget<TextButton>(resendFinder);
      expect(resendButton.onPressed, isNotNull);

      final backFinder = find.ancestor(
        of: find.text('Kimlik bilgilerine geri don'),
        matching: find.byType(TextButton),
      );
      expect(backFinder, findsOneWidget);
      final backButton = tester.widget<TextButton>(backFinder);
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets(
      'Parola sıfırlama isteği adımı alan ve aksiyonları etkin gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passwordResetRequest,
          passwordReset: controller.state.passwordReset.copyWith(
            identifier: 'reset@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        final identifierFinder = find.byType(TextField);
        expect(identifierFinder, findsOneWidget);
        final identifierField = tester.widget<TextField>(identifierFinder);
        expect(identifierField.enabled, isTrue);
        expect(identifierField.controller?.text, 'reset@example.com');

        final requestFinder = find.widgetWithText(
          AppButton,
          'Baglanti gonder',
        );
        expect(requestFinder, findsOneWidget);
        final requestButton = tester.widget<AppButton>(requestFinder);
        expect(requestButton.onPressed, isNotNull);

        final backFinder = find.ancestor(
          of: find.text('Girise geri don'),
          matching: find.byType(TextButton),
        );
        expect(backFinder, findsOneWidget);
        final backButton = tester.widget<TextButton>(backFinder);
        expect(backButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Parola sıfırlama isteği yüklenirken alan ve aksiyonlar pasifleşir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passwordResetRequest,
          isLoading: true,
          passwordReset: controller.state.passwordReset.copyWith(
            identifier: 'reset@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        final identifierFinder = find.byType(TextField);
        expect(identifierFinder, findsOneWidget);
        final identifierField = tester.widget<TextField>(identifierFinder);
        expect(identifierField.enabled, isFalse);

  final requestFinder = find.byType(AppButton);
        expect(requestFinder, findsOneWidget);
  final requestButton = tester.widget<AppButton>(requestFinder);
        expect(requestButton.onPressed, isNull);
        expect(
          find.descendant(
            of: requestFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        final backFinder = find.ancestor(
          of: find.text('Girise geri don'),
          matching: find.byType(TextButton),
        );
        expect(backFinder, findsOneWidget);
        final backButton = tester.widget<TextButton>(backFinder);
        expect(backButton.onPressed, isNull);
      },
    );

    testWidgets('Parola sıfırlama isteği hata mesajını gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.passwordResetRequest,
        passwordReset: controller.state.passwordReset.copyWith(
          identifier: 'reset@example.com',
          errorMessage: 'Kullanıcı bulunamadı',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Kullanıcı bulunamadı'), findsOneWidget);

        final requestFinder = find.widgetWithText(
          AppButton,
        'Baglanti gonder',
      );
      expect(requestFinder, findsOneWidget);
        final requestButton = tester.widget<AppButton>(requestFinder);
      expect(requestButton.onPressed, isNotNull);
    });

    testWidgets('Parola sıfırlama onay adımı formu etkin şekilde gösterir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.passwordResetConfirm,
        passwordReset: controller.state.passwordReset.copyWith(
          identifier: 'reset@example.com',
          token: 'token',
          newPassword: '12345678',
          confirmPassword: '12345678',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[0].enabled, isTrue);
      expect(fields[0].controller?.text, '12345678');
      expect(fields[1].enabled, isTrue);
      expect(fields[1].controller?.text, '12345678');

      final updateButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Parolayi guncelle'),
      );
      expect(updateButton.onPressed, isNotNull);

      final backButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Girise geri don'),
          matching: find.byType(TextButton),
        ),
      );
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets('Parola sıfırlama onay adımı yüklenirken alanlar pasifleşir', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final session = SessionController();
      session.state = session.state.copyWith(isHydrated: true);

      final controller = LoginController(
        MockLoginService(),
        sessionController: session,
        sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
      );

      controller.state = controller.state.copyWith(
        step: LoginStep.passwordResetConfirm,
        isLoading: true,
        passwordReset: controller.state.passwordReset.copyWith(
          identifier: 'reset@example.com',
          token: 'token',
          newPassword: '12345678',
          confirmPassword: '12345678',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => session),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
            loginControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: LoginFlowPage()),
        ),
      );
      await tester.pump();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields.every((field) => field.enabled == false), isTrue);

  final updateFinder = find.byType(AppButton);
      expect(updateFinder, findsOneWidget);
  final updateButton = tester.widget<AppButton>(updateFinder);
      expect(updateButton.onPressed, isNull);
      expect(
        find.descendant(
          of: updateFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      final backButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Girise geri don'),
          matching: find.byType(TextButton),
        ),
      );
      expect(backButton.onPressed, isNull);
    });

    testWidgets(
      'Parola sıfırlama onay adımı hata mesajını gösterir ve buton pasifleşir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passwordResetConfirm,
          passwordReset: controller.state.passwordReset.copyWith(
            identifier: 'reset@example.com',
            token: 'token',
            newPassword: '12345678',
            confirmPassword: '87654321',
            errorMessage: 'Parolalar uyuşmuyor',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Parolalar uyuşmuyor'), findsOneWidget);

        final updateButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Parolayi guncelle'),
        );
        expect(updateButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Parola sıfırlama tamamlandı adımı başarı mesajı ve aksiyonu gösterir',
      (tester) async {
        final view = tester.view;
        view.physicalSize = const Size(900, 1600);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        final session = SessionController();
        session.state = session.state.copyWith(isHydrated: true);

        final controller = LoginController(
          MockLoginService(),
          sessionController: session,
          sessionRefreshCoordinator: _noopSessionRefreshCoordinator,
        );

        controller.state = controller.state.copyWith(
          step: LoginStep.passwordResetComplete,
          passwordReset: controller.state.passwordReset.copyWith(
            identifier: 'reset@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionControllerProvider.overrideWith((ref) => session),
              featureFlagsProvider.overrideWithValue(const FeatureFlags()),
              loginControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: LoginFlowPage()),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(
          find.text(
            'Parolan basariyla guncellendi. Simdi yeni parolanla giris yapabilirsin.',
          ),
          findsOneWidget,
        );

        final backButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Girise geri don'),
        );
        expect(backButton.onPressed, isNotNull);
      },
    );
  });
}
