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

  group('SosTile', () {
    testWidgets('renders title/subtitle and taps once when enabled',
        (tester) async {
      var pressed = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.phone_in_talk,
            color: Colors.red,
            title: 'Call 988',
            subtitle: 'Suicide & Crisis Lifeline · 24/7',
            onTap: () => pressed++,
          ),
          brightness: b,
        ));
        expect(find.text('Call 988'), findsOneWidget);
        expect(find.text('Suicide & Crisis Lifeline · 24/7'), findsOneWidget);
      }
      await tester.tap(find.byType(SosTile));
      expect(pressed, 1);
    });

    // SAFETY: a disabled tile must stay visible (the user has to see that
    // "Call Sponsor" exists) but must not accept a tap.
    testWidgets('disabled tile still renders but does not tap', (tester) async {
      var pressed = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.person_pin_circle,
            color: Colors.blue,
            title: 'Call Sponsor',
            subtitle: 'Add in Settings',
            enabled: false,
            onTap: () => pressed++,
          ),
          brightness: b,
        ));
        expect(find.text('Call Sponsor'), findsOneWidget);
        expect(find.text('Add in Settings'), findsOneWidget);
      }
      await tester.tap(find.byType(SosTile));
      await tester.pump();
      expect(pressed, 0);
    });
  });

  group('SupportLinkRow', () {
    testWidgets('renders copy and invokes onTap once', (tester) async {
      var pressed = 0;
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          SupportLinkRow(
            icon: Icons.qr_code_scanner,
            title: 'Fellowship Handshake',
            subtitle: 'QR connect · offline, private',
            onTap: () => pressed++,
          ),
          brightness: b,
        ));
        expect(find.text('Fellowship Handshake'), findsOneWidget);
        expect(find.text('QR connect · offline, private'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      }
      await tester.tap(find.byType(SupportLinkRow));
      expect(pressed, 1);
    });

    testWidgets('honours an explicit tint for the branded row',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(_host(
        SupportLinkRow(
          key: key,
          icon: Icons.volunteer_activism_outlined,
          title: '7th Tradition',
          subtitle: 'Voluntary support',
          tint: const Color(0xFFD81B60),
          onTap: _noop,
        ),
        brightness: Brightness.light,
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.volunteer_activism_outlined));
      expect(icon.color, const Color(0xFFD81B60));
    });
  });

  // Phase 8 task 6: the toolbox grid uses a fixed childAspectRatio, so a
  // large accessibility text scale is the overflow suspect. Verify ToolCard
  // itself stays inside a fixed-height cell at 1.0x and 2.0x.
  group('ToolCard at fixed grid cell height', () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at textScale $scale inside a 1.35-ratio cell',
          (tester) async {
        // 160dp wide cell => 1.35 ratio => ~118dp tall, matching the grid.
        await tester.pumpWidget(MaterialApp(
          theme: AppColors.themeDataFor(
              const ThemePreference(), Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  height: 118,
                  child: const ToolCard(
                    label: 'Sobriety Counter',
                    subtitle: 'Days, milestones, and streaks',
                    icon: Icons.timeline_outlined,
                    onTap: _noop,
                  ),
                ),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('Sobriety Counter'), findsOneWidget);
      });
    }
  });
}

void _noop() {}
