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

    controller = StreamController<List<FeedPost>>(
      onListen: () {
        localSub = local.listen(
          (list) {
            latestLocal = list;
            controller.add(hasRemote ? merged() : list);
          },
          onError: (Object _) => controller.add(latestLocal),
        );

        _ensureAuth().then((authenticated) {
          if (!authenticated) return;
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

  Future<void> react(String postId, {required String kind, int by = 1}) async {
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

  Future<void> flag(String postId) => database.flagPost(postId);

  Future<void> approve(String postId) => database.setPostStatus(postId, 'visible');

  Future<void> hide(String postId) => database.setPostStatus(postId, 'hidden');
}