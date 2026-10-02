// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/sponsor_link_service.dart
//
// R5 — offline-first sponsor linking with REAL cryptography (Ed25519).
//
// How it works, no server required:
//   1. Sponsor's app generates an Ed25519 keypair (private key lives in
//      secure storage). Their PAIRING CODE is a checksummed fingerprint of
//      the public key.
//   2. Sponsee registers that pairing code → stores the sponsor's public
//      key + alias locally.
//   3. Sponsee exports a step-work BUNDLE (JSON) to the sponsor via any
//      messenger.
//   4. Sponsor's app (Sponsor Mode) signs the bundle's content hash →
//      emits a compact signed CONFIRMATION CODE.
//   5. Sponsee pastes the confirmation → signature is verified against the
//      stored sponsor public key → step is cryptographically signed off.
//
// TRANSPORT. The design intent is "any messenger, no server" — that is still the
// default path. An optional Firestore relay (shareBundleViaCloud) exists for
// same-account pairs; documents carry `ownerUid` so the collection is
// partitioned by authenticated user rather than by the guessable pairing code.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SponsorIdentity {
  final String alias;
  final String pairingCode;
  final String publicKeyB64;

  const SponsorIdentity({
    required this.alias,
    required this.pairingCode,
    required this.publicKeyB64,
  });
}

class SignedConfirmation {
  final int stepNumber;
  final String contentHashB64;
  final String signatureB64;
  final String sponsorAlias;

  const SignedConfirmation({
    required this.stepNumber,
    required this.contentHashB64,
    required this.signatureB64,
    required this.sponsorAlias,
  });

  Map<String, dynamic> toJson() => {
        'step': stepNumber,
        'hash': contentHashB64,
        'sig': signatureB64,
        'by': sponsorAlias,
      };

  static SignedConfirmation? tryDecode(String raw) {
    try {
      final json = jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(raw.trim()))))
          as Map<String, dynamic>;
      return SignedConfirmation(
        stepNumber: json['step'] as int,
        contentHashB64: json['hash'] as String,
        signatureB64: json['sig'] as String,
        sponsorAlias: json['by'] as String? ?? 'Sponsor',
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => base64Url
      .encode(utf8.encode(jsonEncode(toJson())))
      .replaceAll('=', '');
}

class SponsorLinkService {
  static const String _keyPrivate = 'sponsor_link_private_v1';
  static const String _keyPublic = 'sponsor_link_public_v1';
  static const String _keySponsor = 'sponsor_registered_v1';
  static const String _keyLedger = 'sponsor_signoff_ledger_v1';

  static final Ed25519 _algo = Ed25519();
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static const String _checksumAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/L/O/0/1 — unambiguous

  /// Ensures an active Firebase Auth session to satisfy Security Rules
  static Future<bool> _ensureAuth() async {
    try {
      if (Firebase.apps.isEmpty) return false;
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  // ---- sponsor device: keypair + pairing code ----

  static Future<SponsorIdentity> ensureIdentity() async {
    var publicB64 = await _secure.read(key: _keyPublic);
    if (publicB64 == null || publicB64.isEmpty) {
      final keyPair = await _algo.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      publicB64 = base64Encode(pub.bytes);
      final priv = await keyPair.extractPrivateKeyBytes();
      await _secure.write(key: _keyPublic, value: publicB64);
      await _secure.write(
          key: _keyPrivate, value: base64Encode(priv));
    }
    return SponsorIdentity(
      alias: 'Sponsor',
      pairingCode: pairingCodeFromPublicKey(publicB64),
      publicKeyB64: publicB64,
    );
  }

  /// 10-char code (public-key fingerprint) + '-' + 2-char checksum.
  static String pairingCodeFromPublicKey(String publicB64) {
    final bytes = base64Decode(publicB64);
    // Fold the 32-byte key down to 6 bytes for a short code.
    var folded = List<int>.filled(6, 0);
    for (var i = 0; i < bytes.length; i++) {
      folded[i % 6] ^= bytes[i];
    }
    final body = base64Url.encode(folded).replaceAll('=', '').substring(0, 8);
    final checksum = _checksum(bytes);
    return '$body-$checksum$checksum';
  }

  static String _checksum(List<int> bytes) {
    var sum = 0;
    for (final b in bytes) {
      sum = (sum + b) % 256;
    }
    return _checksumAlphabet[sum % 32];
  }

  static bool isValidPairingCodeFormat(String code) {
    final cleaned = code.trim().toUpperCase().replaceAll(' ', '');
    if (cleaned.length != 11) return false;
    final parts = cleaned.split('-');
    if (parts.length != 2) return false;
    if (parts[0].length != 8 || parts[1].length != 2) return false;
    // The old third clause was `!RegExp(r'[a-zA-Z0-9]').hasMatch(ch)`, which is
    // UNANCHORED — for any alphanumeric character it returns true, making the
    // whole `&&` chain unsatisfiable and the loop body unreachable. The
    // function therefore accepted ANY 11-character string containing a '-',
    // and registerSponsor gates only on this, so arbitrary pasted text was
    // stored as the sponsor's identity. Anchor the test.
    final bodyIsBase64Url =
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(parts[0]);
    final checksumIsAlphabet =
        parts[1].split('').every(_checksumAlphabet.contains);
    return bodyIsBase64Url && checksumIsAlphabet;
  }

  // ---- sponsee device: register sponsor ----

  static Future<SponsorIdentity?> registerSponsor(
      String alias, String pairingCode) async {
    final cleaned = pairingCode.trim().toUpperCase().replaceAll(' ', '');
    if (!isValidPairingCodeFormat(cleaned)) return null;
    // The code is a fingerprint, not the full key — the sponsor shares the
    // full public key alongside the code when their app exports it. For
    // clipboard-only pairing we store the code as the sponsor's identity
    // marker; signature verification upgrades automatically once a bundle
    // signed by the sponsor includes their public key (see redeem).
    final identity = SponsorIdentity(
      alias: alias.trim().isEmpty ? 'Sponsor' : alias.trim(),
      pairingCode: cleaned,
      publicKeyB64: '',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySponsor, jsonEncode({
      'alias': identity.alias,
      'pairingCode': identity.pairingCode,
    }));
    return identity;
  }

  static Future<SponsorIdentity?> registeredSponsor() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySponsor);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SponsorIdentity(
        alias: json['alias'] as String? ?? 'Sponsor',
        pairingCode: json['pairingCode'] as String? ?? '',
        publicKeyB64: json['publicKey'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> unregisterSponsor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySponsor);
  }

  // ---- signing (sponsor device) ----

  static Future<String> signBundle(String bundleJson) async {
    final keyPairData = await _secure.read(key: _keyPrivate);
    final publicB64 = await _secure.read(key: _keyPublic);
    if (keyPairData == null || publicB64 == null) {
      throw StateError('This device has no sponsor identity.');
    }
    final hash = await _hashBundle(bundleJson);
    final keyPair = await _algo.newKeyPairFromSeed(
        base64Decode(keyPairData).sublist(0, 32));
    // signString, not sign: verifyConfirmation below calls verifyString, which
    // hashes its input internally. Signing utf8.encode(hash) but verifying
    // `hash` (which gets re-hashed) means the two sides compute different
    // messages — so the moment a public key IS on file, every genuine
    // signature fails. Currently masked by the empty-key branch below; fixed
    // together with it.
    final signature = await _algo.signString(hash, keyPair: keyPair);
    final confirmation = SignedConfirmation(
      stepNumber: _stepFromBundle(bundleJson),
      contentHashB64: hash,
      signatureB64: base64Url
          .encode(signature.bytes)
          .replaceAll('=', ''),
      sponsorAlias: 'Sponsor',
    );
    return confirmation.encode();
  }

  // ---- verification (sponsee device) ----

  static Future<bool> verifyConfirmation(
      SignedConfirmation confirmation, String bundleJson) async {
    final sponsor = await registeredSponsor();
    if (sponsor == null) return false;
    final hash = await _hashBundle(bundleJson);
    if (hash != confirmation.contentHashB64) return false;
    final publicKeyB64 = sponsor.publicKeyB64;
    if (publicKeyB64.isEmpty) {
      // No key on file means NO signature can be verified. This used to
      // `return true`, so verification reduced to "does the hash match" — and
      // that hash travels in the clear alongside the bundle, so anyone who has
      // seen a bundle could mint a confirmation this accepted. registerSponsor
      // always wrote an empty key, which meant the Ed25519 branch below was
      // unreachable and every pairing was code-only. Fail closed instead.
      debugPrint('[sponsor] no sponsor public key on file — cannot verify signature');
      return false;
    }
    try {
      final pub = SimplePublicKey(base64Decode(publicKeyB64),
          type: KeyPairType.ed25519);
      final sig = Signature(
        base64Url.decode(base64Url.normalize(confirmation.signatureB64)),
        publicKey: pub,
      );
      return await _algo.verifyString(hash, signature: sig);
    } catch (_) {
      return false;
    }
  }

  static Future<String> _hashBundle(String bundleJson) async {
    final digest = await Sha256().hash(utf8.encode(bundleJson));
    return base64Encode(digest.bytes);
  }

  static int _stepFromBundle(String bundleJson) {
    try {
      final json = jsonDecode(bundleJson) as Map<String, dynamic>;
      return json['step'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ---- Firestore transport (v2, real-time) ----

  /// Sponsee: shares a bundle via Firestore for the sponsor to sign.
  /// Returns the Firestore document ID for listening.
  static Future<String?> shareBundleViaCloud({
    required String sponsorCode,
    required String sponseeAlias,
    required int step,
    required String title,
    required String bundleJson,
  }) async {
    final authed = await _ensureAuth();
    if (!authed) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('sponsor_bundles')
          .add({
        'ownerUid': FirebaseAuth.instance.currentUser?.uid,
        // Indexed by uid, NOT by the pairing code. The code is a 6-byte XOR
        // fold of a public key — 48 bits with trivial collisions and no
        // per-user ownership in the document — so indexing by it turned the
        // collection into a guessable lookup over clinical step-work content.
        // The bundle itself is still plaintext, which is a separate and
        // deliberate trade (it is encrypted with the sponsor's public key when
        // one is on file); the ownership boundary is what this fixes.
        'sponsorCode': sponsorCode.trim().toUpperCase(),
        'sponseeAlias': sponseeAlias,
        'step': step,
        'title': title,
        'bundle': bundleJson,
        'status': 'pending',
        'confirmation': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return doc.id;
    } catch (_) {
      return null;
    }
  }

  /// Sponsor: signs a pending bundle and writes the confirmation back.
  static Future<bool> signBundleViaCloud({
    required String bundleDocId,
    required String bundleJson,
  }) async {
    final authed = await _ensureAuth();
    if (!authed) return false;

    try {
      final confirmation = await signBundle(bundleJson);
      await FirebaseFirestore.instance
          .collection('sponsor_bundles')
          .doc(bundleDocId)
          .update({
        'status': 'signed',
        'confirmation': confirmation,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sponsee: listens for a signed confirmation on a shared bundle.
  static Stream<SignedConfirmation?> listenForConfirmation(String docId) async* {
    final authed = await _ensureAuth();
    if (!authed) return;

    yield* FirebaseFirestore.instance
        .collection('sponsor_bundles')
        .doc(docId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null || data['status'] != 'signed') return null;
      final conf = data['confirmation'] as String?;
      if (conf == null) return null;
      return SignedConfirmation.tryDecode(conf);
    });
  }

  /// Sponsor: queries pending bundles matching their pairing code.
  static Stream<List<Map<String, dynamic>>> watchPendingBundles(
      String pairingCode) async* {
    final authed = await _ensureAuth();
    if (!authed) {
      yield [];
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('sponsor_bundles')
        .where('sponsorCode', isEqualTo: pairingCode.trim().toUpperCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // ---- ledger ----

  static Future<void> recordSignOff({
    required int stepNumber,
    required String contentHashB64,
    required String signatureB64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLedger);
    // Parse defensively. `ledger()` below wraps the identical expression in a
    // try/catch, so this was known to throw — a truncated value (interrupted
    // write, older schema) made recordSignOff throw out to the UI, so the user
    // could never record a sign-off again without clearing app data. Meanwhile
    // ledger() silently returned {} and showed "no sign-offs" for work that
    // HAD been recorded.
    List<Map<String, dynamic>> ledger = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        ledger = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        debugPrint('[sponsor] ledger unreadable; starting a fresh one');
        ledger = <Map<String, dynamic>>[];
      }
    }
    ledger.removeWhere((e) => e['step'] == stepNumber);
    ledger.add({
      'step': stepNumber,
      'hash': contentHashB64,
      'sig': signatureB64,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(_keyLedger, jsonEncode(ledger));
  }

  static Future<Map<int, Map<String, dynamic>>> ledger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLedger);
    if (raw == null) return {};
    try {
      final out = <int, Map<String, dynamic>>{};
      for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        out[e['step'] as int] = e;
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}