import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_fingerprint_state.dart';
import 'device_fingerprint_storage.dart';

class DeviceFingerprintController
    extends StateNotifier<DeviceFingerprintState> {
  DeviceFingerprintController({
    DeviceFingerprintStorage? storage,
    DateTime Function()? now,
    String Function()? idFactory,
  })  : _storage = storage,
        _now = now ?? DateTime.now,
        _idFactory = idFactory ?? _generateId,
        super(DeviceFingerprintState.initial());

  final DeviceFingerprintStorage? _storage;
  final DateTime Function() _now;
  final String Function() _idFactory;

  static String _generateId() {
    Random generator;
    try {
      generator = Random.secure();
    } on UnsupportedError {
      generator = Random();
    }
    final bytes = List<int>.generate(32, (_) => generator.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  Future<void> hydrate() async {
    if (state.isReady) {
      return;
    }
    final storage = _storage;
    if (storage != null) {
      final persisted = await storage.load();
      if (persisted != null) {
        state = state.copyWith(
          isReady: true,
          deviceIdHash: persisted.deviceIdHash,
          isTrusted: persisted.isTrusted,
          lastUpdated: persisted.updatedAt,
        );
        return;
      }
    }
    final id = state.deviceIdHash.isNotEmpty ? state.deviceIdHash : _idFactory();
    final now = _now();
    state = state.copyWith(
      isReady: true,
      deviceIdHash: id,
      lastUpdated: now,
    );
    await _storage?.save(
      deviceIdHash: id,
      isTrusted: state.isTrusted,
      updatedAt: now,
    );
  }

  Future<void> markTrusted(bool trusted) async {
    if (!state.isReady) {
      await hydrate();
    }
    final id = state.deviceIdHash.isNotEmpty ? state.deviceIdHash : _idFactory();
    final now = _now();
    state = state.copyWith(
      isReady: true,
      deviceIdHash: id,
      isTrusted: trusted,
      lastUpdated: now,
    );
    await _storage?.save(
      deviceIdHash: id,
      isTrusted: trusted,
      updatedAt: now,
    );
  }

  Future<void> rotateFingerprint() async {
    final id = _idFactory();
    final now = _now();
    state = state.copyWith(
      isReady: true,
      deviceIdHash: id,
      isTrusted: false,
      lastUpdated: now,
    );
    await _storage?.save(
      deviceIdHash: id,
      isTrusted: false,
      updatedAt: now,
    );
  }

  Future<void> reset() async {
    await _storage?.clear();
    state = DeviceFingerprintState.initial();
  }
}
