// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/journal_crypto_service.dart
//
// Real journal privacy: a random 256-bit master key lives in system
// secure storage (keystore-backed); entries are AES-GCM encrypted with
// it. The PIN is a gate, never the key: it is stored as a salted
// PBKDF2 hash, so a wrong guess never touches ciphertext and changing
// the PIN never re-encrypts anything.
//
// Ciphertext scheme history:
//   ENC_  — legacy base64 obfuscation (readable fallback)
//   ENC2_ — base64(nonce | cipher | GCM mac) under the master key

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class JournalCryptoService {
  JournalCryptoService._();

  static const String _keyMaster = 'journal_master_key_v1';
  static const String _keyPinHash = 'journal_pin_hash_v1';
  static const String _keyPinSalt = 'journal_pin_salt_v1';

  static const _storage = FlutterSecureStorage();

  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 150000,
    bits: 256,
  );
  static final AesGcm _aes = AesGcm.with256bits();

  static const int pinLength = 6;

  // ---- lifecycle ----

  /// True when the user has completed first-run PIN setup.
  static Future<bool> hasPin() async {
    try {
      return await _storage.containsKey(key: _keyPinHash);
    } catch (_) {
      return false;
    }
  }

  /// First-run setup (or Settings change): sets/overwrites the PIN.
  /// The master key is created once and never rotated by PIN changes.
  static Future<void> setPin(String pin) async {
    _assertPinFormat(pin);
    final salt = _randomBytes(16);
    final hash = await _hashPin(pin, salt);
    await _storage.write(key: _keyPinSalt, value: base64Encode(salt));
    await _storage.write(key: _keyPinHash, value: base64Encode(hash));
  }

  /// Verifies a candidate PIN against the stored hash.
  static Future<bool> verifyPin(String pin) async {
    try {
      final saltB64 = await _storage.read(key: _keyPinSalt);
      final hashB64 = await _storage.read(key: _keyPinHash);
      if (saltB64 == null || hashB64 == null) return false;
      final candidate =
          await _hashPin(pin, base64Decode(saltB64));
      // Constant-time-ish compare.
      var diff = 0;
      final stored = base64Decode(hashB64);
      if (stored.length != candidate.length) return false;
      for (var i = 0; i < stored.length; i++) {
        diff |= stored[i] ^ candidate[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  /// Loads (creating on first use) the master key. Call ONLY after
  /// [verifyPin] has succeeded — the key is the journal's contents.
  static Future<Uint8List> loadMasterKey() async {
    final existing = await _storage.read(key: _keyMaster);
    if (existing != null) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final key = _randomBytes(32);
    await _storage.write(key: _keyMaster, value: base64Encode(key));
    return Uint8List.fromList(key);
  }

  // ---- content ----

  static Future<String> encrypt(
      String plaintext, Uint8List masterKey) async {
    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(masterKey),
    );
    final payload = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return 'ENC2_${base64Encode(payload)}';
  }

  /// Returns null when the payload cannot be authenticated with this
  /// key (wrong key / corrupted). Falls back to legacy schemes.
  static Future<String?> decrypt(
      String ciphertext, Uint8List masterKey) async {
    if (!ciphertext.startsWith('ENC2_')) {
      return decryptLegacy(ciphertext);
    }
    try {
      final raw = base64Decode(ciphertext.substring(5));
      final box = SecretBox(
        raw.sublist(12, raw.length - 16),
        nonce: raw.sublist(0, 12),
        mac: Mac(raw.sublist(raw.length - 16)),
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(masterKey),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  /// Legacy `ENC_` base64 payloads (and any historical plaintext).
  static String? decryptLegacy(String ciphertext) {
    if (!ciphertext.startsWith('ENC_')) return ciphertext;
    try {
      return utf8.decode(base64Decode(ciphertext.substring(4)));
    } catch (_) {
      return null;
    }
  }

  // ---- helpers ----

  static void _assertPinFormat(String pin) {
    if (pin.length != pinLength || int.tryParse(pin) == null) {
      throw ArgumentError('PIN must be exactly $pinLength digits');
    }
  }

  static Future<List<int>> _hashPin(String pin, List<int> salt) async {
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode('recovery-journal:$pin')),
      nonce: salt,
    );
    return key.extractBytes();
  }

  static List<int> _randomBytes(int length) => List<int>.generate(
      length, (_) => Random.secure().nextInt(256),
      growable: false);
}
