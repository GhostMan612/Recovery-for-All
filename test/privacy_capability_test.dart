// test/privacy_capability_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PrivacyCapabilityService.resetForTesting();
  });

  tearDown(() {
    PrivacyCapabilityService.resetForTesting();
  });

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

    test('Asynchronous provider hydration never overwrites newer user consent decisions', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_directoryRefresh': 'denied',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // User immediately grants capability before asynchronous hydration completes
      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.granted);

      // Recheck after hydration has had opportunity to complete
      final state = container.read(privacyCapabilityProvider);
      expect(state.isGranted(PrivacyCapability.directoryRefresh), isTrue,
          reason: 'Newer user decision must NOT be overwritten by older persisted state');
    });
  });

  group('Slice A: Persistence Race & Failure Hardening', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('When persistence fails, setConsent returns false and state fails closed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        return false; // simulate disk write failure
      };
      addTearDown(() => PrivacyCapabilityService.persistenceOverrideForTesting = null);

      final ok = await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.cloudSync, ConsentState.granted);

      expect(ok, isFalse);
      final finalState = container.read(privacyCapabilityProvider);
      expect(finalState.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(finalState.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));
    });

    test('When persistence throws, setConsent returns false and state fails closed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        throw Exception('Disk full / OS write error');
      };
      addTearDown(() => PrivacyCapabilityService.persistenceOverrideForTesting = null);

      final ok = await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.onlineTiles, ConsentState.granted);

      expect(ok, isFalse);
      final finalState = container.read(privacyCapabilityProvider);
      expect(finalState.isGranted(PrivacyCapability.onlineTiles), isFalse);
      expect(finalState.getConsent(PrivacyCapability.onlineTiles), equals(ConsentState.denied));
    });

    test('Revocation immediately blocks in-memory before persistence completes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final delayCompleter = Completer<bool>();
      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        if (state == ConsentState.denied) {
          return delayCompleter.future;
        }
        return true;
      };
      addTearDown(() {
        if (!delayCompleter.isCompleted) delayCompleter.complete(true);
        PrivacyCapabilityService.persistenceOverrideForTesting = null;
      });

      // First grant successfully
      final granted = await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.remoteWeather, ConsentState.granted);
      expect(granted, isTrue);
      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isTrue);

      // Now start revocation with pending persistence
      final revokeFuture = container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.remoteWeather, ConsentState.denied);

      // In-memory must ALREADY be revoked synchronously before persistence finishes
      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isFalse);

      delayCompleter.complete(true);
      final revokeResult = await revokeFuture;
      expect(revokeResult, isTrue);
      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isFalse);
    });

    test('Concurrent consent updates are serialized without race conditions', () async {
      final executionOrder = <int>[];
      final completer1 = Completer<bool>();

      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        if (state == ConsentState.granted) {
          executionOrder.add(1);
          await completer1.future;
          return true;
        } else {
          executionOrder.add(2);
          return true;
        }
      };
      addTearDown(() {
        if (!completer1.isCompleted) completer1.complete(true);
        PrivacyCapabilityService.persistenceOverrideForTesting = null;
      });

      final f1 = PrivacyCapabilityService.setConsent(PrivacyCapability.remoteWeather, ConsentState.granted);
      final f2 = PrivacyCapabilityService.setConsent(PrivacyCapability.remoteWeather, ConsentState.denied);

      await Future.delayed(Duration.zero);
      // f1 has started and is awaiting completer1; f2 is queued behind f1
      expect(executionOrder, equals([1]));

      completer1.complete(true);
      await Future.wait([f1, f2]);

      expect(executionOrder, equals([1, 2]));
    });

    test('PrivacyCapabilityService.isGranted() immediately returns false during delayed revocation', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isTrue);

      final delayCompleter = Completer<bool>();
      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        if (state == ConsentState.denied) {
          return delayCompleter.future;
        }
        return true;
      };
      addTearDown(() {
        if (!delayCompleter.isCompleted) delayCompleter.complete(true);
      });

      // Begin revocation - persistence is pending
      final revokeFuture = PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      // isGranted() MUST be false immediately, even while persistence has not completed
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse,
          reason: 'Network services calling isGranted() must be blocked immediately during pending revocation');

      delayCompleter.complete(true);
      final ok = await revokeFuture;
      expect(ok, isTrue);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
    });

    test('PrivacyCapabilityService.isGranted() remains false when revocation persistence fails', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isTrue);

      // Persistence fails on revocation
      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        return false;
      };

      final ok = await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      expect(ok, isFalse, reason: 'setConsent reports persistence failure');
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse,
          reason: 'Failed revocation persistence must fail closed and never authorize network');
    });

    test('Superseded grant completing after revocation never restores authorization or emits stale grant callback', () async {
      final grantCompleter = Completer<bool>();
      final revokeCompleter = Completer<bool>();
      final callbacksReceived = <ConsentState>[];

      PrivacyCapabilityService.onConsentChangedCallbacks.add((cap, state) {
        if (cap == PrivacyCapability.cloudSync) {
          callbacksReceived.add(state);
        }
      });

      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        if (state == ConsentState.granted) {
          return grantCompleter.future;
        } else if (state == ConsentState.denied) {
          return revokeCompleter.future;
        }
        return true;
      };

      addTearDown(() {
        if (!grantCompleter.isCompleted) grantCompleter.complete(true);
        if (!revokeCompleter.isCompleted) revokeCompleter.complete(true);
        PrivacyCapabilityService.persistenceOverrideForTesting = null;
      });

      // 1. Start grant; hold its persistence.
      final grantFuture = PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      // Allow microtask to enter persistence
      await Future.delayed(Duration.zero);

      // 2. Request revocation.
      final revokeFuture = PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      // 3. Verify authorization is immediately denied.
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(callbacksReceived, equals([ConsentState.denied]));

      // 4. Complete the older grant while holding the newer revocation persistence.
      grantCompleter.complete(true);
      final grantResult = await grantFuture;
      expect(grantResult, isFalse, reason: 'Superseded grant must complete false and not be applied');

      // 5. Verify isGranted() remains false throughout.
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);

      // 6. Verify no stale granted notification re-enables cloud services.
      expect(callbacksReceived.contains(ConsentState.granted), isFalse,
          reason: 'Superseded grant must never emit stale granted callback');
      expect(callbacksReceived, equals([ConsentState.denied]));

      // 7. Complete revocation and verify the final state.
      revokeCompleter.complete(true);
      final revokeResult = await revokeFuture;
      expect(revokeResult, isTrue);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(callbacksReceived, equals([ConsentState.denied]));
    });

    test('Failed revocation retains session denial, reports failure, and documents restart risk on cold start', () async {
      // Setup initial persisted state: cloudSync was previously granted in storage
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isTrue);

      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        return false; // Storage write fails
      };
      addTearDown(() => PrivacyCapabilityService.persistenceOverrideForTesting = null);

      // 1. Attempt revocation
      final ok = await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      // 2. Expose persistence failure to caller/user - never report as successfully saved
      expect(ok, isFalse, reason: 'Revocation must never be reported as successfully saved when persistence fails');

      // 3. Retain session-level denial
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse,
          reason: 'Session-level denial must be retained despite persistence failure');
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(await PrivacyCapabilityService.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));

      // 4. Simulated application restart (in-memory session state cleared)
      // When storage is unavailable, durable denial cannot be guaranteed across restarts
      // because SharedPreferences still contains the older 'granted' value.
      PrivacyCapabilityService.resetForTesting();

      // On cold restart, verify the unresolved restart risk:
      // because storage write failed, disk still has the older value.
      final restartedState = await PrivacyCapabilityService.loadState();
      expect(restartedState.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.granted),
          reason: 'Documents unresolved restart risk when storage write failed during revocation');
    });
  });
}
