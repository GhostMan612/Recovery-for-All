// lib/features/quests/domain/quest_instance.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

/// Lifecycle status of an active or planned quest.
enum QuestStatus {
  planned,
  active,
  completed,
  skipped,
  paused,
}

/// An immutable instance of a quest bound to a calendar day or journey bucket.
@immutable
class QuestInstance {
  final String instanceId;
  final String definitionId;
  final int definitionVersion;
  final String dateBucket;
  final QuestStatus status;
  final int currentProgress;
  final int targetCount;
  final String? selectedAlternative;
  final DateTime? completedAt;
  final String? completionEventId;

  const QuestInstance({
    required this.instanceId,
    required this.definitionId,
    this.definitionVersion = 1,
    required this.dateBucket,
    this.status = QuestStatus.active,
    this.currentProgress = 0,
    required this.targetCount,
    this.selectedAlternative,
    this.completedAt,
    this.completionEventId,
  });

  bool get isCompleted => status == QuestStatus.completed;
  bool get isSkipped => status == QuestStatus.skipped;

  QuestInstance copyWith({
    String? instanceId,
    String? definitionId,
    int? definitionVersion,
    String? dateBucket,
    QuestStatus? status,
    int? currentProgress,
    int? targetCount,
    String? selectedAlternative,
    DateTime? completedAt,
    String? completionEventId,
  }) {
    return QuestInstance(
      instanceId: instanceId ?? this.instanceId,
      definitionId: definitionId ?? this.definitionId,
      definitionVersion: definitionVersion ?? this.definitionVersion,
      dateBucket: dateBucket ?? this.dateBucket,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
      targetCount: targetCount ?? this.targetCount,
      selectedAlternative: selectedAlternative ?? this.selectedAlternative,
      completedAt: completedAt ?? this.completedAt,
      completionEventId: completionEventId ?? this.completionEventId,
    );
  }

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'definitionId': definitionId,
        'definitionVersion': definitionVersion,
        'dateBucket': dateBucket,
        'status': status.name,
        'currentProgress': currentProgress,
        'targetCount': targetCount,
        'selectedAlternative': selectedAlternative,
        'completedAt': completedAt?.toIso8601String(),
        'completionEventId': completionEventId,
      };

  factory QuestInstance.fromJson(Map<String, dynamic> json) {
    return QuestInstance(
      instanceId: json['instanceId'] as String,
      definitionId: json['definitionId'] as String,
      definitionVersion: (json['definitionVersion'] as num?)?.toInt() ?? 1,
      dateBucket: json['dateBucket'] as String,
      status: QuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuestStatus.active,
      ),
      currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 1,
      selectedAlternative: json['selectedAlternative'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      completionEventId: json['completionEventId'] as String?,
    );
  }
}
