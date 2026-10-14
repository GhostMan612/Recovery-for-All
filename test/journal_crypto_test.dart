// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Host tests for the journal privacy wall: PIN hashing/gating,
// AES-GCM entry encryption under the secure-storage master key, and
// legacy payload compatibility.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/services/journal_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({});
    JournalCryptoService.lockSession();
  });

  group('PIN lifecycle and fail-closed security', () {
    test('no PIN exists before first-run setup', () async {
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.unconfigured);
      expect(await JournalCryptoService.hasPin(), isFalse);
    });

    test('unconfigured PIN with existing historical entries requires enrollment', () async {
      expect(
        await JournalCryptoService.checkPinStatus(hasExistingEntries: true),
        JournalPinStatus.unconfiguredWithHistory,
      );
      expect(
        await JournalCryptoService.hasPin(hasExistingEntries: true),
        isTrue,
        reason: 'Must fail closed to protect historical entries',
      );

      // User safely enrolls a new PIN
      await JournalCryptoService.setPin('123456');
      expect(await JournalCryptoService.checkPinStatus(hasExistingEntries: true), JournalPinStatus.configured);
      expect(JournalCryptoService.isSessionUnlocked, isTrue);
      expect(await JournalCryptoService.verifyPin('123456'), isTrue);
    });

    test('centralized lifecycle observer locks session on backgrounding', () {
      JournalCryptoService.initLifecycleObserver();
      addTearDown(JournalCryptoService.disposeLifecycleObserver);

      JournalCryptoService.unlockSession();
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      // Simulate app backgrounding
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(JournalCryptoService.isSessionUnlocked, isFalse);

      JournalCryptoService.unlockSession();
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(JournalCryptoService.isSessionUnlocked, isFalse);
    });

    test('setPin then verify — right and wrong answers', () async {
      await JournalCryptoService.setPin('123456');
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.configured);
      expect(await JournalCryptoService.hasPin(), isTrue);
      expect(await JournalCryptoService.verifyPin('123456'), isTrue);
      expect(await JournalCryptoService.verifyPin('654321'), isFalse);
      expect(await JournalCryptoService.verifyPin('000000'), isFalse);
    });

    test('sessionUnlockedNotifier broadcasts unlock and lock transitions', () {
      final events = <bool>[];
      JournalCryptoService.sessionUnlockedNotifier.addListener(() {
        events.add(JournalCryptoService.sessionUnlockedNotifier.value);
      });

      JournalCryptoService.unlockSession();
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      JournalCryptoService.lockSession();
      expect(JournalCryptoService.isSessionUnlocked, isFalse);

      expect(events, equals([true, false]));
    });

    test('corrupted or partial PIN metadata fails closed', () async {
      const storage = FlutterSecureStorage();

      // Case 1: Hash present, salt missing
      await storage.write(key: 'journal_pin_hash_v1', value: base64Encode(List.filled(32, 1)));
      await storage.delete(key: 'journal_pin_salt_v1');
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.corruptedOrInaccessible);
      expect(await JournalCryptoService.hasPin(), isTrue, reason: 'Must fail closed');
      expect(() => JournalCryptoService.setPin('123456'), throwsStateError);

      // Case 2: Salt present, hash missing
      await storage.delete(key: 'journal_pin_hash_v1');
      await storage.write(key: 'journal_pin_salt_v1', value: base64Encode(List.filled(16, 2)));
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.corruptedOrInaccessible);
      expect(await JournalCryptoService.hasPin(), isTrue, reason: 'Must fail closed');
      expect(() => JournalCryptoService.setPin('123456'), throwsStateError);

      // Case 3: Both present but invalid length (corrupted)
      await storage.write(key: 'journal_pin_hash_v1', value: base64Encode(List.filled(10, 1)));
      await storage.write(key: 'journal_pin_salt_v1', value: base64Encode(List.filled(16, 2)));
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.corruptedOrInaccessible);
      expect(await JournalCryptoService.hasPin(), isTrue, reason: 'Must fail closed');
      expect(() => JournalCryptoService.setPin('123456'), throwsStateError);
    });

    test('rejects malformed PINs', () async {
      expect(() => JournalCryptoService.setPin('12345'),
          throwsArgumentError);
      expect(() => JournalCryptoService.setPin('abcdef'),
          throwsArgumentError);
      expect(() => JournalCryptoService.setPin('1234567'),
          throwsArgumentError);
    });

    test('changing the PIN keeps the same master key', () async {
      await JournalCryptoService.setPin('111111');
      final keyBefore = await JournalCryptoService.loadMasterKey();

      await JournalCryptoService.setPin('222222');
      final ok = await JournalCryptoService.verifyPin('111111');
      expect(ok, isFalse, reason: 'old PIN must stop working');

      final keyAfter = await JournalCryptoService.loadMasterKey();
      expect(keyAfter, keyBefore,
          reason:
              'PIN change must not rotate the key or orphan old entries');
    });

    test('empty-string PIN state reads as no PIN (v3 to v6 lockout)', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'journal_pin_hash_v1', value: '');
      await storage.write(key: 'journal_pin_salt_v1', value: '');
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.unconfigured);
      expect(await JournalCryptoService.hasPin(), isFalse);
      expect(await JournalCryptoService.verifyPin('123456'), isFalse);
    });

    test('clearPin forgets the PIN but keeps entries readable', () async {
      await JournalCryptoService.setPin('123456');
      final key = await JournalCryptoService.loadMasterKey();
      final cipher = await JournalCryptoService.encrypt('keep me', key);

      await JournalCryptoService.clearPin();
      expect(await JournalCryptoService.checkPinStatus(), JournalPinStatus.unconfigured);
      expect(await JournalCryptoService.hasPin(), isFalse);

      await JournalCryptoService.setPin('654321');
      expect(await JournalCryptoService.verifyPin('654321'), isTrue);
      final reopened = await JournalCryptoService.loadMasterKey();
      expect(await JournalCryptoService.decrypt(cipher, reopened), 'keep me');
    });
  });

  group('entry encryption', () {
    test('round-trips through AES-GCM', () async {
      await JournalCryptoService.setPin('123456');
      final key = await JournalCryptoService.loadMasterKey();

      const secret =
          'Day 40. Craving hit hard after the phone call, but I called '
          'my sponsor instead and it passed.';
      final cipher = await JournalCryptoService.encrypt(secret, key);

      expect(cipher, startsWith('ENC2_'));
      expect(cipher.contains('sponsor'), isFalse,
          reason: 'ciphertext must not leak plaintext');
      expect(
        await JournalCryptoService.decrypt(cipher, key),
        secret,
      );
    });

    test('unique nonces — identical texts produce different ciphertexts',
        () async {
      await JournalCryptoService.setPin('123456');
      final key = await JournalCryptoService.loadMasterKey();
      final a = await JournalCryptoService.encrypt('same text', key);
      final b = await JournalCryptoService.encrypt('same text', key);
      expect(a, isNot(b));
    });

    test('wrong key fails authentication, never throws garbage', () async {
      await JournalCryptoService.setPin('123456');
      final realKey = await JournalCryptoService.loadMasterKey();
      final cipher =
          await JournalCryptoService.encrypt('private', realKey);

      // Simulate a different vault (fresh platform = fresh key space).
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform({});
      await JournalCryptoService.setPin('123456');
      final otherKey = await JournalCryptoService.loadMasterKey();

      expect(otherKey, isNot(realKey));
      expect(await JournalCryptoService.decrypt(cipher, otherKey), isNull);
    });
  });

  group('legacy payload compatibility', () {
    test('old ENC_ base64 entries stay readable', () {
      // "grateful for my dog" under the retired scheme.
      const legacy =
          'ENC_Z3JhdGVmdWwgZm9yIG15IGRvZw==';
      expect(JournalCryptoService.decryptLegacy(legacy),
          'grateful for my dog');
    });

    test('historical plaintext passes through untouched', () {
      expect(JournalCryptoService.decryptLegacy('plain as day'),
          'plain as day');
    });

    test('corrupted legacy payloads fail soft', () {
      expect(JournalCryptoService.decryptLegacy('ENC_!!!not-base64!'),
          isNull);
    });

    test('decrypt() routes legacy payloads without a key', () async {
      await JournalCryptoService.setPin('123456');
      final key = await JournalCryptoService.loadMasterKey();
      expect(
        await JournalCryptoService.decrypt(
            'ENC_Z3JhdGVmdWwgZm9yIG15IGRvZw==', key),
        'grateful for my dog',
      );
    });
  });
}
