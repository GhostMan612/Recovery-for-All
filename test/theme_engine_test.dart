// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recovery_for_all/core/providers.dart';
import 'package:recovery_for_all/core/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('themeDataFor matrix', () {
    test('all six palette/brightness combos resolve brightness', () {
      for (final palette in AppTheme.values) {
        const modes = [Brightness.light, Brightness.dark];
        for (final brightness in modes) {
          final theme = AppColors.themeDataFor(
            ThemePreference(palette: palette, mode: AppThemeMode.dark),
            brightness,
          );
          expect(theme.colorScheme.brightness, brightness);
          expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
        }
      }
    });

    test('dark default preserves legacy midnightSlate surfaces', () {
      final theme = AppColors.themeDataFor(
        const ThemePreference(),
        Brightness.dark,
      );
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F172A));
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF1E293B));
      expect(theme.cardTheme.color, const Color(0xFF1E293B));
      expect(theme.bottomSheetTheme.backgroundColor, const Color(0xFF1E293B));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFF1E293B));
      expect(theme.snackBarTheme.backgroundColor, const Color(0xFF1E293B));
      expect(theme.primaryColor, const Color(0xFF38BDF8));
    });

    testWidgets('all six combos pump without crashing', (tester) async {
      for (final palette in AppTheme.values) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppColors.themeDataFor(
                ThemePreference(palette: palette, mode: AppThemeMode.dark),
                brightness,
              ),
              home: const Scaffold(body: Text('combo')),
            ),
          );
          expect(find.text('combo'), findsOneWidget);
        }
      }
    });
  });

  group('ThemeNotifier persistence', () {
    test('setPalette and setMode persist and restore across restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(themeProvider).palette, AppTheme.midnightSlate);
      expect(first.read(themeProvider).mode, AppThemeMode.dark);

      await first.read(themeProvider.notifier).setPalette(AppTheme.deepForest);
      await first.read(themeProvider.notifier).setMode(AppThemeMode.system);
      expect(first.read(themeProvider).palette, AppTheme.deepForest);
      expect(first.read(themeProvider).mode, AppThemeMode.system);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference_v1'), 'deepForest');
      expect(prefs.getString('theme_mode_v1'), 'system');

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(themeProvider).palette, AppTheme.midnightSlate);
      await testerPumpMicrotasks();
      expect(second.read(themeProvider).palette, AppTheme.deepForest);
      expect(second.read(themeProvider).mode, AppThemeMode.system);
    });

    test('unknown persisted values fall back to dark default', () async {
      SharedPreferences.setMockInitialValues({
        'theme_preference_v1': 'nope',
        'theme_mode_v1': 'nope',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await testerPumpMicrotasks();
      expect(container.read(themeProvider).palette, AppTheme.midnightSlate);
      expect(container.read(themeProvider).mode, AppThemeMode.dark);
    });
  });
}

Future<void> testerPumpMicrotasks() async {
  for (var i = 0; i < 100; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
