# WO-1D — Companion, Constellation and Consistent Reward Feedback

## Intent

One action should produce one user-understandable outcome across Pet, XP, Sparks, Raid, Skill tree and Constellation, without independent services disagreeing or double-granting.

## Existing targets and proposed changes

| Existing path | Change |
|---|---|
| `lib/services/recovery_pet_service.dart` | feed new post-cutover rewards from `RewardReceipt`; preserve level formula and cosmetics until economy owner decision; protect no-guilt resting semantics |
| `lib/services/constellation_service.dart` | accept stable action ID and projection checkpoint, preserve old star IDs; no duplicate star on process recreation |
| `lib/screens/constellation_screen.dart` + `constellation_canvas_3d.dart` | surface private story/meaning; avoid publicly revealing activity type and when sharing shapes |
| `lib/screens/pet_home_screen.dart` + `lib/widgets/recovery_pet_card.dart` | one receipt-driven celebration message; accessible labels for all effects |
| `lib/widgets/skill_tree_modal.dart` + dashboard providers | single live projection source, no duplicated pet loads or stale IndexedStack state |
| `lib/services/data_export_service.dart` | private and consented export: rewards with redaction and date precision options, no raw location paths |

## Projection handling

Commit action + ledger locally. `PendingProjection(eventId, projectionName)` records incomplete derived effects such as star creation. Each projector is idempotent keyed on stable event ID, can safely re-run after crash, and exposes a human-friendly consolidated summary. Keep `RaidService` victory grant logic compatible with this idempotence model.

**Example:** locally log an accepted meeting reflection -> award only the approved action XP, attach a star with a local title, update applicable daily quest. Do not separately award 'travel arrived', 'GPS check-in', and 'signed attendance' for the same user-entered meeting when all are different evidence for a single underlying action.

## Opt-out and safety

When no-game mode enabled, hide game surfaces, disable game sounds/haptics/quest prompts and continue storing the user's actual recovery actions only if still required for the feature; no compulsory rewards or pet activity. User can return later; no penalty for disabling. `Reduced motion` disables shakes, flashes, and nonessential animation but leaves readable results.

## Acceptance

100 repeats of a meeting/check-in/battle yield 1 permitted award + 1 star where designed. Out-of-order projector restarts converge without leaking events; opt-out bypasses visuals and notifications; no content of journal or Circle message appears in share cards unless individually selected and previewed. Existing cosmetic inventory and mood survive migration.
