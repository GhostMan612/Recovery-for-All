// lib/features/progression/domain/reward_policy.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'recovery_action.dart';

/// Reward amounts associated with an action.
class RewardAllocation {
  final int xp;
  final int sparks;
  final int policyVersion;

  const RewardAllocation({
    required this.xp,
    required this.sparks,
    this.policyVersion = 1,
  });
}

/// The result status of an attempted reward grant.
enum RewardOutcome {
  /// The reward was newly evaluated and transactionally committed.
  granted,

  /// The event was already recorded; no additional balance mutation occurred.
  alreadyApplied,

  /// The action is recognized but currently ineligible (e.g. daily quota reached).
  notEligible,

  /// The action was rejected (unrecognized type, malformed payload, or invalid proof).
  rejected,
}

/// Comprehensive outcome of a coordinated recovery action and reward.
class RewardResult {
  final RewardOutcome outcome;
  final int xpAwarded;
  final int sparksAwarded;
  final int? newPathLevel;
  final bool leveledUp;
  final String raidSuffix;
  final String? message;

  const RewardResult({
    required this.outcome,
    this.xpAwarded = 0,
    this.sparksAwarded = 0,
    this.newPathLevel,
    this.leveledUp = false,
    this.raidSuffix = '',
    this.message,
  });

  bool get isSuccess => outcome == RewardOutcome.granted;
}

/// Canonical deterministic reward policy for Category Platform Phase 1.
class RewardPolicy {
  static const int currentPolicyVersion = 1;

  static const Map<RecoveryActionType, RewardAllocation> _schedule = {
    RecoveryActionType.checkIn: RewardAllocation(xp: 15, sparks: 5),
    RecoveryActionType.journal: RewardAllocation(xp: 25, sparks: 10),
    RecoveryActionType.gratitude: RewardAllocation(xp: 10, sparks: 5),
    RecoveryActionType.grounding: RewardAllocation(xp: 15, sparks: 8),
    RecoveryActionType.meetingSelfReport: RewardAllocation(xp: 20, sparks: 8),
    RecoveryActionType.meetingPeerAttestation: RewardAllocation(xp: 50, sparks: 15),
    RecoveryActionType.walkVerified: RewardAllocation(xp: 25, sparks: 15),
    RecoveryActionType.questCompleted: RewardAllocation(xp: 30, sparks: 10),
    RecoveryActionType.battleCompleted: RewardAllocation(xp: 30, sparks: 10),
    RecoveryActionType.supportIntention: RewardAllocation(xp: 15, sparks: 5),
  };

  /// Returns the deterministic allocation for a recognized action type,
  /// or `null` if the action type is unknown or unregistered.
  /// Fails closed: no silent fallback to arbitrary XP amounts.
  static RewardAllocation? evaluate(RecoveryActionType type) {
    return _schedule[type];
  }
}
