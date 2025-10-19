import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CringeBank'**
  String get appTitle;

  /// No description provided for @splashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cringe Bank'**
  String get splashTitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your most cringe moments gain value'**
  String get splashSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordDialogTitle;

  /// No description provided for @forgotPasswordDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a reset link.'**
  String get forgotPasswordDialogMessage;

  /// No description provided for @forgotPasswordDialogEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get forgotPasswordDialogEmailLabel;

  /// No description provided for @forgotPasswordDialogEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get forgotPasswordDialogEmailRequired;

  /// No description provided for @forgotPasswordDialogEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get forgotPasswordDialogEmailInvalid;

  /// No description provided for @forgotPasswordDialogError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the reset request. Please try again.'**
  String get forgotPasswordDialogError;

  /// No description provided for @forgotPasswordDialogSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get forgotPasswordDialogSubmit;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @forgotPasswordSnackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email.'**
  String get forgotPasswordSnackSuccess;

  /// No description provided for @signInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInCta;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleSignIn;

  /// No description provided for @googleSignInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is coming soon.'**
  String get googleSignInComingSoon;

  /// No description provided for @appleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get appleSignIn;

  /// No description provided for @appleSignInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in is coming soon.'**
  String get appleSignInComingSoon;

  /// No description provided for @signUpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get signUpPrompt;

  /// No description provided for @signUpCta.
  ///
  /// In en, this message translates to:
  /// **'Sign up now'**
  String get signUpCta;

  /// No description provided for @loginEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get loginEmptyFields;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get loginInvalidEmail;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password!'**
  String get loginInvalidCredentials;

  /// Shown when an unexpected login error occurs.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String loginGenericError(Object error);

  /// No description provided for @themePreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Preference'**
  String get themePreferenceTitle;

  /// No description provided for @themePreferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically match your device or pick a theme manually.'**
  String get themePreferenceDescription;

  /// No description provided for @themePreferenceSystem.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get themePreferenceSystem;

  /// No description provided for @themePreferenceSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows your device\'s dark and light mode settings.'**
  String get themePreferenceSystemSubtitle;

  /// No description provided for @themePreferenceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themePreferenceLight;

  /// No description provided for @themePreferenceLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bright surfaces with warm accent gradients.'**
  String get themePreferenceLightSubtitle;

  /// No description provided for @themePreferenceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themePreferenceDark;

  /// No description provided for @themePreferenceDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deep surfaces with vibrant neon accents.'**
  String get themePreferenceDarkSubtitle;

  /// No description provided for @localePreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localePreferenceTitle;

  /// No description provided for @localePreferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used throughout the interface.'**
  String get localePreferenceDescription;

  /// No description provided for @localePreferenceOptionTr.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get localePreferenceOptionTr;

  /// No description provided for @localePreferenceOptionEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localePreferenceOptionEn;

  /// Snackbar shown after changing the locale.
  ///
  /// In en, this message translates to:
  /// **'Language switched to {language}'**
  String localeChangeSnack(Object language);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
