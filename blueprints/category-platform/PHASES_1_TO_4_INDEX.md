# Category Platform — Phases 1–4 Execution Index

> This document supplements, not replaces, `PHASED_EXECUTION_PLAN.md`. `RULES.md` is highest authority. **No phase is marked shipped by the existence of this overlay.**

## North star

**Recovery Adventure Network:** locally useful recovery actions become durable, accountable *private* progression; meeting discovery becomes arrival-oriented travel; Circle provides safe voluntary cooperation. Recovery tools and SOS stay accessible without game rewards or connectivity.

```text
               user intention and consent
                          |
   personal coping | meeting journey | Circle participation
             \            |             /
            locally committed RecoveryAction (typed ID)
                          |
        idempotent RewardLedger + feature projections
        / companion / quests / raid / constellation \
                          |
      optional, independently consented external effects
        Atlas routing, weather, remote Circle messages
```

## Ordered execution

| Sequence | Folder | Primary objective | Prerequisite exit |
|---|---|---|---|
| Phase 0 | `phase-0/` from earlier overlay | Privacy/identity/Circle correctness and legal owner decisions | Phase 0 actually implemented and proven for any connected Circle write |
| Phase 1 | [phase-1/README.md](phase-1/README.md) | One event -> at most one reward; deeper ethical game mechanics | local storage safety, schema/test gate |
| Phase 2 | [phase-2/README.md](phase-2/README.md) | Meeting -> plan -> travel -> arrival, private offline-capable | destination provenance, Atlas bridge and permission gate |
| Phase 3 | [phase-3/README.md](phase-3/README.md) | Trustworthy Circle collaboration and co-op quests | Phase 0 network moderation, Phase 1 idempotence |
| Phase 4 | [phase-4/README.md](phase-4/README.md) | Coherent UI, real hardware reliability and truthful release | previous phases accepted, evidence recorded |

**Partial orders:** Phase 1 can proceed before remote Phase 0 Circle deployment if confined to personal local functionality. Phase 2's local SDK proof can proceed before Circle rollout. Do not require Circle remote infrastructure for critical meeting navigation. Phase 4 may run accessibility checks incrementally but only releases when all relevant gates pass.

## Exact work orders

- **P1:** `WO-1A-ACTION-LEDGER.md` → `WO-1B-COMBAT-ENGINE.md` → `WO-1C-QUEST-PROGRESSION.md` → `WO-1D-COMPANION-CONSTELLATION.md`; consult `ECONOMY_AND_ETHICS.md`, `SCHEMA_MIGRATION.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P2:** `WO-2A-ATLAS-SDK-BRIDGE.md` → `WO-2B-MEETING-NORMALIZATION.md` → `WO-2C-JOURNEY-WEATHER-UX.md`; consult `BRIDGE_API_CONTRACT.md`, `OFFLINE_AND_LOCATION_PRIVACY.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P3:** `WO-3A-TRUSTED-CIRCLE-TRANSPORT.md` → `WO-3B-COOPERATIVE-QUESTS.md` → `WO-3C-CIRCLE-EXPERIENCE.md`; consult `IDENTITY_AND_MODERATION.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P4:** `WO-4A-COHERENT-USER-JOURNEYS.md` → `WO-4B-PERFORMANCE-ACCESSIBILITY.md` → `WO-4C-PILOT-RELEASE-EVIDENCE.md`; consult `ACCEPTANCE_AND_TESTS.md`, `RELEASE_SCORECARD.md`.

## Shared contracts and governance

- [contracts/CROSS_PHASE_INVARIANTS.md](contracts/CROSS_PHASE_INVARIANTS.md) — invariants 01–24.
- [contracts/PRIVACY_CAPABILITIES.md](contracts/PRIVACY_CAPABILITIES.md) — networking and sharing capability policy.
- [contracts/SCHEMA_REGISTRY.md](contracts/SCHEMA_REGISTRY.md) — examples, validation and versioning; JSON Schemas are **proposed**, not runtime API.
- [contracts/INTEGRATION_TRACEABILITY.md](contracts/INTEGRATION_TRACEABILITY.md) — source/test/evidence map.
- [contracts/DECISION_REGISTER.md](contracts/DECISION_REGISTER.md) — owner decisions, defaults, and deferred options.
- [contracts/RECOVERY_SAFETY_AND_ETHICS.md](contracts/RECOVERY_SAFETY_AND_ETHICS.md) — explicit UX prohibition list.

## Current verified source anchors, as of cited commits

### Recovery for All

- `lib/services/xp_engine_service.dart`: atomic XP+pet event; currently timestamp-generated event IDs, legacy `processAction` unknown-action +10 XP fallback, damage-to-raid as a second operation.
- `lib/services/recovery_pet_service.dart`: Sparks, Bond, Energy, nonpunitive rest; some `SharedPreferences` dual-write state.
- `lib/services/raid_service.dart`: atomic raid HP/damage, victory XP; examine event/XP consistency before rerouting.
- `lib/screens/pet_trials_screen.dart`: battle rules and RNG embedded in widget State; three battles/day in preferences.
- `lib/services/constellation_service.dart`: per-day event limits; verify consistency when migrating to stable action IDs.
- `lib/database/recovery_database.dart`: encrypted Drift database, schema version 13 at inspection; `test/schema_migration_test.dart` is a required baseline.
- `lib/services/meeting_finder_service.dart`: cached meeting feeds, 24-hour freshness marker, sample offline fallback; never treat sample items as authentic meeting targets.
- `lib/screens/meeting_map_screen.dart`: Flutter map, Open-Meteo current temperature, external Google Maps directions, cached tiles, meeting detail/attendance controls.
- `lib/services/community_feed_service.dart`: local Drift plus optional Firestore; remote authority and reaction semantics remain Phase 0 gates.
- `android/app/src/main/kotlin/com/recoveryforall/MainActivity.kt`: current step counter MethodChannel; use *another* namespaced channel for Atlas.

### Metro IntelliTrip (`master`, not default `main`)

- `docs/SDK_INTEGRATION.md`: publish local Maven artifacts via `publishAtlasToLocalRepo` (`com.intellitrip.atlas:atlas-engine:0.1.0` in baseline); consume from Flutter host via Kotlin platform channel.
- `core/atlas-engine/.../AtlasEngine.kt`: public facade with pluggable transit/routing/weather providers.
- `core/atlas-routing/.../StaticNetworkPlanner.kt`, `HybridRoutingProvider.kt`: in-process scheduled routing and opt-in remote fallback; **configuring `AtlasEngine` does not automatically install a routing provider**.
- `core/atlas-gtfs-static/`: cached static feed and disk stop-time index.
- `core/atlas-offline/OfflineRegistry.kt`: stale-vs-live capability; prepared offline basemap is separate from offline transit data.
- `core/atlas-weather/`: NWS alerts and radar adapters, not a complete exposure forecast by itself.

## Agent protocol

Read relevant nested `AGENTS.md` before touching a phase. Produce a `diff plan → code/tests → fresh evidence → human acceptance` cycle per work order. Source must remain in the local repository. Record whether a change is code, test, config, privacy policy, server/rules deployment or documentation only. The user determines release and remote deployment; no auto-commits/pushes/rebases/force pushes.
