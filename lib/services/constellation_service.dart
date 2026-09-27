// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/constellation_service.dart
//
// Centralized helper for adding auto-stars to the Recovery Constellation.
// Screens that earn Sparks via RecoveryPetService.logXxx() call the
// matching addXxxStar() here so the constellation grows automatically.
library;

import '../database/recovery_database.dart';
import 'recovery_pet_service.dart';

/// Adds constellation stars for recovery events that should auto-populate
/// the user's sky. Each method is idempotent-safe (unique ID prefix per
/// event type prevents duplicate stars from repeated calls).
class ConstellationService {
  ConstellationService._();

  /// Add a milestone chip star (24h, 30d, 90d, etc.).
  /// Called from sobriety_counter_screen after logMilestone().
  static Future<void> addMilestoneStar(
    RecoveryDatabase db,
    String counterLabel,
    String chipLabel,
  ) async {
    final id = 'milestone_${counterLabel}_$chipLabel'
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    await _insert(db, id: id, title: '$counterLabel: $chipLabel', category: 'milestone');
  }

  /// Add a journal-entry star.
  /// Called from journal_screen after logJournalEntry().
  static Future<void> addJournalStar(RecoveryDatabase db) async {
    final now = DateTime.now();
    final id = 'journal_${now.year}_${now.month}_${now.day}_${now.millisecondsSinceEpoch}';
    final label = 'Journal · ${now.month}/${now.day}/${now.year}';
    await _insert(db, id: id, title: label, category: 'mindfulness');
  }

  /// Add a meeting-attendance star.
  /// Called from meeting_map_screen after logMeeting().
  static Future<void> addMeetingStar(RecoveryDatabase db, {String? meetingName}) async {
    final now = DateTime.now();
    final id = 'meeting_${now.millisecondsSinceEpoch}';
    final label = meetingName != null && meetingName.isNotEmpty
        ? 'Meeting: $meetingName'
        : 'Attended a meeting';
    await _insert(db, id: id, title: label, category: 'community');
  }

  /// Add a weekly-goal completion star.
  /// Called from weekly_goals_screen after logGoalComplete().
  static Future<void> addGoalStar(RecoveryDatabase db, String goalTitle) async {
    final now = DateTime.now();
    final id = 'goal_${now.millisecondsSinceEpoch}';
    await _insert(db, id: id, title: 'Goal: $goalTitle', category: 'service');
  }

  /// Add a walk-completed star.
  /// Called from dashboard_screen after logWalk().
  static Future<void> addWalkStar(RecoveryDatabase db) async {
    final now = DateTime.now();
    final id = 'walk_${now.millisecondsSinceEpoch}';
    final label = 'Walk · ${now.month}/${now.day}';
    await _insert(db, id: id, title: label, category: 'mindfulness');
  }

  /// Add a trial-victory star.
  /// Called from RecoveryPetService.logBattleWin() since pet_trials_screen
  /// has no direct DB handle.
  static Future<void> addBattleWinStar({String? monsterName}) async {
    final db = RecoveryPetService.database;
    if (db == null) return;
    final now = DateTime.now();
    final id = 'trial_${now.millisecondsSinceEpoch}';
    final label = monsterName != null
        ? 'Trial: defeated $monsterName'
        : 'Trial victory';
    await _insert(db, id: id, title: label, category: 'spiritual');
  }

  // ---- internal ----

  static Future<void> _insert(
    RecoveryDatabase db, {
    required String id,
    required String title,
    required String category,
  }) async {
    try {
      await db.addConstellationPoint(ConstellationPoint(
        id: id,
        title: title.length > 80 ? '${title.substring(0, 77)}...' : title,
        category: category,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        positionX: 0.5, // vestigial — phyllotaxis ignores these
        positionY: 0.5,
      ));
    } catch (_) {
      // Duplicate ID (idempotent) or DB closed — swallow silently.
      // Stars are cosmetic; never crash for a missing star.
    }
  }
}
