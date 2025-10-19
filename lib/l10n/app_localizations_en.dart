// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CringeBank';

  @override
  String get splashTitle => 'Cringe Bank';

  @override
  String get splashSubtitle => 'Where your most cringe moments gain value';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Enter your email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get forgotPasswordDialogTitle => 'Forgot Password';

  @override
  String get forgotPasswordDialogMessage =>
      'Enter your email address and we\'ll send you a reset link.';

  @override
  String get forgotPasswordDialogEmailLabel => 'Email address';

  @override
  String get forgotPasswordDialogEmailRequired =>
      'Please enter your email address.';

  @override
  String get forgotPasswordDialogEmailInvalid =>
      'Please enter a valid email address.';

  @override
  String get forgotPasswordDialogError =>
      'We couldn\'t send the reset request. Please try again.';

  @override
  String get forgotPasswordDialogSubmit => 'Send';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get forgotPasswordSnackSuccess =>
      'Password reset link sent to your email.';

  @override
  String get signInCta => 'Sign In';

  @override
  String get orDivider => 'or';

  @override
  String get googleSignIn => 'Continue with Google';

  @override
  String get googleSignInComingSoon => 'Google sign-in is coming soon.';

  @override
  String get appleSignIn => 'Continue with Apple';

  @override
  String get appleSignInComingSoon => 'Apple sign-in is coming soon.';

  @override
  String get signUpPrompt => 'Don\'t have an account?';

  @override
  String get signUpCta => 'Sign up now';

  @override
  String get loginEmptyFields => 'Please fill in all fields';

  @override
  String get loginInvalidEmail => 'Please enter a valid email address';

  @override
  String get loginInvalidCredentials => 'Invalid username or password!';

  @override
  String loginGenericError(Object error) {
    return 'Something went wrong: $error';
  }

  @override
  String get themePreferenceTitle => 'Theme Preference';

  @override
  String get themePreferenceDescription =>
      'Automatically match your device or pick a theme manually.';

  @override
  String get themePreferenceSystem => 'Automatic';

  @override
  String get themePreferenceSystemSubtitle =>
      'Follows your device\'s dark and light mode settings.';

  @override
  String get themePreferenceLight => 'Light';

  @override
  String get themePreferenceLightSubtitle =>
      'Bright surfaces with warm accent gradients.';

  @override
  String get themePreferenceDark => 'Dark';

  @override
  String get themePreferenceDarkSubtitle =>
      'Deep surfaces with vibrant neon accents.';

  @override
  String get localePreferenceTitle => 'Language';

  @override
  String get localePreferenceDescription =>
      'Choose the language used throughout the interface.';

  @override
  String get localePreferenceOptionTr => 'Turkish';

  @override
  String get localePreferenceOptionEn => 'English';

  @override
  String localeChangeSnack(Object language) {
    return 'Language switched to $language';
  }
}
