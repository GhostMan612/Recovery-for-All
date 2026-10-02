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

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../database/recovery_database.dart';
import 'recovery_pet_service.dart';

/// Adds constellation stars for recovery events that should auto-populate
/// the user's sky.
///
/// IDEMPOTENCE. The class doc used to claim "unique ID prefix per event type
/// prevents duplicate stars from repeated calls". That was never true: a unique
/// *prefix* does not prevent duplicates, and every id carried a
/// `millisecondsSinceEpoch` suffix that guaranteed a brand-new row. So the
/// table grew without bound and a user could farm stars by tapping "attended a
/// meeting" repeatedly. Ids are now deterministic per (type, day, nth-of-day),
/// which makes repeats within a day collapse via the `_insert` catch while
/// still allowing several honest stars of the same type on the same day.
/// `addMilestoneStar` was already deterministic.
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

/// Zero-padded `yyyy-MM-dd`. The unpadded form (`2026-3-1`) is a PREFIX of
  /// `2026-3-10`, so every `startsWith(dayKey)` comparison across this codebase
  /// was fragile — it happened to work only because time moves forward.
  @visibleForTesting
  static String dayKeyForTest([DateTime? when]) => _dayKey(when);

  static String _dayKey([DateTime? when]) {
    final d = when ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// The nth star of [type] on the given day, so the count is per-day rather
  /// than globally.
  static Future<int> _todayCount(RecoveryDatabase db, String type, String day) async {
    final prefix = '${type}_$day';
    final all = await db.getConstellationPoints();
    var n = 0;
    for (final p in all) {
      if (p.id.startsWith('$prefix#')) n++;
    }
    return n;
  }

  /// Add a journal-entry star.
  /// Called from journal_screen after logJournalEntry().
  static Future<void> addJournalStar(RecoveryDatabase db) async {
    final now = DateTime.now();
    final day = _dayKey(now);
    final n = await _todayCount(db, 'journal', day);
    final id = 'journal_$day#$n';
    final label = 'Journal · ${now.month}/${now.day}/${now.year}';
    await _insert(db, id: id, title: label, category: 'mindfulness');
  }

  /// Add a meeting-attendance star.
  /// Called from meeting_map_screen after logMeeting().
  static Future<void> addMeetingStar(RecoveryDatabase db, {String? meetingName}) async {
    final now = DateTime.now();
    final day = _dayKey(now);
    final n = await _todayCount(db, 'meeting', day);
    final id = 'meeting_$day#$n';
    final label = meetingName != null && meetingName.isNotEmpty
        ? 'Meeting: $meetingName'
        : 'Attended a meeting';
    await _insert(db, id: id, title: label, category: 'community');
  }

  /// Add a weekly-goal completion star.
  /// Called from weekly_goals_screen after logGoalComplete().
  static Future<void> addGoalStar(RecoveryDatabase db, String goalTitle) async {
    final day = _dayKey();
    final n = await _todayCount(db, 'goal', day);
    await _insert(db, id: 'goal_$day#$n', title: 'Goal: $goalTitle', category: 'service');
  }

  /// Add a walk-completed star.
  /// Called from dashboard_screen after logWalk().
  static Future<void> addWalkStar(RecoveryDatabase db) async {
    final now = DateTime.now();
    final day = _dayKey(now);
    final n = await _todayCount(db, 'walk', day);
    final label = 'Walk · ${now.month}/${now.day}';
    await _insert(db, id: 'walk_$day#$n', title: label, category: 'mindfulness');
  }

  /// Add a trial-victory star.
  /// Called from RecoveryPetService.logBattleWin() since pet_trials_screen
  /// has no direct DB handle.
  static Future<void> addBattleWinStar({String? monsterName}) async {
    final db = RecoveryPetService.database;
    if (db == null) return;
    final day = _dayKey();
    final n = await _todayCount(db, 'trial', day);
    final label = monsterName != null
        ? 'Trial: defeated $monsterName'
        : 'Trial victory';
    await _insert(db, id: 'trial_$day#$n', title: label, category: 'spiritual');
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
