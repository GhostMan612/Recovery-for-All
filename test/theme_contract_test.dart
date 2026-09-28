// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';

void main() {
  group('schemeFor dark pins palette values', () {
    for (final theme in AppTheme.values) {
      test('${theme.name} dark', () {
        final p = AppColors.paletteFor(theme);
        final s = AppColors.schemeFor(p, Brightness.dark);
        expect(s.brightness, Brightness.dark);
        expect(s.primary, p.accent);
        expect(s.tertiary, p.success);
        expect(s.error, p.danger);
        expect(s.surface, p.bgDeep);
        expect(s.surfaceContainerLowest, p.bgDeep);
        expect(s.surfaceContainerLow, p.bgDeep);
        expect(s.surfaceContainer, p.bgCard);
        expect(s.surfaceContainerHigh, p.bgCard);
        expect(s.surfaceContainerHighest, p.border);
        expect(s.onSurface, p.textPrimary);
        expect(s.onSurfaceVariant, p.textMuted);
        expect(s.outline, p.textDim);
        expect(s.outlineVariant, p.border);
      });
    }
  });

  group('schemeFor light keeps brand slots', () {
    for (final theme in AppTheme.values) {
      test('${theme.name} light', () {
        final p = AppColors.paletteFor(theme);
        final s = AppColors.schemeFor(p, Brightness.light);
        expect(s.brightness, Brightness.light);
        expect(s.primary, p.accent);
        expect(s.tertiary, p.success);
        expect(s.error, p.danger);
      });
    }
  });

  test('light and dark schemes differ per palette', () {
    for (final theme in AppTheme.values) {
      final p = AppColors.paletteFor(theme);
      final dark = AppColors.schemeFor(p, Brightness.dark);
      final light = AppColors.schemeFor(p, Brightness.light);
      expect(dark.surface, isNot(light.surface));
      expect(dark.onSurface, isNot(light.onSurface));
    }
  });

  group('ThemePreference', () {
    test('defaults preserve current boot behavior', () {
      const pref = ThemePreference();
      expect(pref.palette, AppTheme.midnightSlate);
      expect(pref.mode, AppThemeMode.dark);
    });

    test('resolve maps modes correctly', () {
      const pref = ThemePreference();
      expect(
        pref.resolve(Brightness.light),
        Brightness.dark,
      );
      expect(
        const ThemePreference(mode: AppThemeMode.light)
            .resolve(Brightness.dark),
        Brightness.light,
      );
      expect(
        const ThemePreference(mode: AppThemeMode.system)
            .resolve(Brightness.light),
        Brightness.light,
      );
      expect(
        const ThemePreference(mode: AppThemeMode.system)
            .resolve(Brightness.dark),
        Brightness.dark,
      );
    });

    test('serialization round-trips, unknown values fall back', () {
      const pref = ThemePreference(
        palette: AppTheme.deepForest,
        mode: AppThemeMode.system,
      );
      final back = ThemePreference.fromJson(pref.toJson());
      expect(back.palette, AppTheme.deepForest);
      expect(back.mode, AppThemeMode.system);
      final fallback = ThemePreference.fromJson(
        {'palette': 'nope', 'mode': 'nope'},
      );
      expect(fallback.palette, AppTheme.midnightSlate);
      expect(fallback.mode, AppThemeMode.dark);
    });
  });

  test('spacing, radii, and type scales are ordered and positive', () {
    expect(AppSpacing.xs, greaterThan(0));
    expect(AppSpacing.xs, lessThan(AppSpacing.sm));
    expect(AppSpacing.sm, lessThan(AppSpacing.md));
    expect(AppSpacing.md, lessThan(AppSpacing.lg));
    expect(AppSpacing.lg, lessThan(AppSpacing.xl));
    expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
    expect(AppSpacing.xxl, lessThan(AppSpacing.xxxl));
    expect(AppRadii.sm, lessThan(AppRadii.md));
    expect(AppRadii.md, lessThan(AppRadii.lg));
    expect(AppRadii.lg, lessThan(AppRadii.xl));
    expect(AppType.micro, lessThan(AppType.caption));
    expect(AppType.caption, lessThan(AppType.body));
    expect(AppType.body, lessThan(AppType.heading));
    expect(AppType.heading, lessThan(AppType.title));
    expect(AppType.title, lessThan(AppType.display));
  });

  test('AppStateColors derives from scheme', () {
    final s = AppColors.schemeFor(
      AppColors.midnightSlate,
      Brightness.dark,
    );
    expect(s.disabled.a, closeTo(0.38, 0.01));
    expect(s.track, s.surfaceContainerHighest);
  });
}
