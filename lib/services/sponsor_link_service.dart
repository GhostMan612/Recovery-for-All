// lib/services/sponsor_link_service.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Offline-first sponsor linking with Ed25519 cryptography.
// Pairing:
// 1. Sponsor generates an Ed25519 keypair in secure storage.
//    Pairing code is a checksummed fingerprint of the public key.
// 2. Sponsee registers the pairing code and exports step bundles offline or via relay.
// 3. Sponsor signs bundle content hash; sponsee verifies signature with stored public key.
//
// Relay subcollections are partitioned by uid in document paths to enforce ownership rules.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/privacy/privacy_capability.dart';

/// Firestore subcollection holding a sponsee's own outbound bundles.
const _sponsorBundleRoot = 'sponsor_bundles';

/// Firestore subcollection a sponsor reads: bundles copied to *their* uid.
const _sponsorInboxRoot = 'sponsorBundles';

/// Owner's relay partition for [uid].
CollectionReference<Map<String, dynamic>> _ownerBundles(String uid) =>
    FirebaseFirestore.instance
        .collection(_sponsorBundleRoot)
        .doc(uid)
        .collection('bundles');

/// Sponsor's inbox partition for [uid].
CollectionReference<Map<String, dynamic>> _sponsorInbox(String uid) =>
    FirebaseFirestore.instance
        .collection(_sponsorInboxRoot)
        .doc(uid)
        .collection('inbox');

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

  @visibleForTesting
  static Future<bool> Function()? authCheckerForTesting;

  @visibleForTesting
  static String? currentUidForTesting;

  @visibleForTesting
  static Stream<List<Map<String, dynamic>>> Function(String uid, String pairingCode)?
      inboxStreamForTesting;

  @visibleForTesting
  static void resetTestingOverrides() {
    authCheckerForTesting = null;
    currentUidForTesting = null;
    inboxStreamForTesting = null;
    _privacyListenerAttached = false;
    _revocationCallbacks.clear();
  }

  static final List<void Function()> _revocationCallbacks = [];
  static bool _privacyListenerAttached = false;

  static void initPrivacyListener() {
    if (_privacyListenerAttached) return;
    _privacyListenerAttached = true;
    PrivacyCapabilityService.onConsentChangedCallbacks.add((cap, state) {
      if (cap == PrivacyCapability.cloudSync && !state.isGranted) {
        onRevokeCloud();
      }
    });
  }

  static void onRevokeCloud() {
    for (final cb in List.of(_revocationCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
    _revocationCallbacks.clear();
  }

  static const String _checksumAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/L/O/0/1 — unambiguous

  /// Ensures an active Firebase Auth session to satisfy Security Rules
  static Future<bool> _ensureAuth() async {
    if (authCheckerForTesting != null) {
      return authCheckerForTesting!();
    }
    try {
      if (Firebase.apps.isEmpty) return false;
      final cloudAllowed =
          await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
      if (!cloudAllowed) return false;
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Legacy flat-collection doc IDs this user can still see, if any.
  ///
  /// A read-only diagnostic for stranded documents under old flat rules.
  static Future<List<String>> orphanedRelayDocIds() async {
    final authed = await _ensureAuth();
    if (!authed) return const [];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_sponsorBundleRoot)
          .limit(20)
          .get();
      return snap.docs
          .where((d) => d.data()['ownerUid'] == uid)
          .map((d) => d.id)
          .toList();
    } catch (e) {
      debugPrint('[sponsor] legacy relay probe failed: $e');
      return const [];
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

  // ---- Firestore transport (ownership-partitioned) ----

  /// Sponsee: shares a bundle via Firestore for the sponsor to sign.
  static Future<String?> shareBundleViaCloud({
    required String sponsorCode,
    required String sponseeAlias,
    required int step,
    required String title,
    required String bundleJson,
  }) async {
    final authed = await _ensureAuth();
    if (!authed) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _ownerBundles(uid).add({
        'ownerUid': uid,
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
    } catch (e) {
      debugPrint('[sponsor] relay share failed: $e');
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final confirmation = await signBundle(bundleJson);
      await _sponsorInbox(uid).doc(bundleDocId).update({
        'status': 'signed',
        'confirmation': confirmation,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sponsee: listens for a signed confirmation on a shared bundle.
  /// Automatically tears down remote subscription on privacy capability revocation.
  static Stream<SignedConfirmation?> listenForConfirmation(String docId) {
    initPrivacyListener();
    late StreamController<SignedConfirmation?> controller;
    StreamSubscription? sub;
    var revoked = false;

    void cancelStream() {
      revoked = true;
      sub?.cancel();
      sub = null;
      if (!controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<SignedConfirmation?>(
      onListen: () {
        _revocationCallbacks.add(cancelStream);
        _ensureAuth().then((authed) async {
          if (!authed || controller.isClosed || revoked) {
            if (!controller.isClosed) controller.close();
            return;
          }
          final stillAllowed =
              await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
          if (!stillAllowed || controller.isClosed || revoked) {
            if (!controller.isClosed) controller.close();
            return;
          }
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null || controller.isClosed || revoked) {
            if (!controller.isClosed) controller.close();
            return;
          }

          sub = _ownerBundles(uid).doc(docId).snapshots().listen(
            (doc) async {
              final allowed =
                  await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
              if (!allowed || revoked) {
                cancelStream();
                return;
              }
              final data = doc.data();
              if (data == null || data['status'] != 'signed') {
                if (!controller.isClosed) controller.add(null);
                return;
              }
              final conf = data['confirmation'] as String?;
              if (!controller.isClosed) {
                controller.add(conf != null ? SignedConfirmation.tryDecode(conf) : null);
              }
            },
            onError: (Object e) {
              if (!controller.isClosed) controller.add(null);
            },
          );
        });
      },
      onCancel: () async {
        _revocationCallbacks.remove(cancelStream);
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Sponsor: queries pending bundles addressed to their pairing code.
  /// Automatically tears down remote subscription on privacy capability revocation.
  static Stream<List<Map<String, dynamic>>> watchPendingBundles(
      String pairingCode) {
    initPrivacyListener();
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;
    var revoked = false;

    void cancelStream() {
      revoked = true;
      sub?.cancel();
      sub = null;
      if (!controller.isClosed) {
        controller.add(const <Map<String, dynamic>>[]);
        controller.close();
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        _revocationCallbacks.add(cancelStream);
        _ensureAuth().then((authed) async {
          if (!authed || controller.isClosed || revoked) {
            if (!controller.isClosed) {
              controller.add(const <Map<String, dynamic>>[]);
              controller.close();
            }
            return;
          }
          final stillAllowed =
              await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
          if (!stillAllowed || controller.isClosed || revoked) {
            if (!controller.isClosed) {
              controller.add(const <Map<String, dynamic>>[]);
              controller.close();
            }
            return;
          }
          final uid = currentUidForTesting ?? FirebaseAuth.instance.currentUser?.uid;
          if (uid == null || controller.isClosed || revoked) {
            if (!controller.isClosed) {
              controller.add(const <Map<String, dynamic>>[]);
              controller.close();
            }
            return;
          }

          final wanted = pairingCode.trim().toUpperCase();
          final sourceStream = inboxStreamForTesting != null
              ? inboxStreamForTesting!(uid, wanted)
              : _sponsorInbox(uid)
                  .where('sponsorCode', isEqualTo: wanted)
                  .where('status', isEqualTo: 'pending')
                  .snapshots()
                  .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());

          sub = sourceStream.listen(
            (items) async {
              final allowed =
                  await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
              if (!allowed || revoked) {
                cancelStream();
                return;
              }
              if (!controller.isClosed) {
                controller.add(items);
              }
            },
            onError: (Object _) {
              if (!controller.isClosed) controller.add(const <Map<String, dynamic>>[]);
            },
          );
        });
      },
      onCancel: () async {
        _revocationCallbacks.remove(cancelStream);
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  // ---- ledger ----

  static Future<void> recordSignOff({
    required int stepNumber,
    required String contentHashB64,
    required String signatureB64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLedger);
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
