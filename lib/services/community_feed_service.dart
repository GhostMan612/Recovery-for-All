// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  static bool remoteReady = true;

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

  static Future<bool> _ensureAuth() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[circle] Firebase is not initialized.');
        return false;
      }
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint('[circle] Signing in anonymously for feed access...');
        await FirebaseAuth.instance.signInAnonymously();
      }
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      debugPrint('[circle] Anonymous auth failed: $e');
      return false;
    }
  }

  Stream<List<FeedPost>> watchMergedFeed() {
    final local = database.watchVisibleFeed();
    if (Firebase.apps.isEmpty) return local;

    final remote = FirebaseFirestore.instance
        .collection(remoteCollection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        try {
          if (data['status'] != null && data['status'] != 'visible') {
            return null;
          }
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
        byId[p.id] = p;
      }
      return byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    late StreamController<List<FeedPost>> controller;
    late StreamSubscription<List<FeedPost>> localSub;
    StreamSubscription<List<FeedPost>>? remoteSub;
    // Hoisted so onCancel can reach it — see the anonymous-auth race below.
    var cancelled = false;

    controller = StreamController<List<FeedPost>>(
      onListen: () {
        localSub = local.listen(
          (list) {
            latestLocal = list;
            controller.add(hasRemote ? merged() : list);
          },
          onError: (Object _) => controller.add(latestLocal),
        );

        // Anonymous auth can take a second or two. If the user leaves the screen
        // inside that window, onCancel already ran with remoteSub == null, and
        // this continuation then created a live Firestore subscription that
        // nothing would ever cancel — a permanently-active listener per visit.
        // The hoisted `cancelled` flag closes that race.
        _ensureAuth().then((authenticated) {
          if (!authenticated || cancelled) return;
          remoteSub = remote.listen(
            (list) {
              latestRemote = list;
              hasRemote = true;
              controller.add(merged());
            },
            onError: (Object error) {
              debugPrint('[circle] Remote stream error: $error');
              controller.add(latestLocal);
            },
            cancelOnError: false,
          );
        });
      },
      onPause: () {
        localSub.pause();
        remoteSub?.pause();
      },
      onResume: () {
        localSub.resume();
        remoteSub?.resume();
      },
      onCancel: () async {
        cancelled = true;
        await localSub.cancel();
        await remoteSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _mirrorToRemote(FeedPost post) async {
    final authed = await _ensureAuth();
    if (!authed) {
      debugPrint('[circle] Firestore write skipped: Not authenticated');
      return;
    }

    try {
      final payload = {
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
      };

      await FirebaseFirestore.instance
          .collection(remoteCollection)
          .doc(post.id)
          .set(payload);

      debugPrint('[circle] mirrored to Firestore successfully: ${post.id}');
    } catch (e) {
      debugPrint('[circle] mirror FAILED (post stays local): $e');
    }
  }

  static Future<bool> isModerator() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyModerator) ?? false;
  }

  static Future<void> setModerator(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyModerator, value);
  }

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

    final assessment = SafetyGuardrailService.assessInput(text);
    if (assessment.isCrisisTriggered) {
      return FeedComposeResult.blockedCrisis;
    }

    final lower = text.toLowerCase();
    final needsSupport = _supportWords.any((w) => lower.contains(w));

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
      createdAt: (at ?? DateTime.now()).millisecondsSinceEpoch,
    );

    await database.addFeedPost(post);
    await _mirrorToRemote(post);

    return needsSupport
        ? FeedComposeResult.publishedWithSupport
        : FeedComposeResult.published;
  }

  static String _cleanAlias(String alias) {
    final cleaned = alias.trim();
    if (cleaned.isEmpty) return 'Anonymous';
    return cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
  }

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

  static const Set<String> _reactionKinds = {'strength', 'proud', 'respect'};

  Future<void> react(String postId, {required String kind, int by = 1}) async {
    // Validate BEFORE both writes. reactToPost now throws on an unknown kind,
    // and the cloud field name was built as '${kind}Count' with no check at
    // all — so an unrecognised kind incremented a bogus Firestore field while
    // the local write silently changed nothing: a guaranteed desync.
    if (!_reactionKinds.contains(kind)) {
      debugPrint('[circle] ignoring unknown reaction kind "$kind"');
      return;
    }
    await database.reactToPost(postId, kind: kind, by: by);

    final authed = await _ensureAuth();
    if (!authed) return;

    try {
      final fieldName = '${kind}Count';
      await FirebaseFirestore.instance
          .collection(remoteCollection)
          .doc(postId)
          .update({
        fieldName: FieldValue.increment(by),
      });
    } catch (e) {
      debugPrint('[circle] Cloud reaction sync failed: $e');
    }
  }

  /// Mirror a moderation action to the LOCAL row only.
  ///
  /// This used to also write `status` to Firestore. That was removed, for two
  /// reasons that point the same way:
  ///
  ///  1. **It was a vulnerability.** `isModerator()` reads a SharedPreferences
  ///     flag, which the caller controls — Firestore rules cannot see prefs, so
  ///     any way of expressing moderator status in the rules would have been
  ///     self-declared. The old remote write therefore meant *any* signed-in
  ///     user could set `status` to `visible` (self-approving their own post past
  ///     the C5 queue), or to `hidden` (burying anyone else's). The rules now
  ///     deny remote `status` writes outright, which is why this stopped being a
  ///     write at all rather than a guarded one.
  ///  2. **It contradicted the documented design.** pet-store-rules C5 states
  ///     moderation "stays on-device until networked moderation exists". The
  ///     remote mirror was the implementation quietly disagreeing with the spec.
  ///
  /// Reaction counts still mirror — they are communal, need no authorisation,
  /// and are display-only.
  Future<void> flag(String postId) async {
    await database.flagPost(postId);
  }

  Future<void> approve(String postId) async {
    await database.setPostStatus(postId, 'visible');
  }

  Future<void> hide(String postId) async {
    await database.setPostStatus(postId, 'hidden');
  }
}