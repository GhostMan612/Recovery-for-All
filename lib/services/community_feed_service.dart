// lib/services/community_feed_service.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/privacy/privacy_capability.dart';
import '../database/recovery_database.dart';
import 'safety_guardrail_service.dart';

enum FeedComposeResult {
  publishedLocal,
  publishedRemote,
  publishedRemoteFailed,
  publishedWithSupportLocal,
  publishedWithSupportRemote,
  publishedWithSupportRemoteFailed,
  blockedCrisis;

  static const published = publishedLocal;
  static const publishedWithSupport = publishedWithSupportLocal;

  bool get isCrisis => this == blockedCrisis;
  bool get isRemoteDelivered =>
      this == publishedRemote || this == publishedWithSupportRemote;
  bool get isRemoteFailed =>
      this == publishedRemoteFailed || this == publishedWithSupportRemoteFailed;
  bool get isLocalOnly =>
      this == publishedLocal || this == publishedWithSupportLocal;
  bool get needsSupport =>
      this == publishedWithSupportLocal ||
      this == publishedWithSupportRemote ||
      this == publishedWithSupportRemoteFailed;
}

enum RemoteDeliveryStatus {
  localOnly,
  delivered,
  failed,
}

enum CircleConnectionStatus {
  localOnly,
  connecting,
  connected,
  error,
}

class CommunityFeedService {
  static const String _keyModerator = 'feed_moderator_v1';
  static const int maxPostLength = 480;
  static const String remoteCollection = 'community_feeds';

  static bool remoteReady = false;

  static bool isRemoteAvailable() =>
      remoteReady &&
      PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync);

  static final List<void Function()> _revocationCallbacks = [];
  static final List<void Function()> _grantCallbacks = [];

  static void onRevokeCloud() {
    remoteReady = false;
    for (final cb in List.of(_revocationCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  static void onGrantCloud() {
    remoteReady = true;
    for (final cb in List.of(_grantCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
  }

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

  static bool _privacyListenerAttached = false;

  @visibleForTesting
  static Future<bool> Function()? authCheckerForTesting;

  @visibleForTesting
  static Stream<List<FeedPost>> Function()? remoteStreamForTesting;

  @visibleForTesting
  static Future<bool> Function(FeedPost post)? remoteWriterForTesting;

  @visibleForTesting
  static void resetTestingOverrides() {
    authCheckerForTesting = null;
    remoteStreamForTesting = null;
    remoteWriterForTesting = null;
    _privacyListenerAttached = false;
    _revocationCallbacks.clear();
    _grantCallbacks.clear();
    remoteReady = false;
  }

  @visibleForTesting
  static void resetPrivacyListenerForTesting() {
    resetTestingOverrides();
  }

  static void initPrivacyListener() {
    if (_privacyListenerAttached) return;
    _privacyListenerAttached = true;
    PrivacyCapabilityService.onConsentChangedCallbacks.add((cap, state) {
      if (cap == PrivacyCapability.cloudSync) {
        if (state.isGranted) {
          onGrantCloud();
        } else {
          onRevokeCloud();
        }
      }
    });
  }

  final RecoveryDatabase database;
  final ValueNotifier<CircleConnectionStatus> _connectionStatusNotifier =
      ValueNotifier<CircleConnectionStatus>(CircleConnectionStatus.localOnly);
  bool _isDisposed = false;

  ValueListenable<CircleConnectionStatus> get connectionStatus =>
      _connectionStatusNotifier;

  CircleConnectionStatus get currentStatus => _connectionStatusNotifier.value;

  void _setStatus(CircleConnectionStatus status) {
    if (_isDisposed) return;
    if (_connectionStatusNotifier.value == status) return;
    if (WidgetsBinding.instance.buildOwner?.debugBuilding ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          _connectionStatusNotifier.value = status;
        }
      });
    } else {
      _connectionStatusNotifier.value = status;
    }
  }

  void dispose() {
    _isDisposed = true;
    _connectionStatusNotifier.dispose();
  }

  CommunityFeedService(this.database) {
    initPrivacyListener();
  }

  static Future<bool> _ensureAuth() async {
    if (authCheckerForTesting != null) {
      try {
        return await authCheckerForTesting!();
      } catch (e) {
        debugPrint('[circle] authCheckerForTesting failed: $e');
        return false;
      }
    }
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[circle] Firebase is not initialized.');
        return false;
      }
      final cloudAllowed =
          await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
      if (!cloudAllowed) {
        debugPrint('[circle] Cloud sync not permitted by privacy policy.');
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

  Future<void> retryConnect() async {
    if (!PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync)) {
      _setStatus(CircleConnectionStatus.localOnly);
      return;
    }
    onGrantCloud();
  }

  Stream<List<FeedPost>> _defaultRemoteStream() {
    if (Firebase.apps.isEmpty) {
      return const Stream<List<FeedPost>>.empty();
    }
    return FirebaseFirestore.instance
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
  }

  Stream<List<FeedPost>> watchMergedFeed() {
    final local = database.watchVisibleFeed();

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
    var cancelled = false;
    var attachEpoch = 0;

    void cancelRemote() {
      attachEpoch++;
      remoteSub?.cancel();
      remoteSub = null;
      hasRemote = false;
      latestRemote = const <FeedPost>[];
      _setStatus(CircleConnectionStatus.localOnly);
      if (!controller.isClosed) {
        controller.add(latestLocal);
      }
    }

    Future<void> attachRemote() async {
      if (cancelled) return;
      final int epoch = ++attachEpoch;

      if (!PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync) ||
          cancelled ||
          epoch != attachEpoch) {
        if (epoch == attachEpoch) cancelRemote();
        return;
      }

      _setStatus(CircleConnectionStatus.connecting);

      final authed = await _ensureAuth();
      if (cancelled || epoch != attachEpoch) return;
      if (!authed) {
        _setStatus(CircleConnectionStatus.error);
        return;
      }

      if (!PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync) ||
          cancelled ||
          epoch != attachEpoch) {
        if (epoch == attachEpoch) cancelRemote();
        return;
      }

      await remoteSub?.cancel();
      if (cancelled || epoch != attachEpoch) return;

      try {
        final stream = remoteStreamForTesting != null
            ? remoteStreamForTesting!()
            : _defaultRemoteStream();

        remoteSub = stream.listen(
          (list) {
            if (cancelled || epoch != attachEpoch) return;
            if (!PrivacyCapabilityService.isGrantedSync(
                PrivacyCapability.cloudSync)) {
              cancelRemote();
              return;
            }
            latestRemote = list;
            hasRemote = true;
            _setStatus(CircleConnectionStatus.connected);
            if (!controller.isClosed) {
              controller.add(merged());
            }
          },
          onError: (Object error) {
            debugPrint('[circle] Remote stream error: $error');
            if (epoch == attachEpoch) {
              _setStatus(CircleConnectionStatus.error);
            }
            if (!controller.isClosed) {
              controller.add(latestLocal);
            }
          },
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint('[circle] Remote stream setup threw: $e');
        if (epoch == attachEpoch) {
          _setStatus(CircleConnectionStatus.error);
        }
        if (!controller.isClosed) {
          controller.add(latestLocal);
        }
      }
    }

    controller = StreamController<List<FeedPost>>(
      onListen: () {
        localSub = local.listen(
          (list) {
            latestLocal = list;
            if (!controller.isClosed) {
              controller.add(hasRemote ? merged() : list);
            }
          },
          onError: (Object _) {
            if (!controller.isClosed) controller.add(latestLocal);
          },
        );

        _revocationCallbacks.add(cancelRemote);
        _grantCallbacks.add(attachRemote);

        if (PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync)) {
          attachRemote();
        } else {
          _setStatus(CircleConnectionStatus.localOnly);
        }
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
        _revocationCallbacks.remove(cancelRemote);
        _grantCallbacks.remove(attachRemote);
        await localSub.cancel();
        await remoteSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<RemoteDeliveryStatus> _mirrorToRemote(FeedPost post) async {
    final shareAllowed =
        await PrivacyCapabilityService.isGranted(PrivacyCapability.circleShare);
    if (!shareAllowed) {
      debugPrint('[circle] Circle sharing not permitted by privacy policy (post stays local)');
      return RemoteDeliveryStatus.localOnly;
    }

    final cloudAllowed =
        await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
    if (!cloudAllowed) {
      debugPrint('[circle] Cloud sync not permitted by privacy policy (post stays local)');
      return RemoteDeliveryStatus.localOnly;
    }

    final authed = await _ensureAuth();
    if (!authed) {
      debugPrint('[circle] Firestore write skipped: Not authenticated');
      return RemoteDeliveryStatus.failed;
    }

    // Revalidate session authorization after asynchronous authentication and
    // immediately before initiating a remote write. A revocation during authentication
    // must prevent a new Firestore write.
    if (!PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync) ||
        !PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare)) {
      debugPrint(
          '[circle] Privacy authorization revoked during authentication (post stays local)');
      return RemoteDeliveryStatus.localOnly;
    }

    if (remoteWriterForTesting != null) {
      try {
        final ok = await remoteWriterForTesting!(post);
        return ok ? RemoteDeliveryStatus.delivered : RemoteDeliveryStatus.failed;
      } catch (e) {
        debugPrint('[circle] remoteWriterForTesting threw: $e');
        return RemoteDeliveryStatus.failed;
      }
    }

    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[circle] Firebase is not initialized.');
        return RemoteDeliveryStatus.failed;
      }
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
      return RemoteDeliveryStatus.delivered;
    } catch (e) {
      debugPrint('[circle] mirror FAILED (post stays local): $e');
      return RemoteDeliveryStatus.failed;
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
    final delivery = await _mirrorToRemote(post);

    if (needsSupport) {
      switch (delivery) {
        case RemoteDeliveryStatus.delivered:
          return FeedComposeResult.publishedWithSupportRemote;
        case RemoteDeliveryStatus.failed:
          return FeedComposeResult.publishedWithSupportRemoteFailed;
        case RemoteDeliveryStatus.localOnly:
          return FeedComposeResult.publishedWithSupportLocal;
      }
    } else {
      switch (delivery) {
        case RemoteDeliveryStatus.delivered:
          return FeedComposeResult.publishedRemote;
        case RemoteDeliveryStatus.failed:
          return FeedComposeResult.publishedRemoteFailed;
        case RemoteDeliveryStatus.localOnly:
          return FeedComposeResult.publishedLocal;
      }
    }
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
    // Validate reaction kind before local and remote writes to prevent desync
    if (!_reactionKinds.contains(kind)) {
      debugPrint('[circle] ignoring unknown reaction kind "$kind"');
      return;
    }
    await database.reactToPost(postId, kind: kind, by: by);

    final shareAllowed =
        await PrivacyCapabilityService.isGranted(PrivacyCapability.circleShare);
    if (!shareAllowed) return;

    final cloudAllowed =
        await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync);
    if (!cloudAllowed) return;

    final authed = await _ensureAuth();
    if (!authed) return;

    if (!PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync) ||
        !PrivacyCapabilityService.isGrantedSync(PrivacyCapability.circleShare)) {
      return;
    }

    // Skip unmocked live Firestore network calls in unit/widget test environments
    if (remoteStreamForTesting != null) return;

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

  /// Mirror moderation action to the local row only.
  /// Remote status writes are denied by security rules until networked
  /// moderation is implemented (pet-store-rules C5).
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
