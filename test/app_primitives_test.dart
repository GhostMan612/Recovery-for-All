// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/app_primitives_test.dart
//
// Phase 4 gates for the shared presentation primitives:
//  * they render in BOTH brightness modes without a per-screen override,
//  * they consume semantic theme tokens (no raw literals, no dark-pinned
//    AppColors statics),
//  * the interaction contracts (tap, disabled) actually hold.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/widgets/app_primitives.dart';

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
  group('AppCard', () {
    testWidgets('renders in light and dark', (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_host(
          const AppCard(child: Text('hello')),
          brightness: b,
        ));
        expect(find.text('hello'), findsOneWidget);
      }
    });

    testWidgets('exposes a tap target only when onTap is given',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppCard(onTap: () => taps++, child: const Text('tap me')),
        brightness: Brightness.dark,
      ));
      await tester.tap(find.text('tap me'));
      expect(taps, 1);

      await tester.pumpWidget(_host(
        const AppCard(child: Text('inert')),
        brightness: Brightness.dark,
      ));
      await tester.tap(find.text('inert'));
      expect(taps, 1, reason: 'no onTap means no gesture handling');
    });
  });

  group('AppSectionHeader', () {
    testWidgets('shows the title and optional subtitle', (tester) async {
      await tester.pumpWidget(_host(
        const AppSectionHeader(title: 'Appearance', subtitle: 'pick a palette'),
        brightness: Brightness.dark,
      ));
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('pick a palette'), findsOneWidget);
    });

    testWidgets('omits the subtitle slot when not provided', (tester) async {
      await tester.pumpWidget(_host(
        const AppSectionHeader(title: 'Only title'),
        brightness: Brightness.light,
      ));
      expect(find.text('Only title'), findsOneWidget);
    });
  });

  group('AppLoadingState', () {
    testWidgets('renders a progress indicator and optional message',
        (tester) async {
      await tester.pumpWidget(_host(
        const AppLoadingState(message: 'Loading your sky'),
        brightness: Brightness.dark,
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your sky'), findsOneWidget);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders icon, title, message, and action', (tester) async {
      await tester.pumpWidget(_host(
        AppEmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'Nothing here yet',
          message: 'It will appear as you go.',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Start'),
          ),
        ),
        brightness: Brightness.light,
      ));
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('It will appear as you go.'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });
  });

  group('AppActionTile', () {
    testWidgets('fires onTap when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppActionTile(
          icon: Icons.groups_outlined,
          title: 'Meetings',
          subtitle: 'Rooms near you',
          onTap: () => taps++,
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('Meetings'), findsOneWidget);
      await tester.tap(find.text('Meetings'));
      expect(taps, 1);
    });

    testWidgets('is inert when disabled even with an onTap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppActionTile(
          icon: Icons.groups_outlined,
          title: 'Meetings',
          onTap: () => taps++,
          enabled: false,
        ),
        brightness: Brightness.dark,
      ));
      await tester.tap(find.text('Meetings'));
      expect(taps, 0, reason: 'a disabled tile must not fire');
    });
  });

  group('AppErrorState', () {
    testWidgets('renders title, message, and retry when retryable',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(
        AppErrorState(
          title: 'Could not load the directory',
          message: 'No connection.',
          onRetry: () => retries++,
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('Could not load the directory'), findsOneWidget);
      expect(find.text('No connection.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('omits the retry affordance when not retryable',
        (tester) async {
      await tester.pumpWidget(_host(
        const AppErrorState(title: 'Nothing to show'),
        brightness: Brightness.light,
      ));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('AppOfflineState', () {
    testWidgets('explains cached data survives, and can retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(
        AppOfflineState(onRetry: () => retries++),
        brightness: Brightness.dark,
      ));
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.textContaining('saved on this device'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('theme contract', () {
    test('primitives compile against every palette x brightness pair',
        () {
      for (final palette in AppTheme.values) {
        for (final brightness in Brightness.values) {
          final scheme = AppColors.schemeFor(
            AppColors.paletteFor(palette),
            brightness,
          );
          expect(scheme.brightness, brightness);
          expect(
            scheme.onSurface,
            isNot(scheme.surface),
            reason: '$palette/$brightness must keep text off the background',
          );
        }
      }
    });
  });
}
