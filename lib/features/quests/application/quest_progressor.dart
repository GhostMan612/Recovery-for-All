// lib/features/quests/application/quest_progressor.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/recovery_database.dart';
import '../../progression/application/recovery_action_coordinator.dart';
import '../../progression/domain/recovery_action.dart';
import '../../progression/domain/reward_policy.dart';
import '../data/quest_catalog.dart';
import '../domain/quest_instance.dart';

/// Result summary of processing quest progression.
class QuestProgressResult {
  final List<QuestInstance> updatedQuests;
  final List<QuestInstance> newlyCompletedQuests;
  final RewardResult? rewardResult;

  const QuestProgressResult({
    required this.updatedQuests,
    this.newlyCompletedQuests = const [],
    this.rewardResult,
  });
}

/// Orchestrator for voluntary quest progression, safe accommodations, and opt-outs.
class QuestProgressor {
  final RecoveryDatabase database;
  final RecoveryActionCoordinator coordinator;

  static const String _keyQuestInstances = 'recovery_quest_instances_v1';
  static const String _keyLegacyQuest = 'pet_quest_v1';

  QuestProgressor({
    required this.database,
    RecoveryActionCoordinator? coordinator,
  }) : coordinator = coordinator ?? RecoveryActionCoordinator(database: database);

  static String dateKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Retrieves active quest instances for today.
  Future<List<QuestInstance>> getActiveQuests({DateTime? date}) async {
    final today = dateKey(date);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_keyQuestInstances}_$today');

    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => QuestInstance.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      } catch (_) {}
    }

    // Initialize daily rotation deterministically
    final now = date ?? DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final dailyPool = [
      QuestCatalog.dailyGrounding,
      QuestCatalog.dailyGratitude,
      QuestCatalog.dailyReflection,
      QuestCatalog.dailyCheckIn,
    ];
    final def = dailyPool[dayOfYear % dailyPool.length];

    final initialInstance = QuestInstance(
      instanceId: 'quest_${today}_${def.id}',
      definitionId: def.id,
      definitionVersion: def.version,
      dateBucket: today,
      status: QuestStatus.active,
      currentProgress: 0,
      targetCount: def.targetCount,
    );

    final instances = [initialInstance];
    await _saveInstances(today, instances);

    // Sync legacy quest representation for dashboard widget compatibility
    await prefs.setString(
      _keyLegacyQuest,
      jsonEncode({
        'date': today,
        'id': _legacyIdFor(def.id),
        'done': false,
      }),
    );

    return instances;
  }

  /// Processes a committed RecoveryAction and advances matching active quests.
  Future<QuestProgressResult> onActionCommitted(RecoveryAction action) async {
    final today = dateKey();
    final instances = await getActiveQuests();
    final updated = <QuestInstance>[];
    final completed = <QuestInstance>[];
    RewardResult? rewardResult;

    for (final instance in instances) {
      if (instance.status != QuestStatus.active) {
        updated.add(instance);
        continue;
      }

      final def = QuestCatalog.getDefinition(instance.definitionId);
      if (def == null) {
        updated.add(instance);
        continue;
      }

      final matchesType = def.allowedActionTypes.contains(action.actionType);
      if (!matchesType) {
        updated.add(instance);
        continue;
      }

      final newProg = instance.currentProgress + 1;
      if (newProg >= instance.targetCount) {
        final eventId = 'quest_complete_${instance.instanceId}';
        final completedInstance = instance.copyWith(
          currentProgress: instance.targetCount,
          status: QuestStatus.completed,
          completedAt: DateTime.now().toUtc(),
          completionEventId: eventId,
        );
        updated.add(completedInstance);
        completed.add(completedInstance);

        // Award completion reward via coordinator
        final questRewardAction = RecoveryAction(
          eventId: eventId,
          actionType: RecoveryActionType.questCompleted,
          createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          origin: ActionOrigin.localUi,
          proofTier: ProofTier.locallyObserved,
          synthetic: false,
          redactedMeta: RedactedActionMeta(
            intentId: instance.definitionId,
          ),
        );

        rewardResult = await coordinator.processAction(questRewardAction);

        // Update legacy quest sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _keyLegacyQuest,
          jsonEncode({
            'date': today,
            'id': _legacyIdFor(def.id),
            'done': true,
          }),
        );
      } else {
        updated.add(instance.copyWith(currentProgress: newProg));
      }
    }

    await _saveInstances(today, updated);
    return QuestProgressResult(
      updatedQuests: updated,
      newlyCompletedQuests: completed,
      rewardResult: rewardResult,
    );
  }

  /// Voluntary skip / opt-out with ZERO negative consequences.
  Future<void> skipQuest(String instanceId) async {
    final today = dateKey();
    final instances = await getActiveQuests();
    final updated = instances.map((q) {
      if (q.instanceId == instanceId) {
        return q.copyWith(status: QuestStatus.skipped);
      }
      return q;
    }).toList();

    await _saveInstances(today, updated);
    debugPrint('[quests] Quest $instanceId voluntarily skipped. No penalties applied.');
  }

  /// Selects an accessible alternative for the quest.
  Future<void> selectAlternative(String instanceId, String alternative) async {
    final today = dateKey();
    final instances = await getActiveQuests();
    final updated = instances.map((q) {
      if (q.instanceId == instanceId) {
        return q.copyWith(selectedAlternative: alternative);
      }
      return q;
    }).toList();

    await _saveInstances(today, updated);
  }

  /// Completes a quest via selected accommodation.
  Future<RewardResult?> completeViaAlternative(String instanceId) async {
    final today = dateKey();
    final instances = await getActiveQuests();
    final matchIndex = instances.indexWhere((q) => q.instanceId == instanceId);
    if (matchIndex == -1) return null;

    final instance = instances[matchIndex];
    if (instance.status != QuestStatus.active) return null;

    final eventId = 'quest_complete_${instance.instanceId}';
    final completed = instance.copyWith(
      status: QuestStatus.completed,
      currentProgress: instance.targetCount,
      completedAt: DateTime.now().toUtc(),
      completionEventId: eventId,
    );
    instances[matchIndex] = completed;
    await _saveInstances(today, instances);

    final questRewardAction = RecoveryAction(
      eventId: eventId,
      actionType: RecoveryActionType.questCompleted,
      createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      origin: ActionOrigin.localUi,
      proofTier: ProofTier.selfReported,
      synthetic: false,
      redactedMeta: RedactedActionMeta(
        intentId: instance.definitionId,
      ),
    );

    final result = await coordinator.processAction(questRewardAction);

    // Sync legacy representation
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLegacyQuest,
      jsonEncode({
        'date': today,
        'id': _legacyIdFor(instance.definitionId),
        'done': true,
      }),
    );

    return result;
  }

  Future<void> _saveInstances(String today, List<QuestInstance> instances) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(instances.map((q) => q.toJson()).toList());
    await prefs.setString('${_keyQuestInstances}_$today', raw);
  }

  static String _legacyIdFor(String defId) {
    if (defId.contains('grounding')) return 'grounding';
    if (defId.contains('gratitude')) return 'gratitude';
    if (defId.contains('reflection')) return 'journal';
    if (defId.contains('check_in')) return 'wellness';
    if (defId.contains('meeting')) return 'meeting';
    return 'grounding';
  }
}
