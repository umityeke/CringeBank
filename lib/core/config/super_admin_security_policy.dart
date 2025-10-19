import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Super admin girişleri için güvenlik politikalarını temsil eder.
class SuperAdminSecurityPolicy {
  SuperAdminSecurityPolicy({
    Set<String>? allowedIpHashes,
    Set<String>? allowedTimeZones,
    Set<String>? allowedLocales,
    this.requireTrustedDevice = false,
    Duration? sessionTtl,
    this.forceRememberMeDisabled = true,
  })  : allowedIpHashes = Set<String>.unmodifiable(allowedIpHashes ?? const <String>{}),
        allowedTimeZones = Set<String>.unmodifiable(allowedTimeZones ?? const <String>{}),
        allowedLocales = Set<String>.unmodifiable(
          (allowedLocales ?? const <String>{}).map((locale) => locale.toLowerCase()),
        ),
        sessionTtl = (sessionTtl != null && sessionTtl > Duration.zero)
            ? sessionTtl
            : const Duration(minutes: 10);

  final Set<String> allowedIpHashes;
  final Set<String> allowedTimeZones;
  final Set<String> allowedLocales;
  final bool requireTrustedDevice;
  final Duration sessionTtl;
  final bool forceRememberMeDisabled;

  bool get hasIpRestrictions => allowedIpHashes.isNotEmpty;
  bool get hasTimeZoneRestrictions => allowedTimeZones.isNotEmpty;
  bool get hasLocaleRestrictions => allowedLocales.isNotEmpty;

  bool isIpAllowed(String ipHash) {
    if (!hasIpRestrictions) {
      return true;
    }
    return allowedIpHashes.contains(ipHash);
  }

  bool isTimeZoneAllowed(String timeZone) {
    if (!hasTimeZoneRestrictions) {
      return true;
    }
    return allowedTimeZones.contains(timeZone);
  }

  bool isLocaleAllowed(String locale) {
    if (!hasLocaleRestrictions) {
      return true;
    }
    return allowedLocales.contains(locale.toLowerCase());
  }

  SuperAdminSecurityPolicy copyWith({
    Set<String>? allowedIpHashes,
    Set<String>? allowedTimeZones,
    Set<String>? allowedLocales,
    bool? requireTrustedDevice,
    Duration? sessionTtl,
    bool? forceRememberMeDisabled,
  }) {
    return SuperAdminSecurityPolicy(
      allowedIpHashes: allowedIpHashes ?? this.allowedIpHashes,
      allowedTimeZones: allowedTimeZones ?? this.allowedTimeZones,
      allowedLocales: allowedLocales ?? this.allowedLocales,
      requireTrustedDevice: requireTrustedDevice ?? this.requireTrustedDevice,
      sessionTtl: sessionTtl ?? this.sessionTtl,
      forceRememberMeDisabled: forceRememberMeDisabled ?? this.forceRememberMeDisabled,
    );
  }
}

final superAdminSecurityPolicyProvider = Provider<SuperAdminSecurityPolicy>((ref) {
  return SuperAdminSecurityPolicy();
});
