# Agent Handoff — Read-Only Plan to Local Implementation

## Agent operating contract

You are an implementation agent working **only** inside the user's local Recovery for All checkout. Treat `RULES.md`, `AGENTS.md` and `SESSION_HANDOFF.md` as authority, and inspect current source/tests before touching code. Metro IntelliTrip is a separate, read-only dependency from this worktree: read it, publish its SDK artifacts through an explicitly approved local process, but **do not modify the Metro repository as part of this work order**. Do not push GitHub changes unless the human explicitly asks. Do not build in the middle of a plan contrary to current shell discipline. Keep changes minimal and check tests at phase gates.

## Read sequence

1. Root `RULES.md`, `AGENTS.md`, `SESSION_HANDOFF.md`.
2. `blueprints/category-platform/README.md` and this package.
3. Actual current `lib/services/xp_engine_service.dart`, `recovery_pet_service.dart`, `raid_service.dart`, `constellation_service.dart`, `meeting_finder_service.dart`, `map_tile_cache.dart`, `community_feed_service.dart`, `lib/screens/meeting_map_screen.dart`, `community_feed_screen.dart`, `pet_trials_screen.dart`, `lib/database/recovery_database.dart`, and existing tests.
4. Metro `master`: `docs/SDK_INTEGRATION.md`, `docs/OFFLINE_MODEL.md`, `core/atlas-engine/.../AtlasEngine.kt`, and routing/weather contracts.

## First work order

Produce a short implementation impact report BEFORE edits with (a) touched filenames and precise changes, (b) preserved invariants, (c) required migration steps, (d) negative tests, (e) cross-repo/gradle dependencies, and (f) decisions requiring human approval. Then execute **only Phase 0** with approved decisions. Do not jump to multiplayer features or route provider integration during Phase 0.

## Phases

- P0 `PHASED_EXECUTION_PLAN.md` Phase 0: trust/consent/license documentation and Circle reliability.
- P1 Phase 1: event engine and richer RPG.
- P2 Phase 2: Metro SDK meeting navigation.
- P3 Phase 3: Circle cooperative interactions.
- P4 Phase 4: integrated E2E/user experience proof.

Each phase is a small, testable code strike and one handoff checkpoint, not an uncontrolled rewrite. Save explicit evidence (changed file list, test results, screenshots/manual test notes, remaining risks) locally; no invented green test report.

## Definition of success

The user can find a real meeting, receive a plausible multimodal itinerary, save it for offline use, choose an optional coping/quest action, earn exactly one safe reward and optionally offer support to someone else without losing privacy control or facing shame for an interruption. All claims must reflect which parts have been actually verified on real devices.
