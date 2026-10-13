// test/progression/reward_ledger_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/progression/application/recovery_action_coordinator.dart';
import 'package:recovery_for_all/features/progression/data/reward_ledger_repository.dart';
import 'package:recovery_for_all/features/progression/domain/recovery_action.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/services/raid_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late RewardLedgerRepository repository;
  late RecoveryActionCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    RecoveryPetService.bindDatabase(db);
    await RecoveryPetService.ensureHatched();

    repository = RewardLedgerRepository(db);
    coordinator = RecoveryActionCoordinator(
      database: db,
      repository: repository,
    );
  });

  tearDown(() async {
    RecoveryPetService.bindDatabase(null);
    await db.close();
  });

  group('WO-1A — RecoveryAction Ledger & Canonical RewardReceipt', () {
    test('100 sequential replays of identical event produce exactly one XP and Sparks award (CP-03)', () async {
      final petBefore = (await db.getPet(RecoveryPetService.defaultPetId))!;
      final initialXp = petBefore.pathXp;
      final initialSparks = petBefore.sparks;

      final action = RecoveryAction(
        eventId: 'test_event_100_replays',
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );

      // First run: should grant
      final firstResult = await coordinator.processAction(action);
      expect(firstResult.outcome, RewardOutcome.granted);
      expect(firstResult.xpAwarded, 25);
      expect(firstResult.sparksAwarded, 10);

      // Verify balances after first grant
      final petAfterFirst = (await db.getPet(RecoveryPetService.defaultPetId))!;
      expect(petAfterFirst.pathXp, initialXp + 25);
      expect(petAfterFirst.sparks, initialSparks + 10);

      // Replay 99 more times sequentially
      for (int i = 0; i < 99; i++) {
        final replayResult = await coordinator.processAction(action);
        expect(replayResult.outcome, RewardOutcome.alreadyApplied,
            reason: 'Replay $i must be recognized as already applied');
        expect(replayResult.xpAwarded, 0);
        expect(replayResult.sparksAwarded, 0);
      }

      // Verify final balances are identical to first run (never double-credited)
      final petFinal = (await db.getPet(RecoveryPetService.defaultPetId))!;
      expect(petFinal.pathXp, initialXp + 25);
      expect(petFinal.sparks, initialSparks + 10);

      // Exactly one RecoveryAction and one RewardReceipt exist in DB
      final actions = await db.select(db.recoveryActions).get();
      expect(actions, hasLength(1));
      expect(actions.first.eventId, 'test_event_100_replays');

      final receipts = await db.select(db.rewardReceipts).get();
      expect(receipts, hasLength(1));
      expect(receipts.first.eventId, 'test_event_100_replays');
      expect(receipts.first.xp, 25);
      expect(receipts.first.sparks, 10);
    });

    test('Concurrent submissions of identical event resolve idempotently without race inflation', () async {
      final petBefore = (await db.getPet(RecoveryPetService.defaultPetId))!;
      final initialXp = petBefore.pathXp;
      final initialSparks = petBefore.sparks;

      final action = RecoveryAction(
        eventId: 'test_concurrent_event',
        actionType: RecoveryActionType.checkIn,
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );

      // Run 20 concurrent attempts
      final results = await Future.wait(
        List.generate(20, (_) => coordinator.processAction(action)),
      );

      final grantedCount =
          results.where((r) => r.outcome == RewardOutcome.granted).length;
      final alreadyAppliedCount =
          results.where((r) => r.outcome == RewardOutcome.alreadyApplied).length;

      expect(grantedCount, 1, reason: 'Exactly one concurrent call may grant');
      expect(alreadyAppliedCount, 19,
          reason: 'All other concurrent calls must be alreadyApplied');

      // Balances increased by exactly check-in amount (+15 XP, +5 Sparks)
      final petFinal = (await db.getPet(RecoveryPetService.defaultPetId))!;
      expect(petFinal.pathXp, initialXp + 15);
      expect(petFinal.sparks, initialSparks + 5);
    });

    test('Two distinct unique events both award independently (CP-04)', () async {
      final petBefore = (await db.getPet(RecoveryPetService.defaultPetId))!;
      final initialXp = petBefore.pathXp;
      final initialSparks = petBefore.sparks;

      final action1 = RecoveryAction(
        eventId: 'distinct_event_1',
        actionType: RecoveryActionType.gratitude,
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      final action2 = RecoveryAction(
        eventId: 'distinct_event_2',
        actionType: RecoveryActionType.grounding,
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );

      final res1 = await coordinator.processAction(action1);
      final res2 = await coordinator.processAction(action2);

      expect(res1.outcome, RewardOutcome.granted);
      expect(res1.xpAwarded, 10);
      expect(res1.sparksAwarded, 5);

      expect(res2.outcome, RewardOutcome.granted);
      expect(res2.xpAwarded, 15);
      expect(res2.sparksAwarded, 8);

      final petFinal = (await db.getPet(RecoveryPetService.defaultPetId))!;
      expect(petFinal.pathXp, initialXp + 25);
      expect(petFinal.sparks, initialSparks + 13);

      final receipts = await db.select(db.rewardReceipts).get();
      expect(receipts, hasLength(2));
    });

    test('Deterministic schedule evaluates all registered action types correctly', () {
      expect(RewardPolicy.evaluate(RecoveryActionType.checkIn)?.xp, 15);
      expect(RewardPolicy.evaluate(RecoveryActionType.checkIn)?.sparks, 5);

      expect(RewardPolicy.evaluate(RecoveryActionType.journal)?.xp, 25);
      expect(RewardPolicy.evaluate(RecoveryActionType.journal)?.sparks, 10);

      expect(RewardPolicy.evaluate(RecoveryActionType.gratitude)?.xp, 10);
      expect(RewardPolicy.evaluate(RecoveryActionType.gratitude)?.sparks, 5);

      expect(RewardPolicy.evaluate(RecoveryActionType.grounding)?.xp, 15);
      expect(RewardPolicy.evaluate(RecoveryActionType.grounding)?.sparks, 8);

      expect(RewardPolicy.evaluate(RecoveryActionType.meetingSelfReport)?.xp, 20);
      expect(RewardPolicy.evaluate(RecoveryActionType.meetingSelfReport)?.sparks, 8);

      expect(RewardPolicy.evaluate(RecoveryActionType.meetingPeerAttestation)?.xp, 50);
      expect(RewardPolicy.evaluate(RecoveryActionType.meetingPeerAttestation)?.sparks, 15);

      expect(RewardPolicy.evaluate(RecoveryActionType.walkVerified)?.xp, 25);
      expect(RewardPolicy.evaluate(RecoveryActionType.walkVerified)?.sparks, 15);

      expect(RewardPolicy.evaluate(RecoveryActionType.questCompleted)?.xp, 30);
      expect(RewardPolicy.evaluate(RecoveryActionType.questCompleted)?.sparks, 10);

      expect(RewardPolicy.evaluate(RecoveryActionType.battleCompleted)?.xp, 30);
      expect(RewardPolicy.evaluate(RecoveryActionType.battleCompleted)?.sparks, 10);

      expect(RewardPolicy.evaluate(RecoveryActionType.supportIntention)?.xp, 15);
      expect(RewardPolicy.evaluate(RecoveryActionType.supportIntention)?.sparks, 5);
    });

    test('Idempotent secondary raid projection: repeated event never damages raid twice (CP-05)', () async {
      // Create an active raid
      final raid = ActiveRaid(
        id: 'test_raid_id',
        bossName: 'Cravings Golem',
        maxHp: 500,
        currentHp: 500,
        endTime: DateTime.now().millisecondsSinceEpoch + 1000000,
        userContribution: 0,
      );
      await db.addActiveRaid(raid);

      final action = RecoveryAction(
        eventId: 'raid_strike_event_1',
        actionType: RecoveryActionType.journal, // 25 XP
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );

      // Strike 1
      final res1 = await coordinator.processAction(action);
      expect(res1.outcome, RewardOutcome.granted);
      expect(res1.raidSuffix, contains('Boss Struck for 25 DMG'));

      final raidAfterFirst = await db.getActiveRaidById('test_raid_id');
      expect(raidAfterFirst!.currentHp, 475);
      expect(raidAfterFirst.userContribution, 25);

      // Re-submit same action
      final res2 = await coordinator.processAction(action);
      expect(res2.outcome, RewardOutcome.alreadyApplied);

      final raidAfterReplay = await db.getActiveRaidById('test_raid_id');
      expect(raidAfterReplay!.currentHp, 475,
          reason: 'HP must remain 475; event must not strike twice');
      expect(raidAfterReplay.userContribution, 25);

      // Verify raid damage receipt in DB
      final damageReceipts = await db.select(db.raidDamageReceipts).get();
      expect(damageReceipts, hasLength(1));
      expect(damageReceipts.first.raidId, 'test_raid_id');
      expect(damageReceipts.first.eventId, 'raid_strike_event_1');
      expect(damageReceipts.first.damage, 25);
    });

    test('Raid victory grant awards victory XP at most once across concurrent defeat strikes', () async {
      final raid = ActiveRaid(
        id: 'test_raid_defeat',
        bossName: 'Isolation Demon',
        maxHp: 100,
        currentHp: 20, // Low HP: 1 strike will defeat it
        endTime: DateTime.now().millisecondsSinceEpoch + 1000000,
        userContribution: 80,
      );
      await db.addActiveRaid(raid);

      // Strike boss with event 1
      final strike1 = await RaidService.dealDamageForEvent(
        db,
        'test_raid_defeat',
        25,
        'fatal_event_1',
      );
      expect(strike1!.currentHp, 0);

      // Concurrent or duplicate strike attempting to defeat the already-defeated boss
      final strike2 = await RaidService.dealDamageForEvent(
        db,
        'test_raid_defeat',
        25,
        'late_event_2',
      );
      expect(strike2!.currentHp, 0);

      // Verify victory receipt exists exactly once
      final victoryReceipts = await db.select(db.raidVictoryReceipts).get();
      expect(victoryReceipts, hasLength(1));
      expect(victoryReceipts.first.raidId, 'test_raid_defeat');
      expect(victoryReceipts.first.victoryXp, RaidService.victoryXp);
    });

    test('Constellation star projection is idempotent per event ID (CP-05)', () async {
      final action = RecoveryAction(
        eventId: 'journal_star_event_1',
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: DateTime.now().millisecondsSinceEpoch,
      );

      await coordinator.processAction(action);
      final pointsFirst = await db.getConstellationPoints();
      expect(pointsFirst.where((p) => p.id == 'star_journal_star_event_1'), hasLength(1));

      // Replay
      await coordinator.processAction(action);
      final pointsReplay = await db.getConstellationPoints();
      expect(pointsReplay.where((p) => p.id == 'star_journal_star_event_1'), hasLength(1),
          reason: 'Star projection must be idempotent per eventId');
    });
  });
}
