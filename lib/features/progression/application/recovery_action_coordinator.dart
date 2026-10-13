// lib/features/progression/application/recovery_action_coordinator.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

import '../../../database/recovery_database.dart';
import '../../../services/constellation_service.dart';
import '../../../services/raid_service.dart';
import '../data/reward_ledger_repository.dart';
import '../domain/recovery_action.dart';
import '../domain/reward_policy.dart';

/// Single authoritative orchestrator for recovery actions and reward allocation.
///
/// Guarantees cross-phase invariants CP-02 through CP-05:
/// - Stable UUID eventId created at user action boundary.
/// - Idempotent receipt write (100 retries = 1 XP & Sparks award).
/// - Secondary raid and constellation projections are event-deduped.
/// - Unregistered action types fail closed without granting rewards.
class RecoveryActionCoordinator {
  final RecoveryDatabase database;
  final RewardLedgerRepository repository;
  final Future<void> Function(RecoveryAction action)? onActionCommitted;

  RecoveryActionCoordinator({
    required this.database,
    RewardLedgerRepository? repository,
    this.onActionCommitted,
  }) : repository = repository ?? RewardLedgerRepository(database);

  /// Process a canonical RecoveryAction domain event.
  Future<RewardResult> processAction(RecoveryAction action) async {
    // 1. Evaluate reward policy (fail closed on unknown / unsupported types)
    final allocation = RewardPolicy.evaluate(action.actionType);
    if (allocation == null) {
      debugPrint('[progression] Action rejected: unregistered type ${action.actionType}');
      return const RewardResult(
        outcome: RewardOutcome.rejected,
        message: 'Unregistered action type.',
      );
    }

    // 2. Commit action + reward receipt + pet balance atomically
    final result = await repository.recordAndAllocate(
      action: action,
      allocation: allocation,
    );

    // 3. If already applied, return immediately without re-striking raid or star
    if (result.outcome == RewardOutcome.alreadyApplied) {
      debugPrint('[progression] Action ${action.eventId} already applied. Idempotent skip.');
      return result;
    }

    if (result.outcome != RewardOutcome.granted) {
      return result;
    }

    // 4. Idempotent Raid Projection: strike active raid boss with granted XP
    var raidSuffix = '';
    try {
      final raid = await RaidService.getActiveRaid(database);
      if (raid != null) {
        final updated = await RaidService.dealDamageForEvent(
          database,
          raid.id,
          allocation.xp,
          action.eventId,
        );
        if (updated != null) {
          raidSuffix = ' | Boss Struck for ${allocation.xp} DMG';
          if (updated.currentHp <= 0) {
            raidSuffix += ' • Boss Defeated!';
          }
        }
      }
    } catch (e) {
      debugPrint('[progression] Raid projection error (non-fatal): $e');
    }

    // 5. Idempotent Constellation Projection for mindfulness/community actions
    try {
      if (action.actionType == RecoveryActionType.journal) {
        await ConstellationService.addStarForEvent(
          database,
          eventId: action.eventId,
          category: 'mindfulness',
          title: 'Journal Entry',
        );
      } else if (action.actionType == RecoveryActionType.gratitude) {
        await ConstellationService.addStarForEvent(
          database,
          eventId: action.eventId,
          category: 'mindfulness',
          title: 'Daily Gratitude',
        );
      } else if (action.actionType == RecoveryActionType.meetingSelfReport ||
          action.actionType == RecoveryActionType.meetingPeerAttestation) {
        await ConstellationService.addStarForEvent(
          database,
          eventId: action.eventId,
          category: 'community',
          title: 'Meeting Attendance',
        );
      }
    } catch (e) {
      debugPrint('[progression] Constellation projection error (non-fatal): $e');
    }

    // 6. Notify external action listener (e.g. QuestProgressor)
    if (onActionCommitted != null &&
        action.actionType != RecoveryActionType.questCompleted) {
      try {
        await onActionCommitted!(action);
      } catch (e) {
        debugPrint('[progression] Action listener error (non-fatal): ');
      }
    }

    return RewardResult(
      outcome: RewardOutcome.granted,
      xpAwarded: result.xpAwarded,
      sparksAwarded: result.sparksAwarded,
      newPathLevel: result.newPathLevel,
      leveledUp: result.leveledUp,
      raidSuffix: raidSuffix,
    );
  }

  /// Convenience factory for recording a new action from user UI intent.
  Future<RewardResult> recordAction({
    required RecoveryActionType type,
    String? eventId,
    ActionOrigin origin = ActionOrigin.localUi,
    ProofTier proofTier = ProofTier.selfReported,
    String? intentId,
    String? sourceRefHash,
  }) async {
    final action = RecoveryAction(
      eventId: eventId ?? RecoveryAction.generateEventId(),
      actionType: type,
      createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      origin: origin,
      proofTier: proofTier,
      redactedMeta: RedactedActionMeta(
        intentId: intentId,
        sourceRefHash: sourceRefHash,
      ),
    );
    return await processAction(action);
  }
}
