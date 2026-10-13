// test/game/battle_session_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/game/application/battle_session_service.dart';
import 'package:recovery_for_all/features/game/domain/battle_state.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    RecoveryPetService.bindDatabase(db);
    await RecoveryPetService.ensureHatched();
  });

  tearDown(() async {
    await db.close();
  });

  group('WO-1B — Battle Session Service & Lifecycle', () {
    test('startSession initializes deterministic state and difficulty parameters', () async {
      final state = await BattleSessionService.startSession(
        db: db,
        petEnergy: 80,
        petBond: 10,
        petSparks: 50,
        difficulty: BattleDifficulty.guided,
        customSeed: 12345,
      );

      expect(state.seed, 12345);
      expect(state.difficulty, BattleDifficulty.guided);
      expect(state.focus, 3, reason: 'Guided mode grants +1 initial Focus');
      expect(state.phase, BattlePhase.playerTurn);
      expect(state.monster.maxHp, lessThan(40),
          reason: 'Guided mode reduces monster HP');
    });

    test('Active session persistence survives simulated app reload / rotation', () async {
      final state = await BattleSessionService.startSession(
        db: db,
        petEnergy: 60,
        petBond: 20,
        petSparks: 100,
        customSeed: 999,
      );

      final reloaded = await BattleSessionService.loadActiveSession();
      expect(reloaded, isNotNull);
      expect(reloaded!.sessionId, state.sessionId);
      expect(reloaded.seed, state.seed);
      expect(reloaded.monster.name, state.monster.name);
    });

    test('completeSession awards progression XP and Sparks exactly once', () async {
      final state = await BattleSessionService.startSession(
        db: db,
        petEnergy: 60,
        petBond: 20,
        petSparks: 100,
        customSeed: 999,
      );

      // Force state to terminal victory
      final terminalState = state.copyWith(phase: BattlePhase.victory);

      final firstReward =
          await BattleSessionService.completeSession(db, terminalState);
      expect(firstReward, isNotNull);
      expect(firstReward!.outcome, RewardOutcome.granted);
      expect(firstReward.xpAwarded, 30);
      expect(firstReward.sparksAwarded, 10);

      // Verify active session was cleared on completion
      final active = await BattleSessionService.loadActiveSession();
      expect(active, isNull);

      // Second completion of the same session returns alreadyApplied
      final secondReward =
          await BattleSessionService.completeSession(db, terminalState);
      expect(secondReward, isNotNull);
      expect(secondReward!.outcome, RewardOutcome.alreadyApplied);
    });

    test('Daily battle quota increments for combat and tracks cap', () async {
      expect(await BattleSessionService.getBattlesToday(), 0);

      await BattleSessionService.startSession(
        db: db,
        petEnergy: 50,
        petBond: 10,
        petSparks: 0,
      );
      expect(await BattleSessionService.getBattlesToday(), 1);

      await BattleSessionService.startSession(
        db: db,
        petEnergy: 50,
        petBond: 10,
        petSparks: 0,
      );
      expect(await BattleSessionService.getBattlesToday(), 2);
    });

    test('Quiet mode sessions do not consume daily combat battle allowance', () async {
      final initialBattles = await BattleSessionService.getBattlesToday();

      final quietState = await BattleSessionService.startSession(
        db: db,
        petEnergy: 50,
        petBond: 10,
        petSparks: 0,
        isQuietMode: true,
      );

      expect(quietState.isQuietMode, isTrue);
      expect(await BattleSessionService.getBattlesToday(), initialBattles,
          reason: 'Quiet mode reflection is always available without daily combat cap deduction');
    });
  });
}
