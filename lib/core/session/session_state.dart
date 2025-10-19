import 'package:equatable/equatable.dart';

class SessionState extends Equatable {
  const SessionState({
    required this.isAuthenticated,
    required this.isHydrated,
    this.identifier,
    this.displayName,
    this.expiresAt,
    required this.requiresDeviceVerification,
  });

  final bool isAuthenticated;
  final bool isHydrated;
  final String? identifier;
  final String? displayName;
  final DateTime? expiresAt;
  final bool requiresDeviceVerification;

  factory SessionState.initial() {
    return const SessionState(
      isAuthenticated: false,
      isHydrated: false,
      requiresDeviceVerification: false,
    );
  }

  SessionState copyWith({
    bool? isAuthenticated,
    bool? isHydrated,
    String? identifier,
    String? displayName,
    Object? expiresAt = _copySentinel,
    bool? requiresDeviceVerification,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isHydrated: isHydrated ?? this.isHydrated,
      identifier: identifier ?? this.identifier,
      displayName: displayName ?? this.displayName,
      expiresAt: identical(expiresAt, _copySentinel)
          ? this.expiresAt
          : expiresAt as DateTime?,
      requiresDeviceVerification:
          requiresDeviceVerification ?? this.requiresDeviceVerification,
    );
  }

  static const _copySentinel = Object();

  @override
  List<Object?> get props => [
        isAuthenticated,
        isHydrated,
        identifier,
        displayName,
        expiresAt,
        requiresDeviceVerification,
      ];
}
