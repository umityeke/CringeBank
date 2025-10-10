class MessagingFeatureFlags {
  const MessagingFeatureFlags._();

  /// Default toggle for enabling client-side SQL mirror double-write.
  static const bool defaultSqlMirrorDoubleWrite = bool.fromEnvironment(
    'USE_SQL_MIRROR_DOUBLE_WRITE',
    defaultValue: false,
  );

  /// Default toggle for enabling SQL-backed reads inside the messaging layer.
  static const bool defaultSqlMirrorRead = bool.fromEnvironment(
    'USE_SQL_MIRROR_SQL_READ',
    defaultValue: false,
  );

  /// Default latency budget (in milliseconds) for SQL mirror operations.
  static const int defaultSqlMirrorLatencyThresholdMs = int.fromEnvironment(
    'SQL_MIRROR_LATENCY_THRESHOLD_MS',
    defaultValue: 200,
  );
}
