// lib/features/quests/data/quest_catalog.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import '../../progression/domain/recovery_action.dart';
import '../domain/quest_definition.dart';

/// Catalog of versioned recovery quests, gentle daily invitations, and journey milestones.
class QuestCatalog {
  static const QuestDefinition dailyGrounding = QuestDefinition(
    id: 'daily_grounding',
    version: 1,
    title: 'Sixty Gentle Breaths',
    intent: 'Recenter inner peace through slow grounding breaths.',
    category: QuestCategory.dailyGentle,
    difficulty: QuestDifficulty.gentle,
    allowedActionTypes: [RecoveryActionType.grounding],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Listen to ambient recovery chime',
      'Quiet mindful pause',
    ],
    completionMessage: 'Breath steady, ground secure.',
    accessibilityLabel: 'Gentle quest: Sixty slow grounding breaths. Alternative available.',
  );

  static const QuestDefinition dailyGratitude = QuestDefinition(
    id: 'daily_gratitude',
    version: 1,
    title: 'One Grateful Thought',
    intent: 'Acknowledge one gift or kindness in today’s journey.',
    category: QuestCategory.dailyGentle,
    difficulty: QuestDifficulty.gentle,
    allowedActionTypes: [RecoveryActionType.gratitude],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Appreciate a quiet moment in silence',
    ],
    completionMessage: 'Gratitude expressed, spirit lifted.',
    accessibilityLabel: 'Gentle quest: Note one thing you are grateful for.',
  );

  static const QuestDefinition dailyReflection = QuestDefinition(
    id: 'daily_reflection',
    version: 1,
    title: 'Honest Daily Journal',
    intent: 'Put thoughts into words with gentle honesty.',
    category: QuestCategory.dailyGentle,
    difficulty: QuestDifficulty.gentle,
    allowedActionTypes: [RecoveryActionType.journal],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Audio or silent reflection',
    ],
    completionMessage: 'Words honored, clarity found.',
    accessibilityLabel: 'Gentle quest: Write one honest journal reflection.',
  );

  static const QuestDefinition dailyCheckIn = QuestDefinition(
    id: 'daily_check_in',
    version: 1,
    title: 'Morning Compass Check-in',
    intent: 'Calibrate your inner compass for the day ahead.',
    category: QuestCategory.dailyGentle,
    difficulty: QuestDifficulty.gentle,
    allowedActionTypes: [RecoveryActionType.checkIn],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Gentle body scan',
    ],
    completionMessage: 'Compass aligned for today.',
    accessibilityLabel: 'Gentle quest: Check in with your recovery state.',
  );

  static const QuestDefinition prepMeetingSave = QuestDefinition(
    id: 'prep_meeting_save',
    version: 1,
    title: 'Find & Save a Sanctuary',
    intent: 'Identify a safe meeting place or circle to connect with.',
    category: QuestCategory.preparation,
    difficulty: QuestDifficulty.standard,
    allowedActionTypes: [
      RecoveryActionType.meetingSelfReport,
      RecoveryActionType.supportIntention,
    ],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Add peer or sponsor to direct support contacts',
    ],
    completionMessage: 'Sanctuary saved for peace of mind.',
    accessibilityLabel: 'Preparation quest: Locate and save a recovery meeting.',
  );

  static const QuestDefinition journeyMindfulCoping = QuestDefinition(
    id: 'journey_mindful_coping',
    version: 1,
    title: 'Mindful Coping Practice',
    intent: 'Face a coping hurdle in the trials or engage in quiet reflection.',
    category: QuestCategory.pathJourney,
    difficulty: QuestDifficulty.standard,
    allowedActionTypes: [
      RecoveryActionType.battleCompleted,
      RecoveryActionType.grounding,
    ],
    targetCount: 1,
    xpReward: 30,
    sparksReward: 10,
    alternativeAccommodations: [
      'Five minutes of quiet meditation',
    ],
    completionMessage: 'Resilience strengthened through practice.',
    accessibilityLabel: 'Path Journey quest: Complete a coping trial or quiet reflection.',
  );

  static const List<QuestDefinition> allQuests = [
    dailyGrounding,
    dailyGratitude,
    dailyReflection,
    dailyCheckIn,
    prepMeetingSave,
    journeyMindfulCoping,
  ];

  /// Mapping for legacy quest IDs in SharedPreferences.
  static QuestDefinition resolveLegacy(String legacyId) {
    switch (legacyId) {
      case 'grounding':
        return dailyGrounding;
      case 'gratitude':
        return dailyGratitude;
      case 'journal':
        return dailyReflection;
      case 'wellness':
      case 'check_in':
        return dailyCheckIn;
      case 'meeting':
        return prepMeetingSave;
      case 'walk':
      default:
        return dailyGrounding;
    }
  }

  /// Looks up quest definition by unique identifier.
  static QuestDefinition? getDefinition(String id) {
    for (final q in allQuests) {
      if (q.id == id) return q;
    }
    return null;
  }
}
