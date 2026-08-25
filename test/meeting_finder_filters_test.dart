// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Host tests for the meeting finder's schedule engine and
// path-tailoring helpers: live/upcoming filtering, ordering,
// occurrence math, labels, and fellowship inference.

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/services/meeting_finder_service.dart';

RecoveryMeeting _weekly(
  String id, {
  required int day,
  required int minutes,
  String fellowship = 'Other',
}) {
  return RecoveryMeeting(
    id: id,
    name: id,
    latitude: 44.9778,
    longitude: -93.2650,
    type: '',
    time: '$day/$minutes',
    address: 'Minneapolis',
    fellowship: fellowship,
    day: day,
    minutes: minutes,
  );
}

void main() {
  final service = MeetingFinderService();

  // Tuesday, Aug 25 2026, 12:00 noon local.
  final now = DateTime(2026, 8, 25, 12, 0);

  group('nextOccurrence', () {
    test('rolls forward to next week when today slot already passed', () {
      // Tuesday meeting at 09:00 — now is 12:00, so next is NEXT Tuesday.
      final m = _weekly('tues-morning', day: 2, minutes: 540);
      final occ = MeetingFinderService.nextOccurrence(m, now)!;
      expect(occ.isAfter(now), isTrue);
      expect(occ.difference(now).inDays, 6); // Sep 1 09:00 vs Aug 25 12:00
    });

    test('returns later-today for a future slot today', () {
      final m = _weekly('tues-evening', day: 2, minutes: 1080);
      final occ = MeetingFinderService.nextOccurrence(m, now)!;
      expect(occ.day, now.day);
      expect(occ.hour, 18);
    });

    test('Sunday meeting from Tuesday lands on the upcoming Sunday', () {
      final m = _weekly('sunday', day: 0, minutes: 600);
      final occ = MeetingFinderService.nextOccurrence(m, now)!;
      expect(occ.weekday, DateTime.sunday);
      expect(occ.difference(now).inDays, 4); // Sunday the 30th
    });

    test('undated meetings have no occurrence', () {
      final m = RecoveryMeeting(
        id: 'online',
        name: 'Online',
        latitude: 0,
        longitude: 0,
        type: 'Online',
        time: '',
        address: '',
      );
      expect(MeetingFinderService.nextOccurrence(m, now), isNull);
    });
  });

  group('isInProgress (2-hour live window)', () {
    test('started 30 minutes ago is live', () {
      final m = _weekly('live', day: 2, minutes: 690); // 11:30, now 12:00
      expect(MeetingFinderService.isInProgress(m, now), isTrue);
    });

    test('started 3 hours ago is no longer live', () {
      final m = _weekly('ended', day: 2, minutes: 540); // 09:00
      expect(MeetingFinderService.isInProgress(m, now), isFalse);
    });

    test('starting later today is not live yet', () {
      final m = _weekly('later', day: 2, minutes: 1080); // 18:00
      expect(MeetingFinderService.isInProgress(m, now), isFalse);
    });
  });

  group('filterUpcoming', () {
    test('live meetings sort first, then soonest occurrence', () {
      final live = _weekly('live', day: 2, minutes: 690);
      final tonight = _weekly('tonight', day: 2, minutes: 1080);
      final tomorrow = _weekly('tomorrow', day: 3, minutes: 540);

      final out = MeetingFinderService.filterUpcoming(
          [tomorrow, live, tonight], now);

      expect(out.map((m) => m.id).toList(), ['live', 'tonight', 'tomorrow']);
    });

    test('undated entries ride the tail and are capped at maxUndated',
        () async {
      final dated = _weekly('dated', day: 2, minutes: 1080);
      final undated = List.generate(
        14,
        (i) => RecoveryMeeting(
          id: 'online-$i',
          name: 'Online $i',
          latitude: 0,
          longitude: 0,
          type: 'Online',
          time: '',
          address: '',
        ),
      );

      final out =
          MeetingFinderService.filterUpcoming([dated, ...undated], now);

      expect(out.first.id, 'dated');
      expect(out.length, 11); // 1 dated + maxUndated(10)
      expect(out.where((m) => m.id.startsWith('online-')).length, 10);
    });

    test('every dated result is live or within the 7-day window', () {
      final meetings = [
        _weekly('a', day: 0, minutes: 600),
        _weekly('b', day: 5, minutes: 1140),
        _weekly('c', day: 2, minutes: 690),
        _weekly('d', day: 6, minutes: 420),
      ];
      for (final m in MeetingFinderService.filterUpcoming(meetings, now)) {
        final occ = MeetingFinderService.nextOccurrence(m, now)!;
        final live = MeetingFinderService.isInProgress(m, now);
        expect(live || occ.isBefore(now.add(const Duration(days: 7))), isTrue,
            reason: '${m.id} must be live or inside the upcoming window');
      }
    });
  });

  group('upcomingLabel', () {
    test('live meeting gets a Now label with its start time', () {
      final m = _weekly('live', day: 2, minutes: 690); // started 11:30 AM
      expect(MeetingFinderService.upcomingLabel(m, now),
          startsWith('Now ·'));
      expect(MeetingFinderService.upcomingLabel(m, now), contains('11:30'));
    });

    test('future slot today is labeled Today', () {
      final m = _weekly('tonight', day: 2, minutes: 1080);
      expect(MeetingFinderService.upcomingLabel(m, now),
          startsWith('Today ·'));
    });

    test('slot tomorrow is labeled Tomorrow', () {
      final m = _weekly('tomorrow', day: 3, minutes: 540);
      expect(MeetingFinderService.upcomingLabel(m, now),
          startsWith('Tomorrow ·'));
    });
  });

  group('fellowshipForSource (path tailoring)', () {
    test('aaMinnesota feed maps to AA', () {
      expect(
        MeetingFinderService.fellowshipForSource(
            'https://www.aaminnesota.org/meetings.json'),
        'AA',
      );
    });

    test('BMLT endpoint maps to NA', () {
      expect(
        MeetingFinderService.fellowshipForSource(
            'https://na-bmlt.org/main_server/client_interface/tsml/'),
        'NA',
      );
    });

    test('unknown source maps to Other', () {
      expect(
        MeetingFinderService.fellowshipForSource(
            'https://example.org/some-feed.json'),
        'Other',
      );
    });
  });

  group('distance math (radius filter contract)', () {
    test('haversine matches known city-pair distances', () {
      // Minneapolis → St. Paul downtowns ≈ 14.0 km; Minneapolis →
      // Duluth ≈ 220 km.
      expect(service.distanceKm(44.9778, -93.2650, 44.9537, -93.0900),
          closeTo(14.0, 0.5));
      expect(service.distanceKm(44.9778, -93.2650, 46.7867, -92.1005),
          closeTo(220.0, 8.0));
    });

    test('zero distance for identical points', () {
      expect(
        service.distanceKm(44.9778, -93.2650, 44.9778, -93.2650),
        closeTo(0, 0.001),
      );
    });

    test('sortByDistance puts nearest first across real MN cities', () {
      final mpls = _at('mpls', 44.9778, -93.2650);
      final stp = _at('stp', 44.9537, -93.0900);
      final duluth = _at('duluth', 46.7867, -92.1005);

      final sorted = service.sortByDistance([duluth, stp, mpls], 44.9778,
          -93.2650);
      expect(sorted.map((m) => m.id).toList(), ['mpls', 'stp', 'duluth'],
          reason: 'Twin Cities first, Duluth last — Minnesota-first ordering');
    });
  });
}

RecoveryMeeting _at(String id, double lat, double lng) {
  return RecoveryMeeting(
    id: id,
    name: id,
    latitude: lat,
    longitude: lng,
    type: '',
    time: 'Tue · 6:00 PM',
    address: '',
  );
}
