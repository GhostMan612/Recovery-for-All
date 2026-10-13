// test/game/battle_rules_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/game/domain/battle_action.dart';
import 'package:recovery_for_all/features/game/domain/battle_rules.dart';
import 'package:recovery_for_all/features/game/domain/battle_state.dart';
import 'package:recovery_for_all/widgets/trial_monster_painter.dart';

void main() {
  group('WO-1B — Pure Battle Reducer & Deterministic Rules', () {
    late BattleState initialState;

    setUp(() {
      initialState = const BattleState(
        sessionId: 'test_session_1',
        seed: 42,
        turnNumber: 1,
        phase: BattlePhase.playerTurn,
        difficulty: BattleDifficulty.standard,
        isQuietMode: false,
        resolve: 50,
        maxResolve: 50,
        focus: 3,
        maxFocus: 5,
        shieldActive: false,
        monster: BattleMonster(
          id: 'test_wraith',
          name: 'Craving Wraith',
          kind: TrialMonsterKind.wraith,
          maxHp: 40,
          currentHp: 40,
          minDamage: 4,
          maxDamage: 8,
          heals: false,
        ),
        battleLog: ['Battle started.'],
      );
    });

    test('One seed yields identical full turn transcript 100 times (deterministic replay)', () {
      List<String> runSimulation() {
        var state = initialState;
        final rng = Random(12345);
        final actions = [
          BattleAction.takeBreath,
          BattleAction.meetingRally,
          BattleAction.groundingShield,
          BattleAction.gratitudeHeal,
          BattleAction.stepStrike,
        ];

        for (final act in actions) {
          if (state.isTerminal) break;
          if (state.focus >= act.focusCost) {
            state = BattleRules.reduce(state, act, rng);
          }
        }
        return List<String>.from(state.battleLog);
      }

      final baselineTranscript = runSimulation();

      for (var i = 0; i < 100; i++) {
        final rerun = runSimulation();
        expect(rerun, equals(baselineTranscript),
            reason: 'Turn transcript must be strictly identical on replay $i');
      }
    });

    test('Illegal actions and insufficient Focus leave state strictly unchanged', () {
      final lowFocusState = initialState.copyWith(focus: 1);
      final rng = Random(42);

      // stepStrike requires 3 Focus, but player only has 1
      final nextState =
          BattleRules.reduce(lowFocusState, BattleAction.stepStrike, rng);

      expect(nextState.focus, 1);
      expect(nextState.resolve, lowFocusState.resolve);
      expect(nextState.monster.currentHp, lowFocusState.monster.currentHp);
      expect(nextState.turnNumber, lowFocusState.turnNumber);
      expect(nextState.battleLog, equals(lowFocusState.battleLog));
    });

    test('Take a breath restores +2 Focus up to maxFocus (5)', () {
      final rng = Random(42);
      final s1 = initialState.copyWith(focus: 2);
      final s2 = BattleRules.reduce(s1, BattleAction.takeBreath, rng);

      // Focus started at 2 - cost 0 = 2, +2 from breath = 4, +1 end of turn = 5 (capped)
      expect(s2.focus, 5);
      expect(s2.battleLog.any((l) => l.contains('Focus restored (+2)')), isTrue);
    });

    test('Grounding shield raises active barrier and absorbs incoming monster damage', () {
      final rng = Random(42);
      final shieldedState =
          BattleRules.reduce(initialState, BattleAction.groundingShield, rng);

      expect(shieldedState.battleLog.any((l) => l.contains('Grounding Shield')), isTrue);
      // Resolve loss should be attenuated by ~70%
      expect(shieldedState.resolve, greaterThan(40));
    });

    test('Gratitude restores 15 Resolve bounded by maxResolve', () {
      final damagedState = initialState.copyWith(resolve: 20, focus: 4);
      final rng = Random(42);
      final healedState =
          BattleRules.reduce(damagedState, BattleAction.gratitudeHeal, rng);

      expect(healedState.battleLog.any((l) => l.contains('15 Resolve restored')), isTrue);
    });

    test('Step Strike deals 25-40 damage and achieves Victory on 0 enemy HP', () {
      final weakMonster = initialState.copyWith(
        monster: initialState.monster.copyWith(currentHp: 15),
        focus: 4,
      );
      final rng = Random(42);
      final victoryState =
          BattleRules.reduce(weakMonster, BattleAction.stepStrike, rng);

      expect(victoryState.phase, BattlePhase.victory);
      expect(victoryState.monster.currentHp, 0);
      expect(victoryState.battleLog.first, contains('fades. You stood your ground'));
    });

    test('Depleted Resolve transitions to compassionate Learned Defeat (never punitive)', () {
      final nearDefeatState = initialState.copyWith(
        resolve: 2,
        focus: 0,
        shieldActive: false,
        monster: initialState.monster.copyWith(minDamage: 10, maxDamage: 15),
      );
      final rng = Random(42);
      final defeatedState =
          BattleRules.reduce(nearDefeatState, BattleAction.takeBreath, rng);

      expect(defeatedState.phase, BattlePhase.learnedDefeat);
      expect(defeatedState.resolve, 0);
      expect(defeatedState.battleLog.first, contains('companion learned something'));
    });

    test('Peaceful retreat safely escapes without penalty', () {
      final rng = Random(42);
      final escapedState =
          BattleRules.reduce(initialState, BattleAction.peacefulRetreat, rng);

      expect(escapedState.phase, BattlePhase.escaped);
      expect(escapedState.lastOutcomeMessage, contains('Stepped back safely'));
    });

    test('Quiet mode reaches equal supportive outcome through mindful reflection', () {
      final quietState = initialState.copyWith(
        isQuietMode: true,
        monster: initialState.monster.copyWith(currentHp: 20),
      );
      final rng = Random(42);
      final completedState =
          BattleRules.reduce(quietState, BattleAction.quietReflect, rng);

      expect(completedState.phase, BattlePhase.quietComplete);
      expect(completedState.battleLog.first, contains('Inner peace restored'));
    });
  });
}
