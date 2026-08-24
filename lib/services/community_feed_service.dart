// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/community_feed_service.dart
//
// Recovery Circle feed engine. Implements pet-store-rules.md §4:
//   C1 anonymity by default (alias only, no location fields exist)
//   C2 shape-shares carry relative positions, never day counts
//   C3 newest-first ordering; no sober-time field exists to sort by
//   C4 crisis language blocks publish + opens support; relapse language
//      publishes WITH a persistent support footer
//   C5 keyword flags route posts to a moderation queue; moderator mode is
//      an explicit local opt-in
//
// Transport: backed by local Drift always. When Firebase is configured
// (google-services.json present + initializeApp succeeded), the circle also
// mirrors to Firestore `community_feeds` so shapes travel between devices.
// Reactions/flags/moderation stay local until networked moderation exists
// (rules doc §4 C5).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/recovery_database.dart';
import 'safety_guardrail_service.dart';

enum FeedComposeResult {
  published,
  publishedWithSupport,
  blockedCrisis,
}

class CommunityFeedService {
  static const String _keyModerator = 'feed_moderator_v1';
  static const int maxPostLength = 480;

  static const String remoteCollection = 'community_feeds';

  /// Set once in main() after a successful Firebase.initializeApp().
  static bool remoteReady = false;

  /// Softer than crisis: relapse language still belongs in the circle,
  /// it just always travels with visible support (rule C4).
  static const List<String> _supportWords = [
    'relapsed',
    'relapse',
    'slipped',
    'slip up',
    'i drank',
    'i used again',
    'picked up',
    'drinking again',
    'using again',
    'broke my streak',
    'threw away my clean time',
  ];

  final RecoveryDatabase database;

  CommunityFeedService(this.database);

  // ---- remote mirror (Firestore, optional) ----

  /// Local + remote merged, deduped by id (local rows win), newest first.
  Stream<List<FeedPost>> watchMergedFeed() {
    final local = database.watchVisibleFeed();
    if (!remoteReady) return local;

    final remote = FirebaseFirestore.instance
        .collection(remoteCollection)
        .where('status', isEqualTo: 'visible')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        try {
          return FeedPost(
            id: doc.id,
            authorAlias: (data['authorAlias'] ?? 'Anonymous') as String,
            kind: (data['kind'] ?? 'story') as String,
            body: (data['body'] ?? '') as String,
            shapeJson: data['shapeJson'] as String?,
            needsSupport: (data['needsSupport'] ?? false) as bool,
            status: 'visible',
            flagCount: 0,
            strengthCount: (data['strengthCount'] ?? 0) as int,
            proudCount: (data['proudCount'] ?? 0) as int,
            respectCount: (data['respectCount'] ?? 0) as int,
            createdAt: (data['createdAt'] ?? 0) as int,
            isMine: false,
          );
        } catch (_) {
          // Malformed remote docs are skipped entirely.
          return null;
        }
      }).whereType<FeedPost>().toList();
    });

    List<FeedPost> latestLocal = const <FeedPost>[];
    List<FeedPost> latestRemote = const <FeedPost>[];
    bool hasRemote = false;

    List<FeedPost> merged() {
      final byId = <String, FeedPost>{};
      for (final p in latestRemote) {
        byId[p.id] = p;
      }
      for (final p in latestLocal) {
        byId[p.id] = p; // local wins on id collisions
      }
      return byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    late StreamController<List<FeedPost>> controller;
    late StreamSubscription<List<FeedPost>> localSub;
    late StreamSubscription<List<FeedPost>> remoteSub;

    controller = StreamController<List<FeedPost>>(
      onListen: () {
        localSub = local.listen(
          (list) {
            latestLocal = list;
            controller.add(hasRemote ? merged() : list);
          },
          onError: (Object _) => controller.add(latestLocal),
        );
        remoteSub = remote.listen(
          (list) {
            latestRemote = list;
            hasRemote = true;
            controller.add(merged());
          },
          // Cloud unreachable → fall back to the local circle silently.
          onError: (Object _) => controller.add(latestLocal),
          cancelOnError: true,
        );
      },
      onPause: () {
        localSub.pause();
        remoteSub.pause();
      },
      onResume: () {
        localSub.resume();
        remoteSub.resume();
      },
      onCancel: () async {
        await localSub.cancel();
        await remoteSub.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _mirrorToRemote(FeedPost post) async {
    if (!remoteReady) return;
    try {
      await FirebaseFirestore.instance
          .collection(remoteCollection)
          .doc(post.id)
          .set({
        'authorAlias': post.authorAlias,
        'kind': post.kind,
        'body': post.body,
        'shapeJson': post.shapeJson,
        'needsSupport': post.needsSupport,
        'status': post.status,
        'strengthCount': post.strengthCount,
        'proudCount': post.proudCount,
        'respectCount': post.respectCount,
        'createdAt': post.createdAt,
      });
      debugPrint('[circle] mirrored to Firestore: ${post.id}');
    } catch (e) {
      // Offline-first promise: the local circle works regardless of cloud.
      debugPrint('[circle] mirror FAILED (post stays local): $e');
    }
  }

  // ---- moderator mode (C5, explicit local opt-in) ----

  static Future<bool> isModerator() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyModerator) ?? false;
  }

  static Future<void> setModerator(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyModerator, value);
  }

  /// Returns the moderation outcome for [body].
  Future<FeedComposeResult> compose({
    required String authorAlias,
    required String body,
    String kind = 'story',
    String? shapeJson,
    DateTime? at,
  }) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw ArgumentError('Feed posts cannot be empty.');
    }

    // Rule C4a — crisis language never publishes as a post. The UI pairs
    // this result with the SOS sheet; nothing is stored.
    final assessment = SafetyGuardrailService.assessInput(text);
    if (assessment.isCrisisTriggered) {
      return FeedComposeResult.blockedCrisis;
    }

    final lower = text.toLowerCase();
    final needsSupport =
        _supportWords.any((w) => lower.contains(w));

    final post = FeedPost(
      id: 'feed_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode & 0xFFFF}',
      authorAlias: _cleanAlias(authorAlias),
      kind: kind,
      body: text.substring(0, text.length.clamp(1, maxPostLength)),
      shapeJson: shapeJson,
      needsSupport: needsSupport,
      status: 'visible',
      flagCount: 0,
      strengthCount: 0,
      proudCount: 0,
      respectCount: 0,
      isMine: true,
      createdAt:
          (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await database.addFeedPost(post);
    await _mirrorToRemote(post);
    return needsSupport
        ? FeedComposeResult.publishedWithSupport
        : FeedComposeResult.published;
  }

  /// Rule C1 — alias only, trimmed, capped. No other identity is collected.
  static String _cleanAlias(String alias) {
    final cleaned = alias.trim();
    if (cleaned.isEmpty) return 'Anonymous';
    return cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
  }

  /// One-shot read of the visible feed (newest first).
  Future<List<FeedPost>> visibleNow() {
    return (database.select(database.feedPosts)
          ..where((t) => t.status.equals('visible'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();
  }

  Future<void> react(String postId,
      {required String kind, int by = 1}) async {
    await database.reactToPost(postId, kind: kind, by: by);
  }

  Future<void> flag(String postId) => database.flagPost(postId);

  Future<void> approve(String postId) => database.setPostStatus(postId, 'visible');

  Future<void> hide(String postId) => database.setPostStatus(postId, 'hidden');
}
