// lib/features/circle/domain/circle_event.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

enum CircleEventType {
  postCreate,
  postDelete,
  reactionAdd,
  reportSubmit,
}

enum CircleOutboxStatus {
  localDraft,
  queued,
  delivered,
  failed,
  deleting,
  deleted,
}

@immutable
class CircleOutboxItem {
  final String outboxId;
  final CircleEventType eventType;
  final Map<String, dynamic> payload;
  final CircleOutboxStatus status;
  final int createdAtUtcMs;
  final int? lastAttemptUtcMs;
  final String? errorMessage;

  const CircleOutboxItem({
    required this.outboxId,
    required this.eventType,
    required this.payload,
    required this.status,
    required this.createdAtUtcMs,
    this.lastAttemptUtcMs,
    this.errorMessage,
  });

  CircleOutboxItem copyWith({
    CircleOutboxStatus? status,
    int? lastAttemptUtcMs,
    String? errorMessage,
  }) {
    return CircleOutboxItem(
      outboxId: outboxId,
      eventType: eventType,
      payload: payload,
      status: status ?? this.status,
      createdAtUtcMs: createdAtUtcMs,
      lastAttemptUtcMs: lastAttemptUtcMs ?? this.lastAttemptUtcMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
