# Phase 1 — Deepen the Recovery RPG without Breaking Trust

**Status:** BLUEPRINT ONLY. Four focused work orders; proceed with local-only work once schema and P0 consent boundaries are understood. Remote Circle operations remain blocked until P0 is proven.

## Executive outcome

Turn existing Pet, Sparks, Path XP, Trials, Raid and Constellation into *one reliable progression system*, so an action is acknowledged exactly once and the user sees one coherent result. Expand tactical choices while remaining accessible and explicitly nonpunitive. Preserve the shipped UI where possible.

| Slice | Work order | Creates | Exit |
|---|---|---|---|
| P1-A | [WO-1A-ACTION-LEDGER.md](WO-1A-ACTION-LEDGER.md) | typed action + atomic idempotent reward application | 100 replays = 1 reward |
| P1-B | [WO-1B-COMBAT-ENGINE.md](WO-1B-COMBAT-ENGINE.md) | pure battle reducer, deterministic RNG, portable abilities | battle test matrix deterministic |
| P1-C | [WO-1C-QUEST-PROGRESSION.md](WO-1C-QUEST-PROGRESSION.md) | accessible solo quests and supportive skill tree | all pathways have viable alternatives |
| P1-D | [WO-1D-COMPANION-CONSTELLATION.md](WO-1D-COMPANION-CONSTELLATION.md) | consistent projections, animation/opt-out contracts | XP/cosmetics/stars survive restarts |

Read [ECONOMY_AND_ETHICS.md](ECONOMY_AND_ETHICS.md), [SCHEMA_MIGRATION.md](SCHEMA_MIGRATION.md), [ACCEPTANCE_AND_TESTS.md](ACCEPTANCE_AND_TESTS.md), and nested [AGENTS.md](AGENTS.md).

## Minimum stable core

- Never discard or recalculate legacy XP/Sparks/cosmetics without explicit migration and owner approval.
- `XpEngineService` currently atomically stores XP + an event in Drift, **but its event ID uses a fresh timestamp** and `processAction` still has a +10 unknown-action compatibility fallback. Design must fix external-event uniqueness without removing legacy callers carelessly.
- `RaidService` handles damage in a different transaction and grants victory XP inside raid transaction; introduce per-event damage receipts and exactly-once victory before collapsing calls.
- `RecoveryPetService` also handles Sparks and preferences; do not pretend XP and Sparks are already in one authoritative DB event flow.
- `pet_trials_screen.dart` embeds rules in a UI State object, so any refactoring requires widget equivalence and golden tests.

## What not to do

Do not introduce server-required rewards, compulsive leaderboard mechanics, paid currencies or cloud gameplay dependencies. Do not start Phase 3's group quests until actor identity and local event uniqueness are real.
