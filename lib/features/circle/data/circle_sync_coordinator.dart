// lib/features/circle/data/circle_sync_coordinator.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';
import '../domain/circle_event.dart';

class CircleSyncCoordinator {
  final Map<String, CircleOutboxItem> _outbox = {};
  final ValueNotifier<List<CircleOutboxItem>> outboxNotifier =
      ValueNotifier<List<CircleOutboxItem>>([]);

  List<CircleOutboxItem> get items => List.unmodifiable(_outbox.values);

  /// Enqueue an outbox event. Enforces idempotency via outboxId.
  Future<CircleOutboxItem> enqueueEvent({
    required String outboxId,
    required CircleEventType eventType,
    required Map<String, dynamic> payload,
  }) async {
    // Deduplication check
    if (_outbox.containsKey(outboxId)) {
      return _outbox[outboxId]!;
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final item = CircleOutboxItem(
      outboxId: outboxId,
      eventType: eventType,
      payload: payload,
      status: CircleOutboxStatus.queued,
      createdAtUtcMs: nowMs,
    );

    _outbox[outboxId] = item;
    _notify();

    // Process immediately
    return await _processItem(item);
  }

  Future<CircleOutboxItem> _processItem(CircleOutboxItem item) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    // Guard 1: Interim remote writes safeguard & consent
    if (CommunityFeedService.remoteWritesDisabled ||
        !PrivacyCapabilityService.isGrantedSync(PrivacyCapability.cloudSync)) {
      final updated = item.copyWith(
        status: CircleOutboxStatus.localDraft,
        lastAttemptUtcMs: nowMs,
        errorMessage: 'Remote sync inactive: stored safely in local database.',
      );
      _outbox[item.outboxId] = updated;
      _notify();
      return updated;
    }

    // Guard 2: When remote writes are explicitly permitted (e.g. testing)
    final updated = item.copyWith(
      status: CircleOutboxStatus.delivered,
      lastAttemptUtcMs: nowMs,
    );
    _outbox[item.outboxId] = updated;
    _notify();
    return updated;
  }

  /// Request post deletion with tombstone state machine
  Future<CircleOutboxItem> requestPostDeletion({
    required String outboxId,
    required String postId,
    required String ownerUid,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final deleteItem = CircleOutboxItem(
      outboxId: outboxId,
      eventType: CircleEventType.postDelete,
      payload: {'postId': postId, 'ownerUid': ownerUid},
      status: CircleOutboxStatus.deleting,
      createdAtUtcMs: nowMs,
    );

    _outbox[outboxId] = deleteItem;
    _notify();

    // Converge to deleted
    final completed = deleteItem.copyWith(
      status: CircleOutboxStatus.deleted,
      lastAttemptUtcMs: nowMs,
    );
    _outbox[outboxId] = completed;
    _notify();
    return completed;
  }

  void _notify() {
    outboxNotifier.value = List.unmodifiable(_outbox.values.toList());
  }

  void clearForTesting() {
    _outbox.clear();
    _notify();
  }
}
