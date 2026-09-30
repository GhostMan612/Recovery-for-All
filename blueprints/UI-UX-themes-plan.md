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

Phases 0-16 are **implemented**. Phase 17 is **the verification gate itself**
and is satisfied only by the commands in the Completion Standard.

| Phase | State | Evidence |
|---|---|---|
| 0 - Baseline & recon | COMPLETE | analyze clean, suite 167 -> 179 |
| 1 - Semantic design system | COMPLETE | spacing/radii/type/state tokens + 3 palettes x 2 brightness |
| 2 - M3 theme engine | COMPLETE | 6-scheme matrix, `themeMode` wired, persistence, centralized component themes |
| 3 - Color & styling migration | COMPLETE | 875 -> 0 raw literals outside allowlist; `tools/verify_no_hardcoded_colors.py` green |
| 4 - Reusable UI components | COMPLETE | 5 primitives + 11 headers + memory-wall adoption, 9 new tests |
| 5 - Brightness drain | COMPLETE | 390 dark-pinned refs -> 0, constants deleted, gate extended |
| 6 - Empty/loading/error/offline | COMPLETE | `AppErrorState` + `AppOfflineState`, 3 screens adopted, `isCacheStale()` |
| 7 - Dashboard state | COMPLETE | 5 notifiers, 22 fields -> 3, `ConsumerState`, 18 tests, fixed duplicate-DB |
| 8 - Dashboard view reconstruction | COMPLETE | 4 slices, screen 1512 -> 1157 lines, 28 new tests, 3 real bugs fixed |
| 9 - Navigation architecture | COMPLETE | 3 slices: 4 destinations, `IndexedStack`, `PopScope`, Settings reload, pet state unified, 7 tests |
| 10 - Global SOS experience | COMPLETE | audit only: dismiss button, care-alert moved to real activation, header overflow, sheet semantics |
| 11 - Profile / settings | COMPLETE | grouped sections already conformed; added the missing System/Light/Dark mode control |
| 12 - Accessibility engineering | VERIFIED | 13 new tests in `test/accessibility_contracts_test.dart`; found and fixed a real double-announcement defect |
| 13 - Responsive hardening | VERIFIED | onboarding overflow fixes; `test/theme_matrix_test.dart` sweeps 4 form factors x 3 text scales |
| 14 - Motion system | VERIFIED | `core/motion/app_motion.dart`; 5 read sites consolidated; onboarding transition now respects reduce-motion |
| 15 - Theme matrix | VERIFIED | 3 palettes x 2 brightness rendered; one real palette finding recorded below |
| 16 - Architecture hardening | VERIFIED | audit clean; invariant 6 added so the motion policy cannot fragment again |
| 17 - Final verification | VERIFIED | analyze clean, 292 tests, both Python gates exit 0 |

### Phase 12-17: what each phase actually found

The late phases were mostly **consolidation and coverage**, not new UI. That is
the honest summary, and three of them found real defects anyway.

**Phase 12.** The audit had already fixed the high-severity set; almost none
of it was protected by a test, and a `Semantics` wrapper is exactly the kind
of change a later refactor deletes as redundant. The new test file pins the
contracts (button role, disabled state, combined labels, the wellness wheel's
six dimensions) so they cannot be lost silently.

**Phase 12/13 - onboarding had no position indicator at all.** Seven steps
behind a non-scrollable `PageView`, and nothing anywhere said which step you
were on or how many remained. A sighted user could infer it; a screen-reader
user could not even discover that the flow had more pages. Now announced.

**Phase 13.** Three real overflow risks, all found by writing the matrix rather
than by reading: the "Initialize Platform" button, three paired slider
end-labels, and - the worst - `CompanionSection`'s "Tap for Skill Tree" hint,
which is a NON-flexible child of a `Row` and so was laid out at intrinsic width
before the `Expanded` level text received any space. At 2.0x on a 320dp screen
that row needed ~450dp in 292dp. The hint now steps aside above 1.3x; the
essential level and XP stay, and the Semantics label already announced
"Open Skill Tree" regardless.

**Phase 14.** The reduce-motion decision was being made in five places. Each
was individually correct, which is precisely why it drifted. Consolidated into
`core/motion/app_motion.dart`; `themed_background.appReduceMotion` now
delegates so its four existing callers are unchanged. The one behavioural
change: onboarding's page transition animated for users who had turned
animations off. `HardwareTierService.isLowEnd` is deliberately NOT folded in -
"should this move?" and "can this device afford to animate?" are different
questions, and they stay OR-ed at the call sites.

**Phase 15 - a real palette finding.** `midnightSlate` and `oledPitch` share
the same accent (`0xFF38BDF8`), and light mode is generated from the seed
accent, so **those two palettes are indistinguishable while light**. Dark mode
is unaffected (each copies its own `bgDeep` into `surface`). This is a property
of the palettes as designed, not a regression, and it was only discoverable by
actually running the matrix. It is asserted in the test so it cannot change
silently. Changing the palettes is out of scope for this program.

No goldens were written. These surfaces are animated, Lottie-backed and
device-dependent, so a pixel baseline would be brittle and would fail for
reasons unrelated to the design system. Overflow is asserted the honest way
instead: a `RenderFlex` overflow is a `FlutterError`, so `tester.takeException()`
being null *is* the assertion.

**Phase 16.** The audit searches came back clean: `ThemeData(` is constructed
in exactly one file, `ColorScheme.fromSeed` likewise, and there is no duplicate
navigation or SOS logic (invariants 2 and 6 now enforce the latter). The two
`TODO`s in `gguf_model_service.dart` are pre-existing download-verification
work, not debris from this program. The substantive addition is invariant 6,
which fails the build if the motion setting is ever read outside the policy
file again.

Gates at the close of this program: `flutter analyze --no-pub` -> No issues
found; `flutter test` -> **292 passing** (was 254, +38 from the three new files);
`verify_no_hardcoded_colors.py` -> exit 0; `verify_invariants.py` -> exit 0 (six
invariants).

**And the closing gate earned its keep.** The final full run failed 12 tests in
`test/accessibility_contracts_test.dart` — every tree-walking assertion in the
file, throwing "Null check operator used on a null value" on the *harness*,
not on any widget. All 12 assertions read the semantics tree off the wrong
`PipelineOwner`:

- `binding.rootPipelineOwner.semanticsOwner` is **null** in a widget test. Each
  `View` hangs its own `PipelineOwner` off the root, and *that* is the one
  holding the `SemanticsOwner`.
- `binding.pipelineOwner` is a **separate legacy instance**, not an alias for
  the root. It works by accident, and it is what the framework's docs
  recommended for years — which is precisely what made it a trap.

The correct expression, taken from `flutter_test/lib/src/finders.dart`, is
`tester.binding.renderViews`' `owner!.semanticsOwner!.rootSemanticsNode!`.
The widgets, the labels and the a11y fixes were all correct; only the
accessor was wrong, and only the full run could have shown that. Recorded as
**L20** in `lessons-learned.md`. Suite is green again at 292/292.

### Phase 8 breakdown (all four slices committed)

The dashboard screen went from 1512 lines to 1157 by extracting its view
vocabulary, without changing behavior. State ownership stayed in
`dashboard_providers.dart` throughout; every extracted widget is
presentational and takes plain values plus callbacks.

| Slice | Extracted to | Notes |
|---|---|---|
| 1 | `widgets/dashboard_cards.dart` | `PledgeCard`, `ToolCard` |
| 2 | `widgets/dashboard_cards.dart` | `SosTile`, `SupportLinkRow`, `AppSectionHeader` adoption |
| 3 | `widgets/dashboard_sections.dart` | `PathChips`, `MeetingSpotlight`, `ToolGrid` |
| 4 | `widgets/dashboard_sections.dart` | `SkyCrown`, `CompanionSection` (pet + XP) |

**Three real defects were found by tests, not by review.** These are the
reason the phase was worth doing incrementally:

1. **ToolCard overflowed its grid cell at every text scale.** The toolbox
   `GridView` uses a fixed `childAspectRatio: 1.35`, so the card's copy
   overflowed by 6px at scale 1.0, 34px at 1.5, and 61px at 2.0. Fixed with
   `Flexible` + `FittedBox(scaleDown)` around the label/subtitle block, which
   is a no-op at 1.0. Guarded by tests at all three scales.
2. **The meeting card lied while loading.** The `FutureBuilder` used
   `snapshot.data ?? const []`, so a still-reading cache rendered "No
   meetings in the next 6 hours" - telling a user in a meeting-dense area
   that nothing was happening. `MeetingSpotlight` now separates waiting,
   error, and genuinely-empty. This closed the last open Phase 6 gap.
3. **Hiding every tool was a dead end.** The grid collapsed to zero height
   with no explanation and no way back. `ToolGrid` now explains that hiding
   is not deleting and offers "Restore all".

**Not changed, deliberately:** the two-tab Path/Library information
architecture is Phase 9's job. Phase 8 did not add or move a destination.

## Resume Here (program COMPLETE — Phases 0-17, all gates green)

**Nothing is left to build. The verification batch has been run and the suite
is green at 292/292.** The one thing worth carrying forward is *how* the
closing run earned its keep: it failed 12 tests that had previously been
reported as passing, and the defect was in the test harness, not the app. See
L20 and the caveat block above.

### If you re-run the gates

```text
flutter analyze --no-pub
flutter test
python tools/verify_no_hardcoded_colors.py
python tools\verify_invariants.py
```

The three files added late in the program are the likely source of any future
failure, since they lean hardest on SDK behaviour rather than app behaviour:

- `test/accessibility_contracts_test.dart` - walks the **real** semantics tree
  and matches exact labels. The tree must be read off the per-`View` pipeline
  owner (`renderView.owner!.semanticsOwner!.rootSemanticsNode!`); the binding
  root owner has a null `semanticsOwner` in a widget test and throws. If a label
  is reworded, fix the test to the new copy rather than loosening the matcher —
  exact matching is what keeps each lookup resolving to one node.
- `test/theme_matrix_test.dart` - overflow-sensitive by design. A failure is a
  genuine responsive finding, not a bad test.
- `test/app_motion_test.dart` - pure policy, should be trivially green.

### Human-only, still outstanding

Phases 0-17 have never been rendered on a real device. Light mode, the
`HardwareTierService.isLowEnd` Lottie path (Blu View 5, 3 GB), every overflow
fix in Phase 13, and the whole a11y batch are verified only by the compiler and
widget tests. The audit found entire screens invisible in light mode — exactly
what tests cannot catch. Also outstanding: a fresh signed `1.0.0+9` AAB in
Android Studio, device smoke test, and Play versionCode 9 rollout.

## Re-Sequencing Rationale (Sep 28)

The original phase order had two dependency defects, found while executing:

1. **The dark-pinned `AppColors` statics were never scheduled for retirement.**
   Phase 3 banned `Color(0x...)` literals, but the old top-level constants
   (`AppColors.accent`, `.textMuted`, `.bgCard`, ...) are semantically the same
   thing — fixed dark values. The audit found ~398 references across 32 files
   still using them after Phase 3, so the literal gate alone did not make light
   mode real. This is cross-cutting: every later phase edits those files, so
   draining first means touching them once.
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
2. Replace every remaining reference (audit estimated ~398 across 32 files) in
   dependency order: leaf widgets and services first, then screens, then the
   dashboard.
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

**Status: COMPLETE** — every field in `_DashboardScreenState` was inventoried and classified, then lifted into `lib/core/dashboard_providers.dart` following the existing `ThemeNotifier` pattern. `DashboardScreen` went from 22 mutable fields to **3** (`_editingPath`, `_editingLibrary` — ephemeral by design — and `_selectedIndex`, which is navigation state and is isolated from the domain loaders) plus `_skyNodes`, a pure view model computed from the constellation stream. The widget shrank 1551 -> 1449 lines.

Extracted: `DashboardLayoutNotifier` (tool/library order + hidden sets, and it now owns the `_ordered` merge that used to be a private method), `MeetingRadiusNotifier`, `DailyPledgeNotifier`, `SkyNameNotifier`, and `DashboardDataNotifier` (profile + pet + raid, with the load order made explicit: pet before the XP bar, profile before the sponsor phone, and a raid lookup that is best-effort so a miss cannot block the dashboard). `DashboardScreen` is now a `ConsumerStatefulWidget`; `_loadUserData`, `_loadRadiusPrefs`, `_loadLayoutPrefs`, `_saveToolLayout`, `_saveLibraryLayout`, `_refreshPet`'s body and 4 static key constants were deleted. 18 tests (201 -> 219) cover ordering/hiding semantics, persistence round-trips under the **unchanged** key strings, and the profile-decode fallback so a corrupt profile cannot take down the dashboard.

**Latent bug found and fixed here:** `databaseProvider` was lazily constructing a SECOND `RecoveryDatabase` — a second SQLCipher connection to the same encrypted file, with its own key read — while `main.dart` built its own. Six providers watched it, so any of them coming alive would have opened that second connection. `main.dart` now overrides `databaseProvider` with the single instance, so the notifiers and the screens share one database.

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

### Standing override: batch verification at the end (user directive)

Steps 5 and 6 are **suspended for the duration of this program**. The user
directed, more than once, that no shell runs — `flutter analyze`,
`flutter test`, the Python gates, and git included — while working through the
phases, and that verification happens **once, when the whole plan is complete**.

This is not a shortcut, and it is not free. The consequence is that Phases
10-17 were written without a single local analyze or test run.

**And the predicted risk is exactly what happened — but not where predicted.**
The suspicion was that the three new test files would fail on *widget copy*:
exact semantics labels drifting from the widgets' current wording. Instead all
12 tree-walking assertions failed on the *harness*, throwing a null-check error
on a `PipelineOwner` that was never the one holding the `SemanticsOwner`. The
widgets and the labels were correct throughout. The false-confidence note
("this file passed 13/13") was itself the problem: it was inherited from an
earlier run and never re-checked, and reading the SDK source for the *other*
APIs did not mean the right owner had been identified.

The API facts that were checked, and are worth keeping:

- `SemanticsFlag` lives in `dart:ui` and is re-exported by
  `package:flutter/semantics.dart`; it is NOT provided by `material.dart`, so
  the explicit import is required and is not an `unnecessary_import`.
- `SemanticsNode.hasFlag` is DEPRECATED (after v3.32) and the analyzer fails
  the zero-issue gate on it. Use `node.flagsCollection.<flag>` instead. Note
  the types differ by flag: `isButton` and `isSlider` are `bool`, but
  `isEnabled` is a `Tristate`, so "not enabled" is
  `isNot(Tristate.isTrue)` rather than `isFalse`.
- `SemanticsNode` has `label`, `value`, `increasedValue` and `decreasedValue`,
  but **no** `hasAction` — that is on `SemanticsData`, so the assertion is
  `node.getSemanticsData().hasAction(SemanticsAction.tap)`.
- `find.bySemanticsLabel` compares a `String` pattern with `==` and a `RegExp`
  with `hasMatch`, and it reads `renderObject.debugSemantics` — which is not
  the node the platform sees. It is useless for these assertions.
- The semantics root is `tester.binding.renderViews`' per-view
  `owner!.semanticsOwner!.rootSemanticsNode!`. **Not** `binding.rootPipelineOwner`
  (whose `semanticsOwner` is null in a widget test) and **not** the deprecated
  `binding.pipelineOwner` (a separate legacy instance that works by accident).
  This is the same expression `flutter_test/lib/src/finders.dart` uses.
- A `SemanticsHandle` must be disposed in a `finally`, not via `addTearDown`:
  `flutter_test` verifies outstanding handles *before* tearDowns run, so the
  teardown route fails every test.
- `RecoveryPet`, `PetMoodX`, `SkyCrown`, `CompanionSection`, `SosTile`,
  `ToolCard` and `SupportLinkRow` were each read in source, and `_pet()` is
  byte-identical to the one in `dashboard_sections_test.dart`, which already
  renders that tree successfully on the host.

**The durable lesson, now that the gate has actually run:** "I read the source
first" is not a substitute for running the gate, and an inherited green result
is a claim, not a fact. When the whole verification budget is spent once at
the end, the first run is not a formality — it is the *only* run, and it must
be allowed to contradict what the notes say. See L19 and L20 in
`blueprints/lessons-learned.md`.

`AGENTS.md` carries the same directive. If the two documents ever disagree, the
user's instruction wins.

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

**On item 14.** The coverage is a rendered theme matrix plus overflow
assertions across form factors and text scales, not golden images. This is
deliberate and follows this plan's own instruction to "not create brittle
golden coverage for inherently dynamic content": the Companion and dashboard
surfaces are animated, Lottie-backed, and dependent on device memory tier and
`disableAnimations`, so a pixel baseline would churn for reasons that have
nothing to do with the design system. The matrix catches the failures that
matter here - a scheme that stops being distinct, and a layout that clips at a
real text scale - without pretending to be a screenshot test it cannot be.
Golden baselines remain the right tool the day a static, deterministic surface
exists to capture.

**The desired result is not merely a lighter version of the existing dark UI. It is a cohesive Recovery for All product experience whose visual system, navigation, state architecture, accessibility, and interaction patterns are consistent enough to support future feature development without repeating the current fragmentation.**
