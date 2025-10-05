import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized platform detection and capability checking
///
/// Provides a single source of truth for platform-specific features
/// and capabilities across the application.
class PlatformInfo {
  PlatformInfo._();

  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Check if running on mobile platform (Android or iOS)
  static bool get isMobile => isAndroid || isIOS;

  /// Check if running on desktop platform (Windows, macOS, or Linux)
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Check if running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Check if running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  // ============================================================================
  // FEATURE CAPABILITY CHECKS
  // ============================================================================

  /// Firebase Crashlytics support
  /// Only available on Android and iOS
  static bool get supportsCrashlytics => isAndroid || isIOS;

  /// Local notifications support
  /// Available on Android, iOS, and macOS
  static bool get supportsLocalNotifications => isAndroid || isIOS || isMacOS;

  /// Background execution support
  /// Available on mobile platforms
  static bool get supportsBackgroundExecution => isMobile;

  /// Location services support
  /// Available on mobile platforms
  static bool get supportsLocation => isMobile;

  /// Camera support
  /// Available on mobile platforms (desktop cameras need different handling)
  static bool get supportsCamera => isMobile;

  /// Biometric authentication support
  /// Available on mobile platforms
  static bool get supportsBiometrics => isMobile;

  /// Push notifications support (FCM)
  /// Available on Android, iOS, and Web
  static bool get supportsPushNotifications => isAndroid || isIOS || isWeb;

  // ============================================================================
  // PLATFORM INFO
  // ============================================================================

  /// Get current platform name for debugging
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get detailed platform description
  static String get platformDescription {
    final capabilities = <String>[];
    if (supportsCrashlytics) capabilities.add('Crashlytics');
    if (supportsLocalNotifications) capabilities.add('LocalNotifications');
    if (supportsPushNotifications) capabilities.add('PushNotifications');
    if (supportsLocation) capabilities.add('Location');
    if (supportsCamera) capabilities.add('Camera');
    if (supportsBiometrics) capabilities.add('Biometrics');

    return '$platformName [${capabilities.join(', ')}]';
  }
}
