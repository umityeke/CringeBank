import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/login_controller.dart';
import '../../application/login_providers.dart';
import '../../domain/models/login_models.dart';
import 'login_flow_page_old_complex.dart';
import 'package:cringebank/shared/widgets/app_button.dart';
import 'package:cringebank/shared/widgets/glass_panel.dart';

class LoginFlowPage extends ConsumerStatefulWidget {
  const LoginFlowPage({super.key});

  @override
  ConsumerState<LoginFlowPage> createState() => _LoginFlowPageState();
}

class _LoginFlowPageState extends ConsumerState<LoginFlowPage> {
  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;
  late final TextEditingController _captchaController;
  late final TextEditingController _otpController;
  late final TextEditingController _totpController;
  late final TextEditingController _resetIdentifierController;
  late final TextEditingController _resetNewPasswordController;
  late final TextEditingController _resetConfirmPasswordController;
  late final List<_BubbleConfig> _bubbles;
  late final double _bubbleProgressSeed;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(loginControllerProvider);
    _identifierController =
        TextEditingController(text: initial.credentials.identifier);
    _passwordController =
        TextEditingController(text: initial.credentials.password);
    _captchaController = TextEditingController(
      text: initial.credentials.captchaToken ?? '',
    );
  _otpController = TextEditingController(text: initial.otp.code);
  _totpController = TextEditingController(text: initial.totp.code);
  _resetIdentifierController =
    TextEditingController(text: initial.passwordReset.identifier);
  _resetNewPasswordController =
    TextEditingController(text: initial.passwordReset.newPassword);
  _resetConfirmPasswordController =
    TextEditingController(text: initial.passwordReset.confirmPassword);

    _bubbleProgressSeed = math.Random().nextDouble();

    _bubbles = [
      _BubbleConfig(
        origin: const Offset(0.2, 0.25),
        radius: 110,
        horizontalShift: 0.06,
        verticalShift: 0.08,
        speed: 1.0,
        phase: 0.0,
        colors: [
          const Color(0xFF3C8CE7).withOpacity(0.55),
          const Color(0xFF00EAFF).withOpacity(0.25),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.75, 0.2),
        radius: 140,
        horizontalShift: 0.08,
        verticalShift: 0.06,
        speed: 0.75,
        phase: 0.35,
        colors: [
          const Color(0xFF6A11CB).withOpacity(0.45),
          const Color(0xFF2575FC).withOpacity(0.22),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.3, 0.75),
        radius: 90,
        horizontalShift: 0.05,
        verticalShift: 0.07,
        speed: 1.25,
        phase: 0.6,
        colors: [
          const Color(0xFF00B4DB).withOpacity(0.5),
          const Color(0xFF0083B0).withOpacity(0.2),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.8, 0.72),
        radius: 120,
        horizontalShift: 0.07,
        verticalShift: 0.09,
        speed: 0.9,
        phase: 0.9,
        colors: [
          const Color(0xFFE96443).withOpacity(0.42),
          const Color(0xFF904E95).withOpacity(0.18),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _otpController.dispose();
    _totpController.dispose();
    _resetIdentifierController.dispose();
    _resetNewPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    if (state.method != LoginMethod.emailPassword) {
      return const LegacyLoginFlowPage();
    }

    ref.listen<LoginState>(loginControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      _syncControllers(previous, next);

      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        _showSnackBar(next.errorMessage!, Colors.red);
      }

      final newDeviceNotice = next.requiresDeviceVerification &&
          previous?.requiresDeviceVerification !=
              next.requiresDeviceVerification;
      if (newDeviceNotice) {
        _showSnackBar(
          'Yeni bir cihazdan giris yaptin. Guvenlik icin e-postandaki dogrulamayi tamamlaman gerekiyor.',
          const Color(0xFF1D4ED8),
        );
      }

      final becameSuccessful = previous?.step != LoginStep.success &&
          next.step == LoginStep.success;
      if (becameSuccessful && !next.requiresDeviceVerification) {
        GoRouter.of(context).go('/feed');
      }
    });

    final controller = ref.read(loginControllerProvider.notifier);

    return _buildModernCredentials(context, state, controller);
  }

  void _syncControllers(LoginState? previous, LoginState next) {
    if (previous?.credentials.identifier != next.credentials.identifier &&
        _identifierController.text != next.credentials.identifier) {
      _identifierController.value = TextEditingValue(
        text: next.credentials.identifier,
        selection: TextSelection.collapsed(
          offset: next.credentials.identifier.length,
        ),
      );
    }

    if (previous?.credentials.password != next.credentials.password &&
        _passwordController.text != next.credentials.password) {
      _passwordController.value = TextEditingValue(
        text: next.credentials.password,
        selection: TextSelection.collapsed(
          offset: next.credentials.password.length,
        ),
      );
    }

    final updatedCaptcha = next.credentials.captchaToken ?? '';
    if (previous?.credentials.captchaToken != next.credentials.captchaToken &&
        _captchaController.text != updatedCaptcha) {
      _captchaController.value = TextEditingValue(
        text: updatedCaptcha,
        selection: TextSelection.collapsed(offset: updatedCaptcha.length),
      );
    }

    if (previous?.otp.code != next.otp.code &&
        _otpController.text != next.otp.code) {
      _otpController.value = TextEditingValue(
        text: next.otp.code,
        selection: TextSelection.collapsed(offset: next.otp.code.length),
      );
    }

    if (previous?.totp.code != next.totp.code &&
        _totpController.text != next.totp.code) {
      _totpController.value = TextEditingValue(
        text: next.totp.code,
        selection: TextSelection.collapsed(offset: next.totp.code.length),
      );
    }

    if (previous?.passwordReset.identifier != next.passwordReset.identifier &&
        _resetIdentifierController.text != next.passwordReset.identifier) {
      final identifier = next.passwordReset.identifier;
      _resetIdentifierController.value = TextEditingValue(
        text: identifier,
        selection: TextSelection.collapsed(offset: identifier.length),
      );
    }

    if (previous?.passwordReset.newPassword != next.passwordReset.newPassword &&
        _resetNewPasswordController.text != next.passwordReset.newPassword) {
      final newPassword = next.passwordReset.newPassword;
      _resetNewPasswordController.value = TextEditingValue(
        text: newPassword,
        selection: TextSelection.collapsed(offset: newPassword.length),
      );
    }

    if (previous?.passwordReset.confirmPassword !=
            next.passwordReset.confirmPassword &&
        _resetConfirmPasswordController.text !=
            next.passwordReset.confirmPassword) {
      final confirm = next.passwordReset.confirmPassword;
      _resetConfirmPasswordController.value = TextEditingValue(
        text: confirm,
        selection: TextSelection.collapsed(offset: confirm.length),
      );
    }
  }

  void _showSnackBar(String message, Color background) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildModernCredentials(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = mediaQuery.size.width * 0.07;
    final availableWidth = mediaQuery.size.width - (horizontalPadding * 2);
    final double cardWidth = availableWidth > 0
        ? math.min(460, availableWidth)
        : 460;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF111827),
                    Color(0xFF0B1120),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _BubblesPainter(
                bubbles: _bubbles,
                progress: _bubbleProgressSeed,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: mediaQuery.padding.top + 40,
                bottom: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLoginCard(context, cardWidth, state, controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    double cardWidth,
    LoginState state,
    LoginController controller,
  ) {
    return SizedBox(
      width: cardWidth,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
        child: _buildCardContent(context, cardWidth, state, controller),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    double cardWidth,
    LoginState state,
    LoginController controller,
  ) {
    final double contentWidth = math.max(cardWidth - 56, 92.0);
    final double logoWidth = math.max(92.0, math.min(92.0 * 3.0, contentWidth));
    const double logoHeightFactor = 0.42;
    final double logoHeight = logoWidth * logoHeightFactor;
    final String? title = _titleForStep(state.step);
    final String? subtitle = _subtitleForStep(state.step);
    final Widget body = _buildStepContent(context, state, controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child:
              _LogoCropper(targetWidth: logoWidth, targetHeight: logoHeight),
        ),
        const SizedBox(height: 28),
        if (title != null)
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ],
        const SizedBox(height: 24),
        body,
      ],
    );
  }

  String? _titleForStep(LoginStep step) {
    switch (step) {
      case LoginStep.credentials:
        return 'Giris';
      case LoginStep.mfaSelection:
        return 'Ek dogrulama gerekli';
      case LoginStep.otp:
        return 'Tek kullanimlik kod';
      case LoginStep.totp:
        return 'Authenticator kodu';
      case LoginStep.passkey:
        return 'Passkey dogrulamasi';
      case LoginStep.magicLink:
        return 'E-postandaki baglantiyi dogrula';
      case LoginStep.passwordResetRequest:
        return 'Parola sifirlama istegi';
      case LoginStep.passwordResetConfirm:
        return 'Yeni parolani ayarla';
      case LoginStep.passwordResetComplete:
        return 'Parola yenilendi';
      case LoginStep.success:
        return 'Hos geldin';
      case LoginStep.locked:
        return 'Hesap kilitli';
    }
  }

  String? _subtitleForStep(LoginStep step) {
    switch (step) {
      case LoginStep.credentials:
        return 'Oturum acmak icin kimligini dogrula.';
      case LoginStep.mfaSelection:
        return 'Devam etmek icin bir dogrulama yontemi sec.';
      case LoginStep.otp:
        return 'SMS veya e-posta ile gelen kodu gir.';
      case LoginStep.totp:
        return 'Authenticator uygulamandaki kodu yaz.';
      case LoginStep.passkey:
        return 'Cihazinla passkey dogrulamasini tamamla.';
      case LoginStep.magicLink:
        return 'Gonderdigimiz baglanti ile girisi tamamla.';
      case LoginStep.passwordResetRequest:
        return 'Parolani sifirlamak icin kullanici bilgini gir.';
      case LoginStep.passwordResetConfirm:
        return 'Guvende kalmak icin guclu bir parola olustur.';
      case LoginStep.passwordResetComplete:
        return 'Artik yeni parolanla giris yapabilirsin.';
      case LoginStep.success:
        return 'Yardimci olabilecegimiz bir sey varsa bize bildir.';
      case LoginStep.locked:
        return 'Cok sayida basarisiz deneme nedeniyle giris durduruldu.';
    }
  }

  Widget _buildStepContent(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    switch (state.step) {
      case LoginStep.credentials:
        return _buildCredentialsSection(context, state, controller);
      case LoginStep.mfaSelection:
        return _buildMfaSelectionSection(context, state, controller);
      case LoginStep.otp:
        return _buildOtpSection(context, state, controller);
      case LoginStep.totp:
        return _buildTotpSection(context, state, controller);
      case LoginStep.passkey:
        return _buildPasskeySection(context, state, controller);
      case LoginStep.magicLink:
        return _buildMagicLinkSection(context, state, controller);
      case LoginStep.passwordResetRequest:
        return _buildPasswordResetRequestSection(context, state, controller);
      case LoginStep.passwordResetConfirm:
        return _buildPasswordResetConfirmSection(context, state, controller);
      case LoginStep.passwordResetComplete:
        return _buildPasswordResetCompleteSection(context, state, controller);
      case LoginStep.locked:
        return _buildLockedSection(context, state, controller);
      case LoginStep.success:
        return _buildSuccessSection(context, state, controller);
    }
  }

  Widget _buildCredentialsSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final baseNotices = _buildNotices(context, state);
    final notices = [
      ...baseNotices,
      ..._buildTotpNotices(state),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        const Text(
          'E-posta veya kullanici adi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _identifierController,
          hintText: 'E-posta adresini veya kullanici adini gir',
          icon: Icons.alternate_email,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          enabled: !state.isLoading,
          onChanged: controller.updateIdentifier,
        ),
        const SizedBox(height: 18),
        const Text(
          'Sifre',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _passwordController,
          hintText: 'Sifreni gir',
          obscureText: true,
          textInputAction: TextInputAction.done,
          icon: Icons.lock_outline,
          enabled: !state.isLoading,
          onChanged: controller.updatePassword,
          onSubmitted: () => _handleLogin(controller),
        ),
        if (state.captchaRequired) ...[
          const SizedBox(height: 18),
          const Text(
            'Guvenlik dogrulamasi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildInputField(
            controller: _captchaController,
            hintText: 'Captcha kodunu gir',
            icon: Icons.verified_user_outlined,
            textInputAction: TextInputAction.done,
            enabled: !state.isLoading,
            onChanged: controller.setCaptchaToken,
            onSubmitted: () => _handleLogin(controller),
          ),
        ],
        const SizedBox(height: 16),
        _buildRememberForgotRow(context, state, controller),
        if (state.rememberMeForcedOff)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Bu cihazda oturum bilgilerini saklayamazsin.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 26),
        _buildSignInButton(state, controller),
        const SizedBox(height: 18),
        _buildOrDivider(),
        const SizedBox(height: 18),
        _buildSocialButtons(context),
        const SizedBox(height: 24),
        _buildSignUpRow(context, state),
      ],
    );
  }

  Widget _buildInlineMessage({
    required IconData icon,
    required String message,
    Color? background,
    Color? iconColor,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? Colors.white.withOpacity(0.82), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return _buildInlineMessage(
      icon: Icons.error_outline,
      message: message,
      background: const Color(0xFF7F1D1D).withOpacity(0.32),
      iconColor: const Color(0xFFE11D48),
      borderColor: const Color(0xFFF87171).withOpacity(0.6),
    );
  }

  Widget _buildInlineInfo(String message) {
    return _buildInlineMessage(
      icon: Icons.info_outline,
      message: message,
      background: Colors.white.withOpacity(0.06),
      iconColor: Colors.white.withOpacity(0.82),
      borderColor: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildInlineSuccess(String message) {
    return _buildInlineMessage(
      icon: Icons.check_circle_outline,
      message: message,
      background: const Color(0xFF064E3B).withOpacity(0.38),
      iconColor: const Color(0xFF34D399),
      borderColor: const Color(0xFF10B981).withOpacity(0.5),
    );
  }

  String _mfaChannelLabel(MfaChannel channel) {
    switch (channel) {
      case MfaChannel.smsOtp:
        return 'SMS';
      case MfaChannel.emailOtp:
        return 'E-posta';
      case MfaChannel.totp:
        return 'Authenticator';
      case MfaChannel.passkey:
        return 'Passkey';
    }
  }

  String _mfaChannelDescription(MfaChannel channel) {
    switch (channel) {
      case MfaChannel.smsOtp:
        return 'Telefonuna gelen kisa mesajdaki kodu gir.';
      case MfaChannel.emailOtp:
        return 'E-postana gonderdigimiz guvenlik kodunu kullan.';
      case MfaChannel.totp:
        return 'Authenticator uygulamandaki sureli kodu yaz.';
      case MfaChannel.passkey:
        return 'Guvenilen cihazinda biometrik dogrulamayi tamamla.';
    }
  }

  IconData _mfaChannelIcon(MfaChannel channel) {
    switch (channel) {
      case MfaChannel.smsOtp:
        return Icons.sms_outlined;
      case MfaChannel.emailOtp:
        return Icons.mail_outline;
      case MfaChannel.totp:
        return Icons.phonelink_lock_outlined;
      case MfaChannel.passkey:
        return Icons.fingerprint;
    }
  }

  Widget _buildMfaSelectionSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final notices = _buildNotices(context, state);
    final channels = state.availableMfaChannels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          _buildInlineError(state.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (channels.isEmpty)
          _buildInlineInfo(
            'Kullanabilecegin bir MFA yontemi bulunamadi. Destek ekibi ile iletisime gec.',
          ),
        for (final channel in channels) ...[
          _MfaOptionTile(
            icon: _mfaChannelIcon(channel),
            title: _mfaChannelLabel(channel),
            description: _mfaChannelDescription(channel),
            onTap: state.isLoading
                ? null
                : () => controller.chooseMfaChannel(channel),
          ),
          const SizedBox(height: 12),
        ],
        if (channels.isNotEmpty)
          TextButton(
            onPressed: state.isLoading ? null : controller.reset,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.85),
            ),
            child: const Text('Kimlik bilgilerine geri don'),
          ),
      ],
    );
  }

  Widget _buildOtpSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final baseNotices = _buildNotices(context, state);
    final now = DateTime.now();
    final canResend = state.otp.canResend(now);
    final secondsLeft = !canResend && state.otp.resendAvailableAt != null
        ? math.max(0, state.otp.resendAvailableAt!.difference(now).inSeconds)
        : 0;
    final notices = [
      ...baseNotices,
      ..._buildOtpNotices(
        state: state,
        canResend: canResend,
        secondsLeft: secondsLeft,
      ),
    ];
    final channelLabel = state.otp.channel != null
        ? _mfaChannelLabel(state.otp.channel!)
        : 'OTP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          _buildInlineError(state.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildInlineInfo('$channelLabel uzerinden bir kod gonderdik. Kod 6 haneli.'),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _otpController,
          hintText: '6 haneli kodu gir',
          icon: Icons.security_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          enabled: !state.isLoading,
          onChanged: controller.updateOtpCode,
          onSubmitted: controller.verifyOtp,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Kodu dogrula',
          icon: Icons.verified_user,
          isLoading: state.isLoading,
          onPressed:
              state.isLoading || !state.otp.canSubmit ? null : controller.verifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading || !canResend ? null : controller.resendOtp,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF60A5FA),
          ),
          child: Text(
            canResend
                ? 'Kodu yeniden gonder'
                : 'Yeniden gondermek icin ${secondsLeft}s bekle',
          ),
        ),
      ],
    );
  }

  Widget _buildTotpSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final notices = _buildNotices(context, state);
    final fallbackChannels = state.availableMfaChannels
        .where((channel) => channel != MfaChannel.totp)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          _buildInlineError(state.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildInlineInfo('Authenticator uygulamandaki kodu gir. Kod 30 saniyede bir yenilenir.'),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _totpController,
          hintText: 'Authenticator kodu',
          icon: Icons.shield_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          enabled: !state.isLoading,
          onChanged: controller.updateTotpCode,
          onSubmitted: controller.verifyTotp,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Kodu dogrula',
          icon: Icons.verified_outlined,
          isLoading: state.isLoading,
          onPressed:
              state.isLoading || !state.totp.canSubmit ? null : controller.verifyTotp,
        ),
        if (fallbackChannels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: fallbackChannels
                .map(
                  (channel) => TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => controller.chooseMfaChannel(channel),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.82),
                    ),
                    child: Text('${_mfaChannelLabel(channel)} ile dogrula'),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  Widget _buildPasskeySection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final notices = _buildNotices(context, state);
    final passkey = state.passkey;
    final fallback = state.availableMfaChannels
        .firstWhere(
          (channel) => channel != MfaChannel.passkey,
          orElse: () => MfaChannel.passkey,
        );
    final hasFallback = fallback != MfaChannel.passkey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          _buildInlineError(state.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildInlineInfo(
          'Passkey dogrulamasi icin guvenilen cihazinda biometrik onayi tamamla.',
        ),
        if (passkey.errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildInlineError(passkey.errorMessage!),
        ],
        if (passkey.challengeId != null) ...[
          const SizedBox(height: 16),
          _buildInlineInfo('Dogrulama bekleniyor (challenge ${passkey.challengeId}).'),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Passkey dogrulamasini baslat',
          icon: Icons.fingerprint,
          isLoading: state.isLoading || passkey.isInProgress,
          onPressed: state.isLoading ? null : controller.startPasskeyFlow,
        ),
        if (hasFallback) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: state.isLoading
                ? null
                : () => controller.chooseMfaChannel(fallback),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.82),
            ),
            child: Text('${_mfaChannelLabel(fallback)} ile dogrula'),
          ),
        ],
        if (!hasFallback)
          TextButton(
            onPressed: state.isLoading ? null : controller.reset,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.82),
            ),
            child: const Text('Farkli bir yontem secmek icin geri don'),
          ),
      ],
    );
  }

  Widget _buildMagicLinkSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final notices = _buildNotices(context, state);
    final magic = state.magicLink;
    final now = DateTime.now();
    final canResend = magic.canResend(now);
    final secondsLeft = !canResend && magic.resendAvailableAt != null
        ? math.max(0, magic.resendAvailableAt!.difference(now).inSeconds)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (state.errorMessage != null) ...[
          _buildInlineError(state.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildInlineInfo('E-postana bir baglanti gonderdik. Baglantiyi acarak girisi tamamla.'),
        const SizedBox(height: 18),
        if (magic.errorMessage != null) ...[
          _buildInlineError(magic.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildPrimaryButton(
          label: 'Baglantiyi onayladim',
          icon: Icons.mark_email_read,
          isLoading: magic.isVerifying || state.isLoading,
          onPressed: state.isLoading ? null : controller.confirmMagicLink,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading || !canResend ? null : controller.resendMagicLink,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF60A5FA),
          ),
          child: Text(
            canResend
                ? 'Baglantiyi yeniden gonder'
                : 'Yeniden gondermek icin ${secondsLeft}s bekle',
          ),
        ),
        TextButton(
          onPressed: state.isLoading ? null : controller.reset,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.82),
          ),
          child: const Text('Kimlik bilgilerine geri don'),
        ),
      ],
    );
  }

  Widget _buildPasswordResetRequestSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final notices = _buildNotices(context, state);
    final reset = state.passwordReset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...notices,
        if (notices.isNotEmpty) const SizedBox(height: 16),
        if (reset.errorMessage != null) ...[
          _buildInlineError(reset.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildInlineInfo('Parola sifirlama baglantisi icin e-posta veya kullanici adi gir.'),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _resetIdentifierController,
          hintText: 'E-posta veya kullanici adi',
          icon: Icons.alternate_email,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.emailAddress,
          enabled: !state.isLoading,
          onChanged: controller.updatePasswordResetIdentifier,
          onSubmitted: controller.requestPasswordReset,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Baglanti gonder',
          icon: Icons.mail_outline,
          isLoading: state.isLoading,
          onPressed: state.isLoading || !reset.canSubmitIdentifier
              ? null
              : controller.requestPasswordReset,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading ? null : controller.cancelPasswordReset,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.82),
          ),
          child: const Text('Girise geri don'),
        ),
      ],
    );
  }

  Widget _buildPasswordResetConfirmSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final reset = state.passwordReset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reset.errorMessage != null) ...[
          _buildInlineError(reset.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (reset.hasSentLink)
          ...[
            _buildInlineInfo('E-postana sifirlama baglantisi gonderildi. Yeni parolani ayarlayabilirsin.'),
            const SizedBox(height: 18),
          ],
        _buildInputField(
          controller: _resetNewPasswordController,
          hintText: 'Yeni parola',
          icon: Icons.lock_reset_outlined,
          textInputAction: TextInputAction.next,
          obscureText: true,
          enabled: !state.isLoading,
          onChanged: controller.updatePasswordResetNewPassword,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _resetConfirmPasswordController,
          hintText: 'Yeni parolayi tekrar gir',
          icon: Icons.lock_outline,
          textInputAction: TextInputAction.done,
          obscureText: true,
          enabled: !state.isLoading,
          onChanged: controller.updatePasswordResetConfirmPassword,
          onSubmitted: controller.completePasswordReset,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Parolayi guncelle',
          icon: Icons.lock_reset,
          isLoading: state.isLoading,
          onPressed: state.isLoading || !reset.canSubmitNewPassword
              ? null
              : controller.completePasswordReset,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading ? null : controller.cancelPasswordReset,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.82),
          ),
          child: const Text('Girise geri don'),
        ),
      ],
    );
  }

  Widget _buildPasswordResetCompleteSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInlineSuccess('Parolan basariyla guncellendi. Simdi yeni parolanla giris yapabilirsin.'),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Girise geri don',
          icon: Icons.login_outlined,
          onPressed: state.isLoading ? null : controller.cancelPasswordReset,
        ),
      ],
    );
  }

  Widget _buildLockedSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final lock = state.lockInfo;
    final message = lock == null
        ? 'Hesabin gecici olarak kilitlendi. Lutfen biraz sonra tekrar dene.'
        : 'Hesabin ${_formatLockCountdown(lock.until)} sonra otomatik olarak acilacak.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInlineError(message),
        if (lock != null) ...[
          const SizedBox(height: 16),
          _buildInlineInfo('Kalan deneme hakki: ${lock.remainingAttempts}. Nedeni: ${lock.reason}.'),
        ],
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Durumu yenile',
          icon: Icons.refresh_rounded,
          isLoading: state.isLoading,
          onPressed: state.isLoading ? null : controller.loadLockInfo,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isLoading ? null : controller.reset,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.82),
          ),
          child: const Text('Giris ekranina don'),
        ),
      ],
    );
  }

  Widget _buildSuccessSection(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 12),
        CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        SizedBox(height: 16),
        Text(
          'Giris basariyla tamamlandi. Yonlendiriliyorsun...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildNotice({
    required _NoticeVariant variant,
    required IconData icon,
    required String headline,
    String? message,
  }) {
    final palette = _noticePalette(variant);
    return _NoticeBanner(
      icon: icon,
      headline: headline,
      message: message,
      background: palette.background,
      iconColor: palette.iconColor,
      borderColor: palette.border,
    );
  }

  List<Widget> _buildNotices(BuildContext context, LoginState state) {
    final notices = <Widget>[];
    final lock = state.lockInfo;

    if (lock != null) {
      final countdown = _formatLockCountdown(lock.until);
      final reason = lock.reason.trim();
      final buffer = StringBuffer('Giris denemeleri gecici olarak durduruldu.');
      if (reason.isNotEmpty) {
        buffer.write(' Sebep: $reason.');
      }
      if (countdown == 'simdi') {
        buffer.write(' Simdi tekrar deneyebilirsin.');
      } else {
        buffer.write(' $countdown sonra tekrar dene.');
      }
      notices.add(
        _buildNotice(
          variant: _NoticeVariant.danger,
          icon: Icons.lock_clock,
          headline: 'Hesabin kilitlendi',
          message: buffer.toString(),
        ),
      );
    } else {
      if (state.captchaRequired) {
        notices.add(
          _buildNotice(
            variant: _NoticeVariant.warning,
            icon: Icons.verified_user_outlined,
            headline: 'Ek guvenlik dogrulamasi',
            message:
                'Cok sayida basarisiz deneme tespit edildi. Devam etmek icin guvenlik dogrulamasini tamamla.',
          ),
        );
      }

      if (state.failedAttempts > 0) {
        final remaining = math.max(0, 5 - state.failedAttempts);
        final variant = remaining <= 1 ? _NoticeVariant.danger : _NoticeVariant.warning;
        final message = remaining > 0
            ? 'Son deneme basarisiz oldu. $remaining deneme hakkin kaldi.'
            : 'Son deneme basarisiz oldu. Dikkatli ol, hesap kilitlenebilir.';
        notices.add(
          _buildNotice(
            variant: variant,
            icon: Icons.warning_amber_outlined,
            headline: 'Basarisiz giris denemeleri',
            message: message,
          ),
        );
      }
    }

    if (state.requiresVerification && lock == null) {
      notices.add(
        _buildNotice(
          variant: _NoticeVariant.info,
          icon: Icons.mark_email_unread_outlined,
          headline: 'Dogrulama bekleniyor',
          message:
              'Hesabini dogrulaman gerekiyor. Lutfen e-postandaki baglantiyi kontrol et.',
        ),
      );
    }

    if (state.requiresDeviceVerification) {
      notices.add(
        _buildNotice(
          variant: _NoticeVariant.info,
          icon: Icons.phonelink_lock_outlined,
          headline: 'Yeni cihaz dogrulamasi gerekiyor',
          message:
              'Yeni bir cihazdan giris yaptin. Guvenlik mailindeki onayi tamamlayana kadar giris tamamlanmayacak.',
        ),
      );
    }

    return notices;
  }

  List<Widget> _buildOtpNotices({
    required LoginState state,
    required bool canResend,
    required int secondsLeft,
  }) {
    final notices = <Widget>[];
    final attempts = state.otp.attemptsRemaining;
    if (attempts < 5) {
      final variant = attempts <= 1 ? _NoticeVariant.danger : _NoticeVariant.warning;
      final headline = attempts <= 1 ? 'Son OTP hakkin' : 'OTP deneme limitine yaklastin';
      final message = attempts <= 1
          ? 'Yanlis girersen giris gecici olarak kilitlenebilir.'
          : '$attempts deneme hakkin kaldi. Limit asilirsa hesap gecici olarak kilitlenebilir.';
      notices.add(
        _buildNotice(
          variant: variant,
          icon: Icons.security_outlined,
          headline: headline,
          message: message,
        ),
      );
    }

    if (!canResend && secondsLeft > 0) {
      notices.add(
        _buildNotice(
          variant: _NoticeVariant.info,
          icon: Icons.schedule_send_outlined,
          headline: 'OTP yeniden gonderme siniri',
          message: '$secondsLeft saniye sonra yeni bir kod isteyebilirsin.',
        ),
      );
    }

    return notices;
  }

  List<Widget> _buildTotpNotices(LoginState state) {
    final notices = <Widget>[];
    final attempts = state.totp.attemptsRemaining;
    if (attempts < 5) {
      final variant = attempts <= 1 ? _NoticeVariant.danger : _NoticeVariant.warning;
      final headline = attempts <= 1
          ? 'Son dogrulama hakkin'
          : 'Dogrulama deneme limitine yaklastin';
      final message = attempts <= 1
          ? 'Yanlis girersen giris gecici olarak kilitlenebilir.'
          : '$attempts deneme hakkin kaldi. Limit asilirsa hesap kilitlenebilir.';
      notices.add(
        _buildNotice(
          variant: variant,
          icon: Icons.shield_outlined,
          headline: headline,
          message: message,
        ),
      );
    }
    return notices;
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputAction textInputAction = TextInputAction.next,
    TextInputType? keyboardType,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmitted,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    final borderColor = Colors.white.withOpacity(0.12);
    const focusedBorderColor = Color(0xFF2D79F3);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.4),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            icon,
            size: 20,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              enabled: enabled,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              buildCounter: maxLength != null
                  ? (_, {required int currentLength, required bool isFocused, int? maxLength}) => null
                  : null,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              cursorColor: focusedBorderColor,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberForgotRow(
    BuildContext context,
    LoginState state,
    LoginController controller,
  ) {
    final rememberDisabled = state.isLoading || state.rememberMeForcedOff;

    return Row(
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: state.credentials.rememberMe && !state.rememberMeForcedOff,
            onChanged: rememberDisabled
                ? null
                : (value) => controller.toggleRememberMe(value ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: const Color(0xFF2879F3),
            checkColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'Beni hatirla',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  state.isLoading ? null : controller.startPasswordReset,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Sifremi unuttum',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D79F3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton(
    LoginState state,
    LoginController controller,
  ) {
    final canSubmit = state.canAttemptLogin && !state.isLoading;

    return _buildPrimaryButton(
      label: 'Giris yap',
      icon: Icons.login_rounded,
      isLoading: state.isLoading,
      onPressed: canSubmit ? () => _handleLogin(controller) : null,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return AppButton.primary(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      fullWidth: true,
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'ya da',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    return Column(
      children: [
        _buildSocialButton(
          icon: Icons.g_translate,
          label: 'Google ile giris yap',
          onPressed: () {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google ile giris yakinda eklenecek.'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSocialButton(
          icon: Icons.apple,
          label: 'Apple ile giris yap',
          onPressed: () {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apple ile giris yakinda eklenecek.'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpRow(BuildContext context, LoginState state) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Text(
          'Hesabin yok mu?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        GestureDetector(
          onTap: state.isLoading
              ? null
              : () => GoRouter.of(context).push('/register'),
          child: const Text(
            'Hemen kayit ol',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D79F3),
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogin(LoginController controller) {
    if (!mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    controller.submitCredentials();
  }
}

class _MfaOptionTile extends StatelessWidget {
  const _MfaOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final iconColor = enabled ? Colors.white : Colors.white.withOpacity(0.4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          color: Colors.white.withOpacity(0.04),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NoticeVariant {
  info,
  warning,
  danger,
}

class _NoticePalette {
  const _NoticePalette({
    required this.background,
    required this.border,
    required this.iconColor,
  });

  final Color background;
  final Color border;
  final Color iconColor;
}

_NoticePalette _noticePalette(_NoticeVariant variant) {
  switch (variant) {
    case _NoticeVariant.danger:
      const base = Color(0xFFDC2626);
      return _NoticePalette(
        background: base.withOpacity(0.18),
        border: base.withOpacity(0.45),
        iconColor: const Color(0xFFFCA5A5),
      );
    case _NoticeVariant.warning:
      const base = Color(0xFFF59E0B);
      return _NoticePalette(
        background: base.withOpacity(0.16),
        border: base.withOpacity(0.4),
        iconColor: const Color(0xFFFCD34D),
      );
    case _NoticeVariant.info:
      const base = Color(0xFF2563EB);
      return _NoticePalette(
        background: base.withOpacity(0.14),
        border: base.withOpacity(0.35),
        iconColor: const Color(0xFF93C5FD),
      );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.headline,
    this.message,
    this.background,
    this.iconColor,
    this.borderColor,
  });

  final IconData icon;
  final String headline;
  final String? message;
  final Color? background;
  final Color? iconColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final color = background ?? Colors.white.withOpacity(0.06);
    final iconShade = iconColor ?? Colors.white.withOpacity(0.9);
    final borderShade = borderColor ?? Colors.white.withOpacity(0.12);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderShade),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconShade),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLockCountdown(DateTime unlockAt) {
  final diff = unlockAt.difference(DateTime.now());
  if (diff.isNegative || diff == Duration.zero) {
    return 'simdi';
  }

  final hours = diff.inHours;
  final minutes = diff.inMinutes.remainder(60);
  final seconds = diff.inSeconds.remainder(60);
  final parts = <String>[];

  if (hours > 0) {
    parts.add('$hours sa');
  }
  if (minutes > 0) {
    parts.add('$minutes dk');
  }
  if (hours == 0 && seconds > 0) {
    parts.add('$seconds sn');
  }

  if (parts.isEmpty) {
    return 'birkac saniye';
  }

  return parts.join(' ');
}

class _LogoCropper extends StatefulWidget {
  const _LogoCropper({required this.targetWidth, required this.targetHeight});

  final double targetWidth;
  final double targetHeight;

  @override
  State<_LogoCropper> createState() => _LogoCropperState();
}

class _LogoCropperState extends State<_LogoCropper> {
  late final Future<_TrimmedImage> _trimmedImageFuture;

  @override
  void initState() {
    super.initState();
    _trimmedImageFuture = _loadTrimmedImage();
  }

  Future<_TrimmedImage> _loadTrimmedImage() async {
    final data = await rootBundle.load('assets/images/logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

    final bytes = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;

    const alphaThreshold = 80;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final alpha = bytes[offset + 3];
        if (alpha > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX == -1 || maxY == -1) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

    const edgeInset = 1;

    minX = math.min(width - 1, math.max(0, minX + edgeInset));
    minY = math.min(height - 1, math.max(0, minY + edgeInset));
    maxX = math.max(0, math.min(width - 1, maxX - edgeInset));
    maxY = math.max(0, math.min(height - 1, maxY - edgeInset));

    if (maxX <= minX || maxY <= minY) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

    return _TrimmedImage(
      image: image,
      cropRect: ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.targetHeight,
      width: widget.targetWidth,
      child: FutureBuilder<_TrimmedImage>(
        future: _trimmedImageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return SizedBox(
              width: widget.targetWidth,
              height: widget.targetHeight,
            );
          }

          final trimmed = snapshot.data!;
          return CustomPaint(
            size: Size(widget.targetWidth, widget.targetHeight),
            painter: _TrimmedLogoPainter(trimmed),
          );
        },
      ),
    );
  }
}

class _TrimmedImage {
  const _TrimmedImage({required this.image, required this.cropRect});

  final ui.Image image;
  final ui.Rect cropRect;
}

class _TrimmedLogoPainter extends CustomPainter {
  _TrimmedLogoPainter(this.trimmed);

  final _TrimmedImage trimmed;
  final ui.Paint _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      trimmed.image,
      trimmed.cropRect,
      ui.Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrimmedLogoPainter oldDelegate) {
    return oldDelegate.trimmed.image != trimmed.image ||
        oldDelegate.trimmed.cropRect != trimmed.cropRect;
  }
}

class _BubbleConfig {
  const _BubbleConfig({
    required this.origin,
    required this.radius,
    required this.horizontalShift,
    required this.verticalShift,
    required this.speed,
    required this.phase,
    required this.colors,
  });

  final Offset origin;
  final double radius;
  final double horizontalShift;
  final double verticalShift;
  final double speed;
  final double phase;
  final List<Color> colors;
}

class _BubblesPainter extends CustomPainter {
  const _BubblesPainter({required this.bubbles, required this.progress});

  final List<_BubbleConfig> bubbles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final animationPhase =
          (progress * bubble.speed + bubble.phase) * 2 * math.pi;
      final dx = (bubble.origin.dx +
              math.cos(animationPhase) * bubble.horizontalShift) *
          size.width;
      final dy = (bubble.origin.dy +
              math.sin(animationPhase) * bubble.verticalShift) *
          size.height;

      final center = Offset(dx, dy);
      final paint = ui.Paint()
        ..shader = RadialGradient(
          colors: bubble.colors,
          stops: const [0.0, 1.0],
        ).createShader(
          ui.Rect.fromCircle(center: center, radius: bubble.radius),
        );

      canvas.drawCircle(center, bubble.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bubbles != bubbles;
  }
}
