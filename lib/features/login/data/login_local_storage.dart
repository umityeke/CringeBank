import 'package:shared_preferences/shared_preferences.dart';

class LoginPersistedData {
  const LoginPersistedData({
    required this.identifier,
    required this.rememberMe,
    required this.timestamp,
  });

  final String identifier;
  final bool rememberMe;
  final DateTime timestamp;
}

abstract class LoginLocalStorage {
  Future<LoginPersistedData?> load();
  Future<void> save({
    required String identifier,
    required bool rememberMe,
    required DateTime timestamp,
  });
  Future<void> clear();
}

class SharedPreferencesLoginLocalStorage implements LoginLocalStorage {
  SharedPreferencesLoginLocalStorage(this._preferences);

  static const _identifierKey = 'login_last_identifier';
  static const _rememberKey = 'login_remember_me';
  static const _timestampKey = 'login_last_identifier_at';

  final SharedPreferences _preferences;

  @override
  Future<LoginPersistedData?> load() async {
    final remember = _preferences.getBool(_rememberKey) ?? false;
    if (!remember) {
      return null;
    }
    final identifier = _preferences.getString(_identifierKey);
    if (identifier == null || identifier.isEmpty) {
      await clear();
      return null;
    }
    final timestampMillis = _preferences.getInt(_timestampKey);
    if (timestampMillis == null) {
      await clear();
      return null;
    }
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    return LoginPersistedData(
      identifier: identifier,
      rememberMe: remember,
      timestamp: timestamp,
    );
  }

  @override
  Future<void> save({
    required String identifier,
    required bool rememberMe,
    required DateTime timestamp,
  }) async {
    await _preferences.setBool(_rememberKey, rememberMe);
    if (rememberMe) {
      await _preferences.setString(_identifierKey, identifier);
      await _preferences.setInt(_timestampKey, timestamp.millisecondsSinceEpoch);
    } else {
      await _preferences.remove(_identifierKey);
      await _preferences.remove(_timestampKey);
    }
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_identifierKey);
    await _preferences.remove(_rememberKey);
    await _preferences.remove(_timestampKey);
  }
}
