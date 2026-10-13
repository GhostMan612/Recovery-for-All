// lib/features/circle/domain/circle_member.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

enum CircleMemberRole {
  member,
  facilitator,
}

@immutable
class CircleMember {
  final String actorRef;
  final String publicAlias;
  final CircleMemberRole role;
  final int joinedAtUtcMs;

  const CircleMember({
    required this.actorRef,
    required this.publicAlias,
    this.role = CircleMemberRole.member,
    required this.joinedAtUtcMs,
  });

  bool get isFacilitator => role == CircleMemberRole.facilitator;
}
