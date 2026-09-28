# Recovery for All — UI/UX Modernization & Design-System Execution Plan

## Mission

Modernize Recovery for All from a dark-first, screen-specific UI into a cohesive, accessible, production-quality Material 3 application with a durable design system, true Light/Dark/System support, modular navigation, a decomposed dashboard, and consistent interaction patterns.

This is an **execution specification**, not a loose list of ideas. Each phase has explicit scope, invariants, deliverables, and a verification gate so an autonomous coding agent can execute the work without inventing architecture or silently changing recovery behavior.

## Non-Negotiable Engineering Rules

1. **Inspect before modifying.** Reconcile every blueprint assumption with the current repository before implementation. If reality differs, document the discrepancy and adapt the phase rather than guessing.
2. **Preserve behavior by default.** Existing recovery, meeting, sponsor, SOS, tutorial, companion, persistence, and navigation behavior must remain functionally equivalent unless a phase explicitly authorizes a behavior change.
3. **No broad rewrites.** Prefer incremental extraction and migration over replacing working systems with new frameworks.
4. **One source of truth.** Extend existing Riverpod/theme infrastructure where sound; do not introduce a parallel state-management or theme-persistence system without a documented architectural reason.
5. **Semantic over literal styling.** Standard Material UI uses `ColorScheme`, `TextTheme`, and component themes. Custom tokens are reserved for genuinely app-specific semantics.
6. **Do not blindly migrate colors.** Brand, illustration, avatar, artwork, status, and asset colors must be classified before replacement.
7. **Do not duplicate SOS behavior.** The existing SOS behavior is the source of truth; navigation changes must reposition/recompose it, not create competing implementations.
8. **No phase is complete on code alone.** Every phase requires analysis/tests and a written gate result.
9. **Keep transitional scaffolding temporary.** Any compatibility adapter, feature flag, or migration shim must have a removal condition and owner phase.
10. **Review the diff for architectural drift.** A passing test suite does not justify unnecessary abstractions or unrelated cleanup.

## Global Definition of Done

A phase is complete only when:

- requested implementation is present;
- existing relevant behavior is preserved;
- `flutter analyze --no-pub` is clean;
- relevant tests pass;
- new architecture is covered by focused tests;
- no unexplained warnings, skips, or golden changes remain;
- the repository diff contains no unrelated work;
- the phase gate below is explicitly satisfied.

## Execution Status

Phases 0-6 are **complete and verified**. Phases 7-17 are **not started**.

| Phase | State | Evidence |
|---|---|---|
| 0 — Baseline & recon | COMPLETE | analyze clean, suite 167 -> 179 |
| 1 — Semantic design system | COMPLETE | spacing/radii/type/state tokens + 3 palettes x 2 brightness |
| 2 — M3 theme engine | COMPLETE | 6-scheme matrix, `themeMode` wired, persistence, centralized component themes |
| 3 — Color & styling migration | COMPLETE | 875 -> 0 raw literals outside allowlist; `tools/verify_no_hardcoded_colors.py` green |
| 4 — Reusable UI components | COMPLETE | 5 primitives + 11 headers + memory-wall adoption, 9 new tests |
| 5 — Brightness drain | COMPLETE | 390 dark-pinned refs -> 0, constants deleted, gate extended |
| 6 — Empty/loading/error/offline | COMPLETE | `AppErrorState` + `AppOfflineState`, 3 screens adopted, `isCacheStale()` |
| 7-17 | NOT STARTED | no code, no gates run |

Gates at the close of Phase 3: `flutter analyze --no-pub` -> No issues found;
`flutter test` -> all passing; `verify_no_hardcoded_colors.py` -> exit 0.

**Resolved:** the 398 dark-pinned `AppColors` statics were the Phase 5 blocker and
are now gone. Remaining known gaps are tracked per phase below.

**Next phase is Phase 7 (Dashboard State Decomposition)** — state ownership before any
view splitting, per this phase's own prohibited-shortcut rule.

## Re-Sequencing Rationale (Sep 28)

The original phase order had two dependency defects, found while executing:

1. **The dark-pinned `AppColors` statics were never scheduled for retirement.**
   Phase 3 banned `Color(0x...)` literals, but the old top-level constants
   (`AppColors.accent`, `.textMuted`, `.bgCard`, ...) are semantically the same
   thing — fixed dark values. 398 references across 32 files survived the gate.
   Light mode is therefore only partially real. This is cross-cutting: every
   later phase edits those files, so draining first means touching them once.
2. **Empty/loading/error states (old Phase 13) were scheduled after dashboard
   decomposition (old Phases 5-6).** That is backwards: the decomposition moves
   those states, and Phase 4 now supplies shared primitives for them. Doing
   states first makes the dashboard move mechanical instead of creative.

Corrected order below. Each phase keeps its original intent and gate.

---

# Phase 0 — Baseline, Reconnaissance & Contract Freeze

**Status: COMPLETE** — baseline recorded; `flutter analyze --no-pub` clean at every phase gate and the suite grew 167 -> 179 with the phase. Commit `e2b17722048`.

### Objective
Establish the actual repository state before changing architecture or visuals.

### Tasks

1. Inventory `lib/`, tests, integration tests, assets, fonts, animations, theme infrastructure, Riverpod providers/notifiers, navigation, dashboard, settings, and reusable widgets.
2. Establish the current clean baseline with `flutter analyze --no-pub` and the complete applicable test suite.
3. Record test counts, warnings, failures, golden tests, widget tests, and integration coverage.
4. Inventory all theme/color references, including:
   - `Color(0x...)`
   - `Colors.white` / `Colors.black`
   - `AppColors`
   - `AppTheme`
   - `ThemeData`
   - `ColorScheme`
   - `IconThemeData`
   - hardcoded SnackBar/Dialog/AppBar colors
   - opacity/color manipulation
5. Map current navigation and all route entry points.
6. Inventory `_DashboardScreenState` fields and classify each as UI-local, persisted preference, domain/async state, derived state, navigation state, or controller state.
7. Identify behavioral contracts that must not change.

### Deliverables

Create/update planning artifacts only as needed:

- baseline inventory
- theme/color inventory
- navigation map
- dashboard state map
- accessibility baseline

Do not add documentation solely for documentation's sake; retain useful artifacts that future agents can verify.

### Gate 0

**Baseline is reproducible and documented. No implementation begins until the current test/analyze state is known.**

---

# Phase 1 — Semantic Design-System Contract

**Status: COMPLETE** — semantic roles shipped as `AppSpacing`, `AppRadii`, `AppType`, `AppStateColors` (`disabled`/`subtle`/`track`), and the three `AppPalette` values, each gaining a Light and a Dark variant. Palette and brightness are independent selections. Commit `e2b17722048`.

### Objective
Create the semantic vocabulary that all later visual work will use.

### Tasks

1. Define semantic color roles for standard surfaces, text, borders, interactive states, status states, and Recovery-for-All-specific states.
2. Use Material 3 `ColorScheme` for standard Material roles.
3. Add app-specific theme extensions/tokens only for semantics that do not fit Material's standard roles.
4. Define typography hierarchy using `TextTheme`; eliminate ad-hoc typography where it represents a shared role.
5. Define a restrained spacing scale and reuse it consistently.
6. Define standard corner-radius, elevation, icon-size, control-height, and content-width rules where repetition exists.
7. Define standard states for reusable components: normal, pressed, disabled, loading, error, success, and selected.
8. Define illustration/character color ownership separately from UI theme colors.

### Required principle

**Palette is independent from brightness mode.**

The existing conceptual palettes remain:

- Midnight Slate
- Deep Forest
- OLED Pitch

Each receives Light and Dark variants.

Brightness mode is independently selected as:

- System
- Light
- Dark

### Gate 1

**Semantic design-system contract exists, is internally consistent, and does not require widgets to know raw color values.**

---

# Phase 2 — Material 3 Theme Engine

**Status: COMPLETE** — six-scheme matrix live via `ColorScheme.fromSeed` (light and dark both derived, not hand-authored) with `copyWith` for brand slots; `theme`/`darkTheme`/`themeMode` wired in `main.dart`; palette + mode persisted through `ThemePreference` (`theme_preference_v1`, `theme_mode_v1`); component themes centralized for AppBar, NavigationBar, Cards, Dialogs, Bottom sheets, SnackBars, Chips, Inputs, Switch/Checkbox/Radio, Progress, List tiles, Dividers. Uses the 3.32+ `*ThemeData` types. Commit `d336873adea`.

### Objective
Implement the complete theme architecture before mass migration.

### Theme matrix

Support:

- Midnight Slate / Light
- Midnight Slate / Dark
- Deep Forest / Light
- Deep Forest / Dark
- OLED Pitch / Light
- OLED Pitch / Dark

and resolve `System` brightness through the device platform setting.

### Tasks

1. Preserve and extend the existing Riverpod theme-selection mechanism.
2. Implement light and dark `ColorScheme`s for all three palettes.
3. Wire `theme`, `darkTheme`, and `themeMode` correctly into `MaterialApp`.
4. Persist palette and brightness selections through the existing persistence mechanism.
5. Centralize Material component themes for:
   - AppBar
   - NavigationBar
   - FloatingActionButton
   - Buttons
   - Cards
   - Dialogs
   - Bottom sheets
   - SnackBars
   - Chips
   - Inputs
   - Switch/Checkbox/Radio
   - Progress indicators
   - List tiles/dividers
6. Audit surface/container roles so cards, sheets, dialogs, and navigation do not collapse into indistinguishable backgrounds.
7. Verify theme changes survive app restart.

### Gate 2

**All six palette/brightness combinations render without crashes, obvious contrast defects, or persistence regressions.**

---

# Phase 3 — Controlled Color & Styling Migration

**Status: COMPLETE** — every raw literal outside the token file is gone. Raw `Color(0x…)` counts went 875 -> 0 outside the allowlist; `python tools/verify_no_hardcoded_colors.py` is the standing gate (exit 0). Classification honored: theme UI -> `colorScheme`; domain scales (mood, raid outcome, star category, monster) -> named `AppColors` tokens so they stay brightness-independent; Zoom blue -> `AppColors.brandZoom`; the two `CustomPainter`s (`wellness_wheel_widget`, `constellation_canvas_3d`) take injected colors compared in `shouldRepaint` because `paint()` has no `BuildContext`; redundant per-screen AppBar overrides were deleted so the centralized `appBarTheme` is the single source of truth. Avatar/illustration palettes remain theme-independent by design. Commits `94b35d6b55a`, `5529fe1e97e`, `963f47de1c3`, plus the completion batch.

### Objective
Migrate the existing UI without destroying intentional artwork or brand styling.

### Classification rules

Every hardcoded color belongs to one of these classes:

1. **Theme UI color** → migrate to `ColorScheme`/semantic token.
2. **Semantic status color** → migrate to semantic status token.
3. **Brand color** → retain as an explicit brand constant when appropriate.
4. **Illustration/artwork color** → retain or create a dedicated illustration palette.
5. **Asset-internal color** → do not modify merely because it is not theme-aware.
6. **Accidental accessibility/color literal** → replace with the correct semantic role.

### Priority targets

Audit the known high-density files first, including:

- `settings_screen.dart`
- `avatar_painter.dart`
- `onboarding_screen.dart`
- `themed_background.dart`

Also audit:

- AppBars with `Colors.white`
- SnackBars with hardcoded backgrounds
- dialogs/bottom sheets
- disabled-state colors
- icon colors
- divider/border colors
- gradients and opacity assumptions

### Special rule: Avatar Painter

Do not force avatar species, aura, clothing, or illustration colors through the Material color scheme. Define intentional mappings that remain legible in both light and dark environments.

### Gate 3

**Theme-dependent UI no longer relies on accidental raw color literals, while intentional brand/illustration colors remain intact.**

---

# Phase 4 — Reusable UI Component System

**Status: COMPLETE** — five primitives shipped in `lib/widgets/app_primitives.dart`, each built only where the pattern was already repeated: `AppCard` (67 `Border.all` card surfaces across 30 files), `AppSectionHeader` (40 bold-title ladders; 11 in `settings_screen.dart` alone), `AppLoadingState` (31 spinners across 23 files), `AppEmptyState` (52 empty-state blocks across 29 files), `AppActionTile`. Every primitive consumes `ColorScheme` + `AppSpacing`/`AppRadii`/`AppType`, so it is correct in both brightness modes with no per-screen override. `AppSectionHeader` deliberately renders at 18/w700 to match the dominant existing convention rather than restyle shipped screens. Adopted in `memory_wall_screen.dart` (event cards + empty state) and `settings_screen.dart` (11 section headers). `test/app_primitives_test.dart` covers render-in-both-modes, the tap and disabled contracts, and the 6-cell palette x brightness matrix. The other eight candidate primitives were **not** built: `AppPrimaryButton`/`AppSecondaryButton`/`AppIconButton`/`AppStatusChip` would only wrap Material widgets that the centralized component themes already style, `AppAvatar` already exists, and `AppMetricCard`/`AppHeader` had no demonstrated repetition. That exclusion is the "no unnecessary abstraction layer" half of this gate. 9 new tests (189 -> 198).

### Objective
Create enough shared primitives to make the application visually coherent without creating an over-engineered component framework.

### Candidate primitives

Use only where repetition justifies abstraction:

- AppCard
- AppSection
- AppHeader
- AppPrimaryButton
- AppSecondaryButton
- AppIconButton
- AppStatusChip
- AppMetricCard
- AppActionTile
- AppAvatar
- AppLoadingState
- AppEmptyState
- AppErrorState

### Rules

- Abstract repeated visual/behavioral patterns, not every `Container`.
- Prefer existing Material widgets when a custom wrapper adds no value.
- Shared components consume semantic theme tokens rather than local hardcoded styling.
- Do not change domain behavior while standardizing presentation.

### Gate 4

**Repeated UI patterns have a consistent visual language and component behavior, with no unnecessary abstraction layer.**

# Phase 5 — Brightness Drain: Retire the Dark-Pinned Statics

**Status: COMPLETE** — all 390 references to the dark-pinned top-level constants across 31 files were drained to scheme slots (`accent -> primary`, `textMuted -> onSurfaceVariant`, `bgCard -> surfaceContainer`, `success -> tertiary`, `border -> outlineVariant`, `textDim/textHint -> outline`, `textPrimary -> onSurface`, `bgDeep -> surface`, `danger -> error`), then the constants were **deleted** from `AppColors` so the mistake cannot recur. `AppColors.scrim()` was re-signatured to take the surface from the active scheme instead of assuming a dark backdrop. 113 `const` keywords invalidated by theme injection were removed and 19 now-unused `app_colors.dart` imports dropped. The domain-scoped tokens (`mood*`, `raid*`, `star*`, `fellow*`, `pin*`, `housing*`, `starfield`, `brandZoom`, `monsterHound`, `accentSky`, `dangerSoft`, `pink`) were deliberately **kept** — they encode meaning that must not shift with brightness. `tools/verify_no_hardcoded_colors.py` now also fails on any reference to a retired name (verified against a synthetic regression), and an independent sweep confirms zero leftover references and zero re-introduced dark literals. **Light mode is now real across every touched screen, not partially real.**

### Objective
Make light mode real. Phase 3 removed raw literals; this removes the semantic
equivalent that the literal gate cannot see.

### Tasks
1. Map each dark-pinned top-level constant to its scheme slot:
   `accent -> primary`, `success -> tertiary`, `danger -> error`,
   `bgDeep -> surface`, `bgCard -> surfaceContainer`, `border -> outlineVariant`,
   `textPrimary -> onSurface`, `textMuted -> onSurfaceVariant`,
   `textDim -> outline`, `textHint -> outline`.
2. Replace all 398 references across 32 files, in dependency order: leaf widgets
   and services first, then screens, then the dashboard.
3. Keep genuinely domain-scoped constants (`star*`, `mood*`, `fellow*`, `pin*`,
   `housing*`, `raid*`, `brandZoom`, `monsterHound`, `starfield`) as tokens —
   they are brightness-independent by design and must NOT be drained.
4. Delete the drained top-level constants from `AppColors` so the mistake cannot
   recur, and leave a short comment pointing at the scheme slots.
5. Extend `tools/verify_no_hardcoded_colors.py` to also fail on any reference to a
   drained constant, with the domain allowlist enumerated.

### Gate 5
**No file outside `app_colors.dart` references a dark-pinned constant; the
extended color gate is green; light and dark both render for every touched
screen.**

---

---

# Phase 6 — Empty, Loading, Error & Offline UX

**Status: COMPLETE** — two more primitives added to `app_primitives.dart`: `AppErrorState` (title/message/optional retry; copy never blames the user) and `AppOfflineState` (deliberately distinct from the error state, because locally cached data is still on screen — the copy says so). Adopted: `journal_screen.dart` empty state, `constellation_screen.dart` empty sky + loading, `meeting_map_screen.dart` load failure now uses `AppErrorState` with a real retry wired to `_load`. Offline is now a first-class, distinguished condition: `MeetingFinderService.isCacheStale()` was added (missing or older than the 24h `cacheTtl`) so stale network data can be surfaced as an offline affordance instead of silently looking fresh. 3 new tests (198 -> 201). Phase 4's candidates `AppMetricCard`/`AppHeader` remain unbuilt — still no demonstrated repetition.

### Objective
Eliminate unfinished-feeling states throughout the primary product surfaces.

Major screens should intentionally define:

- loading
- empty
- error
- ready
- refreshing
- unavailable/offline where relevant

Do not fabricate offline functionality; distinguish unavailable network data from locally available state.

### Gate 13 (now 6)

**Primary screens no longer expose accidental blank/error/loading states.**

---

# Phase 7 — Dashboard State Decomposition

### Objective
Separate dashboard state from the 1,600-line presentation monolith before extracting major views.

### Required sequence

1. Inventory every `_DashboardScreenState` field.
2. Classify each field by ownership.
3. Extract persisted preferences into the existing Riverpod architecture.
4. Extract async/domain state into focused providers/notifiers.
5. Extract derived state into computed providers where appropriate.
6. Keep ephemeral interaction state local.
7. Isolate navigation state from domain state.
8. Isolate SOS state and tutorial state where justified.
9. Preserve existing meeting-radius and loader behavior.
10. Add focused tests around extracted state before removing old state.

### Prohibited shortcut

Do not merely split the 1,600-line file into multiple files while leaving all meaningful state coupled to one giant controller.

### Gate 5 (now 7)

**Dashboard behavior is equivalent to baseline, while state ownership is explicit and independently testable.**

---

# Phase 8 — Dashboard View Reconstruction

### Objective
Turn the dashboard into composable product surfaces after state has been decoupled.

### Target conceptual structure

- Companion
  - greeting
  - companion/avatar
  - current state
  - encouragement
- Recovery Path
  - pledge
  - current path
  - next action
  - milestones
- Meetings / Support
  - nearby meetings
  - radius controls
  - meeting actions
- Tools
  - recovery tools
  - resources
  - quick actions
- SOS

The exact content must be derived from the current application. Do not invent new domain functionality under this phase.

### Tasks

1. Extract the pledge card into a proper component.
2. Preserve and improve existing `_ToolCard` and `_SosTile` where justified.
3. Extract logical dashboard sections.
4. Establish consistent section headers, spacing, hierarchy, and card treatment.
5. Implement loading/empty/error states deliberately.
6. Ensure dashboard works at large text sizes and small screens.

### Gate 6 (now 8)

**Dashboard is modular, visually coherent, responsive, and behaviorally equivalent to baseline.**

---

# Phase 9 — Navigation Architecture

### Objective
Move toward a four-destination product architecture without losing existing routes or state.

### Target destinations

- Companion
- Path
- Library
- Profile

### Tasks

1. Determine the correct root navigation structure from the existing routing implementation.
2. Promote the Pet/Companion experience to a first-class destination without duplicating its state.
3. Keep Path focused on the recovery journey.
4. Keep Library focused on resources/content/tools.
5. Transform Settings into the appropriate Profile/settings experience rather than duplicating settings.
6. Preserve nested routes where they improve back-stack behavior.
7. Verify Android back behavior.
8. Verify tab state preservation.
9. Verify deep-link/route entry points where they already exist.
10. Verify safe-area and keyboard behavior.

### Gate 7 (now 9)

**Four-destination navigation works without route duplication, lost state, broken back behavior, or inaccessible destinations.**

---

# Phase 10 — Global SOS Experience

### Objective
Make SOS immediately discoverable and consistent across the application.

### Rules

- Reuse the existing `_showSosSheet` behavior.
- Do not create a second SOS implementation.
- SOS must remain available independently of the selected primary destination.
- Do not obscure or collide with `NavigationBar`.

### Audit

- FAB placement
- label/icon clarity
- color and contrast
- touch target
- animation
- bottom-sheet hierarchy
- Sponsor access
- 988 access
- Meetings access
- Resources access
- dismissal behavior
- accidental activation
- screen-reader semantics

### Gate 8 (now 10)

**SOS is globally discoverable, accessible, and behaviorally equivalent to the existing implementation.**

---

# Phase 11 — Profile / Settings Modernization

### Objective
Turn Settings into a coherent control center.

### Organize existing functionality under logical groups such as

- Recovery identity
- Companion
- Appearance
- Notifications
- Accessibility
- Recovery preferences
- Privacy
- About
- Support

Do not invent settings that the application does not currently support.

### Appearance controls

Provide independent controls for:

- Theme Mode: System / Light / Dark
- Color Palette: Midnight Slate / Deep Forest / OLED Pitch

### Gate 9 (now 11)

**All existing settings remain accessible, persistence remains correct, and the screen has a coherent information hierarchy.**

---

# Phase 12 — Accessibility Engineering

### Objective
Turn accessibility into measurable acceptance criteria.

### Requirements

Audit and test:

- text contrast
- icon/control contrast
- minimum 48×48 touch targets
- semantic labels
- semantic roles
- traversal order
- dynamic text scaling
- text clipping/overflow
- screen-reader behavior
- dialogs/bottom sheets
- disabled controls
- focus behavior where applicable
- reduced-motion considerations

### Text-scale matrix

At minimum validate normal, enlarged, and maximum practical accessibility text sizes supported by the app/device.

### Gate 10 (now 12)

**No major accessibility regressions remain, and high-risk screens have explicit widget/accessibility coverage.**

---

# Phase 13 — Responsive & Device Hardening

### Objective
Prevent the polished design from only working at one phone size.

Validate:

- small Android phone
- normal phone
- large phone
- tablet where supported
- portrait
- landscape where supported
- display scaling
- large text
- keyboard-visible states
- safe areas

Audit for:

- overflow
- clipped text
- FAB/navigation collisions
- bottom-sheet layout failures
- cramped cards
- excessive whitespace
- inaccessible controls

### Gate 11 (now 13)

**Primary user journeys remain usable across supported form factors and accessibility settings.**

---

# Phase 14 — Motion & Microinteraction System

### Objective
Add restrained, meaningful motion that makes the product feel finished without becoming distracting.

### Candidates

- navigation transitions
- card/state transitions
- milestone completion
- companion reactions
- loading transitions
- bottom-sheet transitions
- button feedback
- success/error state transitions

### Rules

- Motion communicates state or hierarchy.
- Avoid gratuitous animation.
- Respect accessibility/reduced-motion expectations where applicable.
- Do not introduce animation dependencies unless existing dependencies cannot reasonably support the behavior.

### Gate 12 (now 14)

**Motion is consistent, performant, purposeful, and does not impair accessibility or existing behavior.**

---

# Phase 15 — Visual Regression & Theme Matrix

### Objective
Lock the visual system after it stabilizes.

### Theme matrix

Validate all six explicit combinations:

- Midnight Slate / Light
- Midnight Slate / Dark
- Deep Forest / Light
- Deep Forest / Dark
- OLED Pitch / Light
- OLED Pitch / Dark

Also validate System mode under both device brightness settings.

### Critical surfaces

Capture/test:

- Companion
- Path
- Library
- Profile
- Settings sections
- dashboard states
- SOS
- dialogs
- bottom sheets
- onboarding
- major empty/loading/error states

Use golden tests where stable visual regression provides real value; do not create brittle golden coverage for inherently dynamic content.

### Gate 14 (now 15)

**Approved visual baselines are stable across the supported theme matrix with no unexplained changes.**

---

# Phase 16 — Final Architecture & Repository Hardening

### Objective
Remove migration debris and verify the final architecture.

### Audit searches

Review remaining instances of:

- `Color(0x...)`
- `Colors.white`
- `Colors.black`
- direct theme overrides
- duplicate theme definitions
- duplicate navigation logic
- duplicate SOS logic
- stale compatibility adapters
- feature flags introduced only for migration
- TODO/FIXME items created by this program
- unused imports/dependencies

### Required cleanup

1. Remove temporary migration scaffolding whose removal conditions have been met.
2. Remove dead code.
3. Remove duplicate styling systems.
4. Verify theme ownership is obvious to future maintainers.
5. Verify dashboard state ownership is obvious.
6. Verify navigation ownership is obvious.

### Gate 15 (now 16)

**The finished architecture is simpler to maintain than the starting architecture, not merely different.**

---

# Phase 17 — Final Verification & Beta Gate

### Required verification

Run the project's approved analysis/test commands, including:

```text
flutter analyze --no-pub
flutter test
```

Do not substitute build commands unless the execution environment and project workflow explicitly authorize them.

### Regression matrix

Verify:

- System theme
- Light theme
- Dark theme
- all three palettes
- all four primary destinations
- dashboard
- companion
- recovery path
- library
- profile/settings
- SOS
- meetings
- sponsor functionality
- existing recovery functionality
- persistence after restart
- large text
- accessibility semantics
- portrait/landscape where supported
- offline/unavailable states where applicable

### Final gate

All tests pass, analysis is clean, no unexplained visual changes remain, and no existing beta-critical behavior is broken.

---

# Autonomous Execution Protocol for Muse Spark 1.3

Muse Spark must execute the phases sequentially and must not silently skip gates.

For each phase:

1. **READ** — inspect relevant current files and existing architecture.
2. **RECONCILE** — compare repository reality with this blueprint.
3. **PLAN** — identify the smallest coherent implementation slice.
4. **IMPLEMENT** — change only the authorized scope.
5. **ANALYZE** — run the approved static analysis.
6. **TEST** — run relevant focused tests, then the full suite at phase gates.
7. **REVIEW** — inspect the diff for unrelated changes, duplication, regressions, and architectural drift.
8. **VERIFY** — explicitly evaluate the phase gate.
9. **REPORT** — summarize changed files, tests, gate result, and any unresolved issue.

## Stop Conditions

Muse Spark must stop and report rather than guess when:

- a blueprint assumption contradicts the repository and the correct interpretation is unclear;
- an existing behavior cannot be preserved with the planned architecture;
- tests expose an unrelated pre-existing failure that blocks meaningful verification;
- a requested change requires a new dependency or platform capability not justified by the blueprint;
- a migration would require destructive data/state changes;
- a visual change would alter recovery-domain semantics;
- a phase gate cannot be honestly satisfied.

## Change Discipline

- Do not rewrite unrelated files.
- Do not rename public APIs without necessity.
- Do not replace Riverpod with another state system.
- Do not replace the existing routing system merely for stylistic preference.
- Do not introduce a design-system package when local project architecture is sufficient.
- Do not add dependencies when Flutter/Dart or existing dependencies can solve the problem cleanly.
- Do not delete tests merely because they conflict with the new architecture; migrate them to the new contract.
- Do not weaken assertions to make tests pass.
- Do not modify production recovery logic during a visual-only migration.

## Completion Standard

The program is complete when Recovery for All has:

1. a semantic Material 3 design system;
2. independent palette and brightness selection;
3. robust Light/Dark/System support;
4. intentional illustration/brand color handling;
5. centralized component styling;
6. modular dashboard state and views;
7. coherent Companion / Path / Library / Profile navigation;
8. one globally accessible SOS experience;
9. modernized Profile/Settings;
10. measurable accessibility compliance;
11. responsive behavior across supported devices;
12. intentional loading/empty/error states;
13. restrained, consistent motion;
14. visual regression coverage for the stable design system;
15. clean analysis/tests and no migration debris.

**The desired result is not merely a lighter version of the existing dark UI. It is a cohesive Recovery for All product experience whose visual system, navigation, state architecture, accessibility, and interaction patterns are consistent enough to support future feature development without repeating the current fragmentation.**
