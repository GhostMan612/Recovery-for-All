// test/quests/quest_optout_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/features/quests/application/quest_progressor.dart';
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

  group('WO-1C — Quest Voluntary Opt-Out & Accommodations', () {
    test('Voluntary skip marks quest as skipped with ZERO stat penalty', () async {
      final petBefore = await db.getPet(RecoveryPetService.defaultPetId);
      final quests = await progressor.getActiveQuests();
      final target = quests.first;

      await progressor.skipQuest(target.instanceId);

      final questsAfter = await progressor.getActiveQuests();
      final skippedQuest = questsAfter.firstWhere((q) => q.instanceId == target.instanceId);
      expect(skippedQuest.status, QuestStatus.skipped);

      final petAfter = await db.getPet(RecoveryPetService.defaultPetId);
      expect(petAfter!.pathXp, petBefore!.pathXp,
          reason: 'Skipping a quest never penalizes XP');
      expect(petAfter.sparks, petBefore.sparks,
          reason: 'Skipping a quest never penalizes Sparks');
      expect(petAfter.energy, petBefore.energy,
          reason: 'Skipping a quest never reduces Energy');
      expect(petAfter.bond, petBefore.bond,
          reason: 'Skipping a quest never reduces Bond');
    });

    test('Selecting and completing accessible accommodation awards quest successfully', () async {
      final quests = await progressor.getActiveQuests();
      final target = quests.first;

      await progressor.selectAlternative(target.instanceId, 'Quiet mindful pause');

      final questsWithAlt = await progressor.getActiveQuests();
      expect(questsWithAlt.first.selectedAlternative, 'Quiet mindful pause');

      final rewardResult = await progressor.completeViaAlternative(target.instanceId);
      expect(rewardResult, isNotNull);
      expect(rewardResult!.outcome, RewardOutcome.granted);
      expect(rewardResult.xpAwarded, 30);
      expect(rewardResult.sparksAwarded, 10);

      final finalQuests = await progressor.getActiveQuests();
      expect(finalQuests.first.isCompleted, isTrue);
    });
  });
}
