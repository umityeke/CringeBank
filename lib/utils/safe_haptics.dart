import 'package:flutter/services.dart';
import 'platform_utils.dart';

/// Safe haptic feedback wrapper that no-ops on Windows (and swallows errors).
class SafeHaptics {
  static void selection() {
    if (isWindowsDesktop) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void light() {
    if (isWindowsDesktop) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void medium() {
    if (isWindowsDesktop) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
