import 'package:shared_preferences/shared_preferences.dart';

class SessionPersistedData {
  const SessionPersistedData({
    required this.isAuthenticated,
    this.identifier,
    this.displayName,
    required this.expiresAt,
  });

  final bool isAuthenticated;
  final String? identifier;
  final String? displayName;
  final DateTime expiresAt;
}

abstract class SessionLocalStorage {
  Future<SessionPersistedData?> load();
  Future<void> save({
    required bool isAuthenticated,
    String? identifier,
    String? displayName,
    required DateTime expiresAt,
  });
  Future<void> clear();
}

class SharedPreferencesSessionLocalStorage implements SessionLocalStorage {
  SharedPreferencesSessionLocalStorage(this._preferences);

  static const _authKey = 'session_is_authenticated';
  static const _identifierKey = 'session_identifier';
  static const _displayNameKey = 'session_display_name';
  static const _expiresAtKey = 'session_expires_at';

  final SharedPreferences _preferences;

  @override
  Future<SessionPersistedData?> load() async {
    final isAuthenticated = _preferences.getBool(_authKey) ?? false;
    if (!isAuthenticated) {
      return null;
    }
    final identifier = _preferences.getString(_identifierKey);
    final displayName = _preferences.getString(_displayNameKey);
    final expiresMillis = _preferences.getInt(_expiresAtKey);
    if (expiresMillis == null) {
      return null;
    }
    return SessionPersistedData(
      isAuthenticated: isAuthenticated,
      identifier: identifier,
      displayName: displayName,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresMillis),
    );
  }

  @override
  Future<void> save({
    required bool isAuthenticated,
    String? identifier,
    String? displayName,
    required DateTime expiresAt,
  }) async {
    await _preferences.setBool(_authKey, isAuthenticated);
    if (isAuthenticated) {
      if (identifier != null) {
        await _preferences.setString(_identifierKey, identifier);
      } else {
        await _preferences.remove(_identifierKey);
      }
      if (displayName != null) {
        await _preferences.setString(_displayNameKey, displayName);
      } else {
        await _preferences.remove(_displayNameKey);
      }
      await _preferences.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    } else {
      await clear();
    }
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_authKey);
    await _preferences.remove(_identifierKey);
    await _preferences.remove(_displayNameKey);
    await _preferences.remove(_expiresAtKey);
  }
}
