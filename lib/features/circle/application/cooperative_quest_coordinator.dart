// lib/features/circle/application/cooperative_quest_coordinator.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import '../domain/cooperative_quest.dart';
import '../domain/quest_contribution.dart';
import '../domain/quest_membership.dart';

class CooperativeQuestCoordinator {
  final Map<String, CooperativeQuest> _quests = {};
  final Map<String, QuestMembership> _memberships = {}; // Key: "$questId:$actorRef"
  final Set<String> _processedContributions = {};

  final ValueNotifier<List<CooperativeQuest>> questsNotifier =
      ValueNotifier<List<CooperativeQuest>>([]);

  CooperativeQuestCoordinator({List<CooperativeQuest>? initialQuests}) {
    if (initialQuests != null) {
      for (final q in initialQuests) {
        _quests[q.questId] = q;
      }
    } else {
      // Default initial cooperative quests
      _quests['cq_ground_together'] = const CooperativeQuest(
        questId: 'cq_ground_together',
        title: 'Ground Together',
        intentId: 'ground_together',
        description: 'Choose a calming technique today. Share a gentle support signal.',
        targetContributions: 5,
      );
      _quests['cq_prepare_week'] = const CooperativeQuest(
        questId: 'cq_prepare_week',
        title: 'Prepare a Good Week',
        intentId: 'prepare_week',
        description: 'Members set one self-selected weekly intention.',
        targetContributions: 3,
      );
    }
    _notify();
  }

  List<CooperativeQuest> get activeQuests =>
      List.unmodifiable(_quests.values.toList());

  bool isMember(String questId, String actorRef) {
    final key = '$questId:$actorRef';
    return _memberships[key]?.isActive == true;
  }

  void joinQuest(String questId, String actorRef) {
    final key = '$questId:$actorRef';
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    _memberships[key] = QuestMembership(
      actorRef: actorRef,
      questId: questId,
      isActive: true,
      joinedAtUtcMs: nowMs,
    );
  }

  void leaveQuest(String questId, String actorRef) {
    final key = '$questId:$actorRef';
    final existing = _memberships[key];
    if (existing != null) {
      _memberships[key] = existing.copyWith(isActive: false);
    }
  }

  /// Submit a contribution idempotently.
  /// 100 repeated submissions produce exactly ONE counted contribution.
  bool submitContribution(CircleQuestContribution contribution) {
    final questId = contribution.questInstanceId;
    final quest = _quests[questId];
    if (quest == null) return false;

    // Membership check: must be active member
    if (!isMember(questId, contribution.actorRef)) {
      return false;
    }

    // Idempotency check: duplicate contributions never count twice
    if (_processedContributions.contains(contribution.contributionId)) {
      return true; // Already recorded
    }

    _processedContributions.add(contribution.contributionId);
    _quests[questId] = quest.copyWith(
      currentContributions: quest.currentContributions + 1,
    );
    _notify();
    return true;
  }

  void _notify() {
    questsNotifier.value = List.unmodifiable(_quests.values.toList());
  }

  void resetForTesting() {
    _quests.clear();
    _memberships.clear();
    _processedContributions.clear();
    _notify();
  }
}
