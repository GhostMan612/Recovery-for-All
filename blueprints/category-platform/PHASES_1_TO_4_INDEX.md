# Recovery for All — Master Index: Phases 0–4

> This is the single coordinated execution index for the Phase 0–4 program. It supplements, not replaces, `PHASED_EXECUTION_PLAN.md`; `RULES.md` remains highest authority. Blueprint, CI, fixture, or commit presence is not proof of runtime implementation or phase acceptance.

## Current program status

**Phase 0 — IN PROGRESS (Partially Implemented; Not Accepted)**

Verified development checkpoints:
- **P0-A**: Documentation and CI recovery.
- **P0-B**: Privacy capability authorization and cold-restart durability.
- **WO-P0-CIRCLE-REAUTH**: Contextual consent, reactive subscriptions, and truthful delivery status.

Latest verified checkpoint: `bfdaa1caae7cdde991d95f2f92fc8f5ff6c3e2e3`, GitHub Actions run `38319189867` — 762 Flutter tests passed, zero analyzer issues, 14 architectural invariants passed.

Remaining requirements: P0-C server-authoritative Circle security and migration, P0-D device/emulator acceptance, licensing/IP decision, and final verification evidence.

Phases 1–4 remain planned and unaccepted. Existing application functionality does not constitute acceptance of these new phase work orders.

## North star and shared architecture

**Recovery Adventure Network:** locally useful recovery actions become durable, accountable *private* progression; meeting discovery becomes arrival-oriented travel; Circle enables safe voluntary cooperation. Recovery tools and SOS remain available without game rewards or connectivity.

```text
               user intention and consent
                          |
   personal coping | meeting journey | Circle participation
             \            |             /
            locally committed RecoveryAction (stable eventId)
                          |
          one idempotent RewardReceipt per event
        XP + Sparks together; projections cannot re-award
       / companion / quests / raid / constellation / Circle \
                          |
      optional, independently consented external effects
        Atlas routing, weather, remote Circle messages
```

RPG, Navigator, and Circle are interaction surfaces over shared local data and trust contracts, not independent reward ledgers. Preserve existing encrypted Drift data and current recovery behavior. Every new external effect is separately consented and must remain honestly unavailable when unsupported.

## Ordered phases, dependencies, boundaries, and acceptance

| Order | Dependencies | Blueprint locations | Implementation boundary | Measurable acceptance gate | Status |
|---|---|---|---|---|---|
| Phase 0 — privacy, security, identity, governance | Repository baseline; owner decisions where consent, moderation, licensing, or deployment changes | `phase-0/README.md`, `CIRCLE_THREAT_MODEL.md`, `CIRCLE_SECURITY_PROTOCOL.md`, `CIRCLE_EXECUTION_WORK_ORDER.md`, `NETWORK_PRIVACY_WORK_ORDER.md`, `DATA_FLOW_AND_CONSENT.md`, `CI_AND_VERIFICATION.md`, `PHASE_0_STATUS_AND_GATES.md`, `LICENSE_AND_IP_DECISION.md`, `DECISION_LOG.md` | Implement opt-in/network controls and server-enforced Circle ownership, deletion, moderation, and actor-bound reactions. Do not change the license or deploy rules without approval. | Required positive/negative authorization tests pass for two users and a trusted moderator; deletion converges across devices; denied capabilities produce zero prohibited outbound requests; local SOS/recovery remain available; decisions and device evidence are recorded. | **IN PROGRESS (Partially Implemented; Not Accepted)** |
| Phase 1 — progression and rewards | Shared event/schema contracts; inspect actual local Drift schema and migration chain | `phase-1/README.md`, `WO-1A`–`WO-1D`, `ECONOMY_AND_ETHICS.md`, `SCHEMA_MIGRATION.md`, `ACCEPTANCE_AND_TESTS.md` | Local-first typed actions and one atomic reward receipt per stable event. Feature projections can retry but cannot re-award. Preserve balances, legacy rows, journals, pets, and encrypted storage. | 100 sequential/concurrent/restart replays of one event produce exactly one complete XP/Sparks receipt; distinct eligible events apply once; raid/quest/companion projections recover after interruption without rewards duplication; populated migration preserves encrypted user data. | **PLANNED / NOT IMPLEMENTED** |
| Phase 2 — meeting navigation | Phase 0 privacy/capability rules before network/location use; retain existing map as fallback | `phase-2/README.md`, `BRIDGE_API_CONTRACT.md`, `OFFLINE_AND_LOCATION_PRIVACY.md`, `WO-2A`–`WO-2C`, `ACCEPTANCE_AND_TESTS.md` | Consume only a verified immutable local Atlas SDK artifact through the Flutter/Kotlin boundary. Metro is a separate project: no unapproved edit, build, publication, or source copy. | Artifact coordinates, source revision, transitive dependency set, provenance, and SHA-256 are verified and reproducible; synthetic static-feed route works in airplane mode; absent provider and denied-consent paths make no prohibited network request and report unavailable truthfully; minSdk compatibility is demonstrated without silently raising the floor. | **PLANNED / NOT IMPLEMENTED** |
| Phase 3 — Recovery Circle cooperation | Phase 0 trust/security acceptance and Phase 1 idempotence; otherwise remote writes remain disabled/local-only | `phase-3/README.md`, `IDENTITY_MODERATION_AND_SAFETY.md`, `WO-3A`–`WO-3C`, `ACCEPTANCE_AND_TESTS.md` | Server-authorized identity, membership, moderation, deletion, and contribution deduplication. No client-controlled privilege, precise location, or sensitive recovery history in shared payloads. A Circle contribution is not a local RecoveryAction. | Emulator A/B/moderator matrix proves authorization and rejection cases; one actor-target contribution is accepted once across retries; accepting/acknowledging a linked local action cannot create a second reward receipt; consent, opt-out, deletion state, and local-only fallback pass two-device checks. | **PLANNED / NOT IMPLEMENTED** |
| Phase 4 — integration and release evidence | Applicable acceptance gates from Phases 0–3; evidence tied to exact source/artifact | `phase-4/README.md`, `WO-4A`–`WO-4C`, `ACCEPTANCE_AND_TESTS.md`, `RELEASE_SCORECARD.md` | Integrate only accepted phase outputs. Do not infer success from docs, merged code, fixtures, screenshots alone, or a successful build. Human retains release decision. | Every applicable scenario has a pass/fail/blocked/not-run result, exact revisions, device/build/network context, and evidence. Analyzer/tests plus required accessibility, performance, privacy, offline, and low-end-device checks pass before release. | **PLANNED / NOT IMPLEMENTED** |

**Permitted partial ordering:** Phase 1 personal/local work and Phase 2 offline SDK proof may proceed without enabling remote Circle. Phase 2 must satisfy Phase 0 consent rules before any network/location use. Phase 3 connected rollout is blocked until Phase 0 trust gates and Phase 1 deduplication pass; otherwise only a local-only prototype is allowed. Phase 4 accessibility/performance checks may run incrementally, but release acceptance depends on evidence for all applicable preceding gates.

## Shared cross-phase contracts

- **One reward identity:** One stable action `eventId` is globally deduplicated within the user's action/reward ledger. One canonical `RewardReceipt` records the complete eligible XP and Sparks award. Currency, policy revision, feature, retry, raid, quest, Circle, or phase cannot create a second receipt. Policy version is audit metadata. Corrections are separately keyed, auditable compensating events. Raid, quest, constellation, and Circle projections are retryable but cannot re-issue the underlying reward or route one event to competing ledgers.
- **One schema plan:** `contracts/SCHEMA_REGISTRY.md` and `phase-1/SCHEMA_MIGRATION.md` coordinate all Phase 0–4 data-model changes. Inspect the current checkout's schema version and every migration first. Phase 0 outbox/delivery and Phase 1 action/reward work must not invent duplicate event identities, receipts, outboxes, or independent schema bumps. Use one additive migration sequence, populated-chain tests, encrypted-data preservation, and generated Drift output; never hand-edit generated files.
- **Trust and privacy:** Phase 0 consent and authority requirements constrain Phase 2 providers and Phase 3 sharing. Local permissions, user consent, Firebase authentication, and server authorization are distinct checks. Client-side role/preferences never grant remote privilege.
- **SDK boundary:** Atlas availability means an explicitly configured provider and verified artifact, not merely a class or capability flag. Metro IntelliTrip is separately managed; no unauthorized publication or edits. Keep location and remote fallback disabled absent explicit consent; retain the existing meeting/map fallback.
- **Evidence and terminology:** JSON schemas and fixtures are proposals/synthetic; scorecards begin NOT RUN. `sample`, `cached`, `scheduled`, `live`, `local`, `queued`, and `delivered` are not interchangeable.

## Exact work-order sequence

- **Phase 1:** `WO-1A-ACTION-LEDGER.md` → `WO-1B-COMBAT-ENGINE.md` → `WO-1C-QUEST-PROGRESSION.md` → `WO-1D-COMPANION-CONSTELLATION.md`; consult `ECONOMY_AND_ETHICS.md`, `SCHEMA_MIGRATION.md`, and `ACCEPTANCE_AND_TESTS.md`.
- **Phase 2:** `WO-2A-ATLAS-SDK-BRIDGE.md` → `WO-2B-MEETING-NORMALIZATION.md` → `WO-2C-JOURNEY-WEATHER-UX.md`; consult `BRIDGE_API_CONTRACT.md`, `OFFLINE_AND_LOCATION_PRIVACY.md`, and `ACCEPTANCE_AND_TESTS.md`.
- **Phase 3:** `WO-3A-TRUSTED-CIRCLE-TRANSPORT.md` → `WO-3B-COOPERATIVE-QUESTS.md` → `WO-3C-CIRCLE-EXPERIENCE.md`; consult `IDENTITY_MODERATION_AND_SAFETY.md` and `ACCEPTANCE_AND_TESTS.md`.
- **Phase 4:** `WO-4A-COHERENT-USER-JOURNEYS.md` → `WO-4B-PERFORMANCE-ACCESSIBILITY.md` → `WO-4C-PILOT-RELEASE-EVIDENCE.md`; consult `ACCEPTANCE_AND_TESTS.md` and `RELEASE_SCORECARD.md`.

## Shared contracts and governance

- [Cross-phase invariants](contracts/CROSS_PHASE_INVARIANTS.md) — CP-01–CP-24.
- [Privacy capabilities](contracts/PRIVACY_CAPABILITIES.md) — network and sharing policy.
- [Schema registry](contracts/SCHEMA_REGISTRY.md) — proposed examples, validation, and migration authority; JSON Schemas are not runtime API.
- [Integration traceability](contracts/INTEGRATION_TRACEABILITY.md) — source, tests, and evidence map.
- [Decision register](contracts/DECISION_REGISTER.md) — owner decisions, defaults, and deferred options.
- [Recovery safety and ethics](contracts/RECOVERY_SAFETY_AND_ETHICS.md) — UX prohibition list.

## Existing implementation anchors (prior-art context, not phase evidence)

Reinspect the current checkout before implementation. These observations are orientation points from the cited baseline, not fresh runtime verification or phase signoff.

### Recovery for All

- `lib/services/xp_engine_service.dart`: XP and pet-event integration; inspect event identity and legacy unknown-action handling before migration.
- `lib/services/recovery_pet_service.dart`: Sparks, Bond, Energy, nonpunitive rest, and existing preference/database state.
- `lib/services/raid_service.dart`: raid damage and victory behavior; reconcile every award with the shared receipt.
- `lib/screens/pet_trials_screen.dart`: battle rules and RNG currently associated with widget state; inspect before extraction.
- `lib/services/constellation_service.dart`: per-day limits and reward identity need reconciliation with stable action IDs.
- `lib/database/recovery_database.dart`: encrypted Drift database; inspect actual schema version and full migration chain. `test/schema_migration_test.dart` is a required baseline.
- `lib/services/meeting_finder_service.dart`: cached feeds and sample fallback; sample items must never be treated as authentic routeable meetings.
- `lib/screens/meeting_map_screen.dart`: existing Flutter map, weather, external directions, cached tiles, meeting details, and attendance controls.
- `lib/services/community_feed_service.dart`: local Drift with optional Firestore; remote authority and reaction semantics remain Phase 0 gates.
- `android/app/src/main/kotlin/com/recoveryforall/MainActivity.kt`: existing step-counter MethodChannel; Atlas must use a distinct namespace.

### Metro IntelliTrip (separate repository; `master` was the cited implementation branch)

- `docs/SDK_INTEGRATION.md`: documented local Maven publication and Flutter-host integration; verify current guidance and obtain required authorization before artifact publication.
- `core/atlas-engine/.../AtlasEngine.kt`: public facade with provider-pluggable transit/routing/weather behavior.
- `core/atlas-routing/.../StaticNetworkPlanner.kt` and `HybridRoutingProvider.kt`: local scheduled routing and optional remote fallback; configuring the engine alone does not install a functioning provider.
- `core/atlas-gtfs-static/`: static feed and local stop-time index.
- `core/atlas-offline/OfflineRegistry.kt`: freshness/capability state; prepared offline basemap is separate from offline transit data.
- `core/atlas-weather/`: weather/radar adapters; not proof of a complete exposure forecast.

## Agent handoff and implementation protocol

Read root and relevant nested `AGENTS.md` plus the exact work order before each phase. For each work order, record a concise diff plan, implement only authorized scope, add focused tests, produce fresh evidence, review the diff, and obtain human acceptance before advancing. Classify changes as code, test, config, privacy policy, server/rules deployment, or documentation. Keep phase status **PLANNED / NOT IMPLEMENTED** until its measurable gate is independently satisfied. Owner approval remains required for licensing, remote rule deployment, consent changes, SDK artifact publication, and release decisions.

## Known risks and unresolved decisions

| Risk / decision | Current disposition | Gate / owner |
|---|---|---|
| Repository license and proposed proprietary language may conflict; a README cannot revoke prior grants. | **Owner/legal review pending; do not change license or claim exclusivity.** | Phase 0 `LICENSE_AND_IP_DECISION.md` |
| Local Drift version may have advanced beyond the cited historical baseline; Phase 0 outbox and Phase 1 ledger could otherwise duplicate tables/migrations. | **Revalidate the checkout; one coordinated migration plan required.** | Schema registry and Phase 1 migration plan |
| Source ZIP bytes were not available/inspected during consolidation. | **Archive provenance is not authenticated; only reconciled working-copy hashes can be checked.** | Overlay manifest and verifier |
| Replaying an action under another currency, policy version, subsystem, raid, quest, or Circle could duplicate benefits. | **One event-keyed reward receipt; no policy/currency key bypasses deduplication.** | CP-02–05; Phase 1 ledger tests |
| Atlas version `0.1.0` is documented, but immutable artifact bytes, dependency closure, provenance, and reproducible resolution are not established by that string. | **Unresolved; Metro remains read-only and no SDK publication/consumption is authorized by this index.** | Phase 2 artifact owner approval and gates |
| Static feed licensing, device floor, and remote OTP/weather behavior require concrete configuration and consent evidence. | **No capability claim until measured; keep honest existing fallback.** | Phase 2 offline/privacy and device gates |
| Remote moderation needs a trusted operator, server-issued authority, abuse response, retention, and appeal policy. | **No connected expansion if any trust component is absent.** | Phase 0 and Phase 3 |
| No Phase 0–4 runtime, device, Firebase, native SDK, or performance gate is established by blueprint presence. | **All phase acceptance evidence remains NOT RUN.** | Phase 4 `RELEASE_SCORECARD.md` |
