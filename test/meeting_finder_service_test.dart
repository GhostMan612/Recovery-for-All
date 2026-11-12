// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';

void main() {
  final service = MeetingFinderService();

  test('clearing every directory stays empty after persisted reload', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await service.getSources(), MeetingFinderService.defaultSources);

    await service.setSources([]);
    expect(await service.getSources(), isEmpty,
        reason: 'an explicit user opt-out must not re-enable default feeds');

    await service.setSources(['https://example.org/SAMPLE-aa.json']);
    expect(await service.getSources(),
        ['https://example.org/SAMPLE-aa.json']);
  });

  test('pathway filter never widens to all directories when none matches', () {
    const sources = [
      'https://aaminnesota.org/tsml.json',
      'https://bmlt.naminnesota.org/tsml.json',
    ];
    expect(MeetingFinderService.sourcesForFellowships(
        sources, {'LifeRing'}), isEmpty);
    expect(MeetingFinderService.sourcesForFellowships(
        sources, {'AA'}), [sources.first]);
    expect(MeetingFinderService.sourcesForFellowships(
        sources, null), sources);
  });

  test('offline SAMPLE meeting fixtures never advertise payment destinations', () {
    final fixtures = MeetingFinderService.sampleDirectory(44.9, -93.2);
    expect(fixtures, isNotEmpty);
    expect(fixtures.every((m) => m.id.startsWith('sample_meeting_')),
        isTrue);
    expect(fixtures.every((m) => m.name.startsWith('SAMPLE')), isTrue);
    expect(fixtures.every((m) => m.seventhTraditionUrl == null), isTrue,
        reason: 'fictional recovery meetings must never route donations');
  });

  test('partial or empty feed refresh must preserve the existing directory', () {
    expect(MeetingFinderService.shouldKeepExistingCache(
      attemptedSources: 10, successfulSources: 1, resultCount: 100,
    ), isTrue, reason: 'one live feed must not overwrite a full cache');
    expect(MeetingFinderService.shouldKeepExistingCache(
      attemptedSources: 10, successfulSources: 0, resultCount: 0,
    ), isTrue, reason: 'offline errors must preserve the cache');
    expect(MeetingFinderService.shouldKeepExistingCache(
      attemptedSources: 10, successfulSources: 5, resultCount: 100,
    ), isFalse, reason: 'half of the sources form an accepted refresh');
    expect(MeetingFinderService.shouldKeepExistingCache(
      attemptedSources: 1, successfulSources: 1, resultCount: 3,
    ), isFalse);
  });

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

  test('rejects malformed meeting coordinates without hiding online meetings', () {
    final entries = MeetingFinderService.parseTsmlFeed([
      {'name': 'Out of Range Latitude', 'latitude': 91.0, 'longitude': -93.0},
      {'name': 'Out of Range Longitude', 'latitude': 44.9, 'longitude': -181.0},
      {'name': 'No Location', 'latitude': 0.0, 'longitude': 0.0},
      {'name': 'Equator Meeting', 'latitude': 0.0, 'longitude': -78.0},
      {'name': 'Prime Meridian Meeting', 'latitude': 51.0, 'longitude': 0.0},
      {'name': 'Valid Meeting', 'latitude': 44.9, 'longitude': -93.1},
    ]);
    expect(entries, hasLength(6));
    expect(entries[0].hasLocation, isFalse);
    expect(entries[1].hasLocation, isFalse);
    expect(entries[2].hasLocation, isFalse);
    expect(entries[3].hasLocation, isTrue);
    expect(entries[4].hasLocation, isTrue);
    expect(entries[5].hasLocation, isTrue);

    final notFinite = RecoveryMeeting(
      id: 'non-finite',
      name: 'Non-finite Coordinates',
      latitude: double.nan,
      longitude: double.infinity,
      type: 'In person',
      time: '',
      address: '',
    );
    expect(notFinite.hasLocation, isFalse);
  });

  test('fallback IDs are stable, location-aware, and distinct for same-name meetings', () {
    final source = [
      {
        'name': 'SAMPLE Serenity',
        'address': 'SAMPLE North Road',
        'latitude': 44.91,
        'longitude': -93.11,
        'day': 1,
        'time': '18:00',
      },
      {
        'name': 'SAMPLE Serenity',
        'address': 'SAMPLE South Road',
        'latitude': 44.81,
        'longitude': -93.21,
        'day': 1,
        'time': '18:00',
      },
      {
        'name': 'SAMPLE Serenity',
        'address': 'SAMPLE North Road',
        'latitude': 44.91,
        'longitude': -93.11,
        'day': 3,
        'time': '19:00',
      },
    ];
    final first = MeetingFinderService.parseTsmlFeed(source, fellowship: 'AA');
    final second = MeetingFinderService.parseTsmlFeed(source, fellowship: 'AA');
    expect(first, hasLength(3));
    expect(first.map((m) => m.id).toSet(), hasLength(3));
    expect(first.map((m) => m.id).toList(),
        second.map((m) => m.id).toList(),
        reason: 'reloading the same feed must not change fallback identity');
    expect(first.every((m) => m.id.startsWith('m_')), isTrue);

    final otherFellowship = MeetingFinderService.parseTsmlFeed(
        [source.first], fellowship: 'NA');
    expect(first.first.id, isNot(otherFellowship.first.id));
  });

  test('source-scoped cache keys preserve identical published slugs across feeds', () {
    const slug = 'SAMPLE_same_slug';
    final first = MeetingFinderService.sourceScopedCacheKey(
        'https://example.org/aa.json', slug);
    final second = MeetingFinderService.sourceScopedCacheKey(
        'https://example.org/na.json', slug);
    expect(first, isNot(second));
    expect(first, MeetingFinderService.sourceScopedCacheKey(
        'https://example.org/aa.json', slug));
    final records = <String, String>{first: 'AA', second: 'NA'};
    expect(records, hasLength(2));
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
