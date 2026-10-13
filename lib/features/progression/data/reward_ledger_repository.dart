// lib/features/progression/data/reward_ledger_repository.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/recovery_database.dart';
import '../../../services/recovery_pet_service.dart';
import '../domain/recovery_action.dart';
import '../domain/reward_policy.dart';

/// Idempotent Drift-backed repository for RecoveryActions and RewardReceipts.
class RewardLedgerRepository {
  final RecoveryDatabase database;

  RewardLedgerRepository(this.database);

  /// Commits a RecoveryAction and its calculated RewardAllocation in a single
  /// atomic Drift transaction.
  ///
  /// Guarantees CP-03 and CP-04:
  /// - If [action.eventId] already has a receipt, returns [RewardOutcome.alreadyApplied]
  ///   without mutating pet balances or writing duplicate audit events.
  /// - Otherwise, inserts RecoveryAction, inserts RewardReceipt, updates pet XP/Sparks,
  ///   and writes one PetEventRow for backwards-compatible audit logs.
  Future<RewardResult> recordAndAllocate({
    required RecoveryAction action,
    required RewardAllocation allocation,
  }) async {
    return await database.transaction(() async {
      // 1. Check if receipt already exists for this stable event ID
      final existingReceipt = await (database.select(database.rewardReceipts)
            ..where((t) => t.eventId.equals(action.eventId)))
          .getSingleOrNull();

      if (existingReceipt != null) {
        return const RewardResult(
          outcome: RewardOutcome.alreadyApplied,
          message: 'Reward already applied for this event.',
        );
      }

      // 2. Insert RecoveryAction
      await database.into(database.recoveryActions).insert(
            RecoveryActionsCompanion(
              eventId: Value(action.eventId),
              actionType: Value(action.actionType.wireName),
              createdAtUtcMs: Value(action.createdAtUtcMs),
              origin: Value(action.origin.wireName),
              proofTier: Value(action.proofTier.wireName),
              synthetic: Value(action.synthetic),
              redactedMetaJson: Value(jsonEncode(action.redactedMeta.toJson())),
              schemaVersion: Value(action.schemaVersion),
            ),
          );

      // 3. Atomically allocate XP and Sparks to pet
      await RecoveryPetService.ensureHatched();
      final petRow = await database.getPet(RecoveryPetService.defaultPetId);
      int? newLevel;
      bool leveledUp = false;

      if (petRow != null) {
        final pet = RecoveryPetService.petFromRow(petRow);
        final withRewards = pet.copyWith(
          pathXp: pet.pathXp + allocation.xp,
          sparks: pet.sparks + allocation.sparks,
        );
        final nextPet = RecoveryPetService.evaluateLevel(withRewards);
        newLevel = nextPet.pathLevel;
        leveledUp = nextPet.pathLevel > pet.pathLevel;
        await database.upsertPet(RecoveryPetService.rowFromPet(nextPet));

        // Historical audit event row for legacy screens
        await database.addPetEvent(PetEventRow(
          id: 'pet_event_${action.eventId}',
          petId: RecoveryPetService.defaultPetId,
          eventType: 'action_${action.actionType.wireName}',
          sparksDelta: allocation.sparks,
          timestamp: action.createdAtUtcMs,
          metaJson: jsonEncode({
            'eventId': action.eventId,
            'xp': allocation.xp,
            'sparks': allocation.sparks,
          }),
        ));
      }

      // 4. Insert canonical RewardReceipt
      await database.into(database.rewardReceipts).insert(
            RewardReceiptsCompanion(
              eventId: Value(action.eventId),
              xp: Value(allocation.xp),
              sparks: Value(allocation.sparks),
              status: const Value('granted'),
              policyVersion: Value(allocation.policyVersion),
              awardedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );

      return RewardResult(
        outcome: RewardOutcome.granted,
        xpAwarded: allocation.xp,
        sparksAwarded: allocation.sparks,
        newPathLevel: newLevel,
        leveledUp: leveledUp,
      );
    });
  }

  /// Check whether an action has already been rewarded.
  Future<bool> hasReceipt(String eventId) async {
    final receipt = await (database.select(database.rewardReceipts)
          ..where((t) => t.eventId.equals(eventId)))
        .getSingleOrNull();
    return receipt != null;
  }
}
