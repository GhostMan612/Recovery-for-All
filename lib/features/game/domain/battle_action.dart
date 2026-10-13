// lib/features/game/domain/battle_action.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

/// Action type identifiers for tactical trials and coping battles.
enum BattleActionType {
  takeBreath,
  groundingShield,
  meetingRally,
  gratitudeHeal,
  stepStrike,
  peacefulRetreat,
  quietReflect,
}

/// An immutable action dispatched during a trial or coping encounter.
class BattleAction {
  final BattleActionType type;
  final String name;
  final String description;
  final int focusCost;
  final int minDamage;
  final int maxDamage;
  final bool heals;
  final bool shields;
  final bool isEscape;
  final bool isReflection;

  const BattleAction({
    required this.type,
    required this.name,
    required this.description,
    required this.focusCost,
    this.minDamage = 0,
    this.maxDamage = 0,
    this.heals = false,
    this.shields = false,
    this.isEscape = false,
    this.isReflection = false,
  });

  /// Standard coping skill abilities available in combat and quiet practice.
  static const BattleAction takeBreath = BattleAction(
    type: BattleActionType.takeBreath,
    name: 'Take a Breath',
    description: 'Restore +2 Focus. Free, always available to recenter.',
    focusCost: 0,
  );

  static const BattleAction groundingShield = BattleAction(
    type: BattleActionType.groundingShield,
    name: 'Grounding Shield',
    description: 'Raise inner grounding to absorb most of the incoming impact.',
    focusCost: 1,
    shields: true,
  );

  static const BattleAction meetingRally = BattleAction(
    type: BattleActionType.meetingRally,
    name: 'Meeting Rally',
    description: 'Draw strength from fellowship to dissipate the hurdle.',
    focusCost: 2,
    minDamage: 12,
    maxDamage: 20,
  );

  static const BattleAction gratitudeHeal = BattleAction(
    type: BattleActionType.gratitudeHeal,
    name: 'Gratitude Heal',
    description: 'Restore 15 Resolve through intentional gratitude.',
    focusCost: 2,
    heals: true,
  );

  static const BattleAction stepStrike = BattleAction(
    type: BattleActionType.stepStrike,
    name: 'Step Strike',
    description: 'Focus practiced recovery principles into decisive action.',
    focusCost: 3,
    minDamage: 25,
    maxDamage: 40,
  );

  static const BattleAction peacefulRetreat = BattleAction(
    type: BattleActionType.peacefulRetreat,
    name: 'Peaceful Retreat',
    description: 'Step back safely to preserve energy. No shame in resting.',
    focusCost: 0,
    isEscape: true,
  );

  static const BattleAction quietReflect = BattleAction(
    type: BattleActionType.quietReflect,
    name: 'Quiet Reflection',
    description: 'Mindfully process feelings without tactical confrontation.',
    focusCost: 0,
    isReflection: true,
  );

  static const List<BattleAction> standardDeck = [
    takeBreath,
    groundingShield,
    meetingRally,
    gratitudeHeal,
    stepStrike,
    peacefulRetreat,
  ];
}
