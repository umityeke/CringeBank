class StoreFeatureFlags {
  const StoreFeatureFlags._();

  /// When true the client will call the SQL gateway callable endpoints instead
  /// of the legacy Firestore-backed Cloud Functions for escrow operations and
  /// user synchronization. Defaults to `true`; set
  /// `--dart-define USE_SQL_ESCROW_GATEWAY=false` to force the legacy path.
  static const bool useSqlEscrowGateway = bool.fromEnvironment(
    'USE_SQL_ESCROW_GATEWAY',
    defaultValue: true,
  );
}
