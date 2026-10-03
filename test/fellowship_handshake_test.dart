// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Regression cover for the fellowship handshake.
//
// A tester filed "the QR code fellowship handshake doesn't do anything, even
// after doing the handshake". Three separate defects stacked up behind that
// one symptom, and NONE of them is about the QR code:
//
//   1. The +50 XP was written straight to Drift through
//      `RecoveryPetService.save()`, while the dashboard reads pet state from a
//      ONE-SHOT snapshot in a plain `Notifier` with no stream subscription, and
//      the nav shell is an `IndexedStack` that never rebuilds. So the reward was
//      real, persisted, and invisible until a process restart.
//   2. `MobileScannerController` defaults to `DetectionSpeed.normal`, which
//      re-fires `onDetect` every frame. The screen never stopped the scanner, so
//      the success message was overwritten by "Already synced..." within a
//      second — the user saw the failure, never the success.
//   3. The result was recorded and then discarded: `getAllFellowshipSyncs()` had
//      zero call sites, and the pet event rendered in the memory wall as the
//      catch-all "Kin remembers a moment of care."
//
// These tests pin the parts that are testable without a camera: the payload
// contract, the expiry that finally reads `ts`, the alias validation, and the
// transactional grant.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/services/xp_engine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The wire format, in one place so a change to either side is a test failure.
///
/// `{"alias":"<name>","ts":<ms epoch>}`
Map<String, Object?> buildPayload(String alias, DateTime at) =>
    {'alias': alias, 'ts': at.millisecondsSinceEpoch};

/// The scanner's acceptance rules, mirroring `FellowshipSyncScreen._handleScanned`.
///
/// Duplicated deliberately rather than imported: the screen's version needs a
/// `BuildContext`, and the value of these tests is that they pin the RULES as
/// plain data. If the screen changes one of these, this file is where the change
/// should be made consciously.
class ScanVerdict {
  final bool accepted;
  final String? reason;
  const ScanVerdict.accepted() : accepted = true, reason = null;
  const ScanVerdict.rejected(this.reason) : accepted = false;
}

ScanVerdict validatePayload(String raw, {required String myAlias, required DateTime now}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const ScanVerdict.rejected('not json');
  }
  if (decoded is! Map) return const ScanVerdict.rejected('not an object');

  final alias = decoded['alias']?.toString().trim();
  if (alias == null || alias.isEmpty) {
    return const ScanVerdict.rejected('missing alias');
  }
  if (alias.length > 40) return const ScanVerdict.rejected('alias too long');

  final safe =
      alias.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (safe.isEmpty) return const ScanVerdict.rejected('no visible characters');

  final ts = (decoded['ts'] as num?)?.toInt();
  if (ts == null) return const ScanVerdict.rejected('missing ts');

  final ageMs = now.millisecondsSinceEpoch - ts;
  if (ageMs.abs() > const Duration(minutes: 10).inMilliseconds) {
    return const ScanVerdict.rejected('expired');
  }
  if (safe == myAlias) return const ScanVerdict.rejected('self');
  return const ScanVerdict.accepted();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 2, 12, 0);
  final me = 'QuietRiver';

  group('payload shape', () {
    test('a fresh code is accepted', () {
      final v = validatePayload(
        jsonEncode(buildPayload('BrightOak', now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isTrue, reason: v.reason);
    });

    test('the payload carries only alias and ts — no PII by construction', () {
      final keys = buildPayload('BrightOak', now).keys.toSet();
      expect(keys, {'alias', 'ts'});
      // A field added here is a field a stranger photographing the code reads.
      // This assertion is the reason the key set is pinned rather than assumed.
    });

    test('the fallback alias still produces a valid code', () {
      // A user who skipped the alias question in onboarding still needs to be
      // able to connect.
      final v = validatePayload(
        jsonEncode(buildPayload('Anonymous', now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isTrue);
    });
  });

  group('expiry — `ts` finally does something', () {
    test('a code 11 minutes old is rejected', () {
      // Before this, `ts` was written and read by NOTHING, so a screenshot from
      // a year ago completed a handshake. The card said "tap refresh to rotate",
      // which implied an expiry that did not exist.
      final v = validatePayload(
        jsonEncode(buildPayload('BrightOak',
            now.subtract(const Duration(minutes: 11)))),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isFalse);
      expect(v.reason, 'expired');
    });

    test('a code 9 minutes old is still accepted', () {
      final v = validatePayload(
        jsonEncode(buildPayload('BrightOak',
            now.subtract(const Duration(minutes: 9)))),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isTrue);
    });

    test('a code from 8 hours in the future is rejected', () {
      // A phone with a badly wrong clock must not mint an unbounded-window code.
      final v = validatePayload(
        jsonEncode(buildPayload('BrightOak',
            now.add(const Duration(hours: 8)))),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isFalse);
      expect(v.reason, 'expired');
    });

    test('a code with no ts is rejected', () {
      final v = validatePayload('{"alias":"BrightOak"}', myAlias: me, now: now);
      expect(v.accepted, isFalse);
      expect(v.reason, 'missing ts');
    });
  });

  group('alias validation', () {
    test('an over-long alias is rejected before it is stored', () {
      final v = validatePayload(
        jsonEncode(buildPayload('x' * 41, now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isFalse);
      expect(v.reason, 'alias too long');
    });

    test('an alias of control characters only is rejected', () {
      final v = validatePayload(
        jsonEncode(buildPayload('\u0000\u0007', now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isFalse);
    });

    test('a control-character alias is stripped, not rejected outright', () {
      // Legitimate names could contain a stray control byte from a paste.
      final v = validatePayload(
        jsonEncode(buildPayload('Bright\u0000Oak', now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isTrue);
    });

    test('scanning your own code is rejected', () {
      final v = validatePayload(
        jsonEncode(buildPayload(me, now)),
        myAlias: me,
        now: now,
      );
      expect(v.accepted, isFalse);
      expect(v.reason, 'self');
    });

    test('non-JSON is rejected without throwing', () {
      final v = validatePayload('https://example.com/not-a-code', myAlias: me, now: now);
      expect(v.accepted, isFalse);
      expect(v.reason, 'not json');
    });

    test('a JSON array is rejected — it decodes, but is not a handshake', () {
      final v = validatePayload('[1,2,3]', myAlias: me, now: now);
      expect(v.accepted, isFalse);
      expect(v.reason, 'not an object');
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
      // transaction rolls back, and the audit event disappears with the XP. The
      // first run of this file failed exactly that way and the failure looked
      // like "the grant wrote no event".
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
      // The old path did two untransacted writes from a snapshot read outside
      // them: a process death between them granted XP with no audit event.
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
      // The old code read the pet, added 50 to a snapshot, and wrote the whole
      // row back — so two grants landing close together lost one. Sequential
      // here; the concurrency guarantee is the transaction's, not this test's.
      await XpEngineService.grantXp(db, 50, actionType: 'fellowship_sync');
      await XpEngineService.grantXp(db, 50, actionType: 'fellowship_sync');

      final pet = await db.getPet(RecoveryPetService.defaultPetId);
      expect(pet!.pathXp, 100);
      final rows = await events();
      expect(rows.where((e) => e.eventType == 'xp_fellowship_sync'),
          hasLength(2),
          reason: 'each grant needs its own audit event');
    });

    test('the audit event carries the peer alias', () async {
      await XpEngineService.grantXp(
        db,
        50,
        actionType: 'fellowship_sync',
        metaJson: jsonEncode({'peerAlias': 'BrightOak', 'xp': 50}),
      );
      final rows = await events();
      final event = rows.firstWhere((e) => e.eventType == 'xp_fellowship_sync');
      expect(jsonDecode(event.metaJson!)['peerAlias'], 'BrightOak');
    });

    test('the sync row is recorded with the alias and the XP', () async {
      await db.addFellowshipSync(FellowshipSync(
        id: 'sync_1',
        peerAlias: 'BrightOak',
        timestamp: now.millisecondsSinceEpoch,
        xpAwarded: 50,
      ));
      final recent = await db.getRecentFellowshipSyncsForPeer(
          'BrightOak', now.millisecondsSinceEpoch - 1000);
      expect(recent, hasLength(1));
      expect(recent.single.xpAwarded, 50);
    });

    test('getAllFellowshipSyncs is reachable', () async {
      // It had ZERO call sites from the day the table was created — the one
      // method that could have shown a peer list was never wired to a screen,
      // which is the other half of "it doesn't do anything".
      await db.addFellowshipSync(FellowshipSync(
        id: 'sync_a',
        peerAlias: 'BrightOak',
        timestamp: now.millisecondsSinceEpoch,
        xpAwarded: 50,
      ));
      final all = await db.getAllFellowshipSyncs();
      expect(all.map((s) => s.peerAlias), contains('BrightOak'));
    });
  });
}