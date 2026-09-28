# Phase 1: Color System Migration
**Target Executor:** Muse Spark 1.3
**Context:** We are migrating from a pure dark-mode architecture to a Light/Dark responsive system while preserving the existing 3 palettes (`midnightSlate`, `deepForest`, `oledPitch`).
**Rule Reminder:** Do not run `flutter build`. Gate your work through `flutter analyze` and `flutter test`.

---

## Step 1: Add ThemeMode State
1. Open `lib/core/providers.dart`.
2. Add a new `ThemeModeNotifier` (managing `ThemeMode`) that persists to `shared_preferences` key `theme_mode_v1`. It should default to `ThemeMode.system`.
3. Expose it via `final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);`.

## Step 2: Implement Light Palettes & Theme Extensions
The app relies on `AppPalette` fields (`bgDeep`, `bgCard`, `textMuted`, etc.) which don't map perfectly 1:1 to standard Material `ColorScheme`. We will use a `ThemeExtension`.

1. Open `lib/core/theme/app_colors.dart`.
2. Change `AppPalette` to extend `ThemeExtension<AppPalette>`:
   ```dart
   class AppPalette extends ThemeExtension<AppPalette> {
     // keep existing fields + constructor
     @override
     AppPalette copyWith(...) { ... }
     @override
     AppPalette lerp(ThemeExtension<AppPalette>? other, double t) { ... }
   }
   ```
3. Define the **Light Mode equivalents** as static constants next to the existing dark ones:
   * **`midnightSlateLight`**: bgDeep: 0xFFF8FAFC, bgCard: 0xFFFFFFFF, border: 0xFFE2E8F0, accent: 0xFF0EA5E9, success: 0xFF10B981, danger: 0xFFEF4444, textPrimary: 0xFF0F172A, textMuted: 0xFF64748B, textDim: 0xFF94A3B8, textHint: 0xFFCBD5E1.
   * **`deepForestLight`**: bgDeep: 0xFFF4F9F6, bgCard: 0xFFFFFFFF, border: 0xFFD1E0D7, accent: 0xFF10B981, success: 0xFF34D399, danger: 0xFFEF4444, textPrimary: 0xFF0F1A14, textMuted: 0xFF6B8A75, textDim: 0xFFA7C4B0, textHint: 0xFFCBDDD2.
   * **`oledPitchLight`** (crisp grayscale): bgDeep: 0xFFF3F4F6, bgCard: 0xFFFFFFFF, border: 0xFFE5E7EB, accent: 0xFF0EA5E9, success: 0xFF10B981, danger: 0xFFEF4444, textPrimary: 0xFF000000, textMuted: 0xFF6B7280, textDim: 0xFF9CA3AF, textHint: 0xFFD1D5DB.
4. Modify `paletteFor(AppTheme theme, Brightness brightness)` to return the correct light/dark palette.
5. Modify `themeDataFor(AppTheme theme, Brightness brightness)` to include `extensions: [palette]`. Map `scaffoldBackgroundColor` to `palette.bgDeep` and `cardColor` to `palette.bgCard`.
6. Add a convenient extension for context:
   ```dart
   extension AppThemeContext on BuildContext {
     AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
   }
   ```

## Step 3: Wire MaterialApp
1. Open `lib/main.dart`.
2. Watch `themeModeProvider`.
3. Update `MaterialApp` to use:
   ```dart
   themeMode: ref.watch(themeModeProvider),
   theme: AppColors.themeDataFor(appTheme, Brightness.light),
   darkTheme: AppColors.themeDataFor(appTheme, Brightness.dark),
   ```

## Step 4: The 875-Color Great Migration
This is the bulk of the work. You must eliminate all direct references to `AppColors.bgCard` (the static getters) and inline `Color(0xFF...)` literals.
1. **Search strategy:** Run regex searches for `Color\(0xFF` and `AppColors\.` across `lib/`.
2. **Replacement strategy:** Replace with `context.colors.textMuted`, `context.colors.bgCard`, etc.
   * *Note:* For `avatar_painter.dart`, pass the `BuildContext context` (or the `AppPalette` directly) into the painter constructor so it can react to the active theme.
   * *Edge Case:* Replace `IconThemeData(color: Colors.white)` with `IconThemeData(color: context.colors.textPrimary)`.
   * *Edge Case:* Update `themed_background.dart` to rely entirely on `context.colors.bgDeep`.
3. **Execution chunking:** Group your replacements in batches (e.g., `settings`, `onboarding`, `dashboard`) so you don't stall. Run `flutter analyze` after every chunk. 

## Step 5: Test & Validate
1. Fix any tests that broke due to `AppColors` static access removals.
2. Verify `flutter analyze` is zero.
3. Verify `flutter test` stays green (currently 167 passing).
