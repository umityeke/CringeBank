import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';

const _themeModeStorageKey = 'user_theme_mode';

/// Uygulama genelinde tema tercihini yöneten denetleyici.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController({required SharedPreferences preferences})
      : _preferences = preferences,
        super(_restoreThemeMode(preferences));

  final SharedPreferences _preferences;

  /// Manuel olarak tema modunu günceller ve tercihi kalıcı olarak saklar.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _preferences.setString(_themeModeStorageKey, mode.name);
  }

  /// Tema modunu sistem varsayılanına sıfırlar.
  Future<void> resetToSystem() => setThemeMode(ThemeMode.system);
}

ThemeMode _restoreThemeMode(SharedPreferences preferences) {
  final stored = preferences.getString(_themeModeStorageKey);
  switch (stored) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.system;
  }
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  final prefs = sl<SharedPreferences>();
  return ThemeModeController(preferences: prefs);
});
