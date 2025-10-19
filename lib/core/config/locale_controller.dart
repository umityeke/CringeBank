import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';

const _localeStorageKey = 'user_locale';

class LocaleController extends StateNotifier<Locale> {
  LocaleController({required SharedPreferences preferences})
    : _preferences = preferences,
      super(_restoreLocale(preferences));

  final SharedPreferences _preferences;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _preferences.setString(_localeStorageKey, _encodeLocale(locale));
  }

  static Locale _restoreLocale(SharedPreferences preferences) {
    final stored = preferences.getString(_localeStorageKey);
    if (stored == null || stored.isEmpty) {
      return const Locale('tr', 'TR');
    }

    final parts = stored.split('_');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }

  static String _encodeLocale(Locale locale) {
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
      final prefs = sl<SharedPreferences>();
      return LocaleController(preferences: prefs);
    });
