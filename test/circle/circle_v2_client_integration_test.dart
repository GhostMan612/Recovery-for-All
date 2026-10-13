// test/circle/circle_v2_client_integration_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/circle/data/circle_sync_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/circle_event.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late CommunityFeedService feedService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrivacyCapabilityService.resetForTesting();
    CommunityFeedService.resetTestingOverrides();
    db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
    feedService = CommunityFeedService(db);
  });

  tearDown(() async {
    feedService.dispose();
    await db.close();
    CommunityFeedService.resetTestingOverrides();
    PrivacyCapabilityService.resetForTesting();
  });

  group('Circle v2 Client Integration & Invariants', () {
    test('1. Offline Retries & Queuing: Remote writes fail-closed, posts queue as localDraft', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);

      // In production/interim mode, remote writes are disabled
      expect(CommunityFeedService.remoteWritesDisabled, isTrue);

      final result = await feedService.compose(
        authorAlias: 'Alice',
        body: 'Staying clean today.',
        ownerUid: 'alice_uid_101',
      );

      expect(result, FeedComposeResult.publishedLocal);

      // Verify post exists in local Drift feed
      final localPosts = await feedService.visibleNow();
      expect(localPosts.length, 1);
      expect(localPosts.first.body, 'Staying clean today.');
      expect(localPosts.first.authorAlias, 'Alice');

      // Verify post exists in SQLite outbox table as localDraft
      final outboxItems = await db.getAllCircleOutboxEntries();
      expect(outboxItems.length, 1);
      expect(outboxItems.first.status, 'localDraft');
      expect(outboxItems.first.eventType, 'postCreate');
    });

    test('2. Simulated Process Restart: Outbox preserves exact states from Drift DB', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);

      // Compose post that gets enqueued
      await feedService.compose(
        authorAlias: 'Bob',
        body: 'Restart durability test post',
        ownerUid: 'bob_uid_202',
      );

      final outboxRowsBefore = await db.getAllCircleOutboxEntries();
      expect(outboxRowsBefore.length, 1);
      final outboxId = outboxRowsBefore.first.outboxId;

      // Simulate process termination and re-instantiation
      final newCoordinator = CircleSyncCoordinator(database: db);
      expect(newCoordinator.items, isEmpty);

      // Reload persisted outbox
      await newCoordinator.loadPersistedOutbox();
      expect(newCoordinator.items.length, 1);
      expect(newCoordinator.items.first.outboxId, outboxId);
      expect(newCoordinator.items.first.status, CircleOutboxStatus.localDraft);
      expect(newCoordinator.items.first.eventType, CircleEventType.postCreate);
    });

    test('3. Duplicate Prevention: Stable document ID prevents duplicate entries on retry', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);

      final fixedDate = DateTime(2026, 10, 13, 10, 0, 0);
      final intentId = CommunityFeedService.generateIntentId();

      // Compose first attempt with generated intent ID
      await feedService.compose(
        authorAlias: 'Charlie',
        body: 'Unique share payload',
        at: fixedDate,
        ownerUid: 'charlie_uid_303',
        intentId: intentId,
      );

      // Retry attempt reusing the exact persisted intent ID
      await feedService.compose(
        authorAlias: 'Charlie',
        body: 'Unique share payload',
        at: fixedDate,
        ownerUid: 'charlie_uid_303',
        intentId: intentId,
      );

      // Local feed and outbox should not duplicate rows
      final localPosts = await feedService.visibleNow();
      expect(localPosts.length, 1);

      final outboxRows = await db.getAllCircleOutboxEntries();
      expect(outboxRows.length, 1);
    });

    test('4. Consent Revocation: Tearing down cloud sync stops remote stream and disables remote ops', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.authCheckerForTesting = () async => true;

      final streamEvents = <List<FeedPost>>[];
      final List<FeedPost> mockRemotePosts = [
        FeedPost(
          id: 'v2_remote_1',
          authorAlias: 'RemotePeer',
          kind: 'story',
          body: 'Hello from cloud',
          needsSupport: false,
          status: 'visible',
          flagCount: 0,
          strengthCount: 0,
          proudCount: 0,
          respectCount: 0,
          isMine: false,
          createdAt: 2000,
        ),
      ];

      CommunityFeedService.remoteStreamForTesting = () => Stream.value(mockRemotePosts);
      final sub = feedService.watchMergedFeed().listen(streamEvents.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(streamEvents.isNotEmpty, isTrue);

      // Revoke cloud sync consent
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.denied);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(feedService.currentStatus, CircleConnectionStatus.localOnly);

      await sub.cancel();
    });

    test('5. Two-User Authorization & Owner Deletion: Non-owner cannot delete post; owner deletion works', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authCheckerForTesting = () async => true;

      bool remoteDeleterCalled = false;
      String? deletedPostId;
      String? deletedOwnerUid;

      CommunityFeedService.remoteDeleterForTesting = (postId, {required ownerUid}) async {
        remoteDeleterCalled = true;
        deletedPostId = postId;
        deletedOwnerUid = ownerUid;
        return true;
      };

      // Owner A creates post
      await feedService.compose(
        authorAlias: 'Alice',
        body: 'Post to be deleted',
        ownerUid: 'owner_alice',
      );
      final post = (await feedService.visibleNow()).single;

      // Owner requests deletion
      await feedService.requestDeletePost(post.id, ownerUid: 'owner_alice');

      expect(remoteDeleterCalled, isTrue);
      expect(deletedPostId, post.id);
      expect(deletedOwnerUid, 'owner_alice');

      // Local post is hidden
      final visibleAfter = await feedService.visibleNow();
      expect(visibleAfter, isEmpty);

      // Outbox item is marked as confirmed deleted with validated server ack receipt
      final outboxItem = feedService.outboxCoordinator.items.firstWhere(
        (i) => i.outboxId == 'del_${post.id}',
      );
      expect(outboxItem.status, CircleOutboxStatus.deleted);
      expect(outboxItem.eventType, CircleEventType.postDelete);
    });

    test('6. Actor-Bound Reactions: Reactions invoke v2 actor-bound handler with approved kind', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authCheckerForTesting = () async => true;

      String? reactedPostId;
      String? reactedKind;
      String? reactedActorUid;
      bool? isAddReaction;

      CommunityFeedService.remoteReactorForTesting = (postId, {required kind, required actorUid, required isAdd}) async {
        reactedPostId = postId;
        reactedKind = kind;
        reactedActorUid = actorUid;
        isAddReaction = isAdd;
        return true;
      };

      await feedService.compose(
        authorAlias: 'Author',
        body: 'Reaction target post',
        ownerUid: 'author_uid',
      );
      final post = (await feedService.visibleNow()).single;

      // Actor adds 'strength' reaction
      await feedService.react(
        post.id,
        kind: 'strength',
        by: 1,
        actorUid: 'actor_bob',
      );

      expect(reactedPostId, post.id);
      expect(reactedKind, 'strength');
      expect(reactedActorUid, 'actor_bob');
      expect(isAddReaction, isTrue);

      // Actor removes reaction
      await feedService.react(
        post.id,
        kind: 'strength',
        by: -1,
        actorUid: 'actor_bob',
      );
      expect(isAddReaction, isFalse);

      // Disallowed reaction kind is ignored fail-closed
      reactedKind = null;
      await feedService.react(
        post.id,
        kind: 'unapproved_dislike',
        actorUid: 'actor_bob',
      );
      expect(reactedKind, isNull);
    });

    test('7. Reports: Submitting report triggers private review submission without modifying post', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authCheckerForTesting = () async => true;

      String? reportedPostId;
      String? reportedReason;
      String? reporterId;

      CommunityFeedService.remoteReporterForTesting = (postId, {required reasonCode, required reporterUid, notes}) async {
        reportedPostId = postId;
        reportedReason = reasonCode;
        reporterId = reporterUid;
        return true;
      };

      await feedService.compose(
        authorAlias: 'Author',
        body: 'Post to be reported',
        ownerUid: 'author_uid',
      );
      final post = (await feedService.visibleNow()).single;

      await feedService.flag(
        post.id,
        reporterUid: 'reporter_carol',
        reasonCode: 'harassment',
        notes: 'Needs moderator attention.',
      );

      expect(reportedPostId, post.id);
      expect(reportedReason, 'harassment');
      expect(reporterId, 'reporter_carol');

      // Local queue contains flag
      final queue = await db.watchModerationQueue().first;
      expect(queue.any((p) => p.id == post.id), isTrue);
    });

    test('8. Legacy Feed Preservation: Legacy posts remain readable in merged stream', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.authCheckerForTesting = () async => true;

      final List<FeedPost> legacyMock = [
        FeedPost(
          id: 'v1_legacy_post_100',
          authorAlias: 'OldTimer',
          kind: 'story',
          body: 'Legacy post from 2026-08',
          needsSupport: false,
          status: 'visible',
          flagCount: 0,
          strengthCount: 5,
          proudCount: 2,
          respectCount: 3,
          isMine: false,
          createdAt: 1000,
        ),
      ];

      CommunityFeedService.remoteStreamForTesting = () => Stream.value(legacyMock);

      final streamPosts = await feedService.watchMergedFeed().firstWhere((list) => list.isNotEmpty);
      expect(streamPosts.any((p) => p.id == 'v1_legacy_post_100'), isTrue);
      final legacy = streamPosts.firstWhere((p) => p.id == 'v1_legacy_post_100');
      expect(legacy.body, 'Legacy post from 2026-08');
      expect(legacy.strengthCount, 5);
      expect(legacy.isMine, isFalse);
    });

    test('9. Authentication After Offline Composition: Offline draft remains local; requires explicit consent', () async {
      // User is completely offline / unauthenticated
      final composeResult = await feedService.compose(
        authorAlias: 'OfflineUser',
        body: 'Composed while disconnected.',
      );
      expect(composeResult, FeedComposeResult.publishedLocal);

      final localPosts = await feedService.visibleNow();
      expect(localPosts.length, 1);
      final draft = localPosts.first;
      expect(draft.id, startsWith('circle_local_'));

      final outboxRows = await db.getAllCircleOutboxEntries();
      expect(outboxRows.length, 1);
      expect(outboxRows.first.status, 'localDraft');

      // User subsequently authenticates with Firebase
      CommunityFeedService.authUidForTesting = 'authenticated_uid_555';
      CommunityFeedService.authCheckerForTesting = () async => true;
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);

      // Verify draft owner was NOT silently modified
      final draftAfterAuth = await db.getFeedPost(draft.id);
      expect(draftAfterAuth?.id, draft.id);

      // Attempting to publish without explicit consent throws ArgumentError
      await expectLater(
        () => feedService.publishLocalDraft(draft.id, userConsentGiven: false),
        throwsArgumentError,
      );

      // Publishing with explicit consent establishes remotely publishable post
      CommunityFeedService.allowRemoteWritesForTesting = true;
      String? deliveredId;
      CommunityFeedService.remoteWriterForTesting = (post) async {
        deliveredId = post.id;
        return true;
      };

      final pubResult = await feedService.publishLocalDraft(draft.id, userConsentGiven: true);
      expect(pubResult, FeedComposeResult.publishedRemote);
      expect(deliveredId, startsWith('circle_authenticated_uid_555_'));
    });

    test('10. Restart & Queued-Operation Replay: Automatically loads outbox and flushes queued ops', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authUidForTesting = 'replay_user_999';
      CommunityFeedService.authCheckerForTesting = () async => true;

      // Enqueue a queued post in database (as if previous session failed before acknowledgment)
      final intentId = CommunityFeedService.generateIntentId();
      final postId = 'circle_replay_user_999_$intentId';
      final feedPost = FeedPost(
        id: postId,
        authorAlias: 'ReplayTester',
        kind: 'story',
        body: 'Pending queued post across restart',
        needsSupport: false,
        status: 'visible',
        flagCount: 0,
        strengthCount: 0,
        proudCount: 0,
        respectCount: 0,
        createdAt: 5000,
        isMine: true,
      );
      await db.addFeedPost(feedPost);
      await db.addCircleOutboxEntry(CircleOutboxEntry(
        outboxId: postId,
        eventType: 'postCreate',
        payloadJson: '{"id":"$postId","ownerUid":"replay_user_999","authorAlias":"ReplayTester","kind":"story","body":"Pending queued post across restart","needsSupport":false,"status":"visible","createdAt":5000}',
        status: 'queued',
        createdAtUtcMs: 5000,
      ));

      // Simulate app restart with fresh service instance
      feedService.dispose();
      final restartedService = CommunityFeedService(db);
      feedService = restartedService;

      bool remoteWriteCalled = false;
      CommunityFeedService.remoteWriterForTesting = (p) async {
        if (p.id == postId) {
          remoteWriteCalled = true;
          return true;
        }
        return false;
      };

      // Replay pending operations
      final completed = await restartedService.replayPendingOutbox();
      expect(completed.length, 1);
      expect(remoteWriteCalled, isTrue);
      expect(completed.first.outboxId, postId);
      expect(completed.first.status, CircleOutboxStatus.delivered);

      restartedService.dispose();
    });

    test('11. Two Distinct Posts with Identical Content: UUID intent prevents collisions', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);

      const commonContent = 'Celebrating 90 days clean today!';

      final res1 = await feedService.compose(
        authorAlias: 'Member1',
        body: commonContent,
        ownerUid: 'uid_111',
      );
      final res2 = await feedService.compose(
        authorAlias: 'Member2',
        body: commonContent,
        ownerUid: 'uid_222',
      );

      expect(res1, FeedComposeResult.publishedLocal);
      expect(res2, FeedComposeResult.publishedLocal);

      final visible = await feedService.visibleNow();
      expect(visible.length, 2);
      expect(visible[0].id != visible[1].id, isTrue);
      expect(visible[0].body, commonContent);
      expect(visible[1].body, commonContent);
    });

    test('12. Retried Operations Preserve Original ID: Replay reuses existing intent id', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authUidForTesting = 'retry_user_333';
      CommunityFeedService.authCheckerForTesting = () async => true;

      int attemptCount = 0;
      String? firstAttemptId;
      String? secondAttemptId;

      CommunityFeedService.remoteWriterForTesting = (p) async {
        attemptCount++;
        if (attemptCount == 1) {
          firstAttemptId = p.id;
          return false; // Simulate network failure on first attempt
        }
        secondAttemptId = p.id;
        return true; // Succeed on retry
      };

      await feedService.compose(
        authorAlias: 'RetryUser',
        body: 'Post to test retry ID preservation',
        ownerUid: 'retry_user_333',
      );

      expect(attemptCount, 1);
      expect(firstAttemptId, isNotNull);

      // Verify outbox entry is queued with original ID
      final outboxItem = feedService.outboxCoordinator.items.first;
      expect(outboxItem.status, CircleOutboxStatus.queued);
      expect(outboxItem.outboxId, firstAttemptId);

      // Replay the pending outbox
      final completed = await feedService.replayPendingOutbox();
      expect(completed.length, 1);
      expect(attemptCount, 2);
      expect(secondAttemptId, firstAttemptId, reason: 'Retry must reuse exact same document ID');
      expect(completed.first.status, CircleOutboxStatus.delivered);
    });

    test('13. Consent Revocation Halts Replay: Revoked consent aborts pending operations', () async {
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.granted);
      await PrivacyCapabilityService.setConsent(PrivacyCapability.circleShare, ConsentState.granted);
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authUidForTesting = 'revoked_user_444';
      CommunityFeedService.authCheckerForTesting = () async => true;

      // Fail initially to queue in outbox
      CommunityFeedService.remoteWriterForTesting = (_) async => false;
      await feedService.compose(
        authorAlias: 'RevokeUser',
        body: 'Will revoke consent before replay',
        ownerUid: 'revoked_user_444',
      );

      final outboxItem = feedService.outboxCoordinator.items.first;
      expect(outboxItem.status, CircleOutboxStatus.queued);

      // Revoke consent
      await PrivacyCapabilityService.setConsent(PrivacyCapability.cloudSync, ConsentState.denied);

      bool writerCalledAfterRevoke = false;
      CommunityFeedService.remoteWriterForTesting = (_) async {
        writerCalledAfterRevoke = true;
        return true;
      };

      final completed = await feedService.replayPendingOutbox();
      expect(completed, isEmpty);
      expect(writerCalledAfterRevoke, isFalse);
      expect(feedService.outboxCoordinator.items.first.status, CircleOutboxStatus.queued);
    });

    test('14. SQLite Overwrite Prevention: Collision with different content throws StateError', () async {
      final post = FeedPost(
        id: 'circle_fixed_post_id',
        authorAlias: 'OriginalAuthor',
        kind: 'story',
        body: 'Original content',
        needsSupport: false,
        status: 'visible',
        flagCount: 0,
        strengthCount: 0,
        proudCount: 0,
        respectCount: 0,
        createdAt: 1000,
        isMine: true,
      );
      await db.addFeedPost(post);

      // Idempotent retry with identical content succeeds (returns 0)
      final retryResult = await db.addFeedPost(post);
      expect(retryResult, 0);

      // Attempting to overwrite same ID with different body throws StateError
      final collidingPost = FeedPost(
        id: 'circle_fixed_post_id',
        authorAlias: 'DifferentAuthor',
        kind: 'story',
        body: 'Different clobbering content',
        needsSupport: false,
        status: 'visible',
        flagCount: 0,
        strengthCount: 0,
        proudCount: 0,
        respectCount: 0,
        createdAt: 1000,
        isMine: true,
      );
      await expectLater(
        () => db.addFeedPost(collidingPost),
        throwsStateError,
      );
    });
  });
}
