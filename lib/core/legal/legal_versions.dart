/// Canonical version identifiers for mandatory legal agreements.
/// These constants allow the app to detect when a user must re-accept
/// updated documents after registration.
class LegalVersions {
  const LegalVersions._();

  /// Latest Terms of Service version that a user must acknowledge.
  static const int termsOfService = 1;

  /// Latest Privacy Policy version required for activated accounts.
  static const int privacyPolicy = 1;
}

/// Minimum custom claims version the client expects the backend to enforce.
class ClaimsVersioning {
  const ClaimsVersioning._();

  /// The initial claims version issued for fresh registrations.
  static const int minimum = 1;
}
