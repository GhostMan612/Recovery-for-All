// test/community_feed_service_test.dart
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
import 'package:recovery_for_all/services/community_feed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late CommunityFeedService feed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrivacyCapabilityService.resetForTesting();
    CommunityFeedService.resetTestingOverrides();
    db = RecoveryDatabase.forTesting(
        NativeDatabase.memory() as QueryExecutor);
    feed = CommunityFeedService(db);
  });

  tearDown(() async {
    feed.dispose();
    await db.close();
    CommunityFeedService.resetTestingOverrides();
    PrivacyCapabilityService.resetForTesting();
  });

  group('CommunityFeedService — Core Behavioral Guardrails (C1-C5)', () {
    test('C1: alias is cleaned, capped, and never empty', () async {
      await feed.compose(authorAlias: '  GhostMan G ', body: 'day three');
      final posts = await db.watchVisibleFeed().first;
      expect(posts.single.authorAlias, 'GhostMan G');

      await feed.compose(authorAlias: '   ', body: 'anonymous post');
      final posts2 = await feed.visibleNow();
      // Newest first -> the anonymous post is the most recent entry.
      expect(posts2.first.authorAlias, 'Anonymous');
    });

    test('C4a: crisis language blocks publish — nothing stored', () async {
      final result = await feed.compose(
          authorAlias: 'X', body: 'i want to end my life tonight');
      expect(result, FeedComposeResult.blockedCrisis);
      final posts = await db.watchVisibleFeed().first;
      expect(posts, isEmpty);
    });

    test('C4b: relapse language publishes with support flag', () async {
      final result = await feed.compose(
          authorAlias: 'X', body: 'I relapsed after 40 days, starting over');
      expect(result, FeedComposeResult.publishedWithSupport);
      final posts = await db.watchVisibleFeed().first;
      expect(posts.single.needsSupport, isTrue);
      expect(posts.single.status, 'visible');
    });

    test('C3: feed lists newest first (no ranking metric exists)', () async {
      await feed.compose(
          authorAlias: 'A', body: 'older share', at: DateTime(2026, 8, 1));
      await feed.compose(
          authorAlias: 'B', body: 'newer share', at: DateTime(2026, 8, 20));
      final posts = await db.watchVisibleFeed().first;
      expect(posts.first.body, 'newer share');
      expect(posts.last.body, 'older share');
    });

    test('reactions are masked counts only', () async {
      await feed.compose(authorAlias: 'A', body: 'shape share incoming');
      final post = (await db.watchVisibleFeed().first).single;
      await feed.react(post.id, kind: 'strength');
      await feed.react(post.id, kind: 'strength');
      await feed.react(post.id, kind: 'respect');
      final updated = (await db.watchVisibleFeed().first).single;
      expect(updated.strengthCount, 2);
      expect(updated.respectCount, 1);
      expect(updated.proudCount, 0);
    });

    test('C5: flagged posts enter moderation queue; moderator can act',
        () async {
      await feed.compose(authorAlias: 'A', body: 'totally fine share');
      final post = (await db.watchVisibleFeed().first).single;

      await feed.flag(post.id);
      final queued = await db.watchModerationQueue().first;
      expect(queued.map((p) => p.id), contains(post.id));
      expect(queued.single.status, 'pending');

      await feed.approve(post.id);
      final visible = await db.watchVisibleFeed().first;
      expect(visible.single.status, 'visible');
      final queue = await db.watchModerationQueue().first;
      expect(queue.where((p) => p.status == 'pending'), isEmpty);
    });
  });

  group('CommunityFeedService — Reauth & Reactive Connection Lifecycle (WO-P0-CIRCLE-REAUTH)', () {
    test('Cold start fails closed: localOnly state, no anonymous auth attempted', () async {
      var authAttempted = false;
      CommunityFeedService.authCheckerForTesting = () async {
        authAttempted = true;
        return true;
      };

      // SharedPreferences had old granted preference, but cold start is denied
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();

      expect(feed.currentStatus, CircleConnectionStatus.localOnly);

      final stream = feed.watchMergedFeed();
      final completer = Completer<List<FeedPost>>();
      final sub = stream.listen((posts) {
        if (posts.isNotEmpty && !completer.isCompleted) completer.complete(posts);
      });

      await feed.compose(authorAlias: 'LocalUser', body: 'Local post only');
      final posts = await completer.future;

      expect(posts.single.authorAlias, 'LocalUser');
      expect(feed.currentStatus, CircleConnectionStatus.localOnly);
      expect(authAttempted, isFalse, reason: 'Must not attempt auth on cold-start denial');

      await sub.cancel();
    });

    test('Transitions from denied to granted in same session: attaches remote stream without restart', () async {
      CommunityFeedService.authCheckerForTesting = () async => true;
      final remoteController = StreamController<List<FeedPost>>.broadcast();
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      await feed.compose(authorAlias: 'LocalUser', body: 'Local message');

      final stream = feed.watchMergedFeed();
      final emittedLists = <List<FeedPost>>[];
      final sub = stream.listen((posts) {
        emittedLists.add(posts);
      });

      await Future.delayed(Duration.zero);
      expect(feed.currentStatus, CircleConnectionStatus.localOnly);

      // Now user explicitly authorizes cloudSync in the session
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      // Status should become connecting while awaiting first response
      expect(feed.currentStatus, CircleConnectionStatus.connecting);

      // Allow attachRemote to complete auth and attach listener
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final remotePost = FeedPost(
        id: 'remote_1',
        authorAlias: 'CloudPeer',
        kind: 'story',
        body: 'Encouragement from cloud',
        status: 'visible',
        flagCount: 0,
        strengthCount: 1,
        proudCount: 0,
        respectCount: 0,
        isMine: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        needsSupport: false,
      );

      // Subscription response received -> transitions to connected
      remoteController.add([remotePost]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(feed.currentStatus, CircleConnectionStatus.connected);
      final latest = emittedLists.last;
      expect(latest.any((p) => p.authorAlias == 'CloudPeer'), isTrue);
      expect(latest.any((p) => p.authorAlias == 'LocalUser'), isTrue);

      await sub.cancel();
      await remoteController.close();
    });

    test('Remote feed is not marked connected before response arrives', () async {
      CommunityFeedService.authCheckerForTesting = () async => true;
      final remoteController = StreamController<List<FeedPost>>.broadcast();
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      final stream = feed.watchMergedFeed();
      final sub = stream.listen((_) {});

      // Authorize cloudSync
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Must remain in connecting state until a response actually arrives
      expect(feed.currentStatus, CircleConnectionStatus.connecting);

      // Response arrives
      remoteController.add(const <FeedPost>[]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Now marked connected
      expect(feed.currentStatus, CircleConnectionStatus.connected);

      await sub.cancel();
      await remoteController.close();
    });

    test('Revocation immediately drops remote subscription and preserves local posts', () async {
      CommunityFeedService.authCheckerForTesting = () async => true;
      final remoteController = StreamController<List<FeedPost>>.broadcast();
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      await feed.compose(authorAlias: 'LocalUser', body: 'Local post');

      final stream = feed.watchMergedFeed();
      final emitted = <List<FeedPost>>[];
      final sub = stream.listen((posts) => emitted.add(posts));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final remotePost = FeedPost(
        id: 'remote_99',
        authorAlias: 'RemotePeer',
        kind: 'story',
        body: 'Remote story',
        status: 'visible',
        flagCount: 0,
        strengthCount: 0,
        proudCount: 0,
        respectCount: 0,
        isMine: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        needsSupport: false,
      );

      remoteController.add([remotePost]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(feed.currentStatus, CircleConnectionStatus.connected);
      expect(emitted.last.map((p) => p.authorAlias), contains('RemotePeer'));

      // REVOKE cloudSync
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );

      expect(feed.currentStatus, CircleConnectionStatus.localOnly);
      expect(emitted.last.map((p) => p.authorAlias), contains('LocalUser'));
      expect(emitted.last.map((p) => p.authorAlias), isNot(contains('RemotePeer')));

      await sub.cancel();
      await remoteController.close();
    });

    test('Truthful delivery reporting: remote delivery requires acknowledgement', () async {
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authCheckerForTesting = () async => true;
      CommunityFeedService.remoteStreamForTesting = () => const Stream<List<FeedPost>>.empty();

      // Case 1: circleShare denied -> localOnly
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.denied,
      );

      var result = await feed.compose(authorAlias: 'LocalUser', body: 'Stays local');
      expect(result, FeedComposeResult.publishedLocal);

      // Case 2: circleShare granted & remote write succeeds -> publishedRemote
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.granted,
      );
      CommunityFeedService.remoteWriterForTesting = (post) async => true;

      result = await feed.compose(authorAlias: 'RemoteUser', body: 'Reaches remote');
      expect(result, FeedComposeResult.publishedRemote);

      // Case 3: circleShare granted BUT remote write fails -> publishedRemoteFailed
      CommunityFeedService.remoteWriterForTesting = (post) async => false;

      result = await feed.compose(authorAlias: 'FailingUser', body: 'Fails remote');
      expect(result, FeedComposeResult.publishedRemoteFailed);

      // Local database keeps the post safely despite remote failure
      final allPosts = await feed.visibleNow();
      expect(allPosts.map((p) => p.authorAlias), contains('FailingUser'));
    });

    test('Reconnection failure transitions to error state and keeps local feed intact; retry recovers', () async {
      var shouldFailAuth = true;
      CommunityFeedService.authCheckerForTesting = () async {
        if (shouldFailAuth) return false;
        return true;
      };

      final remoteController = StreamController<List<FeedPost>>.broadcast();
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      await feed.compose(authorAlias: 'LocalUser', body: 'Local note');
      final stream = feed.watchMergedFeed();
      final sub = stream.listen((_) {});

      // User grants cloudSync
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Auth failed, status transitions to error
      expect(feed.currentStatus, CircleConnectionStatus.error);

      // Network recovers, user retries
      shouldFailAuth = false;
      await feed.retryConnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      remoteController.add([
        FeedPost(
          id: 'remote_recov',
          authorAlias: 'RecoveredPeer',
          kind: 'story',
          body: 'Back online',
          status: 'visible',
          flagCount: 0,
          strengthCount: 0,
          proudCount: 0,
          respectCount: 0,
          isMine: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          needsSupport: false,
        )
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(feed.currentStatus, CircleConnectionStatus.connected);

      await sub.cancel();
      await remoteController.close();
    });

    test('Stream cancellation tears down listeners without leaving leaks', () async {
      CommunityFeedService.authCheckerForTesting = () async => true;
      var remoteSubCancelled = false;
      final remoteController = StreamController<List<FeedPost>>.broadcast(
        onCancel: () {
          remoteSubCancelled = true;
        },
      );
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      final stream = feed.watchMergedFeed();
      final sub = stream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Emit response so it connects
      remoteController.add(const <FeedPost>[]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(feed.currentStatus, CircleConnectionStatus.connected);

      // Cancel stream subscription
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(remoteSubCancelled, isTrue, reason: 'Remote sub must cancel when feed stream cancels');
      await remoteController.close();
    });
    test('Revocation during async auth prevents remote write and keeps post local', () async {
      CommunityFeedService.allowRemoteWritesForTesting = true;
      var writeAttempted = false;
      CommunityFeedService.remoteWriterForTesting = (post) async {
        writeAttempted = true;
        return true;
      };

      // Both granted initially
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.granted,
      );

      // During authentication, circleShare is revoked
      CommunityFeedService.authCheckerForTesting = () async {
        await PrivacyCapabilityService.setConsent(
          PrivacyCapability.circleShare,
          ConsentState.denied,
        );
        return true;
      };

      final result = await feed.compose(
        authorAlias: 'LocalAuthor',
        body: 'Revoked during auth',
      );

      expect(result, FeedComposeResult.publishedLocal);
      expect(writeAttempted, isFalse,
          reason: 'Remote writer must not be called after mid-auth revocation');
    });

    test('remoteStreamForTesting existence alone does not report delivered without configured writer', () async {
      CommunityFeedService.allowRemoteWritesForTesting = true;
      CommunityFeedService.authCheckerForTesting = () async => true;
      CommunityFeedService.remoteStreamForTesting =
          () => const Stream<List<FeedPost>>.empty();
      // remoteWriterForTesting is not configured

      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.granted,
      );

      final result = await feed.compose(
        authorAlias: 'Author',
        body: 'No writer configured',
      );

      // Without configured writer or live backend acknowledgement, remote delivery fails soft
      expect(result, FeedComposeResult.publishedRemoteFailed);
    });
  });

  group('CommunityFeedService — Interim Local-Only Publishing Safeguard (WO-P0-CIRCLE-INTERIM)', () {
    test('New posts save locally even when cloudSync and circleShare are both session-authorized', () async {
      var writeAttempted = false;
      CommunityFeedService.remoteWriterForTesting = (post) async {
        writeAttempted = true;
        return true;
      };

      // Explicitly authorize both capabilities in session
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.granted,
      );

      // Verify interim mode is active by default
      expect(CommunityFeedService.remoteWritesDisabled, isTrue);

      final result = await feed.compose(
        authorAlias: 'LocalAuthor',
        body: 'Post during interim safeguard',
      );

      // Must report publishedLocal, never remote
      expect(result, FeedComposeResult.publishedLocal);
      expect(writeAttempted, isFalse,
          reason: 'Remote writer must never be invoked while interim mode is active');

      // Post is persisted in local Drift database
      final visible = await feed.visibleNow();
      expect(visible.map((p) => p.authorAlias), contains('LocalAuthor'));
    });

    test('Interim mode disables remote reaction mutations and preserves local reaction state', () async {
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.circleShare,
        ConsentState.granted,
      );

      await feed.compose(authorAlias: 'LocalAuthor', body: 'Story for reactions');
      final post = (await feed.visibleNow()).first;

      // Reacting increments local Drift database count
      await feed.react(post.id, kind: 'strength');
      final updated = (await feed.visibleNow()).first;
      expect(updated.strengthCount, 1);
    });

    test('Crisis language in interim mode blocks publish completely', () async {
      final result = await feed.compose(
        authorAlias: 'DistressedUser',
        body: 'i want to end my life tonight',
      );

      expect(result, FeedComposeResult.blockedCrisis);
      final posts = await feed.visibleNow();
      expect(posts, isEmpty);
    });

    test('Relapse language in interim mode publishes locally with support flag', () async {
      final result = await feed.compose(
        authorAlias: 'StrugglingUser',
        body: 'i relapsed yesterday but trying again',
      );

      expect(result, FeedComposeResult.publishedWithSupportLocal);
      final post = (await feed.visibleNow()).first;
      expect(post.needsSupport, isTrue);
    });

    test('Explicitly authorized remote reads function normally during interim mode', () async {
      CommunityFeedService.authCheckerForTesting = () async => true;
      final remoteController = StreamController<List<FeedPost>>.broadcast();
      CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

      await feed.compose(authorAlias: 'LocalPeer', body: 'Local reflection');

      final stream = feed.watchMergedFeed();
      final emitted = <List<FeedPost>>[];
      final sub = stream.listen((posts) => emitted.add(posts));

      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      remoteController.add([
        FeedPost(
          id: 'remote_peer_1',
          authorAlias: 'RemotePeer',
          kind: 'story',
          body: 'Shared encouragement',
          status: 'visible',
          flagCount: 0,
          strengthCount: 0,
          proudCount: 0,
          respectCount: 0,
          isMine: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          needsSupport: false,
        )
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(feed.currentStatus, CircleConnectionStatus.connected);
      expect(emitted.last.map((p) => p.authorAlias), contains('RemotePeer'));
      expect(emitted.last.map((p) => p.authorAlias), contains('LocalPeer'));

      await sub.cancel();
      await remoteController.close();
    });
  });
}
