class SessionBootstrapData {
  const SessionBootstrapData({
    required this.identifier,
    required this.issuedAt,
    required this.expiresAt,
    this.rememberMe = false,
    this.requiresDeviceVerification = false,
    this.metadata = const <String, Object?>{},
  });

  final String identifier;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool rememberMe;
  final bool requiresDeviceVerification;
  final Map<String, Object?> metadata;

  SessionBootstrapData copyWith({
    String? identifier,
    DateTime? issuedAt,
    DateTime? expiresAt,
    bool? rememberMe,
    bool? requiresDeviceVerification,
    Map<String, Object?>? metadata,
  }) {
    return SessionBootstrapData(
      identifier: identifier ?? this.identifier,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rememberMe: rememberMe ?? this.rememberMe,
      requiresDeviceVerification:
          requiresDeviceVerification ?? this.requiresDeviceVerification,
      metadata: metadata ?? this.metadata,
    );
  }
}
