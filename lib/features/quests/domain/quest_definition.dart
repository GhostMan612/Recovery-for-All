// lib/features/quests/domain/quest_definition.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import '../../progression/domain/recovery_action.dart';

/// Categories of voluntary recovery progression quests.
enum QuestCategory {
  dailyGentle,
  pathJourney,
  preparation,
  cooperation,
}

/// Difficulty / time investment band for gentle pacing.
enum QuestDifficulty {
  gentle,
  standard,
  creative,
}

/// Immutable definition of a recovery journey quest.
@immutable
class QuestDefinition {
  final String id;
  final int version;
  final String title;
  final String intent;
  final QuestCategory category;
  final QuestDifficulty difficulty;
  final List<RecoveryActionType> allowedActionTypes;
  final ProofTier verificationFloor;
  final int targetCount;
  final int xpReward;
  final int sparksReward;
  final List<String> alternativeAccommodations;
  final String completionMessage;
  final String accessibilityLabel;

  const QuestDefinition({
    required this.id,
    this.version = 1,
    required this.title,
    required this.intent,
    required this.category,
    this.difficulty = QuestDifficulty.gentle,
    required this.allowedActionTypes,
    this.verificationFloor = ProofTier.selfReported,
    this.targetCount = 1,
    this.xpReward = 30,
    this.sparksReward = 10,
    this.alternativeAccommodations = const [],
    this.completionMessage = 'Step completed on your path.',
    required this.accessibilityLabel,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'intent': intent,
        'category': category.name,
        'difficulty': difficulty.name,
        'allowedActionTypes': allowedActionTypes.map((a) => a.wireName).toList(),
        'verificationFloor': verificationFloor.wireName,
        'targetCount': targetCount,
        'xpReward': xpReward,
        'sparksReward': sparksReward,
        'alternativeAccommodations': alternativeAccommodations,
        'completionMessage': completionMessage,
        'accessibilityLabel': accessibilityLabel,
      };

  factory QuestDefinition.fromJson(Map<String, dynamic> json) {
    return QuestDefinition(
      id: json['id'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      title: json['title'] as String,
      intent: json['intent'] as String,
      category: QuestCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => QuestCategory.dailyGentle,
      ),
      difficulty: QuestDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => QuestDifficulty.gentle,
      ),
      allowedActionTypes: (json['allowedActionTypes'] as List<dynamic>?)
              ?.map((e) => RecoveryActionType.fromWireName(e.toString()))
              .whereType<RecoveryActionType>()
              .toList() ??
          const [],
      verificationFloor: ProofTier.fromWireName(json['verificationFloor']?.toString() ?? '') ??
          ProofTier.selfReported,
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 1,
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 30,
      sparksReward: (json['sparksReward'] as num?)?.toInt() ?? 10,
      alternativeAccommodations:
          (json['alternativeAccommodations'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      completionMessage:
          json['completionMessage'] as String? ?? 'Step completed on your path.',
      accessibilityLabel: json['accessibilityLabel'] as String? ?? '',
    );
  }
}
