// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/fellowship_attestation_service.dart
//
// Mutual, replay-proof proof that TWO INSTALLS were in the same room — using
// the Ed25519 keys that already ship with this app for sponsor linking.
//
// WHAT WAS WRONG. The fellowship handshake was a QR carrying `{alias, ts}`.
// Scanning it awarded 50 XP. That had three properties nobody wanted:
//
//   1. ONE-DIRECTIONAL. B scanned A's code and B got the XP. A proved nothing
//      and received nothing. There was no step in which A learned that B had
//      actually been there, so "we met" was an assertion by B alone.
//   2. THE PEER CHOSE THE COOLDOWN KEY. The 24-hour dedupe read
//      `getRecentFellowshipSyncsForPeer(safeAlias, …)`. The alias is a
//      caller-supplied STRING. So "BrightOak" became "BrightOak2" and the
//      cooldown did not apply — the XP was farmable at an arbitrary rate, and
//      varying the alias was enough to defeat the one limit that existed.
//   3. REPLAYABLE inside the window. A 10-minute `ts` expiry bounds the damage
//      of a photographed code to 10 minutes, but nothing bound it to ONE pairing
//      attempt, and nothing stopped the same screenshot being scanned twice.
//
// WHAT THIS DOES. Each install holds an Ed25519 keypair in secure storage
// (`fellowship_id_*`). A pairing is three signed steps:
//
//   step 1  A displays  {v,role:'offer',alias,nonceA,ts,key,sig(over 1|nonceA)}
//   step 2  B scans it, verifies A's signature, and displays
//           {v,role:'answer',alias,nonceB,echo:nonceA,ts,key,sig(over 2|nonceA|nonceB)}
//   step 3  A scans that, verifies B's signature AND that `echo == nonceA`,
//           and displays
//           {v,role:'confirm',alias,nonceA,echo:nonceB,ts,key,sig(over 3|nonceA|nonceB)}
//           B scans the confirm, verifies A's signature and `echo == nonceB`.
//
// WHY THIS ACTUALLY FIXES IT.
//
//   * Both sides now hold a signature over BOTH nonces, produced by the OTHER
//     side. A cannot claim "B met me" without B having signed B's own nonce,
//     and B cannot claim "A met me" without A having signed A's. Neither half
//     is self-issued.
//   * The nonce is echoed, so a code is good for exactly ONE pairing. Replaying
//     a photographed step-1 offer fails at step 3 because `echo` will not match
//     a fresh `nonceA`. This is the property the 10-minute `ts` could not give.
//   * The cooldown is now keyed on `peerKey` — a value the peer cannot choose.
//     Renaming yourself no longer bypasses it. Alias is kept as a legacy
//     fallback ONLY so a handshake recorded before this change still finds its
//     own row.
//
// WHAT IT STILL IS NOT, STATED PLAINLY. There is no server and no third party,
// so this proves CONTEMPORANEOUS PRESENCE between two keys, not IDENTITY. One
// person with two phones can complete a full three-step exchange with themselves,
// and a fresh install is a new key. What that buys is a real cost on farming —
// a bounded, auditable key history rather than an unbounded string space — and
// an audit trail that means something. It does not make the XP unimprovable, and
// this file should not be described as if it did.
//
// PRIVACY. The payload is alias + nonce + timestamp + a PUBLIC key + a signature.
// No location, no contact, no device identifier, no Firebase uid. The public key
// is not a secret: it is the point of a public key.

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wire version. Bumped if the payload shape or the signed message format
/// changes; a peer speaking a different version is refused rather than
/// half-understood.
const int kFellowshipAttestationVersion = 2;

/// Step role in the exchange.
enum AttestationRole {
  /// Step 1: the inviter publishes a challenge.
  offer,

  /// Step 2: the invitee answers, binding its own nonce to the challenge.
  answer,

  /// Step 3: the inviter confirms, so the invitee learns it was not ignored.
  confirm,
}

extension AttestationRoleX on AttestationRole {
  String get wire => name;

  static AttestationRole? parse(String? raw) {
    for (final r in AttestationRole.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// Why an attestation was refused. Typed rather than a bool so the UI can say
/// what went wrong, and so the test can assert the *reason* instead of only that
/// something was rejected.
enum AttestationFailure {
  /// Payload was not decodable, or not an object.
  malformed,

  /// A version this build does not speak.
  versionMismatch,

  /// No signature, or no public key to check it against.
  unsigned,

  /// The signature did not verify against the supplied public key.
  badSignature,

  /// `echo` did not match the nonce we issued — i.e. this is a replay, or an
  /// answer to somebody else's challenge.
  nonceMismatch,

  /// Older than [FellowshipAttestationService.maxAge], or dated in the future.
  expired,
}

class AttestationResult {
  final AttestationPayload? payload;
  final AttestationFailure? failure;

  /// True when the payload parsed AND its signature verified AND it answered the
  /// challenge we are holding. This is the only value that may unlock a reward.
  final bool verified;

  const AttestationResult.verified(AttestationPayload p)
      : payload = p,
        failure = null,
        verified = true;

  const AttestationResult.failed(AttestationFailure f)
      : payload = null,
        failure = f,
        verified = false;

  String get message => switch (failure) {
        null => 'Verified',
        AttestationFailure.malformed => 'That is not a handshake code.',
        AttestationFailure.versionMismatch =>
          'That code is from a different version of the app.',
        AttestationFailure.unsigned =>
          'That code carries no signature, so it cannot be verified.',
        AttestationFailure.badSignature =>
          'That signature does not check out — the code was altered.',
        AttestationFailure.nonceMismatch =>
          'That code answers a different pairing. Ask them to refresh it.',
        AttestationFailure.expired =>
          'That code has expired. Ask them to refresh it.',
      };
}

/// A parsed, structurally-valid payload. Says nothing about whether the
/// signature was checked — that is [AttestationResult].
class AttestationPayload {
  final int version;
  final AttestationRole role;
  final String alias;

  /// The nonce this device generated, echoed through the exchange.
  final String nonce;

  /// The nonce this device is answering, empty on the first step.
  final String echo;
  final int issuedAtMs;
  final String publicKeyB64;
  final String signatureB64;

  const AttestationPayload({
    required this.version,
    required this.role,
    required this.alias,
    required this.nonce,
    required this.echo,
    required this.issuedAtMs,
    required this.publicKeyB64,
    required this.signatureB64,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'role': role.wire,
        'alias': alias,
        'nonce': nonce,
        'echo': echo,
        'ts': issuedAtMs,
        'key': publicKeyB64,
        'sig': signatureB64,
      };

  String encode() => jsonEncode(toJson());

  /// The exact bytes that are signed.
  ///
  /// A single builder, used by BOTH signing and verifying. The original bug in
  /// `SponsorLinkService` was signing one string and verifying another
  /// (`utf8.encode(hash)` vs `hash`), which made every genuine signature fail
  /// once a key was on file — masked only by a branch that returned `true`
  /// without verifying. A signed-message format with two implementations is
  /// guaranteed to drift, so there is one and it is canonical: the role, the
  /// alias, and the two nonces, joined by `|`, in that order.
  ///
  /// **The alias is inside the signature, and the first draft left it out.**
  /// It does not need to be there for the cooldown — that keys on the public key
  /// — but leaving one caller-supplied, *displayed* field outside the signed
  /// envelope means an edited alias travels as a valid code, and the test that
  /// tampered with exactly that field passed. Signing everything is cheaper than
  /// reasoning about which field an attacker would prefer to edit.
  ///
  /// Two defects from review are recorded here because this line is the whole
  /// protocol and both were silent:
  ///
  ///   1. `'...$role.wire|...'` — Dart interpolates ONLY the identifier `role`,
  ///      so `.wire|` was literal text and all three legs signed the identical
  ///      string. The role was not part of the signature at all, which deleted
  ///      the one property F2 depends on: an `answer` signature would have
  ///      verified as a `confirm`. **Invariant 7 does not catch this shape** — its
  ///      pattern needs `$id.field(` or `$id.field.`, and this continues with
  ///      `|`, which reads as prose after the identifier. Prefer `${...}`
  ///      wherever a field follows an interpolation, always.
  ///   2. As above, the alias was excluded from the envelope.
  ///
  /// Both were caught by asserting the EXACT string and by tampering with a
  /// specific field, not by asserting "it verifies" — which is the argument for
  /// never testing a signature check with only a positive case.
  String get signingMessage =>
      '${role.wire}|$alias|$nonce|${echo.isEmpty ? '-' : echo}';

  static AttestationPayload? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AttestationPayload(
        version: (decoded['v'] as num?)?.toInt() ?? 1,
        role: AttestationRoleX.parse(decoded['role']?.toString()) ??
            AttestationRole.offer,
        alias: decoded['alias']?.toString() ?? '',
        nonce: decoded['nonce']?.toString() ?? '',
        echo: decoded['echo']?.toString() ?? '',
        issuedAtMs: (decoded['ts'] as num?)?.toInt() ?? 0,
        publicKeyB64: decoded['key']?.toString() ?? '',
        signatureB64: decoded['sig']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where a device's Ed25519 keypair lives.
///
/// An interface rather than a direct `FlutterSecureStorage` call, for one
/// concrete reason: the protocol cannot be tested without holding TWO
/// independent identities at once, and `flutter_secure_storage`'s mock is a
/// single process-global map — so swapping a namespace in and out means the
/// second "device" reads the first one's key back. That is not a mock
/// limitation to shrug at, it is a sign that the storage is load-bearing
/// behaviour and belongs behind a seam. Production behaviour is unchanged:
/// [keyStore] defaults to [SecureStorageAttestationKeyStore].
abstract class AttestationKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The production store: the platform keystore, via `flutter_secure_storage`.
class SecureStorageAttestationKeyStore implements AttestationKeyStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Per-install Ed25519 identity for the fellowship handshake.
///
/// Deliberately SEPARATE from `SponsorLinkService`'s keypair: that one means
/// "I am a sponsor signing clinical step-work", this one means "this install
/// attended a room". Sharing a key would mean a sponsor's signing identity and
/// a peer's attendance identity are the same value, so a leaked attendance key
/// is also a leaked signing key. Separate keys, separate secure-storage entries.
class FellowshipAttestationService {
  const FellowshipAttestationService._();

  static const String _keyPrivate = 'fellowship_id_private_v1';
  static const String _keyPublic = 'fellowship_id_public_v1';

  static final Ed25519 _algo = Ed25519();

  /// The store holding this device's keypair. Swapped by tests; never swapped
  /// in production.
  @visibleForTesting
  static AttestationKeyStore keyStore = SecureStorageAttestationKeyStore();

  /// Shorter than the 10-minute code expiry on purpose. The exchange should
  /// complete across a table in under two minutes; a five-minute ceiling means
  /// a walked-away phone fails closed quickly instead of sitting valid.
  static const Duration maxAge = Duration(minutes: 5);

  /// The length of an alias accepted from a peer, and the control characters
  /// stripped from it. The peer chooses this string and it reaches the
  /// database and a SnackBar.
  static const int maxAliasLength = 40;
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  static String sanitizeAlias(String raw) =>
      raw.replaceAll(_controlChars, '').trim();

  /// True when [alias] is safe to store and display.
  ///
  /// Trims before testing, because the only caller that matters does
  /// `isAcceptableAlias(sanitizeAlias(...))` — and an untrimmed version would
  /// accept a whitespace-only alias that the sanitiser had just reduced to the
  /// empty string. A predicate that disagrees with its own call site is a trap.
  static bool isAcceptableAlias(String alias) {
    final trimmed = alias.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxAliasLength;
  }

  /// A short, human-typeable nonce. 128 bits of [Random.secure]; not a secret,
  /// but unpredictable so an attacker cannot pre-compute an `echo`.
  static String newNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// This install's public key, creating the keypair on first use.
  static Future<String> publicKeyB64() async {
    final existing = await keyStore.read(_keyPublic);
    if (existing != null && existing.isNotEmpty) return existing;

    final pair = await _algo.newKeyPair();
    final pub = base64Encode((await pair.extractPublicKey()).bytes);
    final priv = base64Encode(await pair.extractPrivateKeyBytes());
    await keyStore.write(_keyPublic, pub);
    await keyStore.write(_keyPrivate, priv);
    return pub;
  }

  /// Builds and signs a payload for [role].
  ///
  /// [nonce] is the nonce this device issued; [echo] is the nonce being
  /// answered, empty on the first step.
  static Future<AttestationPayload> sign({
    required AttestationRole role,
    required String alias,
    required String nonce,
    String echo = '',
    DateTime? now,
  }) async {
    final pub = await publicKeyB64();
    final privB64 = await keyStore.read(_keyPrivate);
    if (privB64 == null || privB64.isEmpty) {
      throw StateError('This device has no fellowship identity.');
    }
    final payload = AttestationPayload(
      version: kFellowshipAttestationVersion,
      role: role,
      alias: sanitizeAlias(alias),
      nonce: nonce,
      echo: echo,
      issuedAtMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      publicKeyB64: pub,
      signatureB64: '',
    );
    final pair = await _algo.newKeyPairFromSeed(
        base64Decode(privB64).sublist(0, 32));
    final sig = await _algo.signString(payload.signingMessage, keyPair: pair);
    return AttestationPayload(
      version: payload.version,
      role: payload.role,
      alias: payload.alias,
      nonce: payload.nonce,
      echo: payload.echo,
      issuedAtMs: payload.issuedAtMs,
      publicKeyB64: payload.publicKeyB64,
      signatureB64: base64Url.encode(sig.bytes).replaceAll('=', ''),
    );
  }

  /// Full acceptance test for a scanned payload.
  ///
  /// [expectedNonce] is the nonce this device issued and is waiting to see
  /// echoed. Pass null for the FIRST step (scanning somebody's offer), where
  /// there is nothing to echo yet and the only question is whether the
  /// signature is genuine and the code is fresh.
  ///
  /// [requiredRole] rejects a role the current step cannot accept, so a peer
  /// cannot skip the middle of the exchange by sending a `confirm` where an
  /// `answer` is expected.
  static Future<AttestationResult> verify(
    String raw, {
    required AttestationRole requiredRole,
    String? expectedNonce,
    DateTime? now,
  }) async {
    final payload = AttestationPayload.tryDecode(raw);
    if (payload == null) {
      return const AttestationResult.failed(AttestationFailure.malformed);
    }
    if (payload.version != kFellowshipAttestationVersion) {
      return const AttestationResult.failed(AttestationFailure.versionMismatch);
    }
    if (payload.role != requiredRole) {
      // Wrong step in the sequence. Reported as a nonce mismatch rather than a
      // new enum value: from the user's side it is the same instruction — ask
      // them to refresh and start again.
      return const AttestationResult.failed(AttestationFailure.nonceMismatch);
    }
    if (payload.publicKeyB64.isEmpty || payload.signatureB64.isEmpty) {
      return const AttestationResult.failed(AttestationFailure.unsigned);
    }
    if (expectedNonce != null && payload.echo != expectedNonce) {
      // Checked BEFORE the signature because it is cheaper, and because it is
      // the replay test: a photographed offer cannot echo a nonce that did not
      // exist when it was photographed.
      return const AttestationResult.failed(AttestationFailure.nonceMismatch);
    }

    final clock = now ?? DateTime.now();
    final ageMs = clock.millisecondsSinceEpoch - payload.issuedAtMs;
    if (ageMs.abs() > maxAge.inMilliseconds) {
      return const AttestationResult.failed(AttestationFailure.expired);
    }

    try {
      final key = SimplePublicKey(base64Decode(payload.publicKeyB64),
          type: KeyPairType.ed25519);
      final sig = Signature(
        base64Url.decode(base64Url.normalize(payload.signatureB64)),
        publicKey: key,
      );
      final ok = await _algo.verifyString(payload.signingMessage, signature: sig);
      if (!ok) {
        return const AttestationResult.failed(AttestationFailure.badSignature);
      }
    } catch (e) {
      debugPrint('[fellowship] signature check threw: $e');
      return const AttestationResult.failed(AttestationFailure.badSignature);
    }

    // The signature covers the nonces, not the display name — a peer is allowed
    // to be called whatever they like. It is still sanitised and bounded before
    // it can reach the database or a SnackBar.
    if (!isAcceptableAlias(sanitizeAlias(payload.alias))) {
      return const AttestationResult.failed(AttestationFailure.malformed);
    }

    return AttestationResult.verified(payload);
  }

  /// The short, human-readable identity shown in the UI.
  ///
  /// The first four bytes of the key in the same unambiguous alphabet the
  /// sponsor pairing code uses (no I/L/O/0/1), so it can be read aloud across a
  /// table or typed from a paper note.
  static String shortFingerprint(String publicKeyB64) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    try {
      final bytes = base64Decode(publicKeyB64);
      final out = StringBuffer();
      for (var i = 0; i < 4 && i < bytes.length; i++) {
        out.write(alphabet[bytes[i] % alphabet.length]);
      }
      return out.toString();
    } catch (_) {
      return '????';
    }
  }
}