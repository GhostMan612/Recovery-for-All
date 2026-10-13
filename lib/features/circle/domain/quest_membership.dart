// lib/features/circle/domain/quest_membership.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

@immutable
class QuestMembership {
  final String actorRef;
  final String questId;
  final bool isActive;
  final int joinedAtUtcMs;

  const QuestMembership({
    required this.actorRef,
    required this.questId,
    this.isActive = true,
    required this.joinedAtUtcMs,
  });

  QuestMembership copyWith({bool? isActive}) {
    return QuestMembership(
      actorRef: actorRef,
      questId: questId,
      isActive: isActive ?? this.isActive,
      joinedAtUtcMs: joinedAtUtcMs,
    );
  }
}
