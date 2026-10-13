// lib/features/game/domain/battle_state.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import '../../../../widgets/trial_monster_painter.dart';

/// Phase of the tactical trial encounter.
enum BattlePhase {
  playerTurn,
  enemyTurn,
  victory,
  learnedDefeat,
  escaped,
  quietComplete,
}

/// User-selectable difficulty bands for compassionate pacing.
enum BattleDifficulty {
  guided,
  standard,
  challenge,
}

/// An immutable monster / hurdle representation.
@immutable
class BattleMonster {
  final String id;
  final String name;
  final TrialMonsterKind kind;
  final int maxHp;
  final int currentHp;
  final int minDamage;
  final int maxDamage;
  final bool heals;

  const BattleMonster({
    required this.id,
    required this.name,
    required this.kind,
    required this.maxHp,
    required this.currentHp,
    required this.minDamage,
    required this.maxDamage,
    this.heals = false,
  });

  BattleMonster copyWith({
    String? id,
    String? name,
    TrialMonsterKind? kind,
    int? maxHp,
    int? currentHp,
    int? minDamage,
    int? maxDamage,
    bool? heals,
  }) {
    return BattleMonster(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      minDamage: minDamage ?? this.minDamage,
      maxDamage: maxDamage ?? this.maxDamage,
      heals: heals ?? this.heals,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'maxHp': maxHp,
    'currentHp': currentHp,
    'minDamage': minDamage,
    'maxDamage': maxDamage,
    'heals': heals,
  };

  factory BattleMonster.fromJson(Map<String, dynamic> json) {
    return BattleMonster(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: TrialMonsterKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => TrialMonsterKind.wraith,
      ),
      maxHp: (json['maxHp'] as num).toInt(),
      currentHp: (json['currentHp'] as num).toInt(),
      minDamage: (json['minDamage'] as num).toInt(),
      maxDamage: (json['maxDamage'] as num).toInt(),
      heals: json['heals'] as bool? ?? false,
    );
  }
}

/// Immutable state of a tactical battle or quiet reflection session.
@immutable
class BattleState {
  final String sessionId;
  final int seed;
  final int turnNumber;
  final BattlePhase phase;
  final BattleDifficulty difficulty;
  final bool isQuietMode;
  final int resolve;
  final int maxResolve;
  final int focus;
  final int maxFocus;
  final bool shieldActive;
  final BattleMonster monster;
  final List<String> battleLog;
  final String? lastOutcomeMessage;

  const BattleState({
    required this.sessionId,
    required this.seed,
    required this.turnNumber,
    required this.phase,
    required this.difficulty,
    this.isQuietMode = false,
    required this.resolve,
    required this.maxResolve,
    required this.focus,
    this.maxFocus = 5,
    required this.shieldActive,
    required this.monster,
    required this.battleLog,
    this.lastOutcomeMessage,
  });

  bool get isTerminal =>
      phase == BattlePhase.victory ||
      phase == BattlePhase.learnedDefeat ||
      phase == BattlePhase.escaped ||
      phase == BattlePhase.quietComplete;

  BattleState copyWith({
    String? sessionId,
    int? seed,
    int? turnNumber,
    BattlePhase? phase,
    BattleDifficulty? difficulty,
    bool? isQuietMode,
    int? resolve,
    int? maxResolve,
    int? focus,
    int? maxFocus,
    bool? shieldActive,
    BattleMonster? monster,
    List<String>? battleLog,
    String? lastOutcomeMessage,
  }) {
    return BattleState(
      sessionId: sessionId ?? this.sessionId,
      seed: seed ?? this.seed,
      turnNumber: turnNumber ?? this.turnNumber,
      phase: phase ?? this.phase,
      difficulty: difficulty ?? this.difficulty,
      isQuietMode: isQuietMode ?? this.isQuietMode,
      resolve: resolve ?? this.resolve,
      maxResolve: maxResolve ?? this.maxResolve,
      focus: focus ?? this.focus,
      maxFocus: maxFocus ?? this.maxFocus,
      shieldActive: shieldActive ?? this.shieldActive,
      monster: monster ?? this.monster,
      battleLog: battleLog ?? this.battleLog,
      lastOutcomeMessage: lastOutcomeMessage ?? this.lastOutcomeMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'seed': seed,
    'turnNumber': turnNumber,
    'phase': phase.name,
    'difficulty': difficulty.name,
    'isQuietMode': isQuietMode,
    'resolve': resolve,
    'maxResolve': maxResolve,
    'focus': focus,
    'maxFocus': maxFocus,
    'shieldActive': shieldActive,
    'monster': monster.toJson(),
    'battleLog': battleLog,
    'lastOutcomeMessage': lastOutcomeMessage,
  };

  factory BattleState.fromJson(Map<String, dynamic> json) {
    return BattleState(
      sessionId: json['sessionId'] as String,
      seed: (json['seed'] as num).toInt(),
      turnNumber: (json['turnNumber'] as num).toInt(),
      phase: BattlePhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => BattlePhase.playerTurn,
      ),
      difficulty: BattleDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => BattleDifficulty.standard,
      ),
      isQuietMode: json['isQuietMode'] as bool? ?? false,
      resolve: (json['resolve'] as num).toInt(),
      maxResolve: (json['maxResolve'] as num).toInt(),
      focus: (json['focus'] as num).toInt(),
      maxFocus: (json['maxFocus'] as num?)?.toInt() ?? 5,
      shieldActive: json['shieldActive'] as bool? ?? false,
      monster: BattleMonster.fromJson(json['monster'] as Map<String, dynamic>),
      battleLog: (json['battleLog'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastOutcomeMessage: json['lastOutcomeMessage'] as String?,
    );
  }
}
