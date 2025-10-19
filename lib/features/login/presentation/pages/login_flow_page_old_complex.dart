import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/login_providers.dart';
import '../../domain/models/login_models.dart';

class LegacyLoginFlowPage extends ConsumerWidget {
  const LegacyLoginFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginControllerProvider);
    ref.listen<LoginState>(loginControllerProvider, (previous, next) {
      if (previous?.errorMessage != next.errorMessage && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
      final newDeviceNotice = next.requiresDeviceVerification &&
          previous?.requiresDeviceVerification != next.requiresDeviceVerification;
      if (newDeviceNotice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Yeni bir cihazdan giri┼ş yapt─▒n. G├╝venlik i├ğin e-postandaki do─şrulamay─▒ tamamlaman gerekiyor.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
      final becameSuccessful = previous?.step != LoginStep.success && next.step == LoginStep.success;
      if (becameSuccessful && !next.requiresDeviceVerification) {
        final router = GoRouter.maybeOf(context);
        router?.go('/feed');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('CringeBank Giri┼ş'),
        actions: [
          if (state.step != LoginStep.credentials)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(loginControllerProvider.notifier).reset(),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (state.step) {
          LoginStep.credentials => const _CredentialsStep(key: ValueKey('login_credentials')),
          LoginStep.otp => const _OtpStep(key: ValueKey('login_otp')),
          LoginStep.totp => const _TotpStep(key: ValueKey('login_totp')),
          LoginStep.passkey => const _PasskeyStep(key: ValueKey('login_passkey')),
          LoginStep.magicLink => const _MagicLinkStep(key: ValueKey('login_magic_link')),
          LoginStep.passwordResetRequest => const _PasswordResetRequestStep(key: ValueKey('login_reset_request')),
          LoginStep.passwordResetConfirm => const _PasswordResetConfirmStep(key: ValueKey('login_reset_confirm')),
          LoginStep.passwordResetComplete => const _PasswordResetCompleteStep(key: ValueKey('login_reset_complete')),
          LoginStep.locked => const _LockedStep(key: ValueKey('login_locked')),
          LoginStep.success => const _SuccessStep(key: ValueKey('login_success')),
          LoginStep.mfaSelection => const _MfaSelectionStep(key: ValueKey('login_mfa_selection')),
        },
      ),
    );
  }
}

String _formatLockCountdown(DateTime unlockAt) {
  final diff = unlockAt.difference(DateTime.now());
  if (diff.isNegative || diff == Duration.zero) {
    return '┼şimdi';
  }

  final parts = <String>[];
  final hours = diff.inHours;
  final minutes = diff.inMinutes.remainder(60);
  final seconds = diff.inSeconds.remainder(60);

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
    return 'birka├ğ saniye';
  }

  return parts.join(' ');
}

class _CredentialsStep extends ConsumerWidget {
  const _CredentialsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (state.lockInfo != null)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hesab─▒n ge├ğici olarak kilitlendi. Kalan deneme hakk─▒: ${state.lockInfo!.remainingAttempts}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      () {
                        final countdown = _formatLockCountdown(state.lockInfo!.until);
                        if (countdown == '┼şimdi') {
                          return 'Kilidin a├ğ─▒lmas─▒ i├ğin yeniden denemeyi deneyebilirsin.';
                        }
                        return 'Tekrar deneyebilmen i├ğin yakla┼ş─▒k $countdown beklemelisin.';
                      }(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          if (state.failedAttempts > 0 && !state.captchaRequired)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  () {
                    final remainingForCaptcha = (3 - state.failedAttempts).clamp(0, 3);
                    if (remainingForCaptcha <= 0) {
                      return 'Ard─▒┼ş─▒k hatal─▒ denemeler nedeniyle ek g├╝venlik kontrolleri uygulanacak.';
                    }
                    final attemptLabel = remainingForCaptcha == 1 ? 'bir deneme' : '$remainingForCaptcha deneme';
                    return 'Ard─▒┼ş─▒k ${state.failedAttempts} ba┼şar─▒s─▒z giri┼ş tespit edildi. Captcha do─şrulamas─▒ zorunlu olmadan ├Ânce $attemptLabel hakk─▒n kald─▒.';
                  }(),
                ),
              ),
            ),
          if (state.requiresVerification)
            const Card(
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Hesab─▒n─▒ do─şrulaman gerekiyor. E-postandaki ba─şlant─▒y─▒ kontrol et.'),
              ),
            ),
          ToggleButtons(
            isSelected: LoginMethod.values
                .map((method) => method == state.method)
                .toList(growable: false),
            onPressed: state.isLoading
                ? null
                : (index) => controller.changeMethod(LoginMethod.values[index]),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('E-posta')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Telefon')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Sihirli ba─şlant─▒')),
            ],
          ),
          const SizedBox(height: 12),
          if (state.method == LoginMethod.phoneOtp)
            const Text(
              'Telefonuna tek kullan─▒ml─▒k giri┼ş kodu g├Ânderece─şiz.',
            ),
          if (state.method == LoginMethod.magicLink)
            const Text(
              'E-postana tek kullan─▒ml─▒k sihirli ba─şlant─▒ g├Ânderece─şiz.',
            ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('login_identifier_field'),
            enabled: !state.isLoading,
            decoration: InputDecoration(
              labelText: state.method == LoginMethod.emailPassword
                  ? 'E-posta adresi'
                  : state.method == LoginMethod.phoneOtp
                      ? 'Telefon numaras─▒ (+905...)'
                      : 'E-posta adresi',
            ),
            keyboardType: state.method == LoginMethod.emailPassword
                ? TextInputType.emailAddress
                : state.method == LoginMethod.phoneOtp
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
            onChanged: controller.updateIdentifier,
          ),
          if (state.method == LoginMethod.emailPassword) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('login_password_field'),
              enabled: !state.isLoading,
              decoration: const InputDecoration(labelText: 'Parola'),
              obscureText: true,
              onChanged: controller.updatePassword,
            ),
          ],
          const SizedBox(height: 16),
          CheckboxListTile(
            value: state.credentials.rememberMe,
            onChanged:
                state.isLoading ? null : (value) => controller.toggleRememberMe(value ?? false),
            title: const Text('Beni hat─▒rla'),
          ),
          if (state.captchaRequired) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('G├╝venlik kontrol├╝ gerekli'),
                    const SizedBox(height: 8),
                    Text(
                      'Ard─▒┼ş─▒k ${state.failedAttempts} hatal─▒ deneme tespit edildi. L├╝tfen captcha do─şrulamas─▒n─▒ tamamla.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('login_captcha_field'),
              enabled: !state.isLoading,
              decoration: const InputDecoration(
                labelText: 'Captcha do─şrulamas─▒',
                hintText: 'reCAPTCHA token',
              ),
              onChanged: controller.setCaptchaToken,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    switch (state.method) {
                      LoginMethod.phoneOtp => Icons.sms,
                      LoginMethod.magicLink => Icons.link,
                      _ => Icons.login,
                    },
                  ),
            label: Text(
              switch (state.method) {
                LoginMethod.phoneOtp => 'Kod g├Ânder',
                LoginMethod.magicLink => 'Ba─şlant─▒ g├Ânder',
                _ => 'Giri┼ş yap',
              },
            ),
            onPressed: state.isLoading ? null : controller.submitCredentials,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: state.isLoading ? null : controller.loadLockInfo,
            child: const Text('Kilidi kontrol et'),
          ),
          TextButton(
            onPressed: state.isLoading ? null : controller.startPasswordReset,
            child: const Text('┼Şifremi unuttum'),
          ),
        ],
      ),
    );
  }
}

class _MagicLinkStep extends ConsumerWidget {
  const _MagicLinkStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);
    final seconds = state.magicLink.resendAvailableAt == null
        ? 0
        : state.magicLink.resendAvailableAt!
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('E-postana bir ba─şlant─▒ g├Ânderdik: ${state.credentials.identifier.trim()}'),
          const SizedBox(height: 8),
          const Text('E-postandaki ba─şlant─▒ya t─▒klay─▒p geri d├Ânmen yeterli.'),
          if (state.magicLink.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.magicLink.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: state.isLoading ? null : controller.confirmMagicLink,
            icon: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified),
            label: const Text('Ba─şlant─▒y─▒ do─şrulad─▒m'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: state.isLoading ? null : controller.resendMagicLink,
            child: seconds > 0
                ? Text('Ba─şlant─▒y─▒ yeniden g├Ânder (${seconds}s)')
                : const Text('Ba─şlant─▒y─▒ yeniden g├Ânder'),
          ),
        ],
      ),
    );
  }
}

class _PasswordResetRequestStep extends ConsumerWidget {
  const _PasswordResetRequestStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Parolan─▒ s─▒f─▒rlamak i├ğin e-posta adresini gir.'),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey('login_reset_identifier_field_${state.passwordReset.identifier}'),
            initialValue: state.passwordReset.identifier,
            enabled: !state.isLoading,
            decoration: const InputDecoration(labelText: 'E-posta adresi'),
            keyboardType: TextInputType.emailAddress,
            onChanged: controller.updatePasswordResetIdentifier,
          ),
          if (state.passwordReset.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.passwordReset.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.isLoading || !state.passwordReset.canSubmitIdentifier
                ? null
                : controller.requestPasswordReset,
            child: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Ba─şlant─▒ g├Ânder'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: state.isLoading ? null : controller.cancelPasswordReset,
            child: const Text('Geri d├Ân'),
          ),
        ],
      ),
    );
  }
}

class _PasswordResetConfirmStep extends ConsumerWidget {
  const _PasswordResetConfirmStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('E-postana g├Ânderdi─şimiz ba─şlant─▒y─▒ a├ğt─▒─ş─▒n─▒ varsay─▒yoruz: ${state.passwordReset.identifier}'),
          const SizedBox(height: 12),
          const Text('Yeni parolan─▒ belirle ve onayla.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('login_reset_new_password_field'),
            enabled: !state.isLoading,
            decoration: const InputDecoration(labelText: 'Yeni parola'),
            obscureText: true,
            onChanged: controller.updatePasswordResetNewPassword,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('login_reset_confirm_password_field'),
            enabled: !state.isLoading,
            decoration: const InputDecoration(labelText: 'Parolay─▒ do─şrula'),
            obscureText: true,
            onChanged: controller.updatePasswordResetConfirmPassword,
          ),
          if (state.passwordReset.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.passwordReset.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.isLoading || !state.passwordReset.canSubmitNewPassword
                ? null
                : controller.completePasswordReset,
            child: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Parolay─▒ g├╝ncelle'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: state.isLoading ? null : controller.cancelPasswordReset,
            child: const Text('Giri┼şe d├Ân'),
          ),
        ],
      ),
    );
  }
}

class _PasswordResetCompleteStep extends ConsumerWidget {
  const _PasswordResetCompleteStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read, size: 72),
            const SizedBox(height: 16),
            Text(
              '${state.passwordReset.identifier} i├ğin parola ba┼şar─▒yla g├╝ncellendi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.reset,
              child: const Text('Giri┼şe d├Ân'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpStep extends ConsumerWidget {
  const _OtpStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);
    final seconds = state.otp.resendAvailableAt == null
        ? 0
        : state.otp.resendAvailableAt!
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Se├ğili kanal: ${state.otp.channel?.name ?? 'SMS'}'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('login_otp_field'),
            enabled: !state.isLoading,
            decoration: const InputDecoration(labelText: 'OTP Kodu'),
            keyboardType: TextInputType.number,
            onChanged: controller.updateOtpCode,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isLoading ? null : controller.verifyOtp,
            child: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Do─şrula'),
          ),
          const SizedBox(height: 24),
          Text('Kalan deneme: ${state.otp.attemptsRemaining}'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: state.isLoading ? null : controller.resendOtp,
            child: seconds > 0 ? Text('Kod g├Ânder (${seconds}s)') : const Text('Kod g├Ânder'),
          ),
        ],
      ),
    );
  }
}

class _TotpStep extends ConsumerWidget {
  const _TotpStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Authenticator uygulamandaki 6 haneli kodu gir.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('login_totp_field'),
            enabled: !state.isLoading,
            decoration: const InputDecoration(labelText: 'TOTP Kodu'),
            keyboardType: TextInputType.number,
            onChanged: controller.updateTotpCode,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isLoading ? null : controller.verifyTotp,
            child: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Do─şrula'),
          ),
          const SizedBox(height: 24),
          Text('Kalan deneme: ${state.totp.attemptsRemaining}'),
        ],
      ),
    );
  }
}

class _PasskeyStep extends ConsumerWidget {
  const _PasskeyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cihaz─▒nda kay─▒tl─▒ passkey ile oturum a├ğ.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.isLoading ? null : controller.startPasskeyFlow,
            icon: state.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.key),
            label: const Text('Passkey do─şrulamas─▒n─▒ ba┼şlat'),
          ),
          const SizedBox(height: 16),
          if (state.passkey.challengeId != null)
            Text('Challenge ID: ${state.passkey.challengeId}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isLoading || state.passkey.challengeId == null
                ? null
                : () => controller.completePasskey(
                      clientDataJson: 'demo-client-data',
                      authenticatorData: 'demo-auth-data',
                      signature: 'demo-signature',
                    ),
            child: const Text('Do─şrulamay─▒ tamamla'),
          ),
          if (state.passkey.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.passkey.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedStep extends ConsumerWidget {
  const _LockedStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    final lock = state.lockInfo;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 72),
            const SizedBox(height: 16),
            Text(
              'Hesab─▒n kilitlendi. ${lock?.reason ?? '├çok say─▒da ba┼şar─▒s─▒z deneme tespit edildi.'}',
              textAlign: TextAlign.center,
            ),
            if (lock != null) ...[
              const SizedBox(height: 8),
              Text(
                () {
                  final countdown = _formatLockCountdown(lock.until);
                  if (countdown == '┼şimdi') {
                    return '┼Şu anda tekrar deneyebilirsin.';
                  }
                  return 'Tekrar deneyebilmen i├ğin yakla┼ş─▒k $countdown beklemelisin.';
                }(),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.reset,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessStep extends ConsumerWidget {
  const _SuccessStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 72),
          const SizedBox(height: 16),
          Text(
            state.requiresDeviceVerification
                ? 'Giri┼ş ba┼şar─▒s─▒z de─şil ama g├╝venlik kontrol├╝ gerekiyor.'
                : 'Giri┼ş ba┼şar─▒l─▒!',
          ),
          if (state.requiresDeviceVerification) ...[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Yeni cihaz─▒ do─şrulamak i├ğin e-postana g├Ânderilen g├╝venlik onay─▒n─▒ tamamlamal─▒s─▒n. Do─şrulama tamamlanana kadar ana sayfaya y├Ânlendirme yap─▒lmayacak.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: controller.reset,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _MfaSelectionStep extends ConsumerWidget {
  const _MfaSelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kullanmak istedi─şin do─şrulama y├Ântemini se├ğ.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.availableMfaChannels.map((channel) {
              return FilledButton.tonal(
                onPressed: state.isLoading ? null : () => controller.chooseMfaChannel(channel),
                child: Text(channel.name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
