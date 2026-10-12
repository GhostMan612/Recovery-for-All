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
    test('Default state fails closed: all capabilities session-denied and not granted', () {
      final state = PrivacyCapabilityState.defaults();

      for (final cap in PrivacyCapability.values) {
        expect(state.getConsent(cap), equals(ConsentState.denied),
            reason: '${cap.name} session consent must default to ConsentState.denied');
        expect(state.getPersistedPreference(cap), equals(ConsentState.unknown),
            reason: '${cap.name} persisted preference must default to unknown');
        expect(state.isGranted(cap), isFalse,
            reason: '${cap.name} must evaluate isGranted to false');
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

    test('Granted session state explicitly evaluates isGranted to true', () {
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
      // All other capabilities must remain denied
      for (final cap in PrivacyCapability.values) {
        if (cap != PrivacyCapability.remoteWeather) {
          expect(state.isGranted(cap), isFalse,
              reason: 'Granting weather must not grant ${cap.name}');
          expect(state.getConsent(cap), equals(ConsentState.denied));
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

  group('Slice A: Session Authorization & Cold-Start Policy (WO-P0-PRIVACY-DURABILITY)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads defaults when no SharedPreferences are set', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await PrivacyCapabilityService.loadState();

      for (final cap in PrivacyCapability.values) {
        expect(state.getConsent(cap), equals(ConsentState.denied));
        expect(state.getPersistedPreference(cap), equals(ConsentState.unknown));
        expect(state.isGranted(cap), isFalse);
        expect(await PrivacyCapabilityService.isGranted(cap), isFalse);
      }
    });

    test('Old granted preference plus cold restart produces zero authorized optional requests', () async {
      // Simulate persistent storage holding older granted preferences
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'granted',
        'privacy_consent_v1_cloudSync': 'granted',
        'privacy_consent_v1_onlineTiles': 'granted',
      });

      // Cold start: preferences are hydrated, but session authorization initializes to denied
      final loaded = await PrivacyCapabilityService.loadState();

      // Invariant: Persisted preferences are preserved for historical context
      expect(loaded.getPersistedPreference(PrivacyCapability.remoteWeather), equals(ConsentState.granted));
      expect(loaded.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted));
      expect(loaded.getPersistedPreference(PrivacyCapability.onlineTiles), equals(ConsentState.granted));

      // Invariant: Old persisted grants alone NEVER authorize network operations on restart
      expect(loaded.isGranted(PrivacyCapability.remoteWeather), isFalse);
      expect(loaded.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(loaded.isGranted(PrivacyCapability.onlineTiles), isFalse);

      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.remoteWeather), isFalse);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.onlineTiles), isFalse);

      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.remoteWeather), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.onlineTiles), isFalse);
    });

    test('Current-session explicit grant enables only the selected capability', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'granted',
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();

      // Cold start starts with both denied
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.remoteWeather), isFalse);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);

      // User explicitly grants weather through authorized consent workflow
      final grantResult = await PrivacyCapabilityService.setConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.granted,
      );
      expect(grantResult, isTrue);

      // Only weather is now session-authorized
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.remoteWeather), isTrue);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.remoteWeather), isTrue);

      // cloudSync remains unauthorized
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
    });

    test('Normal background and resume within the same process preserves session authorization', () async {
      // User grants onlineTiles during the session
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.onlineTiles,
        ConsentState.granted,
      );
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.onlineTiles), isTrue);

      // Simulated background / resume lifecycle: process remains alive, in-memory state unchanged
      // Re-reading authorization state without process restart
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.onlineTiles), isTrue);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.onlineTiles), isTrue);
    });

    test('Corrupt or unrecognized preference values fail closed to unknown', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'corrupt_string_value',
        'privacy_consent_v1_cloudSync': 'malicious_override',
      });

      final loaded = await PrivacyCapabilityService.loadState();
      expect(loaded.getPersistedPreference(PrivacyCapability.remoteWeather), equals(ConsentState.unknown));
      expect(loaded.isGranted(PrivacyCapability.remoteWeather), isFalse);

      expect(loaded.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.unknown));
      expect(loaded.isGranted(PrivacyCapability.cloudSync), isFalse);
    });
  });

  group('Slice A: Riverpod State Management & Session Reactivity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('privacyCapabilityProvider initializes with session-denied defaults on cold start', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_directoryRefresh': 'granted',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(privacyCapabilityProvider);
      expect(initial.isGranted(PrivacyCapability.directoryRefresh), isFalse,
          reason: 'Cold start must fail closed even when disk preference was previously granted');

      // Explicit grant in this session
      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.granted);

      final updated = container.read(privacyCapabilityProvider);
      expect(updated.isGranted(PrivacyCapability.directoryRefresh), isTrue);
      expect(updated.getConsent(PrivacyCapability.directoryRefresh), equals(ConsentState.granted));

      // Revocation in this session
      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.denied);

      final revoked = container.read(privacyCapabilityProvider);
      expect(revoked.isGranted(PrivacyCapability.directoryRefresh), isFalse);
      expect(revoked.getConsent(PrivacyCapability.directoryRefresh), equals(ConsentState.denied));
    });

    test('Explicit user grant updates Riverpod state reactively for the process', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isFalse);

      await container
          .read(privacyCapabilityProvider.notifier)
          .grant(PrivacyCapability.remoteWeather);

      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isTrue);

      await container
          .read(privacyCapabilityProvider.notifier)
          .revoke(PrivacyCapability.remoteWeather);

      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.remoteWeather), isFalse);
    });

    test('Persisted settings or provider initialization alone never silently grant session access', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'granted',
        'privacy_consent_v1_cloudSync': 'granted',
        'privacy_consent_v1_circleShare': 'granted',
        'privacy_consent_v1_directoryRefresh': 'granted',
        'privacy_consent_v1_onlineTiles': 'granted',
        'privacy_consent_v1_externalNavigation': 'granted',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await PrivacyCapabilityService.initialize();
      final state = container.read(privacyCapabilityProvider);

      for (final cap in PrivacyCapability.values) {
        expect(state.isGranted(cap), isFalse, reason: '${cap.name} must never be silently granted');
        expect(state.getConsent(cap), equals(ConsentState.denied));
        expect(state.getPersistedPreference(cap), equals(ConsentState.granted));
      }
    });

    test('Asynchronous provider hydration never overwrites newer user consent decisions', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_directoryRefresh': 'denied',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // User immediately grants capability in this session
      await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.directoryRefresh, ConsentState.granted);

      // Recheck after hydration has had opportunity to complete
      final state = container.read(privacyCapabilityProvider);
      expect(state.isGranted(PrivacyCapability.directoryRefresh), isTrue,
          reason: 'Newer user decision must NOT be overwritten by older persisted state');
    });
  });

  group('Slice A: Persistence Race & Failure Hardening (WO-P0-PRIVACY-DURABILITY)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('When persistence fails on grant, setConsent returns false and session fails closed', () async {
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
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
    });

    test('When persistence throws on grant, setConsent returns false and session fails closed', () async {
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
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.onlineTiles), isFalse);
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

      // First grant successfully in session
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
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.remoteWeather), isFalse);

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
      expect(executionOrder, equals([1]));

      completer1.complete(true);
      await Future.wait([f1, f2]);

      expect(executionOrder, equals([1, 2]));
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

      // 4. Complete the older grant while holding newer revocation persistence.
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

      // 7. Complete revocation and verify final state.
      revokeCompleter.complete(true);
      final revokeResult = await revokeFuture;
      expect(revokeResult, isTrue);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(callbacksReceived, equals([ConsentState.denied]));
    });

    test('Failed revocation write preserves session denial and accurately reports storage failure without claiming save', () async {
      // 1. Setup initial session where cloudSync was explicitly granted
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isTrue);
      expect(await PrivacyCapabilityService.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted));

      // 2. Attempt revocation, but disk persistence fails (disk error / read-only filesystem)
      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        return false; // Storage write fails
      };
      addTearDown(() => PrivacyCapabilityService.persistenceOverrideForTesting = null);

      final ok = await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      // Invariant: Storage failure is accurately reported
      expect(ok, isFalse, reason: 'Revocation must never be reported as successfully saved when persistence fails');

      // Invariant: In current session, access is immediately and strictly denied
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(await PrivacyCapabilityService.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));

      // Invariant (Preference Accuracy): _persistedPreferences accurately retains the unsaved state ('granted')
      // and does NOT falsely claim 'denied' was durably saved
      expect(await PrivacyCapabilityService.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted),
          reason: 'Failed preference write must not be represented as durably saved');

      // 3. SIMULATE APPLICATION PROCESS RESTART (cold start)
      // Memory is cleared. Disk still has 'granted' because revocation write failed.
      PrivacyCapabilityService.resetForTesting();

      final restartedState = await PrivacyCapabilityService.loadState();

      // INVARIANT (WO-P0-PRIVACY-DURABILITY):
      // Even though underlying storage still contains 'granted',
      // session authorization initializes to denied on every fresh launch.
      // Therefore, the failed revocation write CANNOT leak network requests across cold restart!
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse,
          reason: 'Cold start must NEVER authorize network access from old persisted grant alone');
      expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync), isFalse);
      expect(restartedState.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(restartedState.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));
      expect(restartedState.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted),
          reason: 'Persisted preference reflects unsaved storage state, but is never used to authorize network');
    });

    test('Failed revocation in Riverpod keeps session denied while preserving persisted preference accuracy', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially grant
      final grantOk = await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      expect(grantOk, isTrue);
      expect(container.read(privacyCapabilityProvider).isGranted(PrivacyCapability.cloudSync), isTrue);
      expect(container.read(privacyCapabilityProvider).getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted));

      // Attempt revocation with failing persistence
      PrivacyCapabilityService.persistenceOverrideForTesting = (cap, state) async {
        return false;
      };
      addTearDown(() => PrivacyCapabilityService.persistenceOverrideForTesting = null);

      final revokeOk = await container
          .read(privacyCapabilityProvider.notifier)
          .setConsent(PrivacyCapability.cloudSync, ConsentState.denied);

      // Returns false (reported storage error)
      expect(revokeOk, isFalse);

      final state = container.read(privacyCapabilityProvider);
      // Session authorization is strictly denied!
      expect(state.isGranted(PrivacyCapability.cloudSync), isFalse);
      expect(state.getConsent(PrivacyCapability.cloudSync), equals(ConsentState.denied));
      // Persisted preference does NOT falsely claim to be 'denied'
      expect(state.getPersistedPreference(PrivacyCapability.cloudSync), equals(ConsentState.granted),
          reason: 'Failed revocation write must not be represented as durably saved in state');
    });
  });
}
