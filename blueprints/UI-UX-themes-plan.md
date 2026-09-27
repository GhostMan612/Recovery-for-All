# UI/UX Themes & Architecture Plan

## Objective
Safely transition the app from a monolithic, pure-dark design to a modular, Light/Dark compatible architecture. Establish a scalable navigation hierarchy that centers the Pet Avatar while providing immediate access to the SOS Pocket Lifeline.

## Phase 1: The Color System Migration (Risk Mitigation)
**Goal:** Decouple hardcoded colors without breaking the existing dark mode.
1. **Define `AppTheme`:** Create `lib/theme/app_theme.dart` (or expand existing). Define a `ColorScheme.light` and `ColorScheme.dark`. Map existing `AppColors` (midnightSlate, deepForest) into the `ColorScheme.dark` surface and primary slots.
2. **The Great Find & Replace:** Iteratively replace hardcoded colors like `AppColors.bgCard` with `Theme.of(context).colorScheme.surface`. 
   * *Critical Check:* Ensure no text styles are hardcoded to white. Use `Theme.of(context).textTheme.bodyMedium?.color` or `colorScheme.onSurface`.
3. **Asset Audit:** Audit `avatar_painter.dart` and Lottie aura underlays. Define dynamic strokes for the vector painter that react to `Theme.of(context).brightness`. Test thermal-gated Lottie assets against light backgrounds.

## Phase 2: Deconstructing the Monolith (`dashboard_screen.dart`)
**Goal:** Break down the 1538-line dashboard safely to prevent state loss.
1. **Extract Pure Components:** Move purely presentational widgets (like ToolCard, SosTile, PledgeCard) into a new `lib/widgets/` directory. Pass data via constructors; pass actions via callbacks (`VoidCallback`).
2. **Decouple State:** Identify local state variables tied to Pet interactions and extract them into discrete state controllers or `ValueNotifier`s.
3. **Extract Views:** Split the giant dashboard `build()` method into distinct files: `companion_view.dart`, `path_view.dart`, `library_view.dart`. The main `DashboardScreen` should only contain the Scaffold, NavigationBar, and PageView/IndexedStack.

## Phase 3: Navigation Expansion & The SOS Button
**Goal:** Adopt competitor standards (4 tabs + SOS) without burying the Pet.
1. **Implement `NavigationBar`:** Upgrade from the legacy 2-tab system to a modern Flutter `NavigationBar` (Material 3).
   * **Tab 1: Companion** (Pet Avatar, Daily Sparks, Constellation)
   * **Tab 2: Path** (Weekly Goals, Wellness Check-ins, Meetings Tracker)
   * **Tab 3: Library** (Offline Resources, Saved Articles, Worksheets)
   * **Tab 4: Profile** (Settings, Tailoring Doctrine choices, Gear/Cosmetics)
2. **Global SOS FAB:** Implement the 'Pocket Lifeline' as a persistent `FloatingActionButton` on the `DashboardScreen` Scaffold. Use a pill shape with a shield or lifeline icon and a label. Position it safely (e.g., `FloatingActionButtonLocation.centerDocked` or `endFloat`) so it's always one tap away without cluttering the bottom nav.

## Phase 4: Theme Toggles & Polish
**Goal:** Hand control to the user.
1. **Settings Integration:** Add a "Theme" section in the Profile tab (Light / Dark / System Default).
2. **Persistence:** Save the preference to local storage (`shared_preferences` or Drift profiles table) to ensure the app boots in the correct theme instantly.
3. **Contrast Verification:** Run accessibility checks to ensure text contrast passes WCAG AA standards in both Light and Dark modes.
