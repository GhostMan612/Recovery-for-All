# Dashboard IA — Two Tabs + Modular Tiles
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

- `SosTile` is the only SOS tile implementation. The SOS FAB still renders on
  both tabs and Phase 10 will not add a second SOS surface.
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

**Coming next:** Phase 9 moves from two tabs to four destinations
(Companion, Path, Library, Profile) per `UI-UX-themes-plan.md`. That phase
supersedes §1 above; until it lands, §1 remains accurate. Companion must be
promoted without duplicating pet state, and Settings becomes Profile without
being duplicated.
