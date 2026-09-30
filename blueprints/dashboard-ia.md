# Dashboard IA — Four Destinations + Modular Tiles

> **§1 (two tabs) is HISTORICAL as of Phase 9 (Sep 30, 2026).** The app ships
> Companion / Path / Library / Profile in a `NavigationBar` shell. Read §6 for
> what actually ships; §1 is kept below for the original rationale.
## Status: ACTIVE SPEC (August 25, 2026)
## Doctrine: safety never moves (SOS FAB global) · tailoring decides WHAT
## is visible, user order decides WHERE · heroes stay anchored.

---

## 1 · Two-tab structure

`NavigationBar`: **Path** | **Library**

| Tab | Contents |
|---|---|
| **Path** (recovery core) | Constellation crown, pledge card, path badges, pet card, gentle-quest card, **Tools-only** grid |
| **Library** (reference & help) | Literature Library, Community Support, Native Resources, Sober Housing, Crisis & Help Lines — as its own grid, same tile style |

- SOS FloatingActionButton renders on BOTH tabs — always one tap away.
- Toolbox card classification: resource-type cards (literature/community/
  native/housing) move to Library; everything else stays a Path tool.

## 2 · Modular tiles (drag + hide)

- Mechanism: `LongPressDraggable` + `DragTarget` per tile; drop reorders
  the backing list. No third-party package (own ~200 lines beats adopting
  unmaintained wrappers — lessons-learned L5 cousin).
- Persistence: prefs `dashboard_tool_order_v1` = JSON array of card IDs.
  Merge rule: display order = savedOrder ∩ availableCards; new/unlocked
  cards append at the end. Same mechanism reused by Library grid
  (`library_order_v1`).
- Edit mode: pencil icon per tab → tiles get eye toggles (hide/show) +
  drag handles become explicit; "Done" exits.
- Hide rules: any card hideable EXCEPT Meeting Finder (Path) — and SOS is
  not a tile at all. Hidden cards live in an "Hidden" tray inside edit
  mode for one-tap restore.
- Reset Layout: Settings row → clears both order keys + hidden sets.

## 3 · Anchored sections (NOT draggable)

Constellation crown, pledge card, pet card, quest card — the hero stack
stays fixed so the dashboard keeps composition instead of becoming a junk
drawer.

## 4 · Accessibility

Long-press drag is never the ONLY path: edit mode provides explicit
reorder via the same drag handles plus up/down would be redundant — the
edit-mode handle drag uses standard semantics with `Semantics` labels
("Reorder <card name>"), and hide/show gives a non-spatial alternative to
positioning. Reduce-motion: no lift-shadow animations.

## 5 · Implementation status (updated Sep 28, 2026)

The two-tab IA above is still what ships today. It is now implemented through
extracted, individually testable widgets instead of inline column trees, which
is the Phase 8 outcome. **No destination was added or moved.**

| Section | Widget | File |
|---|---|---|
| Constellation crown | `SkyCrown` | `lib/widgets/dashboard_sections.dart` |
| Pledge card | `PledgeCard` | `lib/widgets/dashboard_cards.dart` |
| Path badges | `PathChips` | `lib/widgets/dashboard_sections.dart` |
| Pet card + XP | `CompanionSection` | `lib/widgets/dashboard_sections.dart` |
| Next-meeting | `MeetingSpotlight` (wraps `NextMeetingCard`) | `lib/widgets/dashboard_sections.dart` |
| Toolbox / Library grid | `ToolGrid` + `ToolCard` | `lib/widgets/dashboard_sections.dart`, `dashboard_cards.dart` |
| SOS rows | `SosTile` | `lib/widgets/dashboard_cards.dart` |
| Fellowship / 7th Tradition | `SupportLinkRow` | `lib/widgets/dashboard_cards.dart` |

Rules that are now load-bearing, because a widget enforces them rather than
the dashboard happening to do the right thing:

- `SosTile` is the only SOS tile implementation. The SOS FAB renders from the
  navigation shell, so it is one tap away on all four destinations, and Phase
  10 did not add a second SOS surface.
- Section headers use the shared `AppSectionHeader` primitive.
- `ToolGrid` renders a real empty state. If every tool is hidden it explains
  that hiding is not deleting and offers "Restore all" — the grid no longer
  collapses to nothing silently. This closes the §2 hidden-tray gap that
  existed only while in edit mode.
- `MeetingSpotlight` distinguishes waiting, error, and genuinely-empty. The
  dashboard no longer shows "No meetings in the next 6 hours" while the cache
  is still being read.
- `ToolCard` scales its copy down inside the fixed 1.35-ratio grid cell, so the
  grid holds at large accessibility text sizes.

**Coming next:** nothing. The UI/UX program is complete — see below.

---

## 6 · SUPERSEDED by Phase 9 (Sep 30, 2026)

**§1 above (two tabs) is now HISTORICAL. The app ships FOUR destinations.**
Phase 9 of `UI-UX-themes-plan.md` replaced the Path/Library tab pair with a
`NavigationBar` shell in `lib/core/dashboard_providers.dart`:

```dart
enum DashboardDestination { companion, path, library, profile }
```

| Destination | Body | Notes |
|---|---|---|
| Companion | `PetHomeScreen` | pet state read from `dashboardDataProvider`; the old duplicate "Companion Home" toolbox card was removed |
| Path | constellation + pledge + paths + meetings | the old Path tab |
| Library | toolbox grid | the old Library tab |
| Profile | `SettingsScreen` | promoted in place, NOT duplicated |

The shell uses an `IndexedStack`, so every destination stays alive. That has
one sharp consequence worth remembering: **a persistent body never re-reads
state in `initState`.** Profile reloads through
`GlobalKey<SettingsScreenState>` and an explicit `refreshState()` call when its
destination is selected. A second `initState`-only reload is a bug.

Android back is handled by `PopScope`: from any destination it returns to Path,
and from Path it calls `SystemNavigator.pop()`.

§1's "SOS FAB renders on BOTH tabs" remains true in spirit and is now stronger:
the FAB lives in the shell, so SOS is exactly one tap away on **all four**
destinations. `tools/verify_invariants.py` fails if a `NavigationBar`-owning
screen exists but never *calls* `_showSosSheet` — a live definition with no
caller is not a reachable SOS.

### Load-bearing rules added after Phase 9

- **Pet state has exactly one owner**, `dashboardDataProvider`. Never re-add a
  private `_pet` field or a second `ensureHatched()` call in a screen. Before
  Phase 9, `pet_home_screen` and `dashboard_providers` each loaded the pet
  independently, which would have gone stale the moment Companion became a
  destination.
- **`DashboardDestination` is the single source of truth** for both the
  destination list and the Android back target. Adding a destination anywhere
  else is the failure mode to avoid.
- `SosTile`, `ToolCard` and `SupportLinkRow` now use `excludeSemantics: true`
  (each repeating `onTap`), because a curated `Semantics` label is otherwise
  *concatenated* with the child's own text and screen readers announce every
  card twice. **`CompanionSection` must NOT do this** — `RecoveryPetCard`
  contains an `InkWell` plus two real buttons, and excluding them would make
  check-in and walk unreachable.
- `CompanionSection` hides its "Tap for Skill Tree" hint above a 1.3x text
  scale. It is a non-flexible `Row` child and overflowed at 2.0x on a 320dp
  screen; the level/XP text is the essential part and keeps its space.
