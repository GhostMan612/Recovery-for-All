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

  static const Color pink = Color(0xFFF472B6);

  static const Color moodGood = Color(0xFF60A5FA);
  static const Color moodStruggling = Color(0xFFFBBF24);
  static const Color moodNeedHelp = Color(0xFFEF4444);

  static const Color starfield = Color(0xFF0B1120);

  static const Color pinOnline = Color(0xFFA78BFA);
  static const Color pinSoon = Color(0xFFFBBF24);

  static const Color housingMaternal = Color(0xFFA78BFA);
  static const Color housingDefault = Color(0xFFFBBF24);

  static const Color fellowAA = Color(0xFF38BDF8);
  static const Color fellowNA = Color(0xFFA78BFA);
  static const Color fellowSMART = Color(0xFFFBBF24);
  static const Color fellowWellbriety = Color(0xFF34D399);

  static const Color starMilestone = Color(0xFFFBBF24);
  static const Color starStepWork = Color(0xFF34D399);
  static const Color starCommunity = Color(0xFF38BDF8);
  static const Color starService = Color(0xFFF97316);
  static const Color starMindfulness = Color(0xFFA78BFA);
  static const Color starSpiritual = Color(0xFF34D399);

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

  static ThemeData themeDataFor(ThemePreference pref, Brightness brightness) {
    final p = paletteFor(pref.palette);
    final scheme = schemeFor(p, brightness);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      primaryColor: scheme.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: AppType.body,
          height: AppType.heightBody,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurfaceVariant, fontSize: AppType.micro),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.surfaceContainerHighest,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(
        tileColor: scheme.surface,
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}
