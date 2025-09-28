import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  ConnectivityService._internal() {
    _initialize();
  }

  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<ConnectivityStatus> statusNotifier =
      ValueNotifier<ConnectivityStatus>(ConnectivityStatus.online);
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  ConnectivityStatus get currentStatus => statusNotifier.value;

  Future<void> _initialize() async {
    try {
      final initialResults = await _connectivity.checkConnectivity();
      _handleConnectivityResults(initialResults);
    } catch (error) {
      debugPrint('⚠️ Connectivity check failed: $error');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityResults,
      onError: (error) => debugPrint('⚠️ Connectivity stream error: $error'),
    );
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    final nextStatus =
        hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;

    if (statusNotifier.value != nextStatus) {
      statusNotifier.value = nextStatus;
    }

    _statusController.add(nextStatus);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _statusController.close();
    statusNotifier.dispose();
  }
}
