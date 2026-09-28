# UI/UX Themes & Architecture Plan

## Objective
Safely transition the app from a dark-only design to a modular, Light/Dark compatible architecture, and decompose the dashboard. This plan starts from the actual state of the codebase and acknowledges existing infrastructure (Riverpod, `AppColors`, Material 3 `NavigationBar`, existing FAB).

## Phase 1: The Color System Migration (High Complexity)
**Current State:** The app has a layered theme system in `lib/core/theme/app_colors.dart` (`AppTheme` enum: midnightSlate, deepForest, oledPitch) persisting via Riverpod (`ThemeNotifier`). However, it is **100% dark mode**, heavily reliant on 875 inline `Color(0xFF...)` hardcodes across 46 files.

**Goal:** Implement true Light/Dark support and migrate all raw hex values to contextual theme tokens.

1. **Light-Mode Palettes & MaterialApp:** 
   * Define light-mode equivalents for the 3 existing palettes.
   * Wire `themeMode: ThemeMode.system` and `darkTheme` into `MaterialApp` (currently it only defines `theme`).
2. **The 46-File Token Migration:** 
   * Iteratively replace the 875 hardcoded `Color(0xFF...)` values with `Theme.of(context).colorScheme` or `textTheme`. 
   * **Top targets:** `settings_screen.dart` (106 hits), `avatar_painter.dart` (92 hits), `onboarding_screen.dart` (84 hits).
   * **Edge Cases to fix:** 22 files using `IconThemeData(color: Colors.white)` for AppBars; hardcoded SnackBar background overrides (`Color(0xFF1E293B)`); and `themed_background.dart`.
3. **Avatar Painter & Asset Audit:** 
   * The `avatar_painter.dart` is currently theme-unaware. Define light-mode color mappings for all species, auras, and clothing. 
   * Test thermal-gated `.lottie` assets against light backgrounds.
4. **Rollback & Test Strategy:** Wrap this behind a feature flag or gradual rollout to protect the 12 beta testers. Update any of the 167 existing tests that explicitly assert `AppColors.*` properties.

## Phase 2: Deconstructing the Monolith (`dashboard_screen.dart`)
**Current State:** Dashboard is ~1600 lines with an enormous `_DashboardScreenState` holding ~40 fields and multiple async loaders.
*CRITICAL SEQUENCING:* Do not start Phase 2 until Phase 1 is fully completed to avoid massive merge conflicts.

**Goal:** Decouple state management before extracting views.

1. **Decouple State:** Extract the massive surface area in `_DashboardScreenState` (async loaders, meeting radius tiers, tutorial triggers, SOS state) into Riverpod notifiers or discrete state controllers. You cannot extract views safely until the shared state is modularized.
2. **Extract Pure Components:** Extract `_buildPledgeCard()` into a proper class. Verify separation of `_ToolCard` and `_SosTile` (which already exist as classes).
3. **Extract Views:** Split the main `build()` into distinct logical chunks (e.g., `companion_view.dart`, `path_view.dart`, `library_view.dart`).

## Phase 3: Navigation Expansion & The SOS Button
**Current State:** The app uses a Material 3 `NavigationBar` with 2 tabs (Path, Library). Settings is a pushed screen. The Pet is inside the Path tab (`PetHomeScreen` push). A red `FloatingActionButton.extended` already exists for the SOS sheet (`_showSosSheet`).

**Goal:** Shift toward a 4-tab model and refine the existing lifeline.

1. **Navigation Refactor:** If moving to a 4-tab model (Companion, Path, Library, Profile), architect how the Pet moves from a pushed route on the Path tab to a top-level Companion tab, and how Settings transforms into a Profile tab.
2. **Refine Existing SOS FAB:** Do not build a new FAB. Modify the existing extended red FAB to persist seamlessly across the new tab structure (e.g., center docked or global Scaffold overlay) without blocking the `NavigationBar`. The existing `_showSosSheet` (988, Sponsor, Meetings, Resources) functions well and only needs UI/UX placement adjustments.

## Phase 4: Theme Toggles, Polish & Accessibility
**Current State:** A 3-palette `ChoiceChip` exists in Settings.

**Goal:** Provide full theme control and broaden accessibility.

1. **Theme Settings:** Expand the existing palette picker in `settings_screen.dart` to include a "Theme Mode" toggle (Light / Dark / System Default).
2. **Comprehensive Accessibility:** Beyond running WCAG AA contrast checks, implement and test for dynamic type (`textScaler`), legible font sizing, and minimum touch targets across both themes.
