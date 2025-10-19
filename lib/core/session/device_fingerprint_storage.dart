import 'package:shared_preferences/shared_preferences.dart';

class DeviceFingerprintRecord {
  const DeviceFingerprintRecord({
    required this.deviceIdHash,
    required this.isTrusted,
    required this.updatedAt,
  });

  final String deviceIdHash;
  final bool isTrusted;
  final DateTime updatedAt;
}

abstract class DeviceFingerprintStorage {
  Future<DeviceFingerprintRecord?> load();
  Future<void> save({
    required String deviceIdHash,
    required bool isTrusted,
    required DateTime updatedAt,
  });
  Future<void> clear();
}

class SharedPreferencesDeviceFingerprintStorage
    implements DeviceFingerprintStorage {
  SharedPreferencesDeviceFingerprintStorage(this._preferences);

  static const _idKey = 'device_fingerprint_id';
  static const _trustedKey = 'device_fingerprint_trusted';
  static const _updatedAtKey = 'device_fingerprint_updated_at';

  final SharedPreferences _preferences;

  @override
  Future<DeviceFingerprintRecord?> load() async {
    final id = _preferences.getString(_idKey);
    if (id == null || id.isEmpty) {
      return null;
    }
    final trusted = _preferences.getBool(_trustedKey) ?? false;
    final updatedMillis = _preferences.getInt(_updatedAtKey);
    final updatedAt = updatedMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(updatedMillis)
        : DateTime.fromMillisecondsSinceEpoch(0);
    return DeviceFingerprintRecord(
      deviceIdHash: id,
      isTrusted: trusted,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> save({
    required String deviceIdHash,
    required bool isTrusted,
    required DateTime updatedAt,
  }) async {
    await _preferences.setString(_idKey, deviceIdHash);
    await _preferences.setBool(_trustedKey, isTrusted);
    await _preferences.setInt(_updatedAtKey, updatedAt.millisecondsSinceEpoch);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_idKey);
    await _preferences.remove(_trustedKey);
    await _preferences.remove(_updatedAtKey);
  }
}
