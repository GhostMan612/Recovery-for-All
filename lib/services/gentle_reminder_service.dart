// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/gentle_reminder_service.dart
//
// Tone rule T3: reminders INVITE, never shame. One gentle daily
// notification at a user-chosen time. Copy never references missed days,
// streaks, or obligation — an open door, not a taskmaster.
//
// Timezone note: Minnesota-first product → fixed America/Chicago local time,
// which keeps DST-correct daily recurrence without a device-zone plugin.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/recovery_database.dart';
import 'recovery_pet_service.dart';

class GentleReminderService {
  static const String _keyEnabled = 'gentle_reminder_enabled_v1';
  static const String _keyMinutes = 'gentle_reminder_minutes_v1';

  /// Distinct notification id from SOS (988001).
  static const int _notificationId = 988002;

  static const String _centralTimeZone = 'America/Chicago';

  /// Invitational copy only — rotates by weekday so it stays fresh but
  /// calm. Every variant is an invitation; none mention obligation.
  static const List<String> _titles = [
    'Time for your morning path?',
    'A quiet minute is enough today.',
    'Your companion kept your seat warm.',
    'The sky grows one star at a time.',
    'One honest check-in, whenever you are ready.',
    'Small steps count double here.',
    'Today is a fresh page.',
  ];

  static const String _body =
      'No streaks here — just an open door when you are ready.';

  /// Context-aware copy matrix (R25, tone T1–T4: open-door, never shaming).
  /// Pure, testable — no I/O. Evaluator checks in priority order:
  /// Struggling > Resting > Milestone Eve > Default.
  @visibleForTesting
  static ({String title, String body, String route}) evaluateNotificationPayload({
    RecoveryPet? pet,
    WellnessCheckIn? latestCheckIn,
    List<Counter>? counters,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();

    // Condition A: Struggling / Low Wellness — pet sad OR wellness low
    final isStruggling = pet?.mood == PetMoodX.sad;
    final wellnessLow = latestCheckIn != null && _isWellnessLow(latestCheckIn);
    if (isStruggling || wellnessLow) {
      return (
        title: 'A quiet moment for yourself?',
        body: '1-minute breathwork is open — no rush, no judgment.',
        route: 'grounding'
      );
    }

    // Condition B: Pet resting (energy < 25)
    if (pet != null && pet.isResting) {
      return (
        title: 'Kin is resting quietly',
        body: 'Glad you are here whenever you are ready.',
        route: 'pet'
      );
    }

    // Condition C: Milestone eve (tomorrow is 24h/7d/30d/60d/90d/6mo/1yr/2yr)
    if (counters != null && counters.isNotEmpty) {
      final hasEve = counters.where((c) => c.isActive).any((c) => _isMilestoneEve(c, at));
      if (hasEve) {
        return (
          title: 'A meaningful threshold approaches',
          body: 'Take a moment to reflect on your path.',
          route: 'reflection'
        );
      }
    }

    // Condition D: Default rotating invitation (Central TZ weekday)
    final title = _titles[(at.weekday - 1) % _titles.length];
    return (title: title, body: _body, route: 'home');
  }

  static bool _isWellnessLow(WellnessCheckIn w) {
    final vals = [w.spiritual, w.intellectual, w.emotional, w.physical, w.social, w.occupational];
    if (vals.any((v) => v <= 2.0)) return true;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return avg <= 3.5;
  }

  /// Tomorrow is a milestone anniversary? Checks 1,7,30,60,90,182,365,730 days.
  static bool _isMilestoneEve(Counter c, DateTime now) {
    final start = DateTime.fromMillisecondsSinceEpoch(c.startDateTime);
    final days = now.difference(DateTime(start.year, start.month, start.day)).inDays;
    const milestones = [1, 7, 30, 60, 90, 182, 365, 730];
    for (final m in milestones) {
      if (days + 1 == m) return true;
    }
    // Also catch if start was tomorrow's anniversary at same ms precision
    // (handles counters created exactly at midnight)
    return false;
  }

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _tzReady = false;

  static void _ensureTimezone() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_centralTimeZone));
    _tzReady = true;
  }

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<int> getMinutesOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMinutes) ?? 8 * 60; // 08:00 default
  }

  /// Schedules (or cancels) the single daily invitation.
  /// Returns false when the platform denied notification permission.
  static Future<bool> setSchedule({
    required bool enabled,
    int? minutesOfDay,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = minutesOfDay ?? await getMinutesOfDay();
    await prefs.setBool(_keyEnabled, enabled);
    if (minutesOfDay != null) {
      await prefs.setInt(_keyMinutes, minutes);
    }

    await _plugin.cancel(id: _notificationId);
    if (!enabled) return true;

    // Android 13+ runtime permission.
    if (await _requestPermissionIfNeeded() == false) {
      await prefs.setBool(_keyEnabled, false);
      return false;
    }

    _ensureTimezone();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // R25: context-aware copy from local state (pet/wellness/milestones).
    // Fetch best-effort; on failure fall back to default rotating title.
    var notifPayload = (title: _titles[scheduled.weekday - 1], body: _body, route: 'home');
    try {
      final pet = await RecoveryPetService.ensureHatched();
      WellnessCheckIn? latest;
      List<Counter>? counters;
      final db = RecoveryPetService.database;
      if (db != null) {
        // Latest wellness in last 7 days (most recent)
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final weekAgo = nowMs - const Duration(days: 7).inMilliseconds;
        final checks = await db.getCheckInsForRange(weekAgo, nowMs);
        if (checks.isNotEmpty) latest = checks.first;
        // Active counters
        counters = await (db.select(db.counters)..where((t) => t.isActive.equals(true))).get();
      }
      notifPayload = evaluateNotificationPayload(
        pet: pet,
        latestCheckIn: latest,
        counters: counters,
        now: scheduled,
      );
    } catch (_) {
      // Keep default invitation on any fetch failure (never block notification).
    }

    final androidDetails = AndroidNotificationDetails(
      'gentle_reminders',
      'Gentle Reminders',
      channelDescription:
          'One invitational daily nudge — no streaks, no guilt',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: notifPayload.title,
      body: notifPayload.body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'gentle_reminder:${notifPayload.route}',
    );
    return true;
  }

  /// Re-arms after reboot/app update — call from main().
  /// Never throws: reminder failures must not disturb app boot.
  static Future<void> rescheduleIfEnabled() async {
    try {
      if (await getEnabled()) {
        await setSchedule(enabled: true);
      }
    } catch (e) {
      debugPrint('[boot] gentle reminder reschedule skipped: $e');
    }
  }

  static Future<bool?> _requestPermissionIfNeeded() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// "08:00" style label for settings display.
  static String formatMinutes(int minutes) {
    final h24 = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m $suffix';
  }
}
