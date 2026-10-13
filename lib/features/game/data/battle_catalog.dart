// lib/features/game/data/battle_catalog.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import '../../../../widgets/trial_monster_painter.dart';
import '../domain/battle_action.dart';
import '../domain/battle_state.dart';

/// Catalog of monsters, coping hurdles, and balancing parameters.
class BattleCatalog {
  static const BattleMonster cravingWraith = BattleMonster(
    id: 'craving_wraith',
    name: 'Craving Wraith',
    kind: TrialMonsterKind.wraith,
    maxHp: 40,
    currentHp: 40,
    minDamage: 4,
    maxDamage: 9,
  );

  static const BattleMonster triggerHound = BattleMonster(
    id: 'trigger_hound',
    name: 'Trigger Hound',
    kind: TrialMonsterKind.hound,
    maxHp: 30,
    currentHp: 30,
    minDamage: 6,
    maxDamage: 11,
  );

  static const BattleMonster isolationFog = BattleMonster(
    id: 'isolation_fog',
    name: 'Isolation Fog',
    kind: TrialMonsterKind.fog,
    maxHp: 55,
    currentHp: 55,
    minDamage: 3,
    maxDamage: 8,
    heals: true,
  );

  static const BattleMonster doubtMirage = BattleMonster(
    id: 'doubt_mirage',
    name: 'Doubt Mirage',
    kind: TrialMonsterKind.reaper,
    maxHp: 80,
    currentHp: 80,
    minDamage: 7,
    maxDamage: 13,
  );

  /// Standard monster pool.
  static const List<BattleMonster> standardPool = [
    cravingWraith,
    triggerHound,
    isolationFog,
  ];

  /// Adjusts monster stats based on user-chosen difficulty.
  static BattleMonster configureMonster(
    BattleMonster base,
    BattleDifficulty difficulty,
  ) {
    switch (difficulty) {
      case BattleDifficulty.guided:
        final maxHp = (base.maxHp * 0.8).round();
        final minDmg = (base.minDamage * 0.75).round().clamp(1, 99);
        final maxDmg = (base.maxDamage * 0.75).round().clamp(minDmg, 99);
        return base.copyWith(
          maxHp: maxHp,
          currentHp: maxHp,
          minDamage: minDmg,
          maxDamage: maxDmg,
        );
      case BattleDifficulty.standard:
        return base.copyWith(currentHp: base.maxHp);
      case BattleDifficulty.challenge:
        final maxHp = (base.maxHp * 1.25).round();
        final minDmg = (base.minDamage * 1.15).round();
        final maxDmg = (base.maxDamage * 1.15).round();
        return base.copyWith(
          maxHp: maxHp,
          currentHp: maxHp,
          minDamage: minDmg,
          maxDamage: maxDmg,
        );
    }
  }

  /// Calculates initial Focus based on difficulty.
  static int initialFocus(BattleDifficulty difficulty) {
    switch (difficulty) {
      case BattleDifficulty.guided:
        return 3;
      case BattleDifficulty.standard:
      case BattleDifficulty.challenge:
        return 2;
    }
  }

  /// Available actions for a battle session.
  static List<BattleAction> actionsForSession({required bool isQuietMode}) {
    if (isQuietMode) {
      return const [
        BattleAction.quietReflect,
        BattleAction.takeBreath,
        BattleAction.peacefulRetreat,
      ];
    }
    return BattleAction.standardDeck;
  }
}
