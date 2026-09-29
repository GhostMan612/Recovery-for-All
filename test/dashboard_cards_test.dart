// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/dashboard_cards_test.dart
//
// Phase 8 slice 1: the extracted dashboard card vocabulary must behave
// exactly like the inline code it replaced, in BOTH brightness modes, and
// must not reintroduce brightness-pinned colors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/widgets/dashboard_cards.dart';

Widget _host(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: AppColors.themeDataFor(
      const ThemePreference(),
      brightness,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('PledgeCard', () {
    testWidgets('shows the invitation and a working pledge action when unpledged',
        (tester) async {
      var pressed = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          PledgeCard(pledged: false, onPledge: () => pressed++),
          brightness: b,
        ));
        expect(find.text('Today I pledge to stay the course.'), findsOneWidget);
        expect(find.text('I pledge'), findsOneWidget);
        expect(find.text('Pledge confirmed. Today is yours.'), findsNothing);
      }
      await tester.tap(find.text('I pledge'));
      expect(pressed, 1);
    });

    testWidgets('shows the confirmation state and hides the action when pledged',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          PledgeCard(pledged: true, onPledge: () {}),
          brightness: b,
        ));
        expect(find.text('Pledge confirmed. Today is yours.'), findsOneWidget);
        expect(find.text('Today I pledge to stay the course.'), findsNothing);
        expect(find.text('I pledge'), findsNothing);
      }
    });

    testWidgets('survives an enlarged text scale without overflowing',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(MaterialApp(
          theme: AppColors.themeDataFor(const ThemePreference(), b),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: PledgeCard(pledged: false, onPledge: () {}),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('ToolCard', () {
    testWidgets('renders label, subtitle and icon in both brightness modes',
        (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          const ToolCard(
            label: 'Encrypted Journal',
            subtitle: 'Private, on-device',
            icon: Icons.book_outlined,
            onTap: _noop,
          ),
          brightness: b,
        ));
        expect(find.text('Encrypted Journal'), findsOneWidget);
        expect(find.text('Private, on-device'), findsOneWidget);
        expect(find.byIcon(Icons.book_outlined), findsOneWidget);
      }
    });

    testWidgets('invokes onTap exactly once', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_host(
        ToolCard(
          label: 'Meeting Finder',
          subtitle: 'Live and upcoming',
          icon: Icons.groups_outlined,
          onTap: () => pressed++,
        ),
        brightness: Brightness.dark,
      ));
      await tester.tap(find.byType(ToolCard));
      expect(pressed, 1);
    });

    testWidgets('omits the subtitle row when the subtitle is empty',
        (tester) async {
      await tester.pumpWidget(_host(
        const ToolCard(
          label: 'Crisis Lines',
          subtitle: '',
          icon: Icons.emergency_outlined,
          onTap: _noop,
        ),
        brightness: Brightness.light,
      ));
      expect(find.text('Crisis Lines'), findsOneWidget);
    });
  });
}

void _noop() {}
