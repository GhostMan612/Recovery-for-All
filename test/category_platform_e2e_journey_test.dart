// test/category_platform_e2e_journey_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/circle/application/cooperative_quest_coordinator.dart';
import 'package:recovery_for_all/features/circle/data/circle_sync_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/circle_event.dart';
import 'package:recovery_for_all/features/circle/domain/quest_contribution.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_journey_planner.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_schedule_resolver.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';
import 'package:recovery_for_all/features/progression/domain/recovery_action.dart';
import 'package:recovery_for_all/features/progression/domain/reward_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Platform Phases 0-4 End-to-End Coherent Journeys', () {
    test('Path A: Local-first private progression (Phase 1)', () {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final action = RecoveryAction(
        eventId: RecoveryAction.generateEventId(),
        actionType: RecoveryActionType.journal,
        createdAtUtcMs: nowMs,
      );

      final allocation = RewardPolicy.evaluate(action.actionType);
      expect(allocation, isNotNull);
      expect(allocation!.xp, greaterThan(0));
      expect(allocation.sparks, greaterThanOrEqualTo(0));
      expect(action.eventId, isNotEmpty);
    });

    test('Path B: Meeting reachability and navigation fallback (Phase 2)', () async {
      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'mtg-889',
        name: 'Uptown Alano Step Study',
        fellowship: 'AA',
        meetingType: 'Step Study',
        latitude: 44.9500,
        longitude: -93.2900,
        address: '2214 S 10th Ave',
        dayOfWeek: 1, // Monday
        minuteOfDay: 19 * 60, // 7:00 PM
        fetchedAtUtcMs: 1791750000000,
      );

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

      expect(journeyResult.destination.compositeId, 'tsml_aa_minnesota:mtg-889');
      // When native SDK is unlinked, provides external Google Maps directions link
      expect(journeyResult.fallbackExternalDirectionsUrl, isNotNull);
      expect(journeyResult.fallbackExternalDirectionsUrl, contains('google.com/maps/dir'));
    });

    test('Path C: Recovery Circle cooperative support and outbox tombstone (Phase 0 & 3)', () async {
      final syncCoordinator = CircleSyncCoordinator();
      syncCoordinator.clearForTesting();

      // Enqueue draft: fail-closed interim safeguard preserves post locally
      final draft = await syncCoordinator.enqueueEvent(
        outboxId: 'draft-99',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'One day at a time.'},
      );
      expect(draft.status, CircleOutboxStatus.localDraft);

      // Cooperative quest flow
      final questCoordinator = CooperativeQuestCoordinator();
      const actor = 'actor-phoenix';
      questCoordinator.joinQuest('cq_ground_together', actor);
      expect(questCoordinator.isMember('cq_ground_together', actor), isTrue);

      final contributed = questCoordinator.submitContribution(
        CircleQuestContribution(
          contributionId: 'contrib-flow-1',
          questInstanceId: 'cq_ground_together',
          actorRef: actor,
          intentId: 'ground_together',
          createdAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
      expect(contributed, isTrue);

      // Deletion convergence with tombstone
      final tombstone = await syncCoordinator.requestPostDeletion(
        outboxId: 'del-flow-1',
        postId: 'post-xyz',
        ownerUid: 'uid-abc',
      );
      expect(tombstone.status, CircleOutboxStatus.deleted);
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
  });
}
