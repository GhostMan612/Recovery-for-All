// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';

void main() {
  late RecoveryDatabase db;
  late CommunityFeedService feed;

  setUp(() async {
    db = RecoveryDatabase.forTesting(
        NativeDatabase.memory() as QueryExecutor);
    feed = CommunityFeedService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('C1: alias is cleaned, capped, and never empty', () async {
    await feed.compose(authorAlias: '  GhostMan G ', body: 'day three');
    final posts = await db.watchVisibleFeed().first;
    expect(posts.single.authorAlias, 'GhostMan G');

    await feed.compose(authorAlias: '   ', body: 'anonymous post');
    final posts2 = await feed.visibleNow();
    // Newest first → the anonymous post is the most recent entry.
    expect(posts2.first.authorAlias, 'Anonymous');
  });

  test('C4a: crisis language blocks publish â€” nothing stored', () async {
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
}

