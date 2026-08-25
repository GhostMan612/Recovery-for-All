// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/services/meeting_finder_service.dart';

void main() {
  final service = MeetingFinderService();

  test('parses Meeting Guide / TSML feed entries (AA sheet style)', () {
    final meetings = MeetingFinderService.parseTsmlFeed([
      {
        'name': 'Sunday Serenity',
        'slug': 'sunday-serenity-14',
        'day': 0,
        'time': '18:00',
        'types': ['O', 'T'],
        'address': '123 Main Street',
        'city': 'Anytown',
        'state': 'CA',
        'country': 'US',
        'latitude': 37.33,
        'longitude': -121.89,
      },
    ]);

    expect(meetings, hasLength(1));
    final m = meetings.single;
    expect(m.id, 'sunday-serenity-14');
    expect(m.name, 'Sunday Serenity');
    expect(m.time, contains('Sun'));
    expect(m.time, contains('6:00 PM'));
    expect(m.type, contains('Open'));
    expect(m.latitude, 37.33);
    expect(m.address, '123 Main Street, Anytown, CA');
  });

  test('parses BMLT aggregator TSML entries (online NA meeting)', () {
    final meetings = MeetingFinderService.parseTsmlFeed([
      {
        'day': 0,
        'time': '00:00',
        'end_time': '01:00',
        'name': 'Awokenings Group',
        'formatted_address': 'Lewisville, TX, us',
        'city': 'Lewisville',
        'state': 'TX',
        'types': ['VAR', 'ONL'],
        'coordinates': null,
        'slug': 'awokenings-group-177552',
        'region': 'Dallas Area',
        'conference_url': 'https://us02web.zoom.us/j/9191086501',
      },
    ]);

    expect(meetings, hasLength(1));
    final m = meetings.single;
    expect(m.id, 'awokenings-group-177552');
    expect(m.type, startsWith('Online'));
    expect(m.hasLocation, isFalse);
    expect(m.time, contains('12:00 AM'));
  });

  test('parses BMLT string coordinates ("lat,lng")', () {
    final meetings = MeetingFinderService.parseTsmlFeed([
      {
        'name': 'Experience, Strength, & Hope',
        'slug': 'experience-strength-hope-1049',
        'day': 0,
        'time': '09:00',
        'city': 'Saint Paul',
        'state': 'MN',
        'types': ['BT', 'C'],
        'coordinates': '44.9330076,-93.1629063',
      },
    ]);

    expect(meetings, hasLength(1));
    final m = meetings.single;
    expect(m.hasLocation, isTrue);
    expect(m.latitude, closeTo(44.9330, 0.0001));
    expect(m.longitude, closeTo(-93.1629, 0.0001));
    expect(m.time, contains('Sun'));
    expect(m.address, contains('Saint Paul'));
  });

  test('sortByDistance puts located meetings first, nearest at top', () {
    final meetings = [
      RecoveryMeeting(
          id: 'online',
          name: 'Online Only',
          latitude: 0,
          longitude: 0,
          type: 'Online',
          time: 'Mon · 8:00 PM',
          address: ''),
      RecoveryMeeting(
          id: 'far',
          name: 'Far',
          latitude: 40.0,
          longitude: -105.0,
          type: '',
          time: 'Tue · 7:00 PM',
          address: ''),
      RecoveryMeeting(
          id: 'near',
          name: 'Near',
          latitude: 39.74,
          longitude: -104.99,
          type: '',
          time: 'Wed · 6:00 PM',
          address: ''),
    ];

    final sorted = service.sortByDistance(meetings, 39.7392, -104.9903);
    expect(sorted.first.id, 'near');
    expect(sorted[1].id, 'far');
    expect(sorted.last.id, 'online');
  });
}
