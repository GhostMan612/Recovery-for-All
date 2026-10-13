// test/circle/cooperative_quest_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/circle/application/cooperative_quest_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/cooperative_quest.dart';
import 'package:recovery_for_all/features/circle/domain/quest_contribution.dart';

void main() {
  group('CooperativeQuestCoordinator Tests', () {
    late CooperativeQuestCoordinator coordinator;

    setUp(() {
      coordinator = CooperativeQuestCoordinator(
        initialQuests: [
          const CooperativeQuest(
            questId: 'quest_calm',
            title: 'Ground Together',
            intentId: 'ground_together',
            description: 'Calming collective intention',
            targetContributions: 3,
          ),
        ],
      );
    });

    test('non-members cannot submit contributions', () {
      const contribution = CircleQuestContribution(
        contributionId: 'c-01',
        questInstanceId: 'quest_calm',
        actorRef: 'user_stranger',
        intentId: 'ground_together',
        createdAtUtcMs: 1791750000000,
      );

      final success = coordinator.submitContribution(contribution);
      expect(success, isFalse);

      final quest = coordinator.activeQuests.first;
      expect(quest.currentContributions, 0);
    });

    test('joining allows contribution and updates collective progress', () {
      const actor = 'user_ally';
      coordinator.joinQuest('quest_calm', actor);
      expect(coordinator.isMember('quest_calm', actor), isTrue);

      const contribution = CircleQuestContribution(
        contributionId: 'c-02',
        questInstanceId: 'quest_calm',
        actorRef: actor,
        intentId: 'ground_together',
        createdAtUtcMs: 1791750000000,
      );

      final success = coordinator.submitContribution(contribution);
      expect(success, isTrue);

      final quest = coordinator.activeQuests.first;
      expect(quest.currentContributions, 1);
      expect(quest.progressRatio, closeTo(1 / 3, 0.01));
    });

    test('100 repeated submissions of same contributionId count exactly once', () {
      const actor = 'user_persistent';
      coordinator.joinQuest('quest_calm', actor);

      const contribution = CircleQuestContribution(
        contributionId: 'c-replay-999',
        questInstanceId: 'quest_calm',
        actorRef: actor,
        intentId: 'ground_together',
        createdAtUtcMs: 1791750000000,
      );

      for (int i = 0; i < 100; i++) {
        coordinator.submitContribution(contribution);
      }

      final quest = coordinator.activeQuests.first;
      expect(quest.currentContributions, 1);
    });

    test('reaches completion milestone when target contributions met', () {
      for (int i = 1; i <= 3; i++) {
        final actor = 'user_$i';
        coordinator.joinQuest('quest_calm', actor);
        coordinator.submitContribution(
          CircleQuestContribution(
            contributionId: 'contrib-$i',
            questInstanceId: 'quest_calm',
            actorRef: actor,
            intentId: 'ground_together',
            createdAtUtcMs: 1791750000000,
          ),
        );
      }

      final quest = coordinator.activeQuests.first;
      expect(quest.currentContributions, 3);
      expect(quest.isCompleted, isTrue);
      expect(quest.progressRatio, 1.0);
    });

    test('leaving quest revokes membership without penalty or lost milestones', () {
      const actor = 'user_leaving';
      coordinator.joinQuest('quest_calm', actor);
      coordinator.leaveQuest('quest_calm', actor);

      expect(coordinator.isMember('quest_calm', actor), isFalse);

      final rejected = coordinator.submitContribution(
        const CircleQuestContribution(
          contributionId: 'c-post-leave',
          questInstanceId: 'quest_calm',
          actorRef: actor,
          intentId: 'ground_together',
          createdAtUtcMs: 1791750000000,
        ),
      );
      expect(rejected, isFalse);
    });
  });
}
