// test/navigator/meeting_search_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_search_service.dart';
import 'package:recovery_for_all/features/navigator/ui/meeting_search_delegate.dart';
import 'package:recovery_for_all/screens/meeting_map_screen.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Fixtures
  final testMeetings = [
    RecoveryMeeting(
      id: 'hope_horizon',
      name: 'Hope on the Horizon',
      latitude: 44.9544,
      longitude: -93.1192,
      type: 'Open Discussion',
      time: '8:30 PM',
      address: '165 Western Avenue N, Saint Paul, MN 55102',
      fellowship: 'AA',
      day: 2, // Tuesday
      minutes: 1230,
    ),
    RecoveryMeeting(
      id: 'hope_group',
      name: 'Hope',
      latitude: 44.9778,
      longitude: -93.2650,
      type: 'Closed Speaker',
      time: '7:00 PM',
      address: '1000 Nicollet Mall, Minneapolis, MN 55403',
      fellowship: 'AA',
      day: 1, // Monday
      minutes: 1140,
    ),
    RecoveryMeeting(
      id: 'serenity_tuesday',
      name: 'Serenity Tuesday',
      latitude: 44.9606,
      longitude: -93.2778,
      type: 'Step Study',
      time: '6:30 PM',
      address: '2218 1st Ave S, Minneapolis, MN 55404',
      fellowship: 'NA',
      day: 2, // Tuesday
      minutes: 1110,
    ),
    RecoveryMeeting(
      id: 'smart_mpls',
      name: 'Self-Management Recovery',
      latitude: 44.9800,
      longitude: -93.2700,
      type: 'Discussion',
      time: '6:00 PM',
      address: '500 Marquette Ave, Minneapolis, MN 55402',
      fellowship: 'SMART',
      day: 3, // Wednesday
      minutes: 1080,
    ),
    RecoveryMeeting(
      id: 'online_zoom',
      name: 'Daily Virtual Fellowship',
      latitude: 0.0,
      longitude: 0.0,
      type: 'Online Discussion',
      time: '12:00 PM',
      address: 'Online via Zoom',
      fellowship: 'AA',
      day: 2, // Tuesday
      minutes: 720,
      conferenceUrl: 'https://zoom.us/j/123456789',
    ),
  ];

  group('MeetingSearchService Unit Tests (MF-01)', () {
    test('Empty or whitespace query returns empty list', () {
      expect(MeetingSearchService.search(query: '', meetings: testMeetings), isEmpty);
      expect(MeetingSearchService.search(query: '   ', meetings: testMeetings), isEmpty);
    });

    test('Searches by meeting name prefix and substring', () {
      final results = MeetingSearchService.search(query: 'Hope', meetings: testMeetings);
      expect(results.length, 2);
      // Exact match "Hope" must score higher than "Hope on the Horizon"
      expect(results.first.meeting.id, 'hope_group');
      expect(results.last.meeting.id, 'hope_horizon');
    });

    test('Searches by street address', () {
      final results = MeetingSearchService.search(query: '165 Western', meetings: testMeetings);
      expect(results.length, 1);
      expect(results.first.meeting.id, 'hope_horizon');
      expect(results.first.meeting.address, contains('165 Western Avenue N'));
    });

    test('Searches by city', () {
      final results = MeetingSearchService.search(query: 'Saint Paul', meetings: testMeetings);
      expect(results.length, 1);
      expect(results.first.meeting.id, 'hope_horizon');
    });

    test('Multi-word cross-field search: "Tuesday AA" matches day and fellowship', () {
      final results = MeetingSearchService.search(query: 'Tuesday AA', meetings: testMeetings);
      // hope_horizon (Tuesday + AA) and online_zoom (Tuesday + AA)
      expect(results.length, 2);
      final ids = results.map((r) => r.meeting.id).toList();
      expect(ids, contains('hope_horizon'));
      expect(ids, contains('online_zoom'));
      // serenity_tuesday is NA, so it should not match AA
      expect(ids, isNot(contains('serenity_tuesday')));
    });

    test('Multi-word cross-field search: "SMART Minneapolis" matches fellowship and city', () {
      final results = MeetingSearchService.search(query: 'SMART Minneapolis', meetings: testMeetings);
      expect(results.length, 1);
      expect(results.first.meeting.id, 'smart_mpls');
    });

    test('Case and whitespace normalization', () {
      final results = MeetingSearchService.search(query: '   hOpE   oN   ', meetings: testMeetings);
      expect(results.length, 1);
      expect(results.first.meeting.id, 'hope_horizon');
    });

    test('Online-only meetings without coordinates remain searchable', () {
      final results = MeetingSearchService.search(query: 'Virtual', meetings: testMeetings);
      expect(results.length, 1);
      expect(results.first.meeting.id, 'online_zoom');
      expect(results.first.meeting.hasLocation, isFalse);
    });

    test('No matching meetings returns empty list without error', () {
      final results = MeetingSearchService.search(query: 'NonexistentMeeting12345', meetings: testMeetings);
      expect(results, isEmpty);
    });
  });

  group('MeetingSearchDelegate Widget Tests (MF-01)', () {
    testWidgets('Displays suggestions and empty-state guidance when query is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showSearch<RecoveryMeeting?>(
                    context: ctx,
                    delegate: MeetingSearchDelegate(meetings: testMeetings),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      expect(find.text('Smart Meeting Search'), findsOneWidget);
      expect(find.textContaining('cached meetings available offline'), findsOneWidget);
      expect(find.text('Quick Suggestions'), findsOneWidget);
      expect(find.text('Hope'), findsOneWidget);
      expect(find.text('Tuesday AA'), findsOneWidget);
    });

    testWidgets('Filters meetings responsively and returns selected meeting', (tester) async {
      RecoveryMeeting? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selected = await showSearch<RecoveryMeeting?>(
                    context: ctx,
                    delegate: MeetingSearchDelegate(meetings: testMeetings),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Hope on the Horizon');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Hope on the Horizon'), findsOneWidget);
      expect(find.textContaining('165 Western Avenue N'), findsOneWidget);

      // Tap result
      await tester.tap(find.widgetWithText(ListTile, 'Hope on the Horizon'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, 'hope_horizon');
    });

    testWidgets('Shows clear no-results view on unmatched search', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showSearch<RecoveryMeeting?>(
                    context: ctx,
                    delegate: MeetingSearchDelegate(meetings: testMeetings),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'RandomUnmatchedQuery');
      await tester.pumpAndSettle();

      expect(find.textContaining('No meetings found matching'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });
  });

  group('MeetingMapScreen Search Integration (MF-01)', () {
    testWidgets('MeetingMapScreen renders Search action in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: MeetingMapScreen(
              initialMeetings: testMeetings,
            ),
          ),
        ),
      );

      // Allow initial frame to render
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Search meetings'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Drain GPS timeout timer before test ends
      await tester.pump(const Duration(seconds: 21));
    });
  });
}
