// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/recovery_database.dart';

class MasterKeyInaccessibleException implements Exception {
  final String message;
  final Object? cause;
  const MasterKeyInaccessibleException(this.message, {this.cause});
  @override
  String toString() => 'MasterKeyInaccessibleException: $message';
}

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

  static bool _sessionUnlocked = false;

  /// Whether the journal has been verified and unlocked during this active app session.
  static bool get isSessionUnlocked => _sessionUnlocked;

  /// Marks the active session as unlocked (e.g. after successful PIN verification).
  static void unlockSession() {
    _sessionUnlocked = true;
  }

  /// Locks the active session, requiring PIN verification before decrypting or viewing journal history.
  static void lockSession() {
    _sessionUnlocked = false;
  }

  static Future<bool> hasPin() async {
    try {
      final hashB64 = await _storage.read(key: _keyPinHash);
      final saltB64 = await _storage.read(key: _keyPinSalt);
      if (hashB64 == null || hashB64.isEmpty) return false;
      if (saltB64 == null || saltB64.isEmpty) return false;
      final hash = base64Decode(hashB64);
      final salt = base64Decode(saltB64);
      if (hash.length != 32) return false;
      if (salt.length != 16) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPin(String pin) async {
    _assertPinFormat(pin);
    final salt = _randomBytes(16);
    final hash = await _hashPin(pin, salt);
    await _storage.write(key: _keyPinSalt, value: base64Encode(salt));
    await _storage.write(key: _keyPinHash, value: base64Encode(hash));
    _sessionUnlocked = true;
  }

  static Future<void> clearPin() async {
    try {
      await _storage.delete(key: _keyPinHash);
      await _storage.delete(key: _keyPinSalt);
    } catch (_) {}
    _sessionUnlocked = false;
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      final saltB64 = await _storage.read(key: _keyPinSalt);
      final hashB64 = await _storage.read(key: _keyPinHash);
      if (saltB64 == null || saltB64.isEmpty) return false;
      if (hashB64 == null || hashB64.isEmpty) return false;
      final candidate = await _hashPin(pin, base64Decode(saltB64));
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

  /// Loads the journal master key from secure storage.
  ///
  /// Fail-closed safety property:
  /// If existing encrypted entries or a configured PIN are present, and the key
  /// cannot be retrieved from secure storage (due to storage error, Keystore
  /// lockout, or missing key), this method throws [MasterKeyInaccessibleException]
  /// instead of generating a new random key that would corrupt or lock out existing
  /// journal entries. A new key is generated ONLY for a fresh installation.
  static Future<Uint8List> loadMasterKey({bool? hasExistingEntries}) async {
    String? existing;
    try {
      existing = await _storage.read(key: _keyMaster);
    } catch (e) {
      throw MasterKeyInaccessibleException(
        'Failed to read journal master key from secure storage: $e',
        cause: e,
      );
    }

    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }

    // Key is missing or empty in secure storage.
    // Verify whether existing journal history is present.
    if (hasExistingEntries == true) {
      throw const MasterKeyInaccessibleException(
        'Existing journal history found, but master key was not found in secure storage. '
        'Refusing to generate a replacement key to prevent user data loss.',
      );
    }

    // Clean first-time installation: generate and persist fresh key.
    final key = _randomBytes(32);
    try {
      await _storage.write(key: _keyMaster, value: base64Encode(key));
    } catch (e) {
      throw MasterKeyInaccessibleException(
        'Failed to persist new journal master key to secure storage: $e',
        cause: e,
      );
    }
    return Uint8List.fromList(key);
  }

  static Future<String> encrypt(String plaintext, Uint8List masterKey) async {
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

  static String? decryptLegacy(String ciphertext) {
    if (!ciphertext.startsWith('ENC_')) return ciphertext;
    try {
      return utf8.decode(base64Decode(ciphertext.substring(4)));
    } catch (_) {
      return null;
    }
  }

  /// Safely upgrades historical unencrypted (or legacy ENC_) journal entries to ENC2_ encryption.
  ///
  /// Invariants:
  /// 1. Idempotent: entries already prefixed with 'ENC2_' are left untouched.
  /// 2. Non-destructive: if decryption or re-encryption fails, the entry is NOT modified.
  /// 3. Dependent on successful master key recovery: if key cannot be loaded or is invalid,
  ///    no database records are modified.
  static Future<int> upgradeHistoricalEntries(
    RecoveryDatabase database,
    Uint8List masterKey,
  ) async {
    final entries = await database.select(database.journalEntries).get();
    var upgradedCount = 0;
    for (final entry in entries) {
      if (entry.contentEncrypted.startsWith('ENC2_')) {
        continue;
      }
      final plain = await decrypt(entry.contentEncrypted, masterKey);
      if (plain != null && plain.isNotEmpty) {
        final reEncrypted = await encrypt(plain, masterKey);
        final updated = entry.copyWith(contentEncrypted: reEncrypted);
        await database.updateJournalEntry(updated);
        upgradedCount++;
      }
    }
    return upgradedCount;
  }

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
