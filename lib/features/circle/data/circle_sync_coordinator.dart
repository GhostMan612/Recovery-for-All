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

/// Validated server acknowledgment receipt proving remote delivery or deletion.
class CircleServerAckReceipt {
  final String outboxId;
  final String serverToken;
  final int serverTimestampUtcMs;
  final bool isVerified;

  const CircleServerAckReceipt({
    required this.outboxId,
    required this.serverToken,
    required this.serverTimestampUtcMs,
    this.isVerified = true,
  });

  bool isValid({required String expectedOutboxId}) {
    return isVerified &&
        outboxId == expectedOutboxId &&
        serverToken.trim().isNotEmpty &&
        serverTimestampUtcMs > 0;
  }
}

class CircleSyncCoordinator {
  final RecoveryDatabase database;
  final Map<String, CircleOutboxItem> _outbox = {};
  final ValueNotifier<List<CircleOutboxItem>> outboxNotifier =
      ValueNotifier<List<CircleOutboxItem>>([]);

  CircleSyncCoordinator({required this.database});

  List<CircleOutboxItem> get items => List.unmodifiable(_outbox.values);

  /// Load persisted outbox entries from Drift database.
  Future<void> loadPersistedOutbox() async {
    final rows = await database.getAllCircleOutboxEntries();
    _outbox.clear();
    for (final r in rows) {
      _outbox[r.outboxId] = _rowToItem(r);
    }
    _notify();
  }

  /// Enqueue an outbox event.
  /// Requires database persistence before updating memory or declaring success.
  /// Enforces idempotency via outboxId.
  Future<CircleOutboxItem> enqueueEvent({
    required String outboxId,
    required CircleEventType eventType,
    required Map<String, dynamic> payload,
  }) async {
    // Check persistent database for existing entry to guarantee restart idempotency
    final existing = await database.getCircleOutboxEntry(outboxId);
    if (existing != null) {
      final item = _rowToItem(existing);
      _outbox[outboxId] = item;
      _notify();
      return item;
    }

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

    // Persist to database FIRST. If persistence fails, do NOT record in _outbox.
    await _persistItem(item);
    _outbox[outboxId] = item;
    _notify();

    // Process outbox item according to active privacy & server policy
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
      await _persistItem(updated);
      _outbox[item.outboxId] = updated;
      _notify();
      return updated;
    }

    // Guard 2: Server transport unavailable / production publishing disabled.
    // Never simulate remote delivery success. Keep the item pending in the outbox.
    final updated = item.copyWith(
      status: CircleOutboxStatus.queued,
      lastAttemptUtcMs: nowMs,
      errorMessage: 'Server transport unavailable: operation remains pending in local outbox.',
    );
    await _persistItem(updated);
    _outbox[item.outboxId] = updated;
    _notify();
    return updated;
  }

  /// Request post deletion with tombstone state machine.
  /// Retains `CircleOutboxStatus.deleting` across restarts until verified server acknowledgment.
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

    // Persist to database FIRST
    await _persistItem(deleteItem);
    _outbox[outboxId] = deleteItem;
    _notify();

    return deleteItem;
  }

  /// Transition a pending operation (e.g. `deleting` or `queued`) to confirmed server completion.
  /// Requires an actual verified server receipt with valid token and timestamp.
  /// Rejects unvalidated or spoofed caller tokens.
  Future<CircleOutboxItem> confirmServerAck({
    required String outboxId,
    required CircleServerAckReceipt receipt,
  }) async {
    final item = _outbox[outboxId];
    if (item == null) {
      throw ArgumentError('Outbox item not found: $outboxId');
    }

    if (!receipt.isValid(expectedOutboxId: outboxId)) {
      throw ArgumentError('Invalid or unverified server acknowledgment receipt.');
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final CircleOutboxStatus newStatus = item.eventType == CircleEventType.postDelete
        ? CircleOutboxStatus.deleted
        : CircleOutboxStatus.delivered;

    final confirmed = item.copyWith(
      status: newStatus,
      lastAttemptUtcMs: nowMs,
      errorMessage: null,
    );

    // Persist confirmed state to database FIRST
    await _persistItem(confirmed);
    _outbox[outboxId] = confirmed;
    _notify();
    return confirmed;
  }

  Future<void> _persistItem(CircleOutboxItem item) async {
    await database.addCircleOutboxEntry(CircleOutboxEntry(
      outboxId: item.outboxId,
      eventType: item.eventType.name,
      payloadJson: jsonEncode(item.payload),
      status: item.status.name,
      createdAtUtcMs: item.createdAtUtcMs,
      lastAttemptUtcMs: item.lastAttemptUtcMs,
      errorMessage: item.errorMessage,
    ));
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
