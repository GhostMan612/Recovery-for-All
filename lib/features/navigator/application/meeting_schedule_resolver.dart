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

  const ScheduleResolutionResult({
    required this.status,
    this.nextOccurrence,
    this.minutesUntil,
    required this.statusDescription,
  });

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
    if (!destination.hasKnownSchedule) {
      return const ScheduleResolutionResult(
        status: MeetingScheduleStatus.unknown,
        statusDescription: 'Schedule unlisted or varies',
      );
    }

    final now = referenceTime ?? DateTime.now();
    final targetDayOfWeek = destination.dayOfWeek!;
    final targetMinuteOfDay = destination.minuteOfDay!;

    final hour = targetMinuteOfDay ~/ 60;
    final minute = targetMinuteOfDay % 60;

    // Convert 0=Sunday..6=Saturday to Dart weekday 1=Monday..7=Sunday
    final targetDartWeekday = targetDayOfWeek == 0 ? DateTime.sunday : targetDayOfWeek;

    final currentDartWeekday = now.weekday;

    int daysUntil = (targetDartWeekday - currentDartWeekday) % 7;
    if (daysUntil < 0) daysUntil += 7;

    // Candidate occurrence today or on the target day this week
    final candidateDate = now.add(Duration(days: daysUntil));
    final occurrence = DateTime(
      candidateDate.year,
      candidateDate.month,
      candidateDate.day,
      hour,
      minute,
    );

    final diffMinutes = occurrence.difference(now).inMinutes;

    if (daysUntil == 0) {
      // It's today!
      if (diffMinutes > 0) {
        return ScheduleResolutionResult(
          status: MeetingScheduleStatus.scheduled,
          nextOccurrence: occurrence,
          minutesUntil: diffMinutes,
          statusDescription: 'Starts in $diffMinutes min',
        );
      } else if (diffMinutes >= -meetingDurationMinutes) {
        // Started within meeting duration
        return ScheduleResolutionResult(
          status: MeetingScheduleStatus.inProgress,
          nextOccurrence: occurrence,
          minutesUntil: 0,
          statusDescription: 'In progress (${-diffMinutes}m in)',
        );
      } else {
        // Concluded earlier today; next occurrence is next week
        final nextWeekOccurrence = occurrence.add(const Duration(days: 7));
        final nextDiffMinutes = nextWeekOccurrence.difference(now).inMinutes;
        return ScheduleResolutionResult(
          status: MeetingScheduleStatus.concludedToday,
          nextOccurrence: nextWeekOccurrence,
          minutesUntil: nextDiffMinutes,
          statusDescription: 'Concluded today; next in 7 days',
        );
      }
    } else {
      // Future day this week
      return ScheduleResolutionResult(
        status: MeetingScheduleStatus.scheduled,
        nextOccurrence: occurrence,
        minutesUntil: diffMinutes,
        statusDescription: 'In $daysUntil days (${occurrence.month}/${occurrence.day})',
      );
    }
  }
}
