import 'package:flutter_test/flutter_test.dart';

import 'package:cringebank/core/legal/legal_consent_util.dart';

void main() {
  group('buildInitialLegalUpdate', () {
    test('populates claims and policy versions when none exist', () {
      final updates = buildInitialLegalUpdate(
        existingData: const {},
        claimsVersion: 1,
        termsVersion: 2,
        privacyVersion: 4,
      );

      expect(updates['claimsVersion'], 1);
      expect(updates['claims_version'], 1);

      final policyVersions = updates['policyVersions'] as Map<String, int>;
      expect(policyVersions, containsPair('termsOfService', 2));
      expect(policyVersions, containsPair('privacyPolicy', 4));
  expect(updates.containsKey('legalConsentUpdatedAt'), isFalse);
    });

    test('returns empty updates when everything already satisfies target versions', () {
      final updates = buildInitialLegalUpdate(
        existingData: const {
          'claimsVersion': 3,
          'policyVersions': {
            'termsOfService': 5,
            'privacyPolicy': 5,
          },
        },
        claimsVersion: 3,
        termsVersion: 5,
        privacyVersion: 5,
      );

      expect(updates, isEmpty);
    });

    test('fills in missing policy entries while preserving existing ones', () {
      final updates = buildInitialLegalUpdate(
        existingData: const {
          'claimsVersion': 1,
          'policyVersions': {
            'termsOfService': 1,
          },
        },
        claimsVersion: 1,
        termsVersion: 1,
        privacyVersion: 2,
      );

      final policyVersions = updates['policyVersions'] as Map<String, int>;
      expect(policyVersions.length, 2);
      expect(policyVersions['termsOfService'], 1);
      expect(policyVersions['privacyPolicy'], 2);
    });

    test('upgrades outdated versions without touching newer entries', () {
      final updates = buildInitialLegalUpdate(
        existingData: const {
          'claimsVersion': 0,
          'policyVersions': {
            'termsOfService': 1,
            'privacyPolicy': 1,
          },
        },
        claimsVersion: 2,
        termsVersion: 3,
        privacyVersion: 1,
      );

      expect(updates['claimsVersion'], 2);
      expect(updates['claims_version'], 2);
      final policyVersions = updates['policyVersions'] as Map<String, int>;
      expect(policyVersions['termsOfService'], 3);
      expect(policyVersions['privacyPolicy'], 1);
    });
  });
}
