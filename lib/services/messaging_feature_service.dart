import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/messaging_feature_flags.dart';

@immutable
class MessagingFeatureConfig {
  const MessagingFeatureConfig({
    required this.doubleWriteEnabled,
    required this.sqlReadEnabled,
    required this.latencyThresholdMs,
    this.lastUpdated,
  });

  final bool doubleWriteEnabled;
  final bool sqlReadEnabled;
  final int latencyThresholdMs;
  final DateTime? lastUpdated;

  MessagingFeatureConfig copyWith({
    bool? doubleWriteEnabled,
    bool? sqlReadEnabled,
    int? latencyThresholdMs,
    DateTime? lastUpdated,
  }) {
    return MessagingFeatureConfig(
      doubleWriteEnabled: doubleWriteEnabled ?? this.doubleWriteEnabled,
      sqlReadEnabled: sqlReadEnabled ?? this.sqlReadEnabled,
      latencyThresholdMs: latencyThresholdMs ?? this.latencyThresholdMs,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessagingFeatureConfig &&
        other.doubleWriteEnabled == doubleWriteEnabled &&
        other.sqlReadEnabled == sqlReadEnabled &&
        other.latencyThresholdMs == latencyThresholdMs &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(
    doubleWriteEnabled,
    sqlReadEnabled,
    latencyThresholdMs,
    lastUpdated,
  );

  static MessagingFeatureConfig defaults() => MessagingFeatureConfig(
    doubleWriteEnabled: MessagingFeatureFlags.defaultSqlMirrorDoubleWrite,
    sqlReadEnabled: MessagingFeatureFlags.defaultSqlMirrorRead,
    latencyThresholdMs:
        MessagingFeatureFlags.defaultSqlMirrorLatencyThresholdMs,
    lastUpdated: null,
  );

  factory MessagingFeatureConfig.fromSnapshot(
    Map<String, dynamic> data, {
    DateTime? lastUpdated,
  }) {
    bool readBool(dynamic value, bool fallback) {
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final lowered = value.toLowerCase().trim();
        if (lowered == 'true' || lowered == '1') {
          return true;
        }
        if (lowered == 'false' || lowered == '0') {
          return false;
        }
      }
      return fallback;
    }

    int readInt(dynamic value, int fallback) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return fallback;
    }

    final latencyThreshold =
        (readInt(
                  data['latencyThresholdMs'],
                  MessagingFeatureFlags.defaultSqlMirrorLatencyThresholdMs,
                ).clamp(50, 5000)
                as num)
            .toInt();

    return MessagingFeatureConfig(
      doubleWriteEnabled: readBool(
        data['doubleWriteEnabled'],
        MessagingFeatureFlags.defaultSqlMirrorDoubleWrite,
      ),
      sqlReadEnabled: readBool(
        data['sqlReadEnabled'],
        MessagingFeatureFlags.defaultSqlMirrorRead,
      ),
      latencyThresholdMs: latencyThreshold,
      lastUpdated: lastUpdated,
    );
  }
}

class MessagingFeatureService {
  MessagingFeatureService._();

  static final MessagingFeatureService instance = MessagingFeatureService._();

  @visibleForTesting
  static const String configCollection = 'config_messaging';
  @visibleForTesting
  static const String configDocument = 'sql_mirror';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MessagingFeatureConfig _config = MessagingFeatureConfig.defaults();
  ValueNotifier<MessagingFeatureConfig>? _notifier;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  bool _initialized = false;

  MessagingFeatureConfig get config => _config;
  ValueListenable<MessagingFeatureConfig> get configListenable {
    _notifier ??= ValueNotifier<MessagingFeatureConfig>(_config);
    return _notifier!;
  }

  bool get isSqlMirrorDoubleWriteEnabled => _config.doubleWriteEnabled;
  bool get isSqlMirrorReadEnabled => _config.sqlReadEnabled;
  int get sqlMirrorLatencyThresholdMs => _config.latencyThresholdMs;

  Future<void> initialize({bool listenForUpdates = true}) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_isPlatformSupported) {
      debugPrint(
        'MessagingFeatureService masaüstünde devre dışı bırakıldı; varsayılan '
        'ayarlar kullanılacak.',
      );
      return;
    }

    await _refreshConfig(const GetOptions(source: Source.serverAndCache));

    if (!listenForUpdates) {
      return;
    }

    _subscription = _firestore
        .collection(configCollection)
        .doc(configDocument)
        .snapshots()
        .listen(
          (snapshot) {
            _applySnapshot(snapshot);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isPermissionDenied(error)) {
              debugPrint(
                'MessagingFeatureService yetkisiz erişim nedeniyle dinlemeyi '
                'durdurdu. Varsayılan ayarlar kullanılmaya devam edecek.',
              );
              _subscription?.cancel();
              _subscription = null;
              return;
            }

            debugPrint('MessagingFeatureService snapshot error: $error\n$stackTrace');
          },
        );
  }

  Future<void> _refreshConfig(GetOptions options) async {
    try {
      final docSnapshot = await _firestore
          .collection(configCollection)
          .doc(configDocument)
          .get(options);

      _applySnapshot(docSnapshot);
    } catch (e, stack) {
      if (_isPermissionDenied(e)) {
        debugPrint(
          'MessagingFeatureService Firestore yetkisi yok; varsayılan yapılandırma '
          'kullanılıyor.',
        );
        return;
      }

      debugPrint('Failed to refresh messaging feature config: $e\n$stack');
    }
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      return;
    }

    final nextConfig = MessagingFeatureConfig.fromSnapshot(
      data,
      lastUpdated: DateTime.now(),
    );

    _config = nextConfig;
    _notifier?.value = nextConfig;
  }

  @visibleForTesting
  void applyOverride(MessagingFeatureConfig override) {
    _config = override;
    _notifier?.value = override;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _notifier?.dispose();
    _notifier = null;
  }

  bool get _isPlatformSupported {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    return false;
  }
}
