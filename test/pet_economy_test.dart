// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Host tests for the Sparks economy laws (pet-store-rules.md):
// daily cap tapering, walk sub-cap, milestone cap-exemption, and the
// compassionate idle decay that makes Resting/Napping reachable.
// R28: Now tests use Drift NativeDatabase.memory for atomic pet state.

import 'dart:convert';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;

  setUp(() async {
    db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
    RecoveryPetService.bindDatabase(db);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
  });

  group('decayedEnergy (pure math)', () {
    final now = DateTime(2026, 8, 25, 12, 0);
    int ms(DateTime d) => d.millisecondsSinceEpoch;

    test('energy at or below the floor never decays further', () {
      expect(
        RecoveryPetService.decayedEnergy(
            RecoveryPetService.restingFloor,
            ms(now.subtract(const Duration(days: 30))),
            now),
        RecoveryPetService.restingFloor,
      );
    });

    test('within the 48 h grace period nothing decays', () {
      expect(
        RecoveryPetService.decayedEnergy(
            100, ms(now.subtract(const Duration(hours: 47))), now),
        100,
      );
      expect(
        RecoveryPetService.decayedEnergy(
            100, ms(now.subtract(const Duration(hours: 48))), now),
        100,
      );
    });

    test('decay starts a full day after grace (4/day)', () {
      // 72 h idle → 1 decay day.
      expect(
        RecoveryPetService.decayedEnergy(
            100, ms(now.subtract(const Duration(hours: 72))), now),
        96,
      );
      // 71 h → not yet a full post-grace day.
      expect(
        RecoveryPetService.decayedEnergy(
            100, ms(now.subtract(const Duration(hours: 71))), now),
        100,
      );
    });

    test('long abandonment floors at rest — never zero, never death', () {
      expect(
        RecoveryPetService.decayedEnergy(
            100, ms(now.subtract(const Duration(days: 30))), now),
        RecoveryPetService.restingFloor,
      );
      expect(
        RecoveryPetService.restingFloor,
        lessThan(25),
        reason: 'floor must sit inside the resting zone (< 25)',
      );
    });
  });

group('ensureHatched idle decay (Drift-backed)', () {
    Future<void> seedPet({
      required int energy,
      required DateTime lastFedAt,
    }) async {
      // Seed via Drift (R28: Drift is now source of truth)
      final pet = RecoveryPet(
        id: 'active_pet',
        name: 'Kin',
        energy: energy,
        bond: 40,
        mood: PetMoodX.neutral,
        sparks: 77,
        unlockedItems: ['starter_glow'],
        equippedOutfit: 'default',
        equippedSlots: <String, String>{},
        speciesId: 'ember_kit',
        lastFedAt: lastFedAt.millisecondsSinceEpoch,
        createdAt: lastFedAt.millisecondsSinceEpoch,
        pathLevel: 1,
        pathXp: 0,
      );
      // Manually upsert to Drift (bypassing service to set specific state)
      await RecoveryPetService.database!.upsertPet(
        RecoveryPetService.rowFromPet(pet),
      );
    }

    test('a week of quiet days winds the companion down', () async {
      await seedPet(
          energy: 60,
          lastFedAt:
              DateTime.now().subtract(const Duration(days: 7)));
      final pet = await RecoveryPetService.ensureHatched();
      // 7 days idle → 5 post-grace decay days → 60 − 20 = 40.
      expect(pet.energy, 40);
      expect(pet.isResting, isFalse);
      expect(pet.bond, 40, reason: 'Bond never decays');
      expect(pet.sparks, 77, reason: 'Sparks never decay');

      // Decay persists in Drift so every surface agrees.
      final row = await db.getPet('active_pet');
      expect(row!.energy, 0.4); // DB stores 0.0-1.0 scale
    });

    test('long absence reaches Resting — glad you are back', () async {
      await seedPet(
          energy: 40,
          lastFedAt:
              DateTime.now().subtract(const Duration(days: 12)));
      final pet = await RecoveryPetService.ensureHatched();
      // 12 days idle would be 40 − 40 → floored at 20 (resting zone).
      expect(pet.energy, RecoveryPetService.restingFloor);
      expect(pet.isResting, isTrue);
      expect(pet.mood, PetMoodX.neutral,
          reason: 'tone law: resting, never sad');
    });

    test('recent interaction leaves the pet untouched', () async {
      await seedPet(
          energy: 90,
          lastFedAt:
              DateTime.now().subtract(const Duration(hours: 10)));
      final pet = await RecoveryPetService.ensureHatched();
      expect(pet.energy, 90);
    });
  });

  group('Sparks daily cap (store-rule #1)', () {
    setUp(() async {
      // Ensure fresh pet for each test
      await db.deleteAllPetData();
    });

    test('capped streams taper at 150 across a day of care', () async {
      final pet0 = await RecoveryPetService.ensureHatched();
      expect(pet0.sparks, 0);

      // Two walks pay in full (2 × 15) — and are CAP-EXEMPT.
      await RecoveryPetService.logWalk(requireVerification: false);
      await RecoveryPetService.logWalk(requireVerification: false);
      var pet = await RecoveryPetService.ensureHatched();
      expect(pet.sparks, 30);

      // A third walk is walk-capped before economics even apply.
      await RecoveryPetService.logWalk(requireVerification: false);
      pet = await RecoveryPetService.ensureHatched();
      expect(pet.sparks, 30);

      // Groundings (capped stream) fill all 150 of the global cap:
      // 18 × 8 = 144, then the 19th partially grants the last 6.
      for (var i = 0; i < 19; i++) {
        await RecoveryPetService.logGrounding();
      }
      pet = await RecoveryPetService.ensureHatched();
      expect(pet.sparks, 30 + 150);

      // Further grounded earning is tapered to zero…
      await RecoveryPetService.logGrounding();
      pet = await RecoveryPetService.ensureHatched();
      expect(pet.sparks, 180);
      // …while the audit ledger keeps counting honest effort
      // (exempt walks never touched it).
      expect(await RecoveryPetService.earnedToday(), 20 * 8);
    });

    test('partial grant right under the cap', () async {
      final now = DateTime.now();
      final dayKey =
          '${now.year}-${now.month}-${now.day}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recovery_pet_earn_day_v1', '$dayKey:146');

      final pet = await RecoveryPetService.logGrounding(); // asks 8
      expect(pet.sparks, 4, reason: 'only 4 of the 150 remain today');
    });

    test('milestones are CAP-EXEMPT — a chip always pays in full',
        () async {
      // Exhaust the normal cap first.
      for (var i = 0; i < 19; i++) {
        await RecoveryPetService.logGrounding();
      }
      final capped = await RecoveryPetService.ensureHatched();
      expect(capped.sparks, 150);
      final ledgerAtCap = await RecoveryPetService.earnedToday();

      final pet = await RecoveryPetService.logMilestone('1 Year');
      expect(pet.sparks, 250,
          reason:
              'milestone bypasses the taper entirely (store-rules §1)');
      expect(await RecoveryPetService.earnedToday(), ledgerAtCap,
          reason: 'exempt rewards never consume the daily allowance');
      expect(pet.bond, greaterThanOrEqualTo(5));
    });

    test('meetings are CAP-EXEMPT — showing up always counts', () async {
      for (var i = 0; i < 19; i++) {
        await RecoveryPetService.logGrounding();
      }
      final capped = await RecoveryPetService.ensureHatched();
      expect(capped.sparks, 150);

      final pet = await RecoveryPetService.logMeeting();
      expect(pet.sparks, 158,
          reason: '+8 meeting Sparks land on top of a full cap');
      expect(await RecoveryPetService.earnedToday(), 152,
          reason: 'exempt rewards never consume the daily allowance');
    });

    test('walks are CAP-EXEMPT — movement always counts', () async {
      for (var i = 0; i < 19; i++) {
        await RecoveryPetService.logGrounding();
      }
      final capped = await RecoveryPetService.ensureHatched();
      expect(capped.sparks, 150);

      final pet = await RecoveryPetService.logWalk(requireVerification: false);
      expect(pet.sparks, 165,
          reason: '+15 walk Sparks land on top of a full cap');
      expect(await RecoveryPetService.earnedToday(), 152,
          reason: 'exempt rewards never consume the daily allowance');
    });
  });

  group('walk sub-cap accounting', () {
    test('counter resets across days (keyed by date)', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recovery_pet_walk_day_v1',
          '${now.year}-${now.month}-${now.day}:2');

      final before = await RecoveryPetService.ensureHatched();
      final after = await RecoveryPetService.logWalk(requireVerification: false);
      expect(after.sparks, before.sparks,
          reason: 'third walk today earns nothing');
    });

    test("yesterday's walk count no longer binds", () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recovery_pet_walk_day_v1',
          '${yesterday.year}-${yesterday.month}-${yesterday.day}:2');

      final before = await RecoveryPetService.ensureHatched();
      final after = await RecoveryPetService.logWalk(requireVerification: false);
      expect(after.sparks, before.sparks + 15,
          reason: 'new day, fresh walks');
    });
  });

  group('daily gentle quest (P3.1)', () {
    test('returns a valid catalog invitation, stable within the day',
        () async {
      final a = await RecoveryPetService.todayQuest();
      final b = await RecoveryPetService.todayQuest();
      expect(RecoveryPetService.questCatalog.containsKey(a.id), isTrue);
      expect(a.id, b.id);
      expect(a.title, isNotEmpty);
      expect(a.done, isFalse);
    });

    test('completing the invited action grants +10 exactly once', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pet_quest_v1',
        jsonEncode({
          'date': '${now.year}-${now.month}-${now.day}',
          'id': 'gratitude',
          'done': false,
        }),
      );

      final first = await RecoveryPetService.logGratitude(); // 5 + 10
      expect(first.sparks, 15);

      final second = await RecoveryPetService.logGratitude(); // 5 only
      expect(second.sparks, 20,
          reason: 'quest bonus must not repeat within the day');
    });

    test('non-invited actions never consume the quest', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pet_quest_v1',
        jsonEncode({
          'date': '${now.year}-${now.month}-${now.day}',
          'id': 'journal',
          'done': false,
        }),
      );

      final pet = await RecoveryPetService.logGratitude(); // quest wants journal
      expect(pet.sparks, 5, reason: 'no bonus — wrong action');
      final after = await RecoveryPetService.todayQuest();
      expect(after.done, isFalse);
    });

    test('quest bonus respects the global cap (capped stream)', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pet_quest_v1',
        jsonEncode({
          'date': '${now.year}-${now.month}-${now.day}',
          'id': 'gratitude',
          'done': false,
        }),
      );
      await prefs.setString('recovery_pet_earn_day_v1',
          '${now.year}-${now.month}-${now.day}:150');

      final pet = await RecoveryPetService.logGratitude();
      expect(pet.sparks, 0,
          reason: 'cap full → action and bonus both taper to zero');
    });
  });
}