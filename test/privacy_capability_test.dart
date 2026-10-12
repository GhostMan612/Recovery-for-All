// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice A: PrivacyCapability State & Policy', () {
    test('Default state fails closed: all capabilities unknown and not granted', () {
      final state = PrivacyCapabilityState.defaults();

      for (final cap in PrivacyCapability.values) {
        expect(state.getConsent(cap), equals(ConsentState.unknown),
            reason: '${cap.name} must default to ConsentState.unknown');
        expect(state.isGranted(cap), isFalse,
            reason: '${cap.name} in unknown state must evaluate isGranted to false');
      }
    });

    test('Denied state explicitly evaluates isGranted to false', () {
      final state = PrivacyCapabilityState(const {
        PrivacyCapability.remoteWeather: ConsentState.denied,
        PrivacyCapability.cloudSync: ConsentState.denied,
      });

      expect(state.isGranted(PrivacyCapability.remoteWeather), isFalse);
      expect(state.isGranted(PrivacyCapability.cloudSync), isFalse);
    });

    test('Granted state explicitly evaluates isGranted to true', () {
      final state = PrivacyCapabilityState(const {
        PrivacyCapability.remoteWeather: ConsentState.granted,
      });

      expect(state.isGranted(PrivacyCapability.remoteWeather), isTrue);
    });

    test('Independent consent: granting one capability does not grant others', () {
      final state = PrivacyCapabilityState.defaults().withConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.granted,
      );

      expect(state.isGranted(PrivacyCapability.remoteWeather), isTrue);
      // All other capabilities must remain denied / not granted
      for (final cap in PrivacyCapability.values) {
        if (cap != PrivacyCapability.remoteWeather) {
          expect(state.isGranted(cap), isFalse,
              reason: 'Granting weather must not grant ${cap.name}');
          expect(state.getConsent(cap), equals(ConsentState.unknown));
        }
      }
    });

    test('Immediate revocation: revoking a capability transitions isGranted to false', () {
      var state = PrivacyCapabilityState.defaults().withConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      expect(state.isGranted(PrivacyCapability.cloudSync), isTrue);

      state = state.withConsent(PrivacyCapability.cloudSync, ConsentState.denied);
      expect(state.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(state.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));
    });

    test('Disclosures are complete and descriptive for every capability', () {
      for (final cap in PrivacyCapability.values) {
        final disclosure = PrivacyCapabilityState.disclosures[cap];
        expect(disclosure, isNotNull, reason: 'Disclosure missing for ${cap.name}');
        expect(disclosure!.title.isNotEmpty, isTrue);
        expect(disclosure.description.isNotEmpty, isTrue);
        expect(disclosure.transmittedData.isNotEmpty, isTrue);
        expect(disclosure.recipient.isNotEmpty, isTrue);
        expect(disclosure.fallback.isNotEmpty, isTrue);
      }
    });
  });

  group('Slice A: Persistence Owner & Fail-Closed Deserialization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads defaults when no SharedPreferences are set', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await PrivacyCapabilityService.loadState();

      for (final cap in PrivacyCapability.values) {
        expect(state.getConsent(cap), equals(ConsentState.unknown));
        expect(state.isGranted(cap), isFalse);
      }
    });

    test('Persists and restores explicit consent choices round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      await PrivacyCapabilityService.saveConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.saveConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      final loaded = await PrivacyCapabilityService.loadState();
      expect(loaded.getConsent(PrivacyCapability.remoteWeather), equals(ConsentState.granted));
      expect(loaded.isGranted(PrivacyCapability.remoteWeather), isTrue);

      expect(loaded.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));
      expect(loaded.isGranted(PrivacyCapability.cloudSync), isFalse);

      // Remaining capabilities must still be unknown
      expect(loaded.getConsent(PrivacyCapability.circleShare), equals(ConsentState.unknown));
      expect(loaded.isGranted(PrivacyCapability.circleShare), isFalse);
    });

    test('Corrupt or unrecognized preference values fail closed to unknown', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'corrupt_string_value',
        'privacy_consent_v1_cloudSync': 'malicious_override',
      });

      final loaded = await PrivacyCapabilityService.loadState();
      expect(loaded.getConsent(PrivacyCapability.remoteWeather), equals(ConsentState.unknown));
      expect(loaded.isGranted(PrivacyCapability.remoteWeather), isFalse);

      expect(loaded.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.unknown));
      expect(loaded.isGranted(PrivacyCapability.cloudSync), isFalse);
    });
  });

  group('Slice A: Riverpod State Management & Reactivity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('privacyCapabilityProvider initializes with defaults and updates reactively', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(privacyCapabilityProvider);
      expect(initial.isGranted(PrivacyCapability.directoryRefresh), isFalse);

      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.granted);

      final updated = container.read(privacyCapabilityProvider);
      expect(updated.isGranted(PrivacyCapability.directoryRefresh), isTrue);
      expect(updated.getConsent(PrivacyCapability.directoryRefresh), equals(ConsentState.granted));

      // Revocation
      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.denied);

      final revoked = container.read(privacyCapabilityProvider);
      expect(revoked.isGranted(PrivacyCapability.directoryRefresh), isFalse);
      expect(revoked.getConsent(PrivacyCapability.directoryRefresh), equals(ConsentState.denied));
    });
  });
}
