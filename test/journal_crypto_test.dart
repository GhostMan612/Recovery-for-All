// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Host tests for the journal privacy wall: PIN hashing/gating,
// AES-GCM entry encryption under the secure-storage master key, and
// legacy payload compatibility.

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/services/journal_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({});
  });

  group('PIN lifecycle', () {
    test('no PIN exists before first-run setup', () async {
      expect(await JournalCryptoService.hasPin(), isFalse);
    });

    test('setPin then verify — right and wrong answers', () async {
      await JournalCryptoService.setPin('123456');
      expect(await JournalCryptoService.hasPin(), isTrue);
      expect(await JournalCryptoService.verifyPin('123456'), isTrue);
      expect(await JournalCryptoService.verifyPin('654321'), isFalse);
      expect(await JournalCryptoService.verifyPin('000000'), isFalse);
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
