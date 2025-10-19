import 'package:equatable/equatable.dart';

class DeviceFingerprintState extends Equatable {
  const DeviceFingerprintState({
    required this.isReady,
    required this.deviceIdHash,
    required this.isTrusted,
    this.lastUpdated,
  });

  final bool isReady;
  final String deviceIdHash;
  final bool isTrusted;
  final DateTime? lastUpdated;

  factory DeviceFingerprintState.initial() {
    return const DeviceFingerprintState(
      isReady: false,
      deviceIdHash: '',
      isTrusted: false,
      lastUpdated: null,
    );
  }

  DeviceFingerprintState copyWith({
    bool? isReady,
    String? deviceIdHash,
    bool? isTrusted,
    Object? lastUpdated = _copySentinel,
  }) {
    return DeviceFingerprintState(
      isReady: isReady ?? this.isReady,
      deviceIdHash: deviceIdHash ?? this.deviceIdHash,
      isTrusted: isTrusted ?? this.isTrusted,
      lastUpdated: identical(lastUpdated, _copySentinel)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
    );
  }

  static const _copySentinel = Object();

  @override
  List<Object?> get props => [isReady, deviceIdHash, isTrusted, lastUpdated];
}
