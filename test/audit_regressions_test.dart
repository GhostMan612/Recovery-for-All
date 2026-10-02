// Regression tests for the audit-batch fixes.

//
// Each test fails if its fix is reverted. The `*ForTest` shims are thin
// `@visibleForTesting` wrappers over private statics that were the actual
// defect sites; they add no behaviour of their own.
//
// Run: flutter test test/audit_regressions_test.dart
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:recovery_for_all/core/meeting_radius_logic.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/constellation_service.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/services/map_tile_cache.dart';
import 'package:recovery_for_all/services/resource_link_health.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/services/sponsor_link_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('meeting feed parsing: third-party data cannot crash or lie', () {
    test('a day index of 7 does not index past the weekday table', () {
      // `_weekdays[dayIndex]` used to throw RangeError for a feed sending "7".
      expect(MeetingFinderService.firstDayForTest('7'), isNull);
      expect(MeetingFinderService.firstDayForTest('6'), 6);
      expect(MeetingFinderService.firstDayForTest('0'), 0);
      expect(MeetingFinderService.firstDayForTest(7), isNull);
      expect(MeetingFinderService.firstDayForTest(-1), isNull);
      expect(MeetingFinderService.firstDayForTest(['3', '5']), 3);
      expect(MeetingFinderService.firstDayForTest(['9']), isNull);
      expect(MeetingFinderService.firstDayForTest(<int>[]), isNull);
      expect(MeetingFinderService.firstDayForTest(null), isNull);
    });

    test('a 12-hour feed time is not read as AM', () {
      // "7:00 PM" parsed as h=7, so an evening meeting was labelled AM and
      // scheduled at 07:00 — it could never go live.
      expect(MeetingFinderService.parseMinutesForTest('7:00 PM'), 19 * 60);
      expect(MeetingFinderService.parseMinutesForTest('7:00 AM'), 7 * 60);
      expect(MeetingFinderService.parseMinutesForTest('12:00 AM'), 0);
      expect(MeetingFinderService.parseMinutesForTest('12:30 PM'), 12 * 60 + 30);
      expect(MeetingFinderService.parseMinutesForTest('11:45 pm'), 23 * 60 + 45);
      expect(MeetingFinderService.parseMinutesForTest('19:00'), 19 * 60);
      expect(MeetingFinderService.parseMinutesForTest('07:05'), 7 * 60 + 5);
      expect(MeetingFinderService.parseMinutesForTest('nonsense'), isNull);
      expect(MeetingFinderService.parseMinutesForTest('25:00'), isNull);
      expect(MeetingFinderService.parseMinutesForTest('13:00 PM'), isNull);
      expect(MeetingFinderService.parseMinutesForTest(null), isNull);
    });

    test('formatTime is consistent with the parser', () {
      expect(MeetingFinderService.formatTimeForTest('19:30'), '7:30 PM');
      expect(MeetingFinderService.formatTimeForTest('00:15'), '12:15 AM');
      expect(MeetingFinderService.formatTimeForTest('12:00'), '12:00 PM');
      expect(MeetingFinderService.formatTimeForTest('7:00 PM'), '7:00 PM');
    });
  });

  group('pairing code validation rejects arbitrary text', () {
    test('an unanchored regex made every 11-char string valid', () {
      // `!RegExp(r'[a-zA-Z0-9]').hasMatch(ch)` is unanchored, so the whole
      // &&-chain was unsatisfiable and the loop body unreachable.
      expect(SponsorLinkService.isValidPairingCodeFormat('!!!!!!!!!!!'), isFalse);
      expect(SponsorLinkService.isValidPairingCodeFormat('aaaaaaaaaaa'), isFalse);
      final code = SponsorLinkService.pairingCodeFromPublicKey(_pubKeyB64);
      expect(SponsorLinkService.isValidPairingCodeFormat(code), isTrue);
      expect(SponsorLinkService.isValidPairingCodeFormat('short'), isFalse);
      expect(SponsorLinkService.isValidPairingCodeFormat(''), isFalse);
    });
  });

  group('constellation stars are idempotent within a day', () {
    late RecoveryDatabase db;

    setUp(() {
      db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() async => db.close());

    test('repeated journal entries each get their own star', () async {
      await ConstellationService.addJournalStar(db);
      await ConstellationService.addJournalStar(db);
      await ConstellationService.addJournalStar(db);
      final points = await db.getConstellationPoints();
      expect(points.length, 3);
    });

    test('a milestone star is exactly idempotent', () async {
      await ConstellationService.addMilestoneStar(db, 'Sobriety', '30 days');
      await ConstellationService.addMilestoneStar(db, 'Sobriety', '30 days');
      final points = await db.getConstellationPoints();
      expect(points.length, 1,
          reason: 'the same chip must never produce a second star');
    });

    test('the day key is zero-padded, so day 1 never prefixes day 10', () {
      expect(ConstellationService.dayKeyForTest(DateTime(2026, 3, 1)), '2026-03-01');
      expect(ConstellationService.dayKeyForTest(DateTime(2026, 3, 10)), '2026-03-10');
      expect(ConstellationService.dayKeyForTest(DateTime(2026, 3, 1))
          .startsWith(ConstellationService.dayKeyForTest(DateTime(2026, 3, 10))),
          isFalse);
    });
  });

  group('database: atomic increments and moderation counts', () {
    late RecoveryDatabase db;

    setUp(() async {
      db = RecoveryDatabase.forTesting(
          NativeDatabase.memory() as QueryExecutor);
      await db.addWeeklyGoal(WeeklyGoal(
        id: 'g1',
        title: 'Meetings',
        targetCount: 3,
        currentCount: 0,
        isCompleted: false,
      ));
      await db.addFeedPost(FeedPost(
        id: 'p1',
        authorAlias: 'Anon',
        kind: 'story',
        body: 'hello',
        needsSupport: false,
        status: 'visible',
        flagCount: 0,
        strengthCount: 0,
        proudCount: 0,
        respectCount: 0,
        createdAt: 1,
        isMine: true,
      ));
    });
    tearDown(() async => db.close());

    test('two goal increments both land', () async {
      await db.incrementWeeklyGoal('g1');
      await db.incrementWeeklyGoal('g1');
      final rows = await db.watchAllWeeklyGoals().first;
      expect(rows.first.currentCount, 2);
    });

    test('isCompleted flips when the target is reached', () async {
      await db.incrementWeeklyGoal('g1');
      await db.incrementWeeklyGoal('g1');
      await db.incrementWeeklyGoal('g1');
      final rows = await db.watchAllWeeklyGoals().first;
      expect(rows.first.currentCount, 3);
      expect(rows.first.isCompleted, isTrue);
    });

    test('flagCount increments instead of being reset to 1', () async {
      await db.flagPost('p1');
      await db.flagPost('p1');
      await db.flagPost('p1');
      final post = await db.getFeedPost('p1');
      expect(post?.flagCount, 3,
          reason: 'flagCount: Value(1) reset a post 7 users had reported');
      expect(post?.status, 'pending');
    });

    test('an unknown reaction kind throws rather than silently no-op', () async {
      await db.reactToPost('p1', kind: 'respect');
      await expectLater(
          db.reactToPost('p1', kind: 'bogus'), throwsArgumentError);
    });

    test('each valid reaction kind increments only its own column', () async {
      await db.reactToPost('p1', kind: 'strength');
      await db.reactToPost('p1', kind: 'strength');
      await db.reactToPost('p1', kind: 'proud');
      final post = await db.getFeedPost('p1');
      expect(post?.strengthCount, 2);
      expect(post?.proudCount, 1);
      expect(post?.respectCount, 0);
    });

    test('the indexes exist, so watched queries are not full scans', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
          )
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('idx_journal_ts'));
      expect(names, contains('idx_pet_events_pet_ts'));
      expect(names, contains('idx_feed_status_created'));
      expect(names, contains('idx_feed_flag'));
      expect(names, contains('idx_checkin_ts'));
      expect(names, contains('idx_sync_peer_ts'));
      expect(names, contains('idx_points_ts'));
    });
  });

  group('meeting radius prefs: one owner per key string', () {
    test('the short aliases point at the same three keys', () {
      // The notifier referenced MeetingRadiusKeys.lat/lng/time, which did not
      // exist — so the restore path could never have compiled if reached.
      expect(MeetingRadiusPrefs.lat, MeetingRadiusPrefs.latKey);
      expect(MeetingRadiusPrefs.lng, MeetingRadiusPrefs.lngKey);
      expect(MeetingRadiusPrefs.time, MeetingRadiusPrefs.timeKey);
    });

    test('radius sanitising clamps and rejects nonsense', () {
      expect(MeetingRadiusPrefs.sanitizeRadiusMiles(null),
          MeetingRadiusPrefs.defaultRadiusMiles);
      expect(MeetingRadiusPrefs.sanitizeRadiusMiles(double.nan),
          MeetingRadiusPrefs.defaultRadiusMiles);
      expect(MeetingRadiusPrefs.sanitizeRadiusMiles(-5),
          MeetingRadiusPrefs.minRadiusMiles);
      expect(MeetingRadiusPrefs.sanitizeRadiusMiles(9999),
          MeetingRadiusPrefs.maxRadiusMiles);
      expect(MeetingRadiusPrefs.sanitizeRadiusMiles(12.5), 12.5);
    });
  });

  group('tile cache: mercator maths cannot produce NaN or Infinity', () {
    test('a latitude past the mercator limit clamps instead of throwing', () {
      // latToY used log() of a negative number -> NaN -> NaN.floor() throws
      // UnsupportedError, and the .clamp() was applied AFTER the floor.
      for (final lat in [85.1, 88.0, 89.9, 90.0, -90.0]) {
        final r = TilePrefetch.tileRangeForTest(
          lat: lat,
          lng: 0,
          radiusKm: 500,
          zoom: 8,
        );
        expect(r.xMin, greaterThanOrEqualTo(0));
        expect(r.xMax, lessThanOrEqualTo((1 << 8) - 1));
        expect(r.yMin, greaterThanOrEqualTo(0));
        expect(r.yMax, lessThanOrEqualTo((1 << 8) - 1));
      }
    });
  });

  group('link-health cache survives one malformed entry', () {
    test('a single bad entry must not wipe every other entry', () async {
      final prefs = await SharedPreferences.getInstance();
      // `ok` as a string, not a bool: the old `v['ok'] as bool?` threw and the
      // catch discarded the whole cache.
      await prefs.setString('resource_link_health_v1', jsonEncode({
        'https://good.example': {'ok': true, 'at': 111},
        'https://bad.example': {'ok': 'yes', 'at': 222},
        'https://also-good.example': {'ok': false, 'at': 333},
      }));
      final service = ResourceLinkHealth.instance;
      expect((await service.statusFor('https://good.example')).ok, isTrue);
      expect((await service.statusFor('https://also-good.example')).ok, isFalse);
      expect((await service.statusFor('https://bad.example')).ok, isNull,
          reason: 'malformed entry reads as never checked');
    });
  });

  group('recovery pet: the daily ledger records granted, not requested', () {
    test('copyWith is what preserves Trials progression', () {
      // The raw constructor's pathLevel/pathXp defaults are 1/0, so rebuilding
      // by hand silently zeroed earned XP on every cosmetic equip.
      final pet = RecoveryPet(
        id: 'active_pet',
        name: 'Tester',
        energy: 50,
        bond: 40,
        mood: PetMoodX.neutral,
        sparks: 42,
        unlockedItems: const ['a'],
        equippedOutfit: 'default',
        equippedSlots: const {},
        lastFedAt: 1,
        createdAt: 1,
        pathLevel: 7,
        pathXp: 350,
      );
      expect(pet.copyWith(equippedSlots: const {'aura': 'x'}).pathLevel, 7);
      expect(pet.copyWith(equippedSlots: const {'aura': 'x'}).pathXp, 350);
      expect(pet.copyWith(sparks: 99).pathLevel, 7);
    });

    test('a partially-granted action does not inflate the ledger', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recovery_pet_earn_day_v1',
          '${now.year}-${now.month}-${now.day}:146');
      await prefs.setString('recovery_pet_json_v1', _freshPetJson);

      await RecoveryPetService.logGrounding(); // asks 8, should grant 4
      expect(await RecoveryPetService.earnedToday(), 150,
          reason: 'ledger must reflect the 4 actually granted, not the 8 asked');
    });

    test('a fully-capped action leaves the ledger at the cap', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recovery_pet_earn_day_v1',
          '${now.year}-${now.month}-${now.day}:150');
      await prefs.setString('recovery_pet_json_v1', _freshPetJson);

      await RecoveryPetService.logGrounding();
      expect(await RecoveryPetService.earnedToday(), 150,
          reason: 'a zero grant must not advance the ledger at all');
    });
  });
}

const _freshPetJson =
    '{"id":"active_pet","name":"Tester","energy":1.0,"bond":0.0,'
    '"mood":"neutral","sparks":0,"unlockedItems":[],"equippedOutfit":"default",'
    '"equippedSlots":{},"speciesId":"ember_kit","lastFedAt":0,"createdAt":0}';

/// A deterministic 32-byte Ed25519-shaped public key, base64. Only the
/// fingerprint/checksum shape matters to the pairing-code test.
const _pubKeyB64 =
    'C2Vzc2F0ZWRSZWFsS2V5Rm9yVGVzdGluZ1B1cnBvc2VzT25seQ==';