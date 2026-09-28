// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

enum AppTheme { midnightSlate, deepForest, oledPitch }

enum AppThemeMode { system, light, dark }

class ThemePreference {
  final AppTheme palette;
  final AppThemeMode mode;
  static const String modeKey = 'theme_mode_v1';
  const ThemePreference({
    this.palette = AppTheme.midnightSlate,
    this.mode = AppThemeMode.dark,
  });

  Brightness resolve(Brightness platform) => switch (mode) {
        AppThemeMode.light => Brightness.light,
        AppThemeMode.dark => Brightness.dark,
        AppThemeMode.system => platform,
      };

  Map<String, String> toJson() => {'palette': palette.name, 'mode': mode.name};

  factory ThemePreference.fromJson(Map<String, String> json) {
    final palettes = AppTheme.values.where((e) => e.name == json['palette']);
    final modes = AppThemeMode.values.where((e) => e.name == json['mode']);
    return ThemePreference(
      palette: palettes.isEmpty ? AppTheme.midnightSlate : palettes.first,
      mode: modes.isEmpty ? AppThemeMode.dark : modes.first,
    );
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class AppType {
  static const double display = 28;
  static const double title = 20;
  static const double heading = 16;
  static const double body = 14;
  static const double caption = 12;
  static const double micro = 11;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight regular = FontWeight.w400;
  static const double heightTight = 1.2;
  static const double heightBody = 1.4;
}

extension AppStateColors on ColorScheme {
  Color get disabled => onSurface.withValues(alpha: 0.38);
  Color get subtle => onSurfaceVariant.withValues(alpha: 0.6);
  Color get track => surfaceContainerHighest;
}

class AppPalette {
  final Color bgDeep;
  final Color bgCard;
  final Color border;
  final Color accent;
  final Color success;
  final Color danger;
  final Color textPrimary;
  final Color textMuted;
  final Color textDim;
  final Color textHint;
  const AppPalette({
    required this.bgDeep,
    required this.bgCard,
    required this.border,
    required this.accent,
    required this.success,
    required this.danger,
    required this.textPrimary,
    required this.textMuted,
    required this.textDim,
    required this.textHint,
  });
}

class AppColors {
  static const Color bgDeep = Color(0xFF0F172A);
  static const Color bgCard = Color(0xFF1E293B);
  static const Color border = Color(0xFF334155);
  static const Color accent = Color(0xFF38BDF8);
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFDC2626);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
  static const Color textHint = Color(0xFF475569);

  static Color scrim([double opacity = 0.72]) => bgDeep.withValues(alpha: opacity);

  static const AppPalette midnightSlate = AppPalette(
    bgDeep: Color(0xFF0F172A),
    bgCard: Color(0xFF1E293B),
    border: Color(0xFF334155),
    accent: Color(0xFF38BDF8),
    success: Color(0xFF34D399),
    danger: Color(0xFFDC2626),
    textPrimary: Colors.white,
    textMuted: Color(0xFF94A3B8),
    textDim: Color(0xFF64748B),
    textHint: Color(0xFF475569),
  );

  static const AppPalette deepForest = AppPalette(
    bgDeep: Color(0xFF0F1A14),
    bgCard: Color(0xFF16271F),
    border: Color(0xFF2A3F33),
    accent: Color(0xFF34D399),
    success: Color(0xFF6EE7B7),
    danger: Color(0xFFDC2626),
    textPrimary: Colors.white,
    textMuted: Color(0xFFA7C4B0),
    textDim: Color(0xFF6B8A75),
    textHint: Color(0xFF4A6352),
  );

  static const AppPalette oledPitch = AppPalette(
    bgDeep: Color(0xFF000000),
    bgCard: Color(0xFF0A0A0A),
    border: Color(0xFF2A2A2A),
    accent: Color(0xFF38BDF8),
    success: Color(0xFF34D399),
    danger: Color(0xFFDC2626),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9CA3AF),
    textDim: Color(0xFF6B7280),
    textHint: Color(0xFF4B5563),
  );

  static AppPalette paletteFor(AppTheme theme) => switch (theme) {
        AppTheme.midnightSlate => midnightSlate,
        AppTheme.deepForest => deepForest,
        AppTheme.oledPitch => oledPitch,
      };

  static ColorScheme schemeFor(AppPalette p, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: p.accent,
        tertiary: p.success,
        error: p.danger,
        surface: p.bgDeep,
        surfaceContainerLowest: p.bgDeep,
        surfaceContainerLow: p.bgDeep,
        surfaceContainer: p.bgCard,
        surfaceContainerHigh: p.bgCard,
        surfaceContainerHighest: p.border,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textMuted,
        outline: p.textDim,
        outlineVariant: p.border,
      );
    }
    return ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: p.accent,
      tertiary: p.success,
      error: p.danger,
    );
  }

  static ThemeData themeDataFor(AppTheme theme) {
    final p = paletteFor(theme);
    return ThemeData(
      scaffoldBackgroundColor: p.bgDeep,
      primaryColor: p.accent,
      colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: Brightness.dark),
      appBarTheme: AppBarTheme(backgroundColor: p.bgCard, foregroundColor: p.textPrimary, elevation: 0),
      cardColor: p.bgCard,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.bgCard,
        contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 14, height: 1.4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
