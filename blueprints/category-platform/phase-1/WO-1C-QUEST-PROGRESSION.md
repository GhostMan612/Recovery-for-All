# WO-1C — Recovery Journeys, Gentle Quests and Skill Tree

**Goal:** replace a shallow task checklist with a coherent but voluntary progression narrative that adapts to pathway, energy, accessibility and connectivity.

## Domain

- Quest definitions: stable `questDefinitionId`, version, title, intent, allowed action predicates, verification floor, expiry, max rewards, alternative actions, required consent (none by default), completion message and localized accessibility label.
- Quest instances: stable ID, start/day bucket, `planned/active/completed/skipped/paused`, selected alternative and local progress projection.
- Classes: **Daily gentle** (5-min grounding, gratitude, reflection), **Path journeys** (weeklong toolkit discovery), **Preparation** (save a meeting, prepare transit plan, pack support resources), **Community cooperation** (deferred Phase 3 after trusted Circle); all have solo equivalence.
- Verified travel and attendance: a planned journey may satisfy a *preparation quest*, not attendance. A user-entered attended meeting is self-reported; sponsor/co-attestation is a distinct provenance tier, not proof of abstinence or location.

## Proposed paths

- **NEW** `lib/features/quests/domain/quest_definition.dart`, `quest_instance.dart`, `quest_catalog.dart`.
- **NEW** `lib/features/quests/application/quest_progressor.dart` listening to committed P1 actions, never raw widget taps.
- **NEW** `lib/features/quests/ui/quest_journey_screen.dart`, `widgets/quest_progress_card.dart` if existing dashboard section cannot be reused.
- Reuse and adapt `lib/widgets/skill_tree_modal.dart`, `lib/widgets/recovery_pet_card.dart`, `lib/screens/pet_home_screen.dart`, and existing `RecoveryPetService.todayQuest()` instead of creating parallel XP systems.
- Add `test/quests/quest_progressor_test.dart`, `test/quests/quest_optout_test.dart`.

## Design and balancing

- No irreversible missed-day penalty, no XP deductions, no forced streak, no public progress rank.
- No inferred user addiction status, no diagnosing needs from journals, no cloud-based suggestions required.
- Quest 'difficulty' means *effort and time*, not level of disease or worthiness. Offer `gentle`, `standard`, `creative`, and quiet/no-game participation.
- Balanced predictable rewards capped by the central policy; once-only quest completion and per-reward cap. Meeting attendance and movement accommodations must have equivalent accessible quests.
- Nonprofit/cultural multi-pathway inclusivity; Wellbriety quests must be reviewed by cultural advisors before introducing tribal or ceremonial mechanics.

## Proof

Quest replay, timezones, locale/DST boundary, clock rollback, change of pathway, new install offline, support-mode SOS, screen reader and 200% text. A skipped quest does not lower stats or trigger guilt notifications. On change of quest catalog, existing instances remain resolvable under their original definition version.
