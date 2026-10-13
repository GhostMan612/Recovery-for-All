// lib/features/circle/domain/quest_contribution.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

@immutable
class CircleQuestContribution {
  final int schemaVersion;
  final String contributionId;
  final String questInstanceId;
  final String actorRef;
  final String intentId; // 'ground_together', 'prepare_week', 'connection', 'show_up'
  final int consentPolicyVersion;
  final int createdAtUtcMs;
  final String visibility; // 'circle_only', 'local_only'
  final bool synthetic;

  const CircleQuestContribution({
    this.schemaVersion = 1,
    required this.contributionId,
    required this.questInstanceId,
    required this.actorRef,
    required this.intentId,
    this.consentPolicyVersion = 1,
    required this.createdAtUtcMs,
    this.visibility = 'local_only',
    this.synthetic = false,
  });

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'contributionId': contributionId,
        'questInstanceId': questInstanceId,
        'actorRef': actorRef,
        'intentId': intentId,
        'consentPolicyVersion': consentPolicyVersion,
        'createdAtUtcMs': createdAtUtcMs,
        'visibility': visibility,
        'synthetic': synthetic,
      };

  factory CircleQuestContribution.fromMap(Map<String, dynamic> map) {
    return CircleQuestContribution(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      contributionId: map['contributionId'] as String? ?? '',
      questInstanceId: map['questInstanceId'] as String? ?? '',
      actorRef: map['actorRef'] as String? ?? '',
      intentId: map['intentId'] as String? ?? 'show_up',
      consentPolicyVersion: (map['consentPolicyVersion'] as num?)?.toInt() ?? 1,
      createdAtUtcMs: (map['createdAtUtcMs'] as num?)?.toInt() ?? 0,
      visibility: map['visibility'] as String? ?? 'local_only',
      synthetic: map['synthetic'] == true,
    );
  }
}
