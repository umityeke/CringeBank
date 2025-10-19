// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'CringeBank';

  @override
  String get splashTitle => 'Cringe Bankası';

  @override
  String get splashSubtitle => 'En utanç verici anlarınızın değeri burada';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get emailHint => 'E-posta adresini gir';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get passwordHint => 'Şifreni gir';

  @override
  String get rememberMe => 'Beni hatırla';

  @override
  String get forgotPassword => 'Şifremi unuttum';

  @override
  String get forgotPasswordDialogTitle => 'Şifremi Unuttum';

  @override
  String get forgotPasswordDialogMessage =>
      'E-posta adresini yaz, sıfırlama bağlantısını gönderelim.';

  @override
  String get forgotPasswordDialogEmailLabel => 'E-posta adresi';

  @override
  String get forgotPasswordDialogEmailRequired =>
      'Lütfen e-posta adresini gir.';

  @override
  String get forgotPasswordDialogEmailInvalid =>
      'Lütfen geçerli bir e-posta adresi gir.';

  @override
  String get forgotPasswordDialogError =>
      'Şifre sıfırlama isteği gönderilemedi. Lütfen tekrar dene.';

  @override
  String get forgotPasswordDialogSubmit => 'Gönder';

  @override
  String get commonCancel => 'İptal';

  @override
  String get forgotPasswordSnackSuccess =>
      'Şifre sıfırlama bağlantısı e-postana gönderildi.';

  @override
  String get signInCta => 'Giriş Yap';

  @override
  String get orDivider => 'ya da';

  @override
  String get googleSignIn => 'Google ile giriş yap';

  @override
  String get googleSignInComingSoon => 'Google ile giriş yakında eklenecek.';

  @override
  String get appleSignIn => 'Apple ile giriş yap';

  @override
  String get appleSignInComingSoon => 'Apple ile giriş yakında eklenecek.';

  @override
  String get signUpPrompt => 'Hesabın yok mu?';

  @override
  String get signUpCta => 'Hemen kayıt ol';

  @override
  String get loginEmptyFields => 'Lütfen tüm alanları doldurun';

  @override
  String get loginInvalidEmail => 'Lütfen geçerli bir e-posta adresi girin';

  @override
  String get loginInvalidCredentials => 'Kullanıcı adı veya şifre hatalı!';

  @override
  String loginGenericError(Object error) {
    return 'Bir hata oluştu: $error';
  }

  @override
  String get themePreferenceTitle => 'Tema Tercihi';

  @override
  String get themePreferenceDescription =>
      'Uygulama temasını cihaz ayarına bırakabilir veya manuel seçebilirsin.';

  @override
  String get themePreferenceSystem => 'Otomatik';

  @override
  String get themePreferenceSystemSubtitle =>
      'Cihazının gece/gündüz moduna uyum sağlar.';

  @override
  String get themePreferenceLight => 'Gündüz';

  @override
  String get themePreferenceLightSubtitle =>
      'Aydınlık yüzeyler ve sıcak vurgu gradyanları.';

  @override
  String get themePreferenceDark => 'Gece';

  @override
  String get themePreferenceDarkSubtitle =>
      'Koyu yüzeyler ve canlı neon vurguları.';

  @override
  String get localePreferenceTitle => 'Dil';

  @override
  String get localePreferenceDescription => 'Arayüzde kullanılacak dili seç.';

  @override
  String get localePreferenceOptionTr => 'Türkçe';

  @override
  String get localePreferenceOptionEn => 'İngilizce';

  @override
  String localeChangeSnack(Object language) {
    return '$language diline geçildi';
  }
}
