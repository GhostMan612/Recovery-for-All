// test/community_feed_reauth_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/screens/community_feed_screen.dart';
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
    try {
      await db.close().timeout(const Duration(milliseconds: 200));
    } catch (_) {}
    CommunityFeedService.resetTestingOverrides();
    PrivacyCapabilityService.resetForTesting();
  });

  Widget createSubject() {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: CommunityFeedScreen(database: db, feedService: feed),
      ),
    );
  }

  Future<void> pumpFrames(WidgetTester tester, [int count = 5]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpUntilStatus(
    WidgetTester tester,
    CommunityFeedService feed,
    CircleConnectionStatus target, [
    int maxPumps = 60,
  ]) async {
    for (int i = 0; i < maxPumps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (feed.currentStatus == target) return;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    }
  }

  group('Recovery Circle — Contextual Reauth & Reactive Lifecycle (WO-P0-CIRCLE-REAUTH)', () {
    testWidgets('Cold-start denial displays contextual localOnly banner beneath crisis door',
        (tester) async {
      try {
        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        // Rule C4: Crisis support door remains pinned at top of feed permanently
        expect(find.text('Need help now? 988 \u00b7 your people \u00b7 one tap away'),
            findsOneWidget);

        // Contextual reconnection control appears when session auth is denied
        expect(find.byKey(const Key('circle_status_local_only')), findsOneWidget);
        expect(find.text('Local feed only \u00b7 Cloud sync not authorized'),
            findsOneWidget);
        expect(find.byKey(const Key('reconnect_cloud_button')), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Connect button opens structured cloud disclosure dialog; cancel stays local',
        (tester) async {
      try {
        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        // Tap connect
        await tester.tap(find.byKey(const Key('reconnect_cloud_button')));
        await pumpFrames(tester, 4);

        // Cloud disclosure presented
        final disclosure =
            PrivacyCapabilityState.disclosures[PrivacyCapability.cloudSync]!;
        expect(find.text(disclosure.title), findsOneWidget);
        expect(find.text(disclosure.description), findsOneWidget);
        expect(find.text('Data sent: ${disclosure.transmittedData}'), findsOneWidget);
        expect(find.text('Recipient: ${disclosure.recipient}'), findsOneWidget);
        expect(find.text('Offline fallback: ${disclosure.fallback}'), findsOneWidget);

        // Stay Local button cancels
        expect(find.byKey(const Key('deny_reconnect_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('deny_reconnect_button')));
        await pumpFrames(tester, 10);

        // Dialog dismissed, still localOnly
        expect(find.text(disclosure.title), findsNothing);
        expect(find.byKey(const Key('circle_status_local_only')), findsOneWidget);
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync),
            isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Explicit session authorization connects remote feed without app restart',
        (tester) async {
      try {
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

        await feed.compose(authorAlias: 'LocalAuthor', body: 'Local reflection');

        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        expect(find.text('Local reflection'), findsOneWidget);
        expect(find.byKey(const Key('circle_status_local_only')), findsOneWidget);

        // Tap connect and authorize
        await tester.tap(find.byKey(const Key('reconnect_cloud_button')));
        await pumpFrames(tester, 4);

        await tester.tap(find.byKey(const Key('allow_reconnect_button')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(tester, 6);

        // Independent privacy authorization: cloudSync is granted, circleShare remains denied
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync),
            isTrue);
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare),
            isFalse);

        // Subscription response arrives -> status becomes connected
        final remotePost = FeedPost(
          id: 'remote_77',
          authorAlias: 'CloudFriend',
          kind: 'story',
          body: 'Strength from afar',
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
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected, 60);

        expect(feed.currentStatus, CircleConnectionStatus.connected);

        // Both local and remote are present in feed
        expect(find.text('Local reflection'), findsOneWidget);
        expect(find.text('Strength from afar'), findsOneWidget);

        // Connected state hides the reconnect banner
        expect(find.byKey(const Key('circle_status_connected')), findsOneWidget);
        expect(find.byKey(const Key('circle_status_local_only')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Revocation immediately tears down remote view and restores local banner',
        (tester) async {
      try {
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

        // Pre-grant in session using runAsync to resolve platform message
        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.granted,
          );
        });

        await feed.compose(authorAlias: 'LocalAuthor', body: 'Local memory');

        await tester.pumpWidget(createSubject());
        // Emit response so it connects
        remoteController.add(const <FeedPost>[]);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        final remotePost = FeedPost(
          id: 'remote_88',
          authorAlias: 'CloudFriend',
          kind: 'story',
          body: 'Remote story here',
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
        await pumpFrames(tester, 4);

        expect(find.text('Remote story here'), findsOneWidget);
        expect(find.byKey(const Key('circle_status_connected')), findsOneWidget);

        // Revoke capability
        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.denied,
          );
        });
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.localOnly);

        // Remote post is immediately removed
        expect(find.text('Remote story here'), findsNothing);
        // Local post remains available
        expect(find.text('Local memory'), findsOneWidget);
        // Reconnect banner is back
        expect(find.byKey(const Key('circle_status_local_only')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Connection failure shows error banner with retry control',
        (tester) async {
      try {
        var authFails = true;
        CommunityFeedService.authCheckerForTesting = () async => !authFails;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        // Tap connect and authorize
        await tester.tap(find.byKey(const Key('reconnect_cloud_button')));
        await pumpFrames(tester, 4);

        await tester.tap(find.byKey(const Key('allow_reconnect_button')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(tester, 6);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.error);

        // Auth failed -> Error banner displayed
        expect(find.byKey(const Key('circle_status_error')), findsOneWidget);
        expect(find.text('Connection error \u00b7 Viewing local posts'), findsOneWidget);
        expect(find.byKey(const Key('retry_cloud_button')), findsOneWidget);

        // Network recovers, tap retry
        authFails = false;
        await tester.tap(find.byKey(const Key('retry_cloud_button')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(tester, 6);

        remoteController.add([
          FeedPost(
            id: 'remote_recovered',
            authorAlias: 'OnlinePeer',
            kind: 'story',
            body: 'Reconnected!',
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
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        expect(find.text('Reconnected!'), findsOneWidget);
        expect(find.byKey(const Key('circle_status_connected')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Compose snackbar accurately distinguishes local-only draft from remote share',
        (tester) async {
      try {
        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        // Local only: compose post
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);

        await tester.enterText(find.byType(TextField), 'Local journal draft');
        await pumpFrames(tester, 2);
        final buttonFinder = find.byWidgetPredicate(
          (w) => w is ElevatedButton &&
                 (w.child is Text &&
                  ((w.child as Text).data == 'Save to local circle' ||
                   (w.child as Text).data == 'Share with the circle')),
        );
        await tester.tap(buttonFinder);
        await pumpFrames(tester, 12);

        // Expect local-only confirmation message (does not falsely claim remote sharing)
        expect(find.text('Saved to your local circle.'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Independent circleShare authorization on explicit remote compose attempt',
        (tester) async {
      try {
        CommunityFeedService.allowRemoteWritesForTesting = true;
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;
        CommunityFeedService.remoteWriterForTesting = (post) async => true;

        // Authorize cloudSync only in session
        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.granted,
          );
        });

        await tester.pumpWidget(createSubject());
        remoteController.add(const <FeedPost>[]);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        // Verify circleShare is still denied
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare),
            isFalse);

        // Open composer to share with connected circle
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);
        await tester.enterText(find.byType(TextField), 'Attempting circle share');
        await pumpFrames(tester, 2);

        // Tap share button -> should prompt for circleShare disclosure
        await tester.tap(find.text('Share with the circle'));
        await pumpFrames(tester, 6);

        final shareDisclosure =
            PrivacyCapabilityState.disclosures[PrivacyCapability.circleShare]!;
        expect(find.text(shareDisclosure.title), findsOneWidget);
        expect(find.text('Data sent: ${shareDisclosure.transmittedData}'),
            findsOneWidget);

        // User opts to Stay Local
        await tester.tap(find.byKey(const Key('deny_circle_share_button')));
        await pumpFrames(tester, 12);

        // Post was saved locally, not remotely
        expect(find.text('Saved to your local circle.'), findsOneWidget);
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare),
            isFalse);

        // Compose another post and authorize circleShare
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);
        await tester.enterText(find.byType(TextField), 'Second attempt authorized');
        await pumpFrames(tester, 2);
        await tester.tap(find.text('Share with the circle'));
        await pumpFrames(tester, 6);

        expect(find.text(shareDisclosure.title), findsOneWidget);
        await tester.tap(find.byKey(const Key('allow_circle_share_button')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(tester, 12);

        // Authorized for session and acknowledged by remote backend
        expect(find.text('Shared with the circle.'), findsOneWidget);
        expect(PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare),
            isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Truthful delivery reporting: remote write failure shows error feedback',
        (tester) async {
      try {
        CommunityFeedService.allowRemoteWritesForTesting = true;
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;
        // Simulate backend write failure
        CommunityFeedService.remoteWriterForTesting = (post) async => false;

        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.granted,
          );
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.circleShare,
            ConsentState.granted,
          );
        });

        await tester.pumpWidget(createSubject());
        remoteController.add(const <FeedPost>[]);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        // Compose post
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);
        await tester.enterText(find.byType(TextField), 'Post with failing backend');
        await pumpFrames(tester, 2);
        await tester.tap(find.text('Share with the circle'));
        await pumpFrames(tester, 12);

        // Truthfully reports local save + remote failure, never claims "Shared with the circle."
        expect(find.text('Saved locally. Remote sharing failed.'), findsOneWidget);
        expect(find.text('Shared with the circle.'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });
    testWidgets('Circle share authorization persistence failure falls back to local save truthfully',
        (tester) async {
      try {
        CommunityFeedService.allowRemoteWritesForTesting = true;
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;
        CommunityFeedService.remoteWriterForTesting = (post) async => true;

        // Simulate persistence write failure specifically for circleShare
        PrivacyCapabilityService.persistenceOverrideForTesting =
            (cap, state) async => cap != PrivacyCapability.circleShare;

        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.granted,
          );
        });

        await tester.pumpWidget(createSubject());
        remoteController.add(const <FeedPost>[]);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        // Compose post
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);
        await tester.enterText(
            find.byType(TextField), 'Post with failing persistence');
        await pumpFrames(tester, 2);
        await tester.tap(find.text('Share with the circle'));
        await pumpFrames(tester, 6);

        // Prompt shows disclosure -> tap allow
        final shareDisclosure =
            PrivacyCapabilityState.disclosures[PrivacyCapability.circleShare]!;
        expect(find.text(shareDisclosure.title), findsOneWidget);
        await tester.tap(find.byKey(const Key('allow_circle_share_button')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(tester, 12);

        // Persistence failed -> circleShare was not granted
        expect(
            PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare),
            isFalse);

        // Truthfully reports local-only save, never claims remote delivery
        expect(find.text('Saved to your local circle.'), findsOneWidget);
        expect(find.text('Shared with the circle.'), findsNothing);
      } finally {
        PrivacyCapabilityService.persistenceOverrideForTesting = null;
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });
  });

  group('Recovery Circle — Interim Local-Only Safeguard UI (WO-P0-CIRCLE-INTERIM)', () {
    testWidgets('Composer makes local save clear, omits circleShare prompt, and saves locally',
        (tester) async {
      try {
        CommunityFeedService.authCheckerForTesting = () async => true;
        final remoteController = StreamController<List<FeedPost>>.broadcast();
        addTearDown(remoteController.close);
        CommunityFeedService.remoteStreamForTesting = () => remoteController.stream;

        await tester.runAsync(() async {
          await PrivacyCapabilityService.setConsent(
            PrivacyCapability.cloudSync,
            ConsentState.granted,
          );
        });

        await tester.pumpWidget(createSubject());
        remoteController.add(const <FeedPost>[]);
        await pumpUntilStatus(tester, feed, CircleConnectionStatus.connected);

        // Open composer
        await tester.tap(find.byType(FloatingActionButton));
        await pumpFrames(tester, 6);

        // Verify subtitle clearly states local-only persistence
        expect(
            find.text(
                'Saved to this device only \u00b7 remote publishing paused \u00b7 no location required'),
            findsOneWidget);

        // Verify submit button explicitly states local circle
        expect(find.text('Save to local circle'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Private note on device');
        await pumpFrames(tester, 2);

        // Tap submit
        await tester.tap(find.text('Save to local circle'));
        await pumpFrames(tester, 12);

        // circleShare prompt was NEVER shown
        final shareDisclosure =
            PrivacyCapabilityState.disclosures[PrivacyCapability.circleShare]!;
        expect(find.text(shareDisclosure.title), findsNothing);

        // Feedback confirms saved locally
        expect(find.text('Saved to your local circle.'), findsOneWidget);
        expect(find.text('Shared with the circle.'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Reactions are presented as paused and disabled in interim mode',
        (tester) async {
      try {
        await feed.compose(authorAlias: 'Author', body: 'Story with reactions');

        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        // Verify reaction buttons are disabled and semantics reflect paused status
        for (final kind in ['strength', 'proud', 'respect']) {
          final button = tester.widget<InkWell>(
            find.byKey(Key('reaction_${kind}_button')),
          );
          expect(button.onTap, isNull,
              reason: '$kind reaction must be non-operational in interim mode');
        }
        expect(
            find.bySemanticsLabel(RegExp(r'strength.*reactions paused')),
            findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });

    testWidgets('Local post deletion explicitly confirms device deletion without remote claim',
        (tester) async {
      try {
        await feed.compose(authorAlias: 'Author', body: 'Post to delete');

        await tester.pumpWidget(createSubject());
        await pumpFrames(tester, 3);

        expect(find.text('Post to delete'), findsOneWidget);

        // Find and tap local delete icon
        await tester.tap(find.byTooltip('Delete your local post'));
        await pumpFrames(tester, 6);

        // Feedback specifically confirms deletion from this device only
        expect(find.text('Post deleted from your device.'), findsOneWidget);
        expect(find.text('Post to delete'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await pumpFrames(tester, 2);
      }
    });
  });
}
