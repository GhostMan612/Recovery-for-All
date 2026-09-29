// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/dashboard_sections_test.dart
//
// Phase 8 slice 3: the extracted section bodies must render in BOTH
// brightness modes, and — the part that matters — MeetingSpotlight must
// keep waiting / error / empty genuinely distinct. The dashboard used to
// show "No meetings in the next 6 hours" while the cache was still being
// read, which is a Phase 6 gap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/widgets/dashboard_sections.dart';

Widget _host(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: AppColors.themeDataFor(const ThemePreference(), brightness),
    home: Scaffold(body: child),
  );
}

RecoveryMeeting _meeting({String name = 'Tuesday Night Group'}) {
  return RecoveryMeeting(
    id: 'm1',
    name: name,
    latitude: 44.98,
    longitude: -93.27,
    type: 'Group',
    time: '7:00 PM',
    address: '123 Main St',
  );
}

void main() {
  group('PathChips', () {
    testWidgets('renders one chip per path in both brightness modes',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          const PathChips(paths: ['Alcoholics Anonymous', 'Narcotics Anonymous']),
          brightness: b,
        ));
        expect(find.text('Alcoholics Anonymous'), findsOneWidget);
        expect(find.text('Narcotics Anonymous'), findsOneWidget);
      }
    });

    testWidgets('renders nothing at all when there are no paths',
        (tester) async {
      await tester.pumpWidget(_host(
        const PathChips(paths: []),
        brightness: Brightness.light,
      ));
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('MeetingSpotlight state separation', () {
    testWidgets('waiting shows a loading message, NOT the empty copy',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          MeetingSpotlight(
            snapshot: const AsyncSnapshot<List<RecoveryMeeting>>.waiting(),
          ),
          brightness: b,
        ));
        expect(find.textContaining('Checking today'), findsOneWidget);
        // The regression this guards: an empty-looking card while loading.
        expect(
            find.text('No meetings in the next 6 hours'), findsNothing);
      }
    });

    testWidgets('error shows an error state with a retry affordance',
        (tester) async {
      var retried = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          MeetingSpotlight(
            snapshot: AsyncSnapshot<List<RecoveryMeeting>>.withError(
              ConnectionState.done,
              Exception('cache unreadable'),
              StackTrace.current,
            ),
            onRetry: () => retried++,
          ),
          brightness: b,
        ));
        expect(find.text('Could not load meetings'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      }
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('error state reassures that other tools still work',
        (tester) async {
      await tester.pumpWidget(_host(
        MeetingSpotlight(
          snapshot: AsyncSnapshot<List<RecoveryMeeting>>.withError(
            ConnectionState.done,
            Exception('boom'),
            StackTrace.current,
          ),
        ),
        brightness: Brightness.dark,
      ));
      expect(find.textContaining('still work'), findsOneWidget);
    });

    testWidgets('a loaded-but-empty cache shows the honest empty copy',
        (tester) async {
      var found = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          MeetingSpotlight(
            snapshot: AsyncSnapshot<List<RecoveryMeeting>>.withData(
              ConnectionState.done,
              const <RecoveryMeeting>[],
            ),
            onFindMeetings: () => found++,
          ),
          brightness: b,
        ));
        expect(find.text('No meetings in the next 6 hours'), findsOneWidget);
        expect(find.text('Find'), findsOneWidget);
        expect(find.textContaining('Checking today'), findsNothing);
        expect(find.text('Could not load meetings'), findsNothing);
      }
      await tester.tap(find.text('Find'));
      expect(found, 1);
    });

    testWidgets('a real pick renders the meeting name', (tester) async {
      final m = _meeting();
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          MeetingSpotlight(
            snapshot: AsyncSnapshot<List<RecoveryMeeting>>.withData(
                ConnectionState.done,
                [m],
              ),
            pick: (meeting: m, isLive: false),
            onOpenMap: _noop,
            onFindMeetings: _noop,
          ),
          brightness: b,
        ));
        expect(find.text('Tuesday Night Group'), findsOneWidget);
        expect(find.text('View on Map'), findsOneWidget);
      }
    });
  });

  group('ToolGrid', () {
    testWidgets('shows the header and the grid when tools are visible',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          ToolGrid(
            title: 'Your Toolbox',
            editing: false,
            hidden: const <String>{},
            onRestore: (_) {},
            onToggleEditing: _noop,
            children: const [
              Text('tool one'),
              Text('tool two'),
            ],
          ),
          brightness: b,
        ));
        expect(find.text('Your Toolbox'), findsOneWidget);
        expect(find.text('tool one'), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
      }
    });

    testWidgets('toggles edit mode and restores a single hidden tool',
        (tester) async {
      var toggles = 0;
      final restored = <String>[];
      await tester.pumpWidget(_host(
        ToolGrid(
          title: 'Your Toolbox',
          editing: true,
          hidden: const {'Crisis Lines'},
          onRestore: restored.add,
          onToggleEditing: () => toggles++,
          children: const [Text('tool one')],
        ),
        brightness: Brightness.light,
      ));
      expect(find.text('Crisis Lines'), findsOneWidget);
      // Tap the chip itself: the 14px visibility_off avatar is a decorative
      // sub-target of the ActionChip, not the hit area we care about.
      await tester.tap(find.text('Crisis Lines'));
      await tester.pump();
      expect(restored, ['Crisis Lines']);
      // editing: true means the button reads "Done" and shows a check, so
      // tapping the edit icon is not meaningful here.
      expect(find.byTooltip('Done'), findsOneWidget);
      await tester.tap(find.byTooltip('Done'));
      expect(toggles, 1);
    });

    // The regression this guards: hiding every tool collapsed the grid to
    // nothing with no explanation and no way back.
    testWidgets('every tool hidden explains itself and offers a restore',
        (tester) async {
      final restored = <String>[];
      await tester.pumpWidget(_host(
        ToolGrid(
          title: 'Your Toolbox',
          editing: false,
          hidden: const {'A', 'B', 'C'},
          onRestore: restored.add,
          onToggleEditing: _noop,
          children: const [],
        ),
        brightness: Brightness.light,
      ));
      expect(find.text('Every tool is hidden'), findsOneWidget);
      expect(find.textContaining('not the same as'), findsOneWidget);
      expect(find.text('Restore all'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      await tester.tap(find.text('Restore all'));
      expect(restored, ['A', 'B', 'C']);
    });

    testWidgets('an empty section with nothing hidden says so plainly',
        (tester) async {
      await tester.pumpWidget(_host(
        ToolGrid(
          title: 'Library',
          editing: false,
          hidden: const <String>{},
          onRestore: (_) {},
          onToggleEditing: _noop,
          children: const [],
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('No tools here yet'), findsOneWidget);
      expect(find.text('Restore all'), findsNothing);
    });

    testWidgets('grid does not overflow at a 2.0 text scale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppColors.themeDataFor(
            const ThemePreference(), Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: ToolGrid(
              title: 'Your Toolbox',
              editing: true,
              hidden: const {'A very long hidden tool name indeed'},
              onRestore: (_) {},
              onToggleEditing: _noop,
              children: const [Text('tool one'), Text('tool two')],
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('SkyCrown', () {
    testWidgets('named sky with no stars invites the first star',
        (tester) async {
      var taps = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          SkyCrown(
            nodes: const [],
            skyName: 'Recovery for All',
            onTap: () => taps++,
          ),
          brightness: b,
        ));
        expect(find.text('Recovery for All'), findsOneWidget);
        expect(find.textContaining('Plant your first star'), findsOneWidget);
        // No star count when there is nothing to count.
        expect(find.textContaining('stars'), findsNothing);
      }
      await tester.tap(find.byType(SkyCrown));
      expect(taps, 1);
    });
  });

  group('CompanionSection', () {
    testWidgets('XP bar and skill-tree affordance render and tap through',
        (tester) async {
      var taps = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          CompanionSection(
            pet: _pet(),
            onTap: () => taps++,
            onCheckIn: _noop,
            onWalk: _noop,
            onOpen: _noop,
          ),
          brightness: b,
        ));
        expect(find.text('Level 3 • 45/100 XP'), findsOneWidget);
        expect(find.text('Tap for Skill Tree'), findsOneWidget);
      }
      await tester.tap(find.text('Tap for Skill Tree'));
      expect(taps, 1);
    });

    testWidgets('XP progress reflects pathXp modulo 100', (tester) async {
      await tester.pumpWidget(_host(
        CompanionSection(
          pet: _pet(pathXp: 145),
          onTap: _noop,
          onCheckIn: _noop,
          onWalk: _noop,
          onOpen: _noop,
        ),
        brightness: Brightness.light,
      ));
      expect(find.text('Level 3 • 45/100 XP'), findsOneWidget);
      // RecoveryPetCard renders more than one bar of its own, so type alone
      // cannot identify the XP bar. The XP bar is unambiguously the one
      // carrying pathXp/100, and it is the one painted after the pet card
      // inside this widget's own subtree.
      final bars = tester
          .widgetList<LinearProgressIndicator>(
              find.descendant(
                of: find.byType(CompanionSection),
                matching: find.byType(LinearProgressIndicator),
              ),
          )
          .toList();
      final xpBar = bars.lastWhere(
        (b) => b.value != null && (b.value! - 0.45).abs() < 0.001,
        orElse: () => fail(
            'no bar with value 0.45 among ${bars.map((b) => b.value).toList()}'),
      );
      expect(xpBar.value, closeTo(0.45, 0.001));
    });
  });
}
RecoveryPet _pet({int pathXp = 145, int pathLevel = 3}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return RecoveryPet(
    id: 'p1',
    name: 'Kin',
    energy: 80,
    bond: 20,
    mood: PetMoodX.happy,
    sparks: 10,
    unlockedItems: const ['starter_glow'],
    equippedOutfit: 'starter_glow',
    equippedSlots: const {},
    lastFedAt: now,
    createdAt: now,
    pathLevel: pathLevel,
    pathXp: pathXp,
  );
}

void _noop() {}
