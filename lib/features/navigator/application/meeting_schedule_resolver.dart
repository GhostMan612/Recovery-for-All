// lib/features/navigator/application/meeting_schedule_resolver.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import '../domain/meeting_destination.dart';

enum MeetingScheduleStatus {
  scheduled,
  inProgress,
  concludedToday,
  unknown,
}

@immutable
class ScheduleResolutionResult {
  final MeetingScheduleStatus status;
  final DateTime? nextOccurrence;
  final int? minutesUntil;
  final String statusDescription;
  final String timeZone;
  final bool isStaleSchedule;

  const ScheduleResolutionResult({
    required this.status,
    this.nextOccurrence,
    this.minutesUntil,
    required this.statusDescription,
    this.timeZone = 'America/Chicago',
    this.isStaleSchedule = false,
  });

  int? get nextOccurrenceUtcMs => nextOccurrence?.toUtc().millisecondsSinceEpoch;

  bool isHappeningSoon({int thresholdMinutes = 60}) {
    if (status == MeetingScheduleStatus.inProgress) return true;
    if (minutesUntil == null) return false;
    return minutesUntil! >= 0 && minutesUntil! <= thresholdMinutes;
  }
}

class MeetingScheduleResolver {
  static const int defaultMeetingDurationMinutes = 60;

  static ScheduleResolutionResult resolveNextOccurrence(
    MeetingDestination destination, {
    DateTime? referenceTime,
    int meetingDurationMinutes = defaultMeetingDurationMinutes,
  }) {
    final isStale = destination.sourceFreshness == 'stale';

    if (!destination.hasKnownSchedule) {
      return ScheduleResolutionResult(
        status: MeetingScheduleStatus.unknown,
        statusDescription: isStale ? 'Schedule unknown (cached)' : 'Schedule unknown',
        isStaleSchedule: isStale,
      );
    }

    final dayOfWeek = destination.dayOfWeek!;
    final minuteOfDay = destination.minuteOfDay!;

    if (dayOfWeek < 0 || dayOfWeek > 6 || minuteOfDay < 0 || minuteOfDay >= 1440) {
      return ScheduleResolutionResult(
        status: MeetingScheduleStatus.unknown,
        statusDescription: isStale ? 'Schedule invalid (cached)' : 'Schedule invalid',
        isStaleSchedule: isStale,
      );
    }

    final now = referenceTime ?? DateTime.now();

    // Map TSML 0=Sunday..6=Saturday to DateTime 1=Monday..7=Sunday
    final targetIsoWeekday = dayOfWeek == 0 ? DateTime.sunday : dayOfWeek;
    final currentIsoWeekday = now.weekday;

    int daysAhead = (targetIsoWeekday - currentIsoWeekday) % 7;

    final targetHour = minuteOfDay ~/ 60;
    final targetMinute = minuteOfDay % 60;

    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      targetHour,
      targetMinute,
    );

    final duration = Duration(minutes: meetingDurationMinutes);
    final meetingEnd = candidate.add(duration);

    if (daysAhead == 0) {
      if (now.isAfter(candidate) && now.isBefore(meetingEnd)) {
        return ScheduleResolutionResult(
          status: MeetingScheduleStatus.inProgress,
          nextOccurrence: candidate,
          minutesUntil: 0,
          statusDescription: _formatStatusDescription(candidate, MeetingScheduleStatus.inProgress, isStale),
          isStaleSchedule: isStale,
        );
      } else if (now.isAfter(meetingEnd)) {
        // Rollover to same day next week
        candidate = candidate.add(const Duration(days: 7));
        return ScheduleResolutionResult(
          status: MeetingScheduleStatus.concludedToday,
          nextOccurrence: candidate,
          minutesUntil: candidate.difference(now).inMinutes,
          statusDescription: _formatStatusDescription(candidate, MeetingScheduleStatus.concludedToday, isStale),
          isStaleSchedule: isStale,
        );
      }
    }

    final minutesUntil = candidate.difference(now).inMinutes;

    return ScheduleResolutionResult(
      status: MeetingScheduleStatus.scheduled,
      nextOccurrence: candidate,
      minutesUntil: minutesUntil,
      statusDescription: _formatStatusDescription(candidate, MeetingScheduleStatus.scheduled, isStale),
      isStaleSchedule: isStale,
    );
  }

  static String _formatStatusDescription(
    DateTime dt,
    MeetingScheduleStatus status,
    bool isStale,
  ) {
    final staleSuffix = isStale ? ' (cached)' : '';
    if (status == MeetingScheduleStatus.inProgress) {
      return 'In progress now$staleSuffix';
    }

    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final dayName = days[dt.weekday % 7];

    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';

    if (status == MeetingScheduleStatus.concludedToday) {
      return 'Concluded today \u2022 Next $dayName at $hour:$minute $ampm$staleSuffix';
    }

    return '$dayName at $hour:$minute $ampm$staleSuffix';
  }
}
