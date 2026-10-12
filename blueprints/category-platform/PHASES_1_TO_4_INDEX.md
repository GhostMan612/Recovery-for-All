# Recovery for All — Master Index: Phases 0–4

> This is the single execution index for the coordinated Phase 0–4 program. It supplements, not replaces, `PHASED_EXECUTION_PLAN.md`; `RULES.md` remains highest authority. Blueprint, CI, fixture, or commit presence is not proof of runtime implementation or phase acceptance.

## Current program status

**All five phases: PLANNED / NOT IMPLEMENTED.** Phase 0 documentation and CI changes are present in this checkout, but their GitHub execution and runtime/security gates have not been verified. The Phase 1–4 contracts and synthetic fixtures are proposals. No phase is accepted, and the Phase 4 release scorecard remains NOT RUN. Existing Recovery for All functionality listed below is prior-art context, not acceptance evidence for this program.

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

## Ordered execution, dependencies, boundaries, and acceptance gates

| Order | Dependencies | Blueprint locations | Implementation boundary | Measurable acceptance gate | Status |
|---|---|---|---|---|---|
| Phase 0 — trust, privacy, identity | Foundation; owner decisions for changed consent behavior and licensing | [phase-0/README.md](phase-0/README.md), `CIRCLE_SECURITY_PROTOCOL.md`, `NETWORK_PRIVACY_WORK_ORDER.md`, `PHASE_0_STATUS_AND_GATES.md` | Implement opt-in/network controls and server-enforced Circle ownership, deletion, moderation, and actor-bound reactions. Do not change license or deploy rules without approval. | Required negative/positive Firebase emulator tests pass for two users and trusted moderator; cross-device deletion converges; denied capabilities produce zero prohibited outbound requests; local SOS/recovery stays available; decisions and device evidence recorded. | **PLANNED / NOT IMPLEMENTED** |
| Phase 1 — progression and rewards | Shared event/schema contracts; audit actual local Drift version and migration chain | [phase-1/README.md](phase-1/README.md), `WO-1A`–`WO-1D`, `SCHEMA_MIGRATION.md`, `ACCEPTANCE_AND_TESTS.md` | Local-first typed actions and one atomic reward receipt per stable event; feature projections may retry but cannot re-award. Preserve balances and legacy rows. | 100 sequential/concurrent/restart replays of one event produce exactly one XP/Sparks receipt; distinct eligible events each apply once; raid/quest/companion projections recover after interruption; populated migration preserves encrypted user data. | **PLANNED / NOT IMPLEMENTED** |
| Phase 2 — meeting navigation | Phase 0 privacy/capability rules before any network/location use; existing map remains fallback | [phase-2/README.md](phase-2/README.md), `BRIDGE_API_CONTRACT.md`, `OFFLINE_AND_LOCATION_PRIVACY.md`, `WO-2A`–`WO-2C`, `ACCEPTANCE_AND_TESTS.md` | RFA consumes a verified, immutable local Atlas SDK artifact through the Flutter/Kotlin boundary. Metro is a separate read-only dependency; no source copy, Metro edit, or unapproved publication. | Artifact coordinates, source revision, full dependency set and SHA-256 are reproducible and verified; synthetic static-feed route works in airplane mode; no-provider and denied-consent paths make no network request and report unavailable truthfully; device/minSdk gate passes. | **PLANNED / NOT IMPLEMENTED** |
| Phase 3 — Recovery Circle cooperation | Phase 0 trust/security acceptance and Phase 1 idempotent action/reward contract; otherwise local-only with remote writes disabled | [phase-3/README.md](phase-3/README.md), `IDENTITY_MODERATION_AND_SAFETY.md`, `WO-3A`–`WO-3C`, `ACCEPTANCE_AND_TESTS.md` | Server-authorized identity, membership, moderation, deletion and contribution deduplication. No client-controlled privilege; no precise location or sensitive recovery history in shared payloads. | Emulator A/B/moderator matrix proves authorization and rejection cases; one actor-target contribution/reaction is accepted once across retries; consent, opt-out, delete status and local-only fallback pass two-device checks. | **PLANNED / NOT IMPLEMENTED** |
| Phase 4 — integration and release evidence | Applicable acceptance gates from Phases 0–3; evidence tied to exact source/artifact | [phase-4/README.md](phase-4/README.md), `WO-4A`–`WO-4C`, `ACCEPTANCE_AND_TESTS.md`, `RELEASE_SCORECARD.md` | Integrate only accepted phase outputs. Do not infer success from docs, merged code, fixtures, screenshots alone, or a successful build. Human retains release decision. | Every applicable P4 scenario has a pass/fail/blocked/not-run result, exact revisions, device/build/network context and evidence; analyze/tests and required accessibility, performance, privacy, and low-end-device checks pass before release. | **PLANNED / NOT IMPLEMENTED** |

**Permitted partial ordering:** Phase 1 personal/local work and Phase 2 offline SDK proof can be developed without enabling remote Circle. Phase 2 remains subject to Phase 0 consent rules before network/location use. Phase 3 connected rollout is blocked until Phase 0 trust gates and Phase 1 deduplication pass; otherwise only a local-only prototype is allowed. Phase 4 accessibility/performance checks may run incrementally, but its release gate depends on the preceding phase evidence.

## Shared cross-phase contracts

- **One reward identity:** a stable action `eventId` is globally deduplicated within the user's action/reward ledger. One `RewardReceipt` records all XP/Sparks awarded for that action; currency, policy version, feature, retry, or phase cannot create another receipt. Policy version is audit metadata. Corrections require a separately identified, auditable compensating event. Raid, quest, constellation, and Circle projections are independently retryable but cannot re-issue the underlying reward.
- **One schema plan:** `contracts/SCHEMA_REGISTRY.md` and Phase 1 `SCHEMA_MIGRATION.md` are the coordination points for all Phase 0–4 data-model changes. Audit the actual checkout's Drift version and every migration first. P0 outbox/Circle work and P1 action/reward work must not invent duplicate event identities, receipts, or independent schema bumps. Use additive migrations and populated old-to-current tests; never hand-edit generated Drift output.
- **Trust and privacy:** Phase 0 consent and authority requirements constrain Phase 2 providers and Phase 3 sharing. Local permissions, user consent, Firebase authentication, and server authorization are distinct checks.
- **SDK boundary:** Atlas availability means an explicitly configured provider and verified artifact, not merely a class or capability flag. Keep location and remote fallback disabled absent consent; retain the existing meeting/map fallback.
- **Evidence and terminology:** schema JSON and fixtures are proposals/synthetic; scorecards begin NOT RUN; `sample`, `cached`, `scheduled`, `live`, `local`, `queued`, and `delivered` are not interchangeable.

## Exact work orders

- **P1:** `WO-1A-ACTION-LEDGER.md` → `WO-1B-COMBAT-ENGINE.md` → `WO-1C-QUEST-PROGRESSION.md` → `WO-1D-COMPANION-CONSTELLATION.md`; consult `ECONOMY_AND_ETHICS.md`, `SCHEMA_MIGRATION.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P2:** `WO-2A-ATLAS-SDK-BRIDGE.md` → `WO-2B-MEETING-NORMALIZATION.md` → `WO-2C-JOURNEY-WEATHER-UX.md`; consult `BRIDGE_API_CONTRACT.md`, `OFFLINE_AND_LOCATION_PRIVACY.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P3:** `WO-3A-TRUSTED-CIRCLE-TRANSPORT.md` → `WO-3B-COOPERATIVE-QUESTS.md` → `WO-3C-CIRCLE-EXPERIENCE.md`; consult `IDENTITY_MODERATION_AND_SAFETY.md`, `ACCEPTANCE_AND_TESTS.md`.
- **P4:** `WO-4A-COHERENT-USER-JOURNEYS.md` → `WO-4B-PERFORMANCE-ACCESSIBILITY.md` → `WO-4C-PILOT-RELEASE-EVIDENCE.md`; consult `ACCEPTANCE_AND_TESTS.md`, `RELEASE_SCORECARD.md`.

## Shared contracts and governance

- [contracts/CROSS_PHASE_INVARIANTS.md](contracts/CROSS_PHASE_INVARIANTS.md) — invariants 01–24.
- [contracts/PRIVACY_CAPABILITIES.md](contracts/PRIVACY_CAPABILITIES.md) — networking and sharing capability policy.
- [contracts/SCHEMA_REGISTRY.md](contracts/SCHEMA_REGISTRY.md) — examples, validation and versioning; JSON Schemas are **proposed**, not runtime API.
- [contracts/INTEGRATION_TRACEABILITY.md](contracts/INTEGRATION_TRACEABILITY.md) — source/test/evidence map.
- [contracts/DECISION_REGISTER.md](contracts/DECISION_REGISTER.md) — owner decisions, defaults, and deferred options.
- [contracts/RECOVERY_SAFETY_AND_ETHICS.md](contracts/RECOVERY_SAFETY_AND_ETHICS.md) — explicit UX prohibition list.

## Existing implementation anchors at the cited baselines

These are orientation points from the package's static baseline review, not fresh runtime verification or phase signoff. Re-read the current checkout before implementation.

### Recovery for All

- `lib/services/xp_engine_service.dart`: atomic XP+pet event; currently timestamp-generated event IDs, legacy `processAction` unknown-action +10 XP fallback, damage-to-raid as a second operation.
- `lib/services/recovery_pet_service.dart`: Sparks, Bond, Energy, nonpunitive rest; some `SharedPreferences` dual-write state.
- `lib/services/raid_service.dart`: atomic raid HP/damage, victory XP; examine event/XP consistency before rerouting.
- `lib/screens/pet_trials_screen.dart`: battle rules and RNG embedded in widget State; three battles/day in preferences.
- `lib/services/constellation_service.dart`: per-day event limits; verify consistency when migrating to stable action IDs.
- `lib/database/recovery_database.dart`: encrypted Drift database, schema version 13 at the cited inspection; `test/schema_migration_test.dart` is a required baseline. Revalidate the local version before planning a migration.
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

## Known risks and unresolved decisions

| Risk / decision | Current disposition | Gate / owner |
|---|---|---|
| MIT `LICENSE` conflicts with earlier proprietary wording; prior grants cannot be revoked by a README edit. | **Owner/legal review pending; do not change license or claim exclusivity.** | Phase 0 `LICENSE_AND_IP_DECISION.md` |
| Actual local Drift version and schema history may have advanced beyond the cited v13 baseline; P0 outbox and P1 ledger could otherwise duplicate tables or migrations. | **Revalidate checkout; one coordinated migration plan required.** | `contracts/SCHEMA_REGISTRY.md`, Phase 1 `SCHEMA_MIGRATION.md` |
| The two named source ZIPs were unavailable in the local locations searched for this consolidation. | **Reconciliation uses the already extracted files and supplied manifest declarations; source archive bytes and archive-level integrity were not independently verified.** | Overlay manifests and this consolidation handoff |
| Replaying one action under another currency, policy version, subsystem, raid, or retry could duplicate benefits. | **Use one event-keyed reward receipt; no policy/currency key may bypass deduplication.** | CP-02–05, Phase 1 1A/1B tests |
| Phase 2 names Atlas `0.1.0`, but an immutable artifact/dependency set, checksum and reproducible publication/resolution procedure are not yet evidenced. | **Unresolved; do not treat the version string or SDK class as a verified package. Metro remains read-only.** | Phase 2 P2-001 / owner-authorized artifact supply |
| Static GTFS source, legal feed use, device floor and any remote OTP/weather behavior need concrete configuration and consent evidence. | **No route or provider capability claim until measured; retain honest existing fallback.** | Phase 2 offline/privacy and device gates |
| Remote moderation requires a real trusted operator, server-issued authority, abuse response, retention and appeal policy. | **No connected expansion if any trust component is absent.** | Phase 0 and Phase 3 |
| No cross-phase runtime, device, Firebase, native SDK or performance gate has been run for this consolidation. | **All Phase 0–4 scorecard evidence remains NOT RUN.** | Phase 4 `RELEASE_SCORECARD.md` |
