// test/category_platform_e2e_journey_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/circle/application/cooperative_quest_coordinator.dart';
import 'package:recovery_for_all/features/circle/data/circle_sync_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/circle_event.dart';
import 'package:recovery_for_all/features/circle/domain/quest_contribution.dart';
import 'package:recovery_for_all/features/game/application/battle_session_service.dart';
import 'package:recovery_for_all/features/game/domain/battle_state.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_journey_planner.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_schedule_resolver.dart';
import 'package:recovery_for_all/features/navigator/data/meeting_destination_adapter.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';
import 'package:recovery_for_all/features/navigator/ui/widgets/journey_sheet.dart';
import 'package:recovery_for_all/features/progression/application/recovery_action_coordinator.dart';
import 'package:recovery_for_all/features/progression/domain/recovery_action.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';
import 'package:recovery_for_all/features/quests/application/quest_progressor.dart';
import 'package:recovery_for_all/features/quests/data/quest_catalog.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Platform Phases 0-4 End-to-End Coherent Journeys', () {
    late RecoveryDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = RecoveryDatabase.forTesting(NativeDatabase.memory());
      RecoveryPetService.bindDatabase(db);
      await RecoveryPetService.ensureHatched();
    });

    tearDown(() async {
      await db.close();
    });

    test('Path A: Screen-to-ledger atomic progression and idempotency (Phase 1)', () async {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final coordinator = RecoveryActionCoordinator(database: db);
      final eventId = RecoveryAction.generateEventId();

      final action = RecoveryAction(
        eventId: eventId,
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: nowMs,
        origin: ActionOrigin.localUi,
      );

      // 1. First execution allocates rewards atomically
      final firstResult = await coordinator.processAction(action);
      expect(firstResult.outcome, RewardOutcome.granted);
      expect(firstResult.xpAwarded, 25);
      expect(firstResult.sparksAwarded, 10);

      // Verify canonical ledger entries in database
      final receipt = await (db.select(db.rewardReceipts)
            ..where((t) => t.eventId.equals(eventId)))
          .getSingleOrNull();
      expect(receipt, isNotNull);
      expect(receipt!.xp, 25);
      expect(receipt.sparks, 10);
      expect(receipt.status, 'granted');

      // Verify constellation star projection occurred
      final stars = await db.select(db.constellationPoints).get();
      expect(stars.any((s) => s.id.contains(eventId)), isTrue);

      // 2. Double-tap / duplicate retry with same eventId fails safe and idempotent
      final duplicateResult = await coordinator.processAction(action);
      expect(duplicateResult.outcome, RewardOutcome.alreadyApplied);
      expect(duplicateResult.xpAwarded, 0);
      expect(duplicateResult.sparksAwarded, 0);

      // Assert pet balance was NOT inflated
      final pet = await db.getPet(RecoveryPetService.defaultPetId);
      expect(pet, isNotNull);
      expect(pet!.pathXp, 25);
      expect(pet.sparks, 10);
    });

    test('Path A2: Intent-bound journal reward binding survives retries and prevents double awards', () async {
      const userText = 'Clean and sober 30 days today!';
      final intentHash = (userText.hashCode & 0x7FFFFFFF).toRadixString(16);
      final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final entryId = 'journal_${intentHash}_$minuteBucket';
      final stableEventId = 'action_reward_$entryId';

      // First save attempt
      final coordinator = RecoveryActionCoordinator(database: db);
      final action1 = RecoveryAction(
        eventId: stableEventId,
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        origin: ActionOrigin.localUi,
      );
      final res1 = await coordinator.processAction(action1);
      expect(res1.outcome, RewardOutcome.granted);
      expect(res1.sparksAwarded, 10);
      expect(res1.xpAwarded, 25);

      // Simulated network retry or rapid button repeat of the exact same user intent
      final actionRetry = RecoveryAction(
        eventId: stableEventId,
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        origin: ActionOrigin.localUi,
      );
      final resRetry = await coordinator.processAction(actionRetry);
      expect(resRetry.outcome, RewardOutcome.alreadyApplied);
      expect(resRetry.sparksAwarded, 0);
      expect(resRetry.xpAwarded, 0);
    });

    test('Path B: Meeting reachability, planning, and navigation fallback (Phase 2)', () async {
      final recoveryMeeting = RecoveryMeeting(
        id: 'tsml_aa_minnesota:mtg-889',
        name: 'Uptown Alano Step Study',
        fellowship: 'AA',
        address: '2214 S 10th Ave, Minneapolis, MN',
        type: 'Step Study',
        time: '7:00 PM',
        day: 1, // Monday
        minutes: 19 * 60,
        latitude: 44.9500,
        longitude: -93.2900,
      );

      final destination = MeetingDestinationAdapter.fromRecoveryMeeting(recoveryMeeting);
      expect(destination.compositeId, 'tsml_aa_minnesota:mtg-889');

      final schedule = MeetingScheduleResolver.resolveNextOccurrence(
        destination,
        referenceTime: DateTime(2026, 10, 12, 12, 0), // Monday noon
      );

      expect(schedule.status, MeetingScheduleStatus.scheduled);
      expect(schedule.minutesUntil, 7 * 60);

      final planner = MeetingJourneyPlanner();
      final journeyResult = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      // When native SDK is unlinked, provides external Google Maps directions link
      expect(journeyResult.fallbackExternalDirectionsUrl, isNotNull);
      expect(journeyResult.fallbackExternalDirectionsUrl, contains('google.com/maps/dir'));
      expect(journeyResult.isRouteAvailableInApp, isFalse);
    });

    testWidgets('Path B2: JourneySheet renders destination details and external navigation trigger', (tester) async {
      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'mtg-ui-1',
        name: 'St. Paul Sunrise Group',
        fellowship: 'AA',
        meetingType: 'Discussion',
        latitude: 44.9400,
        longitude: -93.1000,
        address: '123 University Ave',
        fetchedAtUtcMs: 1791750000000,
      );

      const planResult = PlannedMeetingJourneyResult(
        destination: destination,
        schedule: ScheduleResolutionResult(
          status: MeetingScheduleStatus.scheduled,
          minutesUntil: 45,
          statusDescription: 'Starts in 45m',
        ),
        fallbackExternalDirectionsUrl: 'https://maps.google.com/test',
        isRouteAvailableInApp: false,
        statusMessage: 'In-app transit routing unavailable. Open external directions.',
      );

      bool launchedExternal = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: JourneySheet(
              planResult: planResult,
              onLaunchExternalDirections: () => launchedExternal = true,
            ),
          ),
        ),
      );

      expect(find.text('St. Paul Sunrise Group'), findsOneWidget);
      expect(find.textContaining('AA \u2022 Starts in 45m'), findsOneWidget);

      final directionsBtn = find.text('Open External Directions (Google Maps)');
      expect(directionsBtn, findsOneWidget);
      await tester.tap(directionsBtn);
      await tester.pump();
      expect(launchedExternal, isTrue);
    });

    test('Path C: Recovery Circle cooperative support and durable outbox restart survival (Phase 0 & 3)', () async {
      // 1. Initial coordinator enqueues post with durable database backing
      final syncCoordinator = CircleSyncCoordinator(database: db);

      final draft = await syncCoordinator.enqueueEvent(
        outboxId: 'draft-durable-1',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'One day at a time.'},
      );
      expect(draft.status, CircleOutboxStatus.localDraft);

      // Verify row persisted in Drift database
      final row = await db.getCircleOutboxEntry('draft-durable-1');
      expect(row, isNotNull);
      expect(row!.status, 'localDraft');
      expect(row.payloadJson, contains('One day at a time.'));

      // 2. Restart simulation: brand new instance reloads persisted state
      final restartedCoordinator = CircleSyncCoordinator(database: db);
      await restartedCoordinator.loadPersistedOutbox();
      expect(restartedCoordinator.items.length, 1);
      expect(restartedCoordinator.items.first.outboxId, 'draft-durable-1');

      // 3. Deletion state accuracy: request marks as deleting, requires verified proof before deleted
      final pendingDeletion = await restartedCoordinator.requestPostDeletion(
        outboxId: 'del-flow-1',
        postId: 'post-xyz',
        ownerUid: 'uid-abc',
      );
      expect(pendingDeletion.status, CircleOutboxStatus.deleting);

      // Persisted in deleting state
      final delRow = await db.getCircleOutboxEntry('del-flow-1');
      expect(delRow?.status, 'deleting');

      // Server acknowledgment promotes to deleted only with verified receipt
      final receipt = CircleServerAckReceipt(
        outboxId: 'del-flow-1',
        serverToken: 'ack_token_123',
        serverTimestampUtcMs: DateTime.now().millisecondsSinceEpoch,
        isVerified: true,
      );
      final tombstone = await restartedCoordinator.confirmServerAck(
        outboxId: 'del-flow-1',
        receipt: receipt,
      );
      expect(tombstone.status, CircleOutboxStatus.deleted);

      final finalDelRow = await db.getCircleOutboxEntry('del-flow-1');
      expect(finalDelRow?.status, 'deleted');
    });

    test('Path D: Non-punitive opt-out and independence from gameplay (Phase 1, 3, 4)', () {
      final questCoordinator = CooperativeQuestCoordinator();
      const actor = 'actor-quiet';

      // Joining then voluntarily leaving
      questCoordinator.joinQuest('cq_prepare_week', actor);
      questCoordinator.leaveQuest('cq_prepare_week', actor);

      // No negative consequences or penalties
      expect(questCoordinator.isMember('cq_prepare_week', actor), isFalse);

      // Submitting while not a member is safely ignored
      final ignored = questCoordinator.submitContribution(
        CircleQuestContribution(
          contributionId: 'contrib-ignored',
          questInstanceId: 'cq_prepare_week',
          actorRef: actor,
          intentId: 'prepare_week',
          createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
      expect(ignored, isFalse);
    });

    test('Path E: Combat engine reducer and gentle quests integration (Phase 1)', () async {
      // 1. Gentle quest accommodation workflow
      final progressor = QuestProgressor(database: db);
      final activeQuests = await progressor.getActiveQuests();
      expect(activeQuests, isNotEmpty);

      final initialQuest = activeQuests.first;
      final def = QuestCatalog.getDefinition(initialQuest.definitionId)!;
      final alt = def.alternativeAccommodations.first;

      await progressor.selectAlternative(
        initialQuest.instanceId,
        alt,
      );
      final refreshed = (await progressor.getActiveQuests()).first;
      expect(refreshed.selectedAlternative, alt);

      // 2. Battle session pure reducer workflow
      final state = await BattleSessionService.startSession(
        db: db,
        petEnergy: 80,
        petBond: 10,
        petSparks: 50,
        difficulty: BattleDifficulty.guided,
        customSeed: 12345,
      );

      expect(state.phase, BattlePhase.playerTurn);
      expect(state.monster.maxHp, lessThan(40));
    });
  });
}
