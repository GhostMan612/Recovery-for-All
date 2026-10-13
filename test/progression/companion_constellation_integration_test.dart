// test/progression/companion_constellation_integration_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/progression/application/recovery_action_coordinator.dart';
import 'package:recovery_for_all/features/progression/domain/recovery_action.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/services/constellation_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late RecoveryActionCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    RecoveryPetService.bindDatabase(db);
    await RecoveryPetService.ensureHatched();
    coordinator = RecoveryActionCoordinator(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WO-1D — Companion, Constellation & Consistent Feedback', () {
    test('100 repeats of a meeting reflection yield exactly 1 permitted award + 1 star', () async {
      const stableEventId = 'test_meeting_reflection_event_100';
      final action = RecoveryAction(
        eventId: stableEventId,
        actionType: RecoveryActionType.meetingSelfReport,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        origin: ActionOrigin.localUi,
        proofTier: ProofTier.selfReported,
      );

      final petBefore = (await db.getPet(RecoveryPetService.defaultPetId))!;
      final initialXp = petBefore.pathXp;
      final initialSparks = petBefore.sparks;

      for (var i = 0; i < 100; i++) {
        final result = await coordinator.processAction(action);
        if (i == 0) {
          expect(result.outcome, RewardOutcome.granted);
          expect(result.xpAwarded, 20);
          expect(result.sparksAwarded, 8);
        } else {
          expect(result.outcome, RewardOutcome.alreadyApplied);
        }
      }

      final petAfter = (await db.getPet(RecoveryPetService.defaultPetId))!;
      expect(petAfter.pathXp, initialXp + 20);
      expect(petAfter.sparks, initialSparks + 8);

      final stars = await db.select(db.constellationPoints).get();
      final matchingStars = stars.where((s) => s.id == 'star_$stableEventId').toList();
      expect(matchingStars, hasLength(1),
          reason: '100 replay iterations must produce exactly 1 star');
    });

    test('Constellation projector idempotently resumes after simulated crash', () async {
      const eventId = 'crash_recovery_star_event';

      // First run: star created
      await ConstellationService.addStarForEvent(
        db,
        eventId: eventId,
        category: 'mindfulness',
        title: 'Deep Breathing',
      );

      final count1 = (await db.select(db.constellationPoints).get()).length;
      expect(count1, 1);

      // Simulated process restart: re-run same projector step
      await ConstellationService.addStarForEvent(
        db,
        eventId: eventId,
        category: 'mindfulness',
        title: 'Deep Breathing',
      );

      final count2 = (await db.select(db.constellationPoints).get()).length;
      expect(count2, 1, reason: 'Duplicate event ID projection must be a no-op');
    });

    test('Existing cosmetics, unlocked items, and mood survive companion updates', () async {
      final initial = await RecoveryPetService.ensureHatched();
      final updatedWithCosmetics = initial.copyWith(
        equippedOutfit: 'ranger_cloak',
        unlockedItems: ['hat_feather', 'boots_trail', 'ranger_cloak'],
        mood: PetMoodX.happy,
      );
      await db.upsertPet(RecoveryPetService.rowFromPet(updatedWithCosmetics));

      // Trigger standard progression action
      final action = RecoveryAction(
        eventId: 'cosmetic_survival_action',
        actionType: RecoveryActionType.gratitude,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      await coordinator.processAction(action);

      final petRow = await db.getPet(RecoveryPetService.defaultPetId);
      final petAfter = RecoveryPetService.petFromRow(petRow!);

      expect(petAfter.equippedOutfit, 'ranger_cloak');
      expect(petAfter.unlockedItems, contains('ranger_cloak'));
      expect(petAfter.unlockedItems, contains('hat_feather'));
      expect(petAfter.mood, PetMoodX.happy);
    });
  });
}
