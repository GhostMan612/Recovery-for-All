// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// R27 — Predictive Next-Meeting Widget tests.
// Covers Live, Upcoming Today, Empty states + Fellowship badge + tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/widgets/next_meeting_card.dart';

RecoveryMeeting _m(String id, int? day, int? minutes, {String fellowship = 'AA', String name = 'Test Meeting'}) =>
    RecoveryMeeting(
      id: id,
      name: name,
      latitude: 44.97,
      longitude: -93.26,
      type: 'Open',
      time: 'Mon · 7:00 PM',
      address: '123 Fellowship Way',
      fellowship: fellowship,
      day: day,
      minutes: minutes,
    );

void main() {
  group('NextMeetingCard.pickNext', () {
    test('picks live in-progress over upcoming', () {
      // Monday 19:30, meeting Mon 19:00 (90 min ago → live within 2h)
      final now = DateTime(2026, 8, 31, 19, 30); // Mon
      final live = _m('live', 1, 19 * 60, name: 'Live Now');
      final later = _m('later', 1, 21 * 60, name: 'Later Tonight');
      final pick = NextMeetingCard.pickNext([later, live], now);
      expect(pick, isNotNull);
      expect(pick!.isLive, isTrue);
      expect(pick.meeting.id, 'live');
    });

    test('picks next today within 6h when no live', () {
      final now = DateTime(2026, 8, 31, 10, 0); // Mon 10am
      final at11 = _m('11', 1, 11 * 60, name: 'At 11');
      final at18 = _m('18', 1, 18 * 60, name: 'At 6pm');
      final pick = NextMeetingCard.pickNext([at18, at11], now);
      expect(pick, isNotNull);
      expect(pick!.isLive, isFalse);
      expect(pick.meeting.id, '11');
    });

    test('returns null when nothing within 6h', () {
      final now = DateTime(2026, 8, 31, 10, 0);
      final tomorrow = _m('tom', 2, 10 * 60, name: 'Tomorrow'); // Tue
      final pick = NextMeetingCard.pickNext([tomorrow], now);
      expect(pick, isNull);
    });

    test('empty list returns null (empty state)', () {
      final now = DateTime(2026, 8, 31, 10, 0);
      expect(NextMeetingCard.pickNext([], now), isNull);
    });

    test('undated meetings never picked as live/next', () {
      final now = DateTime(2026, 8, 31, 10, 0);
      final undated = _m('u', null, null, name: 'Undated');
      expect(NextMeetingCard.pickNext([undated], now), isNull);
    });
  });

  group('NextMeetingCard widget', () {
    testWidgets('Live state shows In Progress Now chip', (tester) async {
      final now = DateTime(2026, 8, 31, 19, 30);
      final live = _m('live', 1, 19 * 60, name: 'Live Meeting');
      expect(MeetingFinderService.isInProgress(live, now), isTrue);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NextMeetingCard(meeting: live, isLive: true, onOpenMap: () {})),
      ));
      expect(find.text('In Progress Now'), findsOneWidget);
      expect(find.text('Live Meeting'), findsOneWidget);
      expect(find.text('AA'), findsOneWidget);
      expect(find.text('View on Map — Join now'), findsOneWidget);
    });

    testWidgets('Upcoming state shows Today chip', (tester) async {
      final upcoming = _m('up', 1, 21 * 60, name: 'Upcoming Tonight');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NextMeetingCard(meeting: upcoming, isLive: false, onOpenMap: () {})),
      ));
      expect(find.byType(NextMeetingCard), findsOneWidget);
      expect(find.text('Upcoming Tonight'), findsOneWidget);
      // Chip contains time (Today/Tomorrow/Mon) + 9:00 PM — time is deterministic
      expect(find.textContaining('9:00'), findsOneWidget);
    });

    testWidgets('Empty state shows Find button and fallback copy', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NextMeetingCard(meeting: null, onFindMeetings: () {})),
      ));
      expect(find.text('No meetings in the next 6 hours'), findsOneWidget);
      expect(find.text('Find'), findsOneWidget);
    });

    testWidgets('Empty tap calls onFindMeetings', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NextMeetingCard(meeting: null, onFindMeetings: () => tapped = true)),
      ));
      await tester.tap(find.text('Find'));
      expect(tapped, isTrue);
    });

    testWidgets('Live tap calls onOpenMap', (tester) async {
      var tapped = false;
      final live = _m('live', 1, 19 * 60, name: 'Live');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NextMeetingCard(meeting: live, isLive: true, onOpenMap: () => tapped = true)),
      ));
      await tester.tap(find.text('View on Map — Join now'));
      expect(tapped, isTrue);
    });
  });
}
