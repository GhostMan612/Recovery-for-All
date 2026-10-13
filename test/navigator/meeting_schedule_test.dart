// test/navigator/meeting_schedule_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_schedule_resolver.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';

void main() {
  group('MeetingScheduleResolver Tests', () {
    test('returns unknown status when meeting has no structured day/minute', () {
      const undated = MeetingDestination(
        sourceId: 'src1',
        sourceMeetingId: 'm1',
        name: 'Pop-Up Meeting',
        fellowship: 'AA',
        meetingType: 'Discussion',
        latitude: 44.97,
        longitude: -93.26,
        address: 'Minneapolis',
        fetchedAtUtcMs: 1791750000000,
      );

      final result = MeetingScheduleResolver.resolveNextOccurrence(undated);
      expect(result.status, MeetingScheduleStatus.unknown);
      expect(result.nextOccurrence, isNull);
      expect(result.isHappeningSoon(), isFalse);
    });

    test('resolves future meeting occurring later today', () {
      // Monday 12:00 PM
      final reference = DateTime(2026, 10, 12, 12, 0); // Monday

      final monday7pm = MeetingDestination(
        sourceId: 'src1',
        sourceMeetingId: 'm1',
        name: 'Monday Night Group',
        fellowship: 'AA',
        meetingType: 'Speaker',
        latitude: 44.97,
        longitude: -93.26,
        address: 'Minneapolis',
        dayOfWeek: 1, // Monday
        minuteOfDay: 19 * 60, // 7:00 PM
        fetchedAtUtcMs: 1791750000000,
      );

      final result = MeetingScheduleResolver.resolveNextOccurrence(
        monday7pm,
        referenceTime: reference,
      );

      expect(result.status, MeetingScheduleStatus.scheduled);
      expect(result.nextOccurrence, DateTime(2026, 10, 12, 19, 0));
      expect(result.minutesUntil, 7 * 60);
      expect(result.isHappeningSoon(thresholdMinutes: 60), isFalse);
      expect(result.isHappeningSoon(thresholdMinutes: 500), isTrue);
    });

    test('resolves in-progress meeting when started 15 minutes ago', () {
      // Monday 7:15 PM
      final reference = DateTime(2026, 10, 12, 19, 15);

      final monday7pm = MeetingDestination(
        sourceId: 'src1',
        sourceMeetingId: 'm1',
        name: 'Monday Night Group',
        fellowship: 'AA',
        meetingType: 'Speaker',
        latitude: 44.97,
        longitude: -93.26,
        address: 'Minneapolis',
        dayOfWeek: 1, // Monday
        minuteOfDay: 19 * 60, // 7:00 PM
        fetchedAtUtcMs: 1791750000000,
      );

      final result = MeetingScheduleResolver.resolveNextOccurrence(
        monday7pm,
        referenceTime: reference,
      );

      expect(result.status, MeetingScheduleStatus.inProgress);
      expect(result.isHappeningSoon(), isTrue);
    });

    test('rolls over to next week when meeting concluded earlier today', () {
      // Monday 9:00 PM (after 7:00 PM - 8:00 PM meeting)
      final reference = DateTime(2026, 10, 12, 21, 0);

      final monday7pm = MeetingDestination(
        sourceId: 'src1',
        sourceMeetingId: 'm1',
        name: 'Monday Night Group',
        fellowship: 'AA',
        meetingType: 'Speaker',
        latitude: 44.97,
        longitude: -93.26,
        address: 'Minneapolis',
        dayOfWeek: 1, // Monday
        minuteOfDay: 19 * 60, // 7:00 PM
        fetchedAtUtcMs: 1791750000000,
      );

      final result = MeetingScheduleResolver.resolveNextOccurrence(
        monday7pm,
        referenceTime: reference,
      );

      expect(result.status, MeetingScheduleStatus.concludedToday);
      expect(result.nextOccurrence, DateTime(2026, 10, 19, 19, 0)); // Next Monday
    });

    test('resolves occurrence for future day of week', () {
      // Monday
      final reference = DateTime(2026, 10, 12, 10, 0);

      final wednesdayNoon = MeetingDestination(
        sourceId: 'src1',
        sourceMeetingId: 'm1',
        name: 'Wednesday Lunch Step Study',
        fellowship: 'NA',
        meetingType: 'Step',
        latitude: 44.97,
        longitude: -93.26,
        address: 'Minneapolis',
        dayOfWeek: 3, // Wednesday
        minuteOfDay: 12 * 60, // 12:00 PM
        fetchedAtUtcMs: 1791750000000,
      );

      final result = MeetingScheduleResolver.resolveNextOccurrence(
        wednesdayNoon,
        referenceTime: reference,
      );

      expect(result.status, MeetingScheduleStatus.scheduled);
      expect(result.nextOccurrence, DateTime(2026, 10, 14, 12, 0)); // Wednesday Oct 14
    });
  });
}
