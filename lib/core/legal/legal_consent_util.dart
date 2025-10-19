/// Builds the Firestore update payload required to stamp a newly registered
/// user with mandatory claims and policy version information.
///
/// The function inspects an optional [existingData] map (typically the current
/// Firestore snapshot) and only returns the fields that need to change.
Map<String, dynamic> buildInitialLegalUpdate({
  Map<String, dynamic>? existingData,
  required int claimsVersion,
  required int termsVersion,
  required int privacyVersion,
}) {
  final updates = <String, dynamic>{};
  final data = existingData ?? const <String, dynamic>{};

  final currentClaimsVersion = _parseInt(
    data['claimsVersion'] ?? data['claims_version'],
  );

  if (currentClaimsVersion == null || currentClaimsVersion < claimsVersion) {
    updates['claimsVersion'] = claimsVersion;
    updates['claims_version'] = claimsVersion;
  }

  final existingPolicyVersions = _normalizePolicyVersions(data['policyVersions']);
  final mergedPolicyVersions = Map<String, int>.from(existingPolicyVersions);
  var policyUpdated = false;

  void ensurePolicy(String key, int version) {
    final current = existingPolicyVersions[key];
    if (current == null || current < version) {
      mergedPolicyVersions[key] = version;
      policyUpdated = true;
    }
  }

  ensurePolicy('termsOfService', termsVersion);
  ensurePolicy('privacyPolicy', privacyVersion);

  if (policyUpdated) {
    updates['policyVersions'] = mergedPolicyVersions;
  }

  return updates;
}

int? _parseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final stringValue = value.toString();
  if (stringValue.isEmpty) {
    return null;
  }
  return int.tryParse(stringValue);
}

Map<String, int> _normalizePolicyVersions(dynamic raw) {
  if (raw is Map) {
    return raw.map((key, value) {
      if (key is! String) {
        return MapEntry(key.toString(), _parseInt(value) ?? 0);
      }
      return MapEntry(key, _parseInt(value) ?? 0);
    });
  }
  if (raw is Iterable) {
    final pairs = raw
        .whereType<MapEntry>()
        .map((entry) => MapEntry(entry.key.toString(), _parseInt(entry.value) ?? 0))
        .toList(growable: false);
    if (pairs.isEmpty) {
      return const <String, int>{};
    }
    return Map<String, int>.fromEntries(pairs);
  }
  return const <String, int>{};
}
