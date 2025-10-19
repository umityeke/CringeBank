import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama genelindeki deneysel özellikleri kontrol eden bayrak seti.
class FeatureFlags {
  const FeatureFlags({
    this.loginWithPhone = true,
    this.magicLinkLogin = true,
    this.webauthnPasskey = true,
    this.requireMfaForAdmins = true,
    this.enforceCaptchaAfterThreeFails = true,
  });

  final bool loginWithPhone;
  final bool magicLinkLogin;
  final bool webauthnPasskey;
  final bool requireMfaForAdmins;
  final bool enforceCaptchaAfterThreeFails;

  FeatureFlags copyWith({
    bool? loginWithPhone,
    bool? magicLinkLogin,
    bool? webauthnPasskey,
    bool? requireMfaForAdmins,
    bool? enforceCaptchaAfterThreeFails,
  }) {
    return FeatureFlags(
      loginWithPhone: loginWithPhone ?? this.loginWithPhone,
      magicLinkLogin: magicLinkLogin ?? this.magicLinkLogin,
      webauthnPasskey: webauthnPasskey ?? this.webauthnPasskey,
      requireMfaForAdmins: requireMfaForAdmins ?? this.requireMfaForAdmins,
      enforceCaptchaAfterThreeFails:
          enforceCaptchaAfterThreeFails ?? this.enforceCaptchaAfterThreeFails,
    );
  }
}

/// Varsayılan özellik bayrakları sağlayıcısı. Testlerde veya farklı ortamda
/// ihtiyaç halinde override edilebilir.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return const FeatureFlags();
});
