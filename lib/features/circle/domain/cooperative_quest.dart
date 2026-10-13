// lib/features/circle/domain/cooperative_quest.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

@immutable
class CooperativeQuest {
  final String questId;
  final String title;
  final String intentId; // 'ground_together', 'prepare_week', 'connection', 'show_up'
  final String description;
  final int targetContributions;
  final int currentContributions;

  const CooperativeQuest({
    required this.questId,
    required this.title,
    required this.intentId,
    required this.description,
    required this.targetContributions,
    this.currentContributions = 0,
  });

  bool get isCompleted => currentContributions >= targetContributions;

  double get progressRatio {
    if (targetContributions <= 0) return 1.0;
    return (currentContributions / targetContributions).clamp(0.0, 1.0);
  }

  CooperativeQuest copyWith({
    int? currentContributions,
  }) {
    return CooperativeQuest(
      questId: questId,
      title: title,
      intentId: intentId,
      description: description,
      targetContributions: targetContributions,
      currentContributions: currentContributions ?? this.currentContributions,
    );
  }
}
