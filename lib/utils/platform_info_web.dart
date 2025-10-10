import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;

/// Web-friendly implementation of [PlatformInfo] that avoids importing dart:io.
class PlatformInfo {
  PlatformInfo._();

  static bool get isWeb => true;

  static bool get isAndroid => false;

  static bool get isIOS => false;

  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static bool get supportsCrashlytics => false;

  static bool get supportsLocalNotifications => false;

  static bool get supportsBackgroundExecution => false;

  static bool get supportsLocation => false;

  static bool get supportsCamera => false;

  static bool get supportsBiometrics => false;

  static bool get supportsPushNotifications => kIsWeb;

  static String get platformName => 'Web';

  static String get platformDescription => 'Web []';
}
