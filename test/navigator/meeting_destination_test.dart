// test/navigator/meeting_destination_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/data/meeting_destination_adapter.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';

void main() {
  group('MeetingDestination Tests', () {
    test('compositeId combines sourceId and sourceMeetingId strictly', () {
      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: '12345',
        name: 'Downtown Alano Club',
        fellowship: 'AA',
        meetingType: 'Open Discussion',
        latitude: 44.9778,
        longitude: -93.2650,
        address: '2214 S 10th Ave, Minneapolis, MN',
        fetchedAtUtcMs: 1791750000000,
      );

      expect(destination.compositeId, 'tsml_aa_minnesota:12345');
      expect(destination.hasValidCoordinates, isTrue);
      expect(destination.isEligibleForPhysicalRouting, isTrue);
      expect(destination.isOnlineOnly, isFalse);
    });

    test('synthetic fixture detection marks isSynthetic=true and blocks physical routing', () {
      final sampleMeeting = RecoveryMeeting(
        id: 'sample-001',
        name: 'Sample AA Fellowship Meeting',
        latitude: 44.9778,
        longitude: -93.2650,
        type: 'Step Study',
        time: '7:00 PM',
        address: '123 Test St',
        fellowship: 'AA',
      );

      final destination = MeetingDestinationAdapter.fromRecoveryMeeting(sampleMeeting);

      expect(destination.isSynthetic, isTrue);
      expect(destination.isEligibleForPhysicalRouting, isFalse);
    });

    test('invalid or NaN coordinates are sanitized and ineligible for routing', () {
      final badCoordsMeeting = RecoveryMeeting(
        id: 'real-001',
        name: 'Lake Harriet Group',
        latitude: double.nan,
        longitude: -93.2650,
        type: 'Open',
        time: '6:30 PM',
        address: '4400 Dupont Ave S',
        fellowship: 'AA',
      );

      final destination = MeetingDestinationAdapter.fromRecoveryMeeting(badCoordsMeeting);

      expect(destination.latitude, 0.0);
      expect(destination.hasValidCoordinates, isFalse);
      expect(destination.isEligibleForPhysicalRouting, isFalse);
    });

    test('online only meetings are detected and ineligible for physical routing', () {
      final onlineMeeting = RecoveryMeeting(
        id: 'online-101',
        name: 'Zoom Midnight Recovery',
        latitude: 0.0,
        longitude: 0.0,
        type: 'Discussion',
        time: '11:59 PM',
        address: 'Online',
        conferenceUrl: 'https://zoom.us/j/123456789',
        fellowship: 'NA',
      );

      final destination = MeetingDestinationAdapter.fromRecoveryMeeting(onlineMeeting);

      expect(destination.isOnlineOnly, isTrue);
      expect(destination.isEligibleForPhysicalRouting, isFalse);
    });

    test('preserves existing provider-scoped IDs when present in meeting id', () {
      final scopedMeeting = RecoveryMeeting(
        id: 'bmlt_tcna:8842',
        name: 'Sub-Zero NA Group',
        latitude: 44.9537,
        longitude: -93.0900,
        type: 'Closed',
        time: '8:00 PM',
        address: 'Saint Paul, MN',
        fellowship: 'NA',
      );

      final destination = MeetingDestinationAdapter.fromRecoveryMeeting(scopedMeeting);

      expect(destination.sourceId, 'bmlt_tcna');
      expect(destination.sourceMeetingId, '8842');
      expect(destination.compositeId, 'bmlt_tcna:8842');
    });
  });
}
