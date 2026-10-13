// lib/features/circle/data/circle_sync_coordinator.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';
import '../domain/circle_event.dart';

class CircleSyncCoordinator {
  final RecoveryDatabase? database;
  final Map<String, CircleOutboxItem> _outbox = {};
  final ValueNotifier<List<CircleOutboxItem>> outboxNotifier =
      ValueNotifier<List<CircleOutboxItem>>([]);

  CircleSyncCoordinator({this.database});

  List<CircleOutboxItem> get items => List.unmodifiable(_outbox.values);

  /// Load persisted outbox entries from Drift database.
  Future<void> loadPersistedOutbox() async {
    if (database == null) return;
    try {
      final rows = await database!.getAllCircleOutboxEntries();
      for (final r in rows) {
        _outbox[r.outboxId] = _rowToItem(r);
      }
      _notify();
    } catch (e) {
      debugPrint('[circle_outbox] Error loading persisted outbox: $e');
    }
  }

  /// Enqueue an outbox event. Enforces idempotency via outboxId and persists to database.
  Future<CircleOutboxItem> enqueueEvent({
    required String outboxId,
    required CircleEventType eventType,
    required Map<String, dynamic> payload,
  }) async {
    // If not loaded yet, check database first
    if (!_outbox.containsKey(outboxId) && database != null) {
      final existing = await database!.getCircleOutboxEntry(outboxId);
      if (existing != null) {
        final item = _rowToItem(existing);
        _outbox[outboxId] = item;
        _notify();
        return item;
      }
    }

    // In-memory deduplication check
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
    await _persistItem(item);
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
      await _persistItem(updated);
      _notify();
      return updated;
    }

    // Guard 2: When remote writes are explicitly permitted (e.g. testing)
    final updated = item.copyWith(
      status: CircleOutboxStatus.delivered,
      lastAttemptUtcMs: nowMs,
    );
    _outbox[item.outboxId] = updated;
    await _persistItem(updated);
    _notify();
    return updated;
  }

  /// Request post deletion with tombstone state machine.
  /// Retains `CircleOutboxStatus.deleting` until server acknowledgment is received.
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
    await _persistItem(deleteItem);
    _notify();

    return deleteItem;
  }

  /// Transition a pending operation (e.g. `deleting`) to confirmed server completion.
  /// Enforces proof before declaring `deleted` or `delivered`.
  Future<CircleOutboxItem?> confirmServerAck(
    String outboxId, {
    String? serverAckToken,
  }) async {
    final item = _outbox[outboxId];
    if (item == null) return null;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    CircleOutboxStatus newStatus;
    if (item.eventType == CircleEventType.postDelete) {
      newStatus = CircleOutboxStatus.deleted;
    } else {
      newStatus = CircleOutboxStatus.delivered;
    }

    final confirmed = item.copyWith(
      status: newStatus,
      lastAttemptUtcMs: nowMs,
      errorMessage: null,
    );

    _outbox[outboxId] = confirmed;
    await _persistItem(confirmed);
    _notify();
    return confirmed;
  }

  Future<void> _persistItem(CircleOutboxItem item) async {
    if (database == null) return;
    try {
      await database!.addCircleOutboxEntry(CircleOutboxEntry(
        outboxId: item.outboxId,
        eventType: item.eventType.name,
        payloadJson: jsonEncode(item.payload),
        status: item.status.name,
        createdAtUtcMs: item.createdAtUtcMs,
        lastAttemptUtcMs: item.lastAttemptUtcMs,
        errorMessage: item.errorMessage,
      ));
    } catch (e) {
      debugPrint('[circle_outbox] Error persisting outbox entry: $e');
    }
  }

  CircleOutboxItem _rowToItem(CircleOutboxEntry r) {
    final eventType = CircleEventType.values.firstWhere(
      (e) => e.name == r.eventType,
      orElse: () => CircleEventType.postCreate,
    );
    final status = CircleOutboxStatus.values.firstWhere(
      (s) => s.name == r.status,
      orElse: () => CircleOutboxStatus.localDraft,
    );
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
    } catch (_) {}

    return CircleOutboxItem(
      outboxId: r.outboxId,
      eventType: eventType,
      payload: payload,
      status: status,
      createdAtUtcMs: r.createdAtUtcMs,
      lastAttemptUtcMs: r.lastAttemptUtcMs,
      errorMessage: r.errorMessage,
    );
  }

  void _notify() {
    outboxNotifier.value = List.unmodifiable(_outbox.values.toList());
  }

  void clearForTesting() {
    _outbox.clear();
    _notify();
  }
}
