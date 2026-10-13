// lib/features/game/domain/battle_rules.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;

import 'battle_action.dart';
import 'battle_state.dart';

/// Pure reducer and deterministic rules for trials and coping battles.
class BattleRules {
  /// Evaluates one player turn and subsequent enemy reaction deterministically.
  ///
  /// Zero BuildContext, storage, or wall-clock dependencies.
  static BattleState reduce(
    BattleState state,
    BattleAction action,
    math.Random rng,
  ) {
    // Terminal sessions or non-player phases cannot accept actions
    if (state.isTerminal || state.phase != BattlePhase.playerTurn) {
      return state;
    }

    // Negative focus or insufficient focus leaves state strictly unchanged
    if (state.focus < action.focusCost) {
      return state;
    }

    final newLog = List<String>.from(state.battleLog);
    void log(String msg) {
      newLog.insert(0, msg);
      if (newLog.length > 25) newLog.removeLast();
    }

    // 1. Deduct Focus
    var focus = math.max(0, state.focus - action.focusCost);
    var resolve = state.resolve;
    var shieldActive = state.shieldActive;
    var monster = state.monster;

    // 2. Handle Escape
    if (action.isEscape) {
      log('You mindfully step back from the encounter.');
      return state.copyWith(
        phase: BattlePhase.escaped,
        focus: focus,
        battleLog: newLog,
        lastOutcomeMessage: 'Stepped back safely to rest and regroup.',
      );
    }

    // 3. Handle Quiet Mode Reflection
    if (action.isReflection || state.isQuietMode) {
      final dmg = 25;
      final newHp = math.max(0, monster.currentHp - dmg);
      monster = monster.copyWith(currentHp: newHp);
      log('You reflect mindfully on the feeling without judgment.');
      if (newHp <= 0) {
        log('Inner peace restored through gentle reflection.');
        return state.copyWith(
          phase: BattlePhase.quietComplete,
          monster: monster,
          focus: focus,
          battleLog: newLog,
          lastOutcomeMessage: 'Completed mindful reflection with steady peace.',
        );
      }
      focus = math.min(state.maxFocus, focus + 1);
      return state.copyWith(
        turnNumber: state.turnNumber + 1,
        monster: monster,
        focus: focus,
        battleLog: newLog,
      );
    }

    // 4. Handle Standard Tactical Actions
    if (action.type == BattleActionType.takeBreath) {
      focus = math.min(state.maxFocus, focus + 2);
      log('You breathe and center — Focus restored (+2).');
    } else if (action.heals) {
      resolve = math.min(state.maxResolve, resolve + 15);
      log('15 Resolve restored by ${action.name}.');
    } else if (action.shields) {
      shieldActive = true;
      log('Grounding Shield raised.');
    } else {
      final spread = action.maxDamage - action.minDamage;
      final dmg = spread > 0
          ? action.minDamage + rng.nextInt(spread + 1)
          : action.minDamage;
      final newHp = math.max(0, monster.currentHp - dmg);
      monster = monster.copyWith(currentHp: newHp);
      log('${action.name} deals $dmg damage!');

      if (newHp <= 0) {
        log('The ${monster.name} fades. You stood your ground.');
        return state.copyWith(
          phase: BattlePhase.victory,
          monster: monster,
          focus: focus,
          shieldActive: shieldActive,
          resolve: resolve,
          battleLog: newLog,
          lastOutcomeMessage: 'Stood your ground and cleared the hurdle.',
        );
      }
    }

    // 5. Enemy Turn (Deterministic via injected RNG)
    if (monster.heals && rng.nextBool()) {
      final heal = 5 + rng.nextInt(4);
      final newHp = math.min(monster.maxHp, monster.currentHp + heal);
      monster = monster.copyWith(currentHp: newHp);
      log('${monster.name} absorbs $heal HP.');
    } else {
      final spread = monster.maxDamage - monster.minDamage;
      var dmg = spread > 0
          ? monster.minDamage + rng.nextInt(spread + 1)
          : monster.minDamage;

      if (shieldActive) {
        dmg = (dmg * 0.3).round();
        shieldActive = false;
        log('Grounding Shield absorbed most of the hit! ($dmg taken)');
      } else {
        log('${monster.name} deals $dmg damage.');
      }
      resolve = math.max(0, resolve - dmg);
    }

    // 6. Check Player Defeat / Learned Exit
    if (resolve <= 0) {
      log('The ${monster.name} retreats. Your companion learned something.');
      return state.copyWith(
        phase: BattlePhase.learnedDefeat,
        resolve: 0,
        monster: monster,
        focus: focus,
        shieldActive: shieldActive,
        battleLog: newLog,
        lastOutcomeMessage: 'Your companion learned something valuable.',
      );
    }

    // 7. End of round focus replenishment
    focus = math.min(state.maxFocus, focus + 1);

    return state.copyWith(
      turnNumber: state.turnNumber + 1,
      phase: BattlePhase.playerTurn,
      resolve: resolve,
      focus: focus,
      shieldActive: shieldActive,
      monster: monster,
      battleLog: newLog,
    );
  }
}
