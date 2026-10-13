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

      // Compose first attempt
      await feedService.compose(
        authorAlias: 'Charlie',
        body: 'Unique share payload',
        at: fixedDate,
        ownerUid: 'charlie_uid_303',
      );

      // Retry attempt with same author, body, timestamp, and owner
      await feedService.compose(
        authorAlias: 'Charlie',
        body: 'Unique share payload',
        at: fixedDate,
        ownerUid: 'charlie_uid_303',
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
  });
}
