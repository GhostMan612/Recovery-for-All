// lib/features/game/application/battle_session_service.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/recovery_database.dart';
import '../../progression/application/recovery_action_coordinator.dart';
import '../../progression/domain/recovery_action.dart';
import '../../progression/domain/reward_policy.dart';
import '../data/battle_catalog.dart';
import '../domain/battle_action.dart';
import '../domain/battle_rules.dart';
import '../domain/battle_state.dart';

/// Application service orchestrating tactical trials, deterministic turns,
/// session persistence, and idempotent completion rewards.
class BattleSessionService {
  static const int maxBattlesPerDay = 3;
  static const String _keyBattles = 'pet_trials_battles_v1';
  static const String _keyActiveSession = 'pet_trials_active_session_v1';
  static const String _keyRewardedSessions = 'pet_trials_rewarded_sessions_v1';

  /// Returns count of battles completed today.
  static Future<int> getBattlesToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('${_keyBattles}_date') != today) return 0;
    return prefs.getInt('${_keyBattles}_count') ?? 0;
  }

  /// Increments the count of battles completed today.
  static Future<void> incrementBattlesToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final count = await getBattlesToday();
    await prefs.setString('${_keyBattles}_date', today);
    await prefs.setInt('${_keyBattles}_count', count + 1);
  }

  /// Starts a new battle or quiet session with a deterministic seed.
  static Future<BattleState> startSession({
    required RecoveryDatabase db,
    required int petEnergy,
    required int petBond,
    required int petSparks,
    BattleDifficulty difficulty = BattleDifficulty.standard,
    bool isQuietMode = false,
    int? customSeed,
  }) async {
    final seed = customSeed ?? math.Random().nextInt(1 << 30);
    final rng = math.Random(seed);

    final sessionId =
        'trial_${DateTime.now().toUtc().millisecondsSinceEpoch}_${rng.nextInt(999999)}';

    // Pick monster from catalog
    BattleMonster baseMonster;
    if (petBond >= 50 && rng.nextBool()) {
      baseMonster = BattleCatalog.doubtMirage;
    } else if (petSparks ~/ 100 >= 5) {
      baseMonster =
          BattleCatalog.standardPool[rng.nextInt(BattleCatalog.standardPool.length)];
    } else {
      baseMonster = BattleCatalog.standardPool[rng.nextInt(2)];
    }

    final monster = BattleCatalog.configureMonster(baseMonster, difficulty);
    final maxResolve = 30 + (petEnergy * 0.7).round();
    final focus = BattleCatalog.initialFocus(difficulty);

    final initialLog = isQuietMode
        ? ['You pause mindfully to reflect on inner resilience.']
        : ['A ${monster.name} emerges from the shadows.'];

    final state = BattleState(
      sessionId: sessionId,
      seed: seed,
      turnNumber: 1,
      phase: BattlePhase.playerTurn,
      difficulty: difficulty,
      isQuietMode: isQuietMode,
      resolve: maxResolve,
      maxResolve: maxResolve,
      focus: focus,
      maxFocus: 5,
      shieldActive: false,
      monster: monster,
      battleLog: initialLog,
    );

    if (!isQuietMode) {
      await incrementBattlesToday();
    }
    await saveActiveSession(state);
    return state;
  }

  /// Dispatches an action through the pure reducer using the session seed.
  static BattleState dispatch(
    BattleState state,
    BattleAction action, {
    math.Random? rng,
  }) {
    // Each turn computes deterministic seed from base seed + turn number
    final turnRng = rng ?? math.Random(state.seed + state.turnNumber);
    final nextState = BattleRules.reduce(state, action, turnRng);
    return nextState;
  }

  /// Saves the active in-progress session to survive rotations and rebuilds.
  static Future<void> saveActiveSession(BattleState state) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.isTerminal) {
      await prefs.remove(_keyActiveSession);
    } else {
      await prefs.setString(_keyActiveSession, jsonEncode(state.toJson()));
    }
  }

  /// Restores active session if one was in progress.
  static Future<BattleState?> loadActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActiveSession);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return BattleState.fromJson(json);
    } catch (_) {
      await prefs.remove(_keyActiveSession);
      return null;
    }
  }

  /// Clears active session (e.g. on exit or abandonment).
  static Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveSession);
  }

  /// Completes a terminal session by routing rewards through the idempotent
  /// Category Platform Phase 1 coordinator.
  ///
  /// Guarantees exact-once reward allocation even if invoked repeatedly.
  static Future<RewardResult?> completeSession(
    RecoveryDatabase db,
    BattleState state,
  ) async {
    if (!state.isTerminal) return null;

    final stableEventId = 'battle_event_${state.sessionId}';
    final prefs = await SharedPreferences.getInstance();
    final rewarded = prefs.getStringList(_keyRewardedSessions) ?? [];

    if (rewarded.contains(state.sessionId)) {
      // Local session already marked completed
      return const RewardResult(
        outcome: RewardOutcome.alreadyApplied,
        message: 'Session reward already granted.',
      );
    }

    // Clear active session
    await clearActiveSession();

    final coordinator = RecoveryActionCoordinator(database: db);
    final action = RecoveryAction(
      eventId: stableEventId,
      actionType: RecoveryActionType.battleCompleted,
      createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      origin: ActionOrigin.localUi,
      proofTier: ProofTier.locallyObserved,
      synthetic: false,
      redactedMeta: RedactedActionMeta(
        intentId: state.sessionId,
      ),
    );

    final result = await coordinator.processAction(action);

    // Record session as completed
    rewarded.add(state.sessionId);
    if (rewarded.length > 50) rewarded.removeAt(0);
    await prefs.setStringList(_keyRewardedSessions, rewarded);

    return result;
  }
}
