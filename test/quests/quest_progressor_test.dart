// test/quests/quest_progressor_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/progression/domain/recovery_action.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/features/quests/application/quest_progressor.dart';
import 'package:recovery_for_all/features/quests/data/quest_catalog.dart';
import 'package:recovery_for_all/features/quests/domain/quest_instance.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late QuestProgressor progressor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    RecoveryPetService.bindDatabase(db);
    await RecoveryPetService.ensureHatched();
    progressor = QuestProgressor(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WO-1C — Quest Progressor & Idempotent Rewards', () {
    test('Daily gentle quest generates deterministically for current date bucket', () async {
      final quests = await progressor.getActiveQuests();

      expect(quests, isNotEmpty);
      final q = quests.first;
      expect(q.status, QuestStatus.active);
      expect(q.currentProgress, 0);
      expect(q.targetCount, 1);
      expect(q.dateBucket, QuestProgressor.dateKey());
    });

    test('Action matching quest definition advances progress and triggers exact-once reward', () async {
      final quests = await progressor.getActiveQuests();
      final activeQuest = quests.first;
      final def = QuestCatalog.getDefinition(activeQuest.definitionId)!;
      final matchingType = def.allowedActionTypes.first;

      final action = RecoveryAction(
        eventId: 'test_action_matching_1',
        actionType: matchingType,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        origin: ActionOrigin.localUi,
        proofTier: ProofTier.locallyObserved,
      );

      final result = await progressor.onActionCommitted(action);

      expect(result.newlyCompletedQuests, hasLength(1));
      final completed = result.newlyCompletedQuests.first;
      expect(completed.isCompleted, isTrue);
      expect(result.rewardResult, isNotNull);
      expect(result.rewardResult!.outcome, RewardOutcome.granted);
      expect(result.rewardResult!.xpAwarded, 30);
      expect(result.rewardResult!.sparksAwarded, 10);

      // Subsequent identical action does not re-complete or double-grant
      final repeatResult = await progressor.onActionCommitted(action);
      expect(repeatResult.newlyCompletedQuests, isEmpty);
      expect(repeatResult.rewardResult, isNull);
    });

    test('Non-matching recovery action leaves quest progress unchanged', () async {
      final quests = await progressor.getActiveQuests();
      final activeQuest = quests.first;
      final def = QuestCatalog.getDefinition(activeQuest.definitionId)!;

      // Find an action type not in allowedActionTypes
      final nonMatchingType = RecoveryActionType.values.firstWhere(
        (t) => !def.allowedActionTypes.contains(t),
      );

      final action = RecoveryAction(
        eventId: 'test_action_non_matching',
        actionType: nonMatchingType,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      final result = await progressor.onActionCommitted(action);
      expect(result.newlyCompletedQuests, isEmpty);
      final currentQuests = await progressor.getActiveQuests();
      expect(currentQuests.first.currentProgress, 0);
    });

    test('Completing quest synchronizes with legacy RecoveryPetService.todayQuest', () async {
      final quests = await progressor.getActiveQuests();
      final def = QuestCatalog.getDefinition(quests.first.definitionId)!;

      final action = RecoveryAction(
        eventId: 'test_sync_action',
        actionType: def.allowedActionTypes.first,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      await progressor.onActionCommitted(action);

      final legacyQuest = await RecoveryPetService.todayQuest();
      expect(legacyQuest.done, isTrue,
          reason: 'Legacy todayQuest must reflect completed status');
    });
  });
}
