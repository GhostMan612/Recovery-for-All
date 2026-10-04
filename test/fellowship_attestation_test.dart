// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Regression + protocol cover for the fellowship handshake's CRYPTOGRAPHY.
//
// A tester filed "the QR code fellowship handshake doesn't do anything, even
// after doing the handshake". Four separate defects stacked behind that one
// symptom, and NONE of them was about the QR code:
//
//   1. The +50 XP was written straight to Drift through a raw `save()`, while
//      the dashboard reads pet state from a ONE-SHOT snapshot in a plain
//      `Notifier` with no stream subscription, and the nav shell is an
//      `IndexedStack` that never rebuilds. The reward was real, persisted, and
//      invisible until a process restart.
//   2. `MobileScannerController` defaults to `DetectionSpeed.normal`, which
//      re-fires `onDetect` every frame. The screen never stopped the scanner, so
//      the success message was overwritten by "Already synced..." within a
//      second — the user saw the failure, never the success.
//   3. The result was recorded and then discarded: `getAllFellowshipSyncs()` had
//      zero call sites.
//   4. The exchange was ONE-DIRECTIONAL and the 24-hour cooldown was keyed on
//      the peer-chosen ALIAS, so "BrightOak" -> "BrightOak2" defeated the limit
//      entirely and the XP was farmable.
//
// This file covers defects 1, 3 and 4 AS BEHAVIOUR: the three signed legs, the
// nonce echo, replay refusal, tamper detection, expiry, and the cooldown that is
// keyed on something the peer cannot rename. Defect 2 and the SCREEN-WIRING
// ordering (verify strictly before the reward) live in
// `fellowship_handshake_test.dart`, because those are only observable from the
// source of a method with no seam.
//
// TWO REAL BUGS THIS FILE CAUGHT IN ITS OWN FIRST DRAFT, both left in the code
// as comments because a test that only ever passed teaches nothing:
//
//   * `'...$role.wire|...'` — Dart interpolates ONLY `role`, so all three legs
//     signed the identical string and the role was not part of the signature at
//     all. F2 (both sides sign BOTH nonces) was quietly false.
//   * Two "devices" cannot be simulated by swapping one process-global
//     `flutter_secure_storage` mock — the second reads the first one's key back.
//     Hence `AttestationKeyStore`.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/fellowship_attestation_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/services/xp_engine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store per simulated device.
class _MemStore implements AttestationKeyStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

/// Runs [body] as the device holding [store]'s keypair.
Future<T> _asDevice<T>(AttestationKeyStore store, Future<T> Function() body) async {
  final prev = FellowshipAttestationService.keyStore;
  FellowshipAttestationService.keyStore = store;
  try {
    return await body();
  } finally {
    FellowshipAttestationService.keyStore = prev;
  }
}

Future<AttestationPayload> _sign(
  AttestationKeyStore store,
  AttestationRole role,
  String alias,
  String nonce,
  DateTime at, {
  String echo = '',
}) =>
    _asDevice(
      store,
      () => FellowshipAttestationService.sign(
        role: role,
        alias: alias,
        nonce: nonce,
        echo: echo,
        now: at,
      ),
    );

Future<AttestationResult> _verify(
  AttestationKeyStore store,
  String raw, {
  required AttestationRole role,
  String? expectNonce,
  required DateTime at,
}) =>
    _asDevice(
      store,
      () => FellowshipAttestationService.verify(
        raw,
        requiredRole: role,
        expectedNonce: expectNonce,
        now: at,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 2, 12, 0);

  group('signed payload shape', () {
    test('the payload carries no PII by construction', () {
      final p = AttestationPayload(
        version: kFellowshipAttestationVersion,
        role: AttestationRole.offer,
        alias: 'BrightOak',
        nonce: 'nonce-a',
        echo: '',
        issuedAtMs: now.millisecondsSinceEpoch,
        publicKeyB64: 'AAAA',
        signatureB64: 'BBBB',
      );
      expect(p.toJson().keys.toSet(),
          {'v', 'role', 'alias', 'nonce', 'echo', 'ts', 'key', 'sig'});

      final round = AttestationPayload.tryDecode(p.encode());
      expect(round, isNotNull);
      expect(round!.role, AttestationRole.offer);
      expect(round.nonce, 'nonce-a');
      expect(round.publicKeyB64, 'AAAA');
    });

    test('the signed message binds the role AND both nonces', () {
      // This is the whole protocol in one string, and it is asserted
      // EXACTLY rather than via "it verifies", because the first draft wrote
      // `'$role.wire|...'` — Dart interpolated only `role`, so all three legs
      // signed an identical string and the role was not covered at all.
      AttestationPayload at(AttestationRole role, String nonce, String echo) =>
          AttestationPayload(
            version: kFellowshipAttestationVersion,
            role: role,
            alias: 'A',
            nonce: nonce,
            echo: echo,
            issuedAtMs: 0,
            publicKeyB64: '',
            signatureB64: '',
          );

      expect(at(AttestationRole.answer, 'nB', 'nA').signingMessage,
          'answer|A|nB|nA');
      expect(at(AttestationRole.confirm, 'nA', 'nB').signingMessage,
          'confirm|A|nA|nB');
      expect(at(AttestationRole.offer, 'nA', '').signingMessage, 'offer|A|nA|-');

      // The three legs must be three DIFFERENT messages. If this fails, a
      // signature minted for one leg verifies for another.
      final messages = {
        at(AttestationRole.offer, 'nA', '').signingMessage,
        at(AttestationRole.answer, 'nB', 'nA').signingMessage,
        at(AttestationRole.confirm, 'nA', 'nB').signingMessage,
      };
      expect(messages, hasLength(3),
          reason: 'a role change must change what is signed');
    });

    test('the alias is INSIDE the signed envelope', () {
      // The first draft signed only role+nonces, so an edited alias travelled
      // as a valid code. The cooldown does not depend on it (that keys on the
      // public key), but one unsigned caller-supplied displayed field is one
      // attacker-chosen field too many.
      AttestationPayload withAlias(String alias) => AttestationPayload(
            version: kFellowshipAttestationVersion,
            role: AttestationRole.offer,
            alias: alias,
            nonce: 'nA',
            echo: '',
            issuedAtMs: 0,
            publicKeyB64: '',
            signatureB64: '',
          );
      expect(withAlias('QuietRiver').signingMessage,
          isNot(withAlias('SomeoneElse').signingMessage),
          reason: 'the alias must change what is signed');
      expect(withAlias('QuietRiver').signingMessage, contains('QuietRiver'));
    });

    test('an empty echo is a placeholder, never an empty segment', () {
      // So 'a||b' can never be confused with a payload whose echo is missing.
      final p = AttestationPayload(
        version: kFellowshipAttestationVersion,
        role: AttestationRole.offer,
        alias: 'A',
        nonce: 'nA',
        echo: '',
        issuedAtMs: 0,
        publicKeyB64: '',
        signatureB64: '',
      );
      expect(p.signingMessage, contains('|-'));
      expect(p.signingMessage.split('|').last, '-');
    });

    test('a malformed payload decodes to null rather than throwing', () {
      expect(AttestationPayload.tryDecode('not json'), isNull);
      expect(AttestationPayload.tryDecode('[1,2,3]'), isNull);
      expect(AttestationPayload.tryDecode(''), isNull);
    });

    test('alias sanitising strips control characters and bounds length', () {
      // The peer chooses this string and it reaches the database and a SnackBar.
      expect(FellowshipAttestationService.sanitizeAlias('Bright\u0000Oak'),
          'BrightOak');
      expect(FellowshipAttestationService.isAcceptableAlias('x' * 41), isFalse);
      expect(FellowshipAttestationService.isAcceptableAlias('x' * 40), isTrue);
      // A whitespace-only alias must fail, not pass. The first draft tested the
      // UNTRIMMED string here while the production call site passes the
      // sanitised one, so the predicate and its only caller disagreed.
      expect(FellowshipAttestationService.isAcceptableAlias('   '), isFalse);
      expect(
        FellowshipAttestationService.isAcceptableAlias(
            FellowshipAttestationService.sanitizeAlias('   ')),
        isFalse,
      );
    });

    test('nonces are unpredictable and unique', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(FellowshipAttestationService.newNonce());
      }
      expect(seen, hasLength(200), reason: 'nonces must not repeat');
    });

    test('the fingerprint uses an unambiguous alphabet', () {
      // I/L/O/0/1 are excluded because this is read aloud across a table or
      // typed from a paper note, which is the whole point of showing it.
      const ambiguous = 'ILO01';
      for (final key in [
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        '//////////8D//////////w==',
      ]) {
        final fp = FellowshipAttestationService.shortFingerprint(key);
        expect(fp, hasLength(4));
        for (final ch in fp.split('')) {
          expect(ambiguous.contains(ch), isFalse, reason: 'ambiguous "$ch"');
        }
      }
    });
  });

  group('the three-leg exchange', () {
    late _MemStore a;
    late _MemStore b;
    late String aKey;
    late String bKey;

    setUp(() async {
      a = _MemStore();
      b = _MemStore();
      aKey = await _asDevice(a, FellowshipAttestationService.publicKeyB64);
      bKey = await _asDevice(b, FellowshipAttestationService.publicKeyB64);
      expect(aKey, isNot(bKey),
          reason: 'two installs must not share an identity');
    });

    test('the full exchange verifies on both sides', () async {
      final nonceA = FellowshipAttestationService.newNonce();
      final nonceB = FellowshipAttestationService.newNonce();

      // Step 1 — A offers.
      final offer = await _sign(a, AttestationRole.offer, 'QuietRiver',
          nonceA, now);

      // Step 2 — B scans it, verifies A's signature, and answers.
      final bSeesOffer = await _verify(b, offer.encode(),
          role: AttestationRole.offer, at: now);
      expect(bSeesOffer.verified, isTrue, reason: bSeesOffer.message);
      expect(bSeesOffer.payload!.publicKeyB64, aKey);

      final answer = await _sign(
          b, AttestationRole.answer, 'BrightOak', nonceB, now,
          echo: bSeesOffer.payload!.nonce);

      // Step 3 — A scans the answer and verifies the echo.
      final aSeesAnswer = await _verify(a, answer.encode(),
          role: AttestationRole.answer, expectNonce: nonceA, at: now);
      expect(aSeesAnswer.verified, isTrue, reason: aSeesAnswer.message);

      // A confirms, so B can prove the same thing in reverse.
      final confirm = await _sign(
          a, AttestationRole.confirm, 'QuietRiver', nonceA, now,
          echo: aSeesAnswer.payload!.nonce);

      final bSeesConfirm = await _verify(b, confirm.encode(),
          role: AttestationRole.confirm, expectNonce: nonceB, at: now);
      expect(bSeesConfirm.verified, isTrue, reason: bSeesConfirm.message);
      expect(bSeesConfirm.payload!.publicKeyB64, aKey);
    });

    test('an answer echoing the WRONG nonce is refused', () async {
      // This is the cooldown/farming line: without the echo, B could answer a
      // challenge it never saw and A would still credit it.
      final answer = await _sign(
          b, AttestationRole.answer, 'BrightOak',
          FellowshipAttestationService.newNonce(), now,
          echo: 'somebody-elses-nonce');
      final r = await _verify(a, answer.encode(),
          role: AttestationRole.answer,
          expectNonce: 'my-own-nonce',
          at: now);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.nonceMismatch);
    });

    test('a replayed offer cannot be reused a second time', () async {
      // The nonce is what makes a code single-use. A photographed step-1 offer
      // is useless later because the answer A waits for must echo the nonce
      // from THIS pairing.
      final offer =
          await _sign(a, AttestationRole.offer, 'QuietRiver', 'nonce-first', now);

      final first = await _verify(b, offer.encode(),
          role: AttestationRole.offer, at: now);
      expect(first.verified, isTrue);

      // A starts a NEW pairing, so it is waiting on a different nonce.
      final replay = await _sign(
          b, AttestationRole.answer, 'BrightOak', 'nonce-b', now,
          echo: 'nonce-first');
      final second = await _verify(a, replay.encode(),
          role: AttestationRole.answer,
          expectNonce: 'nonce-second',
          at: now);
      expect(second.verified, isFalse);
      expect(second.failure, AttestationFailure.nonceMismatch);
    });

    test('a tampered payload fails the signature check', () async {
      final offer =
          await _sign(a, AttestationRole.offer, 'QuietRiver', 'nonce-a', now);
      // Flip the alias in the encoded JSON. Everything else is intact, so only
      // the SIGNATURE can catch this — there is no hash of the body.
      final tampered = offer.encode().replaceAll('QuietRiver', 'SomeoneElse');
      expect(tampered, isNot(offer.encode()),
          reason: 'the test must actually change the payload');

      final r = await _verify(b, tampered,
          role: AttestationRole.offer, at: now);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.badSignature);
    });

    test('a signature from one key does not verify under another', () async {
      final forged =
          await _sign(b, AttestationRole.offer, 'Impostor', 'nonce-a', now);
      // Relabel it as A's key — the classic "swap the identity" forgery.
      final swapped = AttestationPayload(
        version: forged.version,
        role: forged.role,
        alias: forged.alias,
        nonce: forged.nonce,
        echo: forged.echo,
        issuedAtMs: forged.issuedAtMs,
        publicKeyB64: aKey,
        signatureB64: forged.signatureB64,
      ).encode();

      final r = await _verify(b, swapped, role: AttestationRole.offer, at: now);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.badSignature);
    });

    test('a payload from another protocol version is refused', () async {
      final offer =
          await _sign(a, AttestationRole.offer, 'QuietRiver', 'n', now);
      final bumped = AttestationPayload(
        version: kFellowshipAttestationVersion + 1,
        role: offer.role,
        alias: offer.alias,
        nonce: offer.nonce,
        echo: offer.echo,
        issuedAtMs: offer.issuedAtMs,
        publicKeyB64: offer.publicKeyB64,
        signatureB64: offer.signatureB64,
      ).encode();
      final r = await _verify(b, bumped, role: AttestationRole.offer, at: now);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.versionMismatch);
    });

    test('the wrong leg of the exchange is refused', () async {
      // An invitee expecting a confirm must not accept an offer: without this,
      // the third leg could be skipped entirely, which is precisely the hole
      // that lets an invitee self-reward unilaterally.
      final confirm = await _sign(a, AttestationRole.confirm, 'QuietRiver',
          'nA', now, echo: 'nB');
      final r = await _verify(b, confirm.encode(),
          role: AttestationRole.answer, expectNonce: 'nB', at: now);
      expect(r.verified, isFalse);
    });

    test('an expired code is refused', () async {
      final offer =
          await _sign(a, AttestationRole.offer, 'QuietRiver', 'n', now);
      final late =
          now.add(FellowshipAttestationService.maxAge + const Duration(minutes: 1));
      final r = await _verify(b, offer.encode(),
          role: AttestationRole.offer, at: late);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.expired);
    });

    test('a code dated far in the future is refused', () async {
      // A phone with a badly wrong clock must not mint an unbounded code.
      final offer =
          await _sign(a, AttestationRole.offer, 'QuietRiver', 'n', now);
      final r = await _verify(b, offer.encode(),
          role: AttestationRole.offer,
          at: now.subtract(const Duration(hours: 8)));
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.expired);
    });
  });

  group('legacy payloads are refused, never downgraded', () {
    // The old wire format was `{alias, ts}`. Accepting it would silently drop
    // every guarantee for anyone on an older build, so it is rejected outright
    // and the message names the reason.
    late _MemStore device;

    setUp(() => device = _MemStore());

    test('an unsigned {alias, ts} code is refused', () async {
      final r = await _verify(
        device,
        jsonEncode({'alias': 'BrightOak', 'ts': now.millisecondsSinceEpoch}),
        role: AttestationRole.offer,
        at: now,
      );
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.versionMismatch);
    });

    test('a v2 payload with the signature stripped is refused', () async {
      final key = await _asDevice(device, FellowshipAttestationService.publicKeyB64);
      final bare = AttestationPayload(
        version: kFellowshipAttestationVersion,
        role: AttestationRole.offer,
        alias: 'BrightOak',
        nonce: 'n',
        echo: '',
        issuedAtMs: now.millisecondsSinceEpoch,
        publicKeyB64: key,
        signatureB64: '',
      ).encode();
      final r = await _verify(device, bare,
          role: AttestationRole.offer, at: now);
      expect(r.verified, isFalse);
      expect(r.failure, AttestationFailure.unsigned);
    });
  });

  group('cooldown is keyed on the peer KEY, not the peer-chosen alias', () {
    late Directory tempDir;
    late RecoveryDatabase db;
    RecoveryDatabase? previousDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fellowship_test');
      db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
      SharedPreferences.setMockInitialValues({});
      previousDb = RecoveryPetService.database;
      RecoveryPetService.bindDatabase(db);
    });

    tearDown(() async {
      RecoveryPetService.bindDatabase(previousDb);
      await db.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<void> addSync({
      required String alias,
      String? key,
      int? at,
    }) =>
        db.addFellowshipSync(FellowshipSync(
          id: 'sync_${at ?? DateTime.now().microsecondsSinceEpoch}',
          peerAlias: alias,
          timestamp: at ?? now.millisecondsSinceEpoch,
          xpAwarded: 50,
          peerKeyB64: key,
          attested: key == null ? 0 : 1,
          role: key == null ? null : 'inviter',
        ));

    test('the same key is blocked regardless of what it calls itself',
        () async {
      // THE bug. The old cooldown read the alias, so renaming defeated it.
      await addSync(alias: 'BrightOak', key: 'KEY-1');
      final window =
          now.millisecondsSinceEpoch - const Duration(hours: 1).inMilliseconds;
      final blocked = await db.getRecentFellowshipSyncsForPeerKey('KEY-1', window);
      expect(blocked, hasLength(1));
      expect(blocked.single.peerAlias, 'BrightOak');

      // Same person, new name — still blocked, because the key is unchanged.
      // The alias lookup for the NEW name finds nothing, which is exactly why
      // the alias cannot be the key.
      expect(
        await db.getRecentFellowshipSyncsForPeer('BrightOak2', window),
        isEmpty,
      );
      expect(
        (await db.getRecentFellowshipSyncsForPeerKey('KEY-1', window)).single.peerAlias,
        'BrightOak',
        reason: 'the key, not the name, is what still matches',
      );
    });

    test('a different key is not blocked', () async {
      await addSync(alias: 'BrightOak', key: 'KEY-1');
      final other = await db.getRecentFellowshipSyncsForPeerKey(
          'KEY-2',
          now.millisecondsSinceEpoch - const Duration(hours: 1).inMilliseconds);
      expect(other, isEmpty);
    });

    test('the same key outside the window is allowed again', () async {
      await addSync(
          alias: 'BrightOak',
          key: 'KEY-1',
          at: now.subtract(const Duration(hours: 30)).millisecondsSinceEpoch);
      final blocked = await db.getRecentFellowshipSyncsForPeerKey(
          'KEY-1',
          now.millisecondsSinceEpoch - const Duration(hours: 24).inMilliseconds);
      expect(blocked, isEmpty);
    });

    test('a legacy row with no key is still findable by alias', () async {
      // So a user who synced yesterday under the old protocol cannot bank a
      // second grant today just because their old row has a null key.
      await addSync(alias: 'BrightOak');
      final window =
          now.millisecondsSinceEpoch - const Duration(hours: 1).inMilliseconds;
      final byAlias =
          await db.getRecentFellowshipSyncsForPeer('BrightOak', window);
      expect(byAlias, hasLength(1));
      expect(byAlias.single.attested, 0);
      expect(byAlias.single.peerKeyB64, isNull);
      expect(await db.getRecentFellowshipSyncsForPeerKey('anything', window),
          isEmpty);
    });

    test('an attested row round-trips its key, flag and role', () async {
      await addSync(alias: 'BrightOak', key: 'KEY-X');
      final rows = await db.getAllFellowshipSyncs();
      final row = rows.firstWhere((r) => r.peerAlias == 'BrightOak');
      expect(row.peerKeyB64, 'KEY-X');
      expect(row.attested, 1);
      expect(row.role, 'inviter');
    });
  });

  group('XP grant is transactional and audited', () {
    late Directory tempDir;
    late RecoveryDatabase db;
    RecoveryDatabase? previousDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fellowship_test');
      db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
      // `ensureHatched()` — called inside every grant — reads and writes
      // SharedPreferences. Without a mock platform it throws, the surrounding
      // transaction rolls back, and the audit event disappears with the XP.
      SharedPreferences.setMockInitialValues({});
      previousDb = RecoveryPetService.database;
      RecoveryPetService.bindDatabase(db);
    });

    tearDown(() async {
      RecoveryPetService.bindDatabase(previousDb);
      await db.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    /// All events, read directly rather than via `watchPetEvents(...).first`,
    /// which can emit its pre-write snapshot.
    Future<List<PetEventRow>> events() => db.select(db.petEvents).get();

    test('fellowship_sync is a known XP action, not a silent default', () {
      // `processAction` used to fall back to `_xpMap[type] ?? 10`, so a typo in
      // an event name quietly awarded 10 XP forever — a number nobody chose and
      // nobody could see.
      expect(XpEngineService.xpFor('fellowship_sync'), 50);
      expect(XpEngineService.xpFor('not_a_real_action'), isNull);
    });

    test('grantXp adds XP AND writes exactly one audit event', () async {
      await XpEngineService.grantXp(db, 50, actionType: 'fellowship_sync');

      final rows = await events();
      final xp = rows.where((e) => e.eventType == 'xp_fellowship_sync');
      expect(xp, hasLength(1),
          reason: 'a grant with no audit event cannot be explained later');
      expect(jsonDecode(xp.single.metaJson!)['xp'], 50);

      final pet = await db.getPet(RecoveryPetService.defaultPetId);
      expect(pet!.pathXp, 50,
          reason: 'the XP the user was promised must actually be stored');
    });

    test('a second grant accumulates rather than overwriting', () async {
      await XpEngineService.grantXp(db, 50, actionType: 'fellowship_sync');
      await XpEngineService.grantXp(db, 50, actionType: 'fellowship_sync');

      final pet = await db.getPet(RecoveryPetService.defaultPetId);
      expect(pet!.pathXp, 100);
      final rows = await events();
      expect(rows.where((e) => e.eventType == 'xp_fellowship_sync'),
          hasLength(2),
          reason: 'each grant needs its own audit event');
    });

    test('the audit event records that the handshake was attested', () async {
      // Without this, an explainer months later cannot tell a verified pairing
      // from an unverified one, which is the difference the whole protocol
      // exists to create.
      await XpEngineService.grantXp(
        db,
        50,
        actionType: 'fellowship_sync',
        metaJson: jsonEncode({
          'peerAlias': 'BrightOak',
          'xp': 50,
          'attested': true,
          'role': 'inviter',
        }),
      );
      final rows = await events();
      final event = rows.firstWhere((e) => e.eventType == 'xp_fellowship_sync');
      final meta = jsonDecode(event.metaJson!) as Map<String, dynamic>;
      expect(meta['peerAlias'], 'BrightOak');
      expect(meta['attested'], isTrue);
      expect(meta['role'], 'inviter');
    });
  });
}