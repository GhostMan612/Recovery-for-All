# Category Platform — High-Priority Execution Phases

**Directive:** a compact, gated program with **foundations first; game first among the new experience work; Navigator second; Circle third.** Agents should minimize edits and reuse the substantial shipped code. Each phase is a separate local change set/PR. No remote modifications authorized by this planning package.

## Phase 0 — Stabilize boundaries / truthful contracts (P0)

**Goal:** establish privacy, legal and synchronization truth before making the game and Circle bigger.

**Step 0.1 — Repo identity and standards:** Compare `LICENSE` (MIT) versus README (proprietary) and document one approved legal direction; do NOT change license without owner/counsel decision. Reconcile inaccurate README competitor claims and missing blueprint links by approved work order only. Inventory current schema, `AGENTS.md` and `RULES.md` invariants.

**Step 0.2 — Network/privacy flow:** enumerate exact remote calls (Open-Meteo coordinates, online map tiles, external navigation, Firestore, meeting directory, SOS). Introduce a privacy capability / consent checklist. Make local, provider-visible and cloud-synced data boundaries user understandable.

**Step 0.3 — Circle correctness gate:** Fix/define remote post deletion, trusted report/moderation path, reaction idempotency/rate limiting, offline draft queue and attribution. Block community-expansion release if trust model is not ready; conservative fallback is to disable remote posting until ready.

**Deliverables:** ADRs for licensing/privacy/Circle transport, testable data-flow inventory, nonregression tests. **Exit:** all actual sharing/deletion claims match observed cross-device behavior; no license contradiction in published statements.

## Phase 1 — One event ledger and robust RPG (P1)

**Goal:** unified quest, companion, XP, Sparks, raids, and constellation; make the game worthwhile but never coercive.

**Step 1.1 — RecoveryAction + RewardLedger design:** typed action definitions with source, proof level, stable event id; schema migration proposal with test fixtures. Route existing `XpEngineService`, `RecoveryPetService`, `RaidService` via an orchestrator without duplicate grants.

**Step 1.2 — Combat/quest foundation:** abstract battle rules from UI, deterministic RNG injectable in tests, mission catalog for multiple recovery paths, accessible alternative actions; introduce a soft-limits/balance document. Keep “resting, not dead” and defeat-as-learning semantics.

**Step 1.3 — Rewards that reinforce meaningful care:** constellation links to event records, personal quest feedback, companion development and daily gentle prompts. Offline actions commit now, reconcile later without duplication. Add optional “no game mode” without compromising core recovery tools.

**Deliverables:** game economy spec, action contract, migration tests, battle/pet/raid integration tests, walkthrough of accessibility and no-guilt UX. **Exit:** 100 repetitions/restarts/replays cannot double grant one event; no XP loss; critical coping tools are never gated behind rewards.

## Phase 2 — In-app Meeting Navigator + Metro SDK (P1)

**Goal:** selected recovery meeting -> safe, comprehensible, offline-capable route with weather/transfer awareness.

**Step 2.1 — SDK spike, bounded:** use Metro `master` Atlas SDK's `docs/SDK_INTEGRATION.md`; publish versioned Maven artifacts, create Flutter MethodChannel proof-of-concept, read `AtlasEngine.capabilities` and produce one test `planJourney` result. Verify Android SDK/Gradle compatibility and ownership of the Android host. Keep existing Flutter map renderer.

**Step 2.2 — Meeting schedule/destination normalization:** stable source+meeting ID, timezone, frequency/exception handling, accessible attributes when sourced, precise staleness states. No SAMPLE fixture routing. Wire journey candidate selection and local saved itinerary.

**Step 2.3 — Route/weather UX:** add route polylines, walking legs, transfers, arrival buffer, confidence/uncertainty, weather exposure and NWS warnings where sourced. Permit explicit external fallback with consent if the SDK cannot answer locally. Respect tile/weather license and caching restrictions.

**Deliverables:** bridge contract, thin Android adapter, Dart orchestration, offline route fixture and weather degradation tests. **Exit:** a prepared offline device can plan a test GTFS journey to a real cached meeting; fresh install offline cannot invent a route. No third-party routing call without policy-consistent consent.

## Phase 3 — Recovery Circle 2.0 (P1/P2)

**Goal:** meaningful supportive social actions with enforceable privacy and trusted moderation.

**Step 3.1 — Trust model:** decide local-only, shared Firestore, or other audited transport; server-authorized moderation, rate limits, per-user blocking, deletion/reconciliation and data retention. Separate Wellbriety directory from interactive Community Circle.

**Step 3.2 — Cooperative quests:** safe group intentions (“Reach out”, “Ground together”, “Prepare for a meeting”), voluntary confirmations, small shared outcomes. No competitive public sobriety scores and no rewards for sensitive confessions. Optional signed peer encounter kept separate from meeting attendance.

**Step 3.3 — Disconnected UI and recovery:** local drafts, queue and resend indicators; last-known activity marked cached, idempotent event matching, human-centered support affordances. Do NOT promise offline interdevice sync absent actual mesh transport.

**Deliverables:** Circle protocol / moderation ADR, Firestore emulator rules tests or alternative audited transport tests, offline/reconnect integration tests, anonymous account removal and deletion UX. **Exit:** block/report/delete/consent verified cross-device, duplicate reactions do not inflate rewards, no published precise location from Navigator.

## Phase 4 — Coherence, pilot and category proof (P2)

**Goal:** single recovery journey rather than feature islands.

**Step 4.1 — Guided onboarding:** choose pathway, privacy level, accessibility, preferred transport and optional companion. “Find a meeting” and “Need support now” remain one tap away.

**Step 4.2 — Performance / reliability:** test with 3GB low-end device plus Moto G; map pan/zoom, GTFS snapshot download and cold offline restart, battle frame pacing, reduced motion, large fonts and assistive semantics. Use explicit capped memory and file budgets.

**Step 4.3 — Ethical user study:** compare usability, saved-to-arrived journeys, journey explanation clarity, Circle support satisfaction, gaming opt-out and perceived pressure. Do NOT claim improved abstinence or relapse prevention from engagement alone.

**Deliverables:** release benchmark evidence, user-testing guide, actual vs planned feature matrix, accurate README and optional outward-facing positioning. **Exit:** independent walkthroughs demonstrate core loop; no P0 issues; evidence-based category claims.

## Work order priorities (file-level, proposed)

| Work order | Existing files to inspect/modify only when approved | Why |
|---|---|---|
| WO-00 Privacy/licensing | `README.md`, `LICENSE`, `PRIVACY_POLICY.md`, `firestore/firestore.rules`, `lib/screens/meeting_map_screen.dart` | Truthful IP/privacy boundaries; must be decision-gated |
| WO-01 Circle integrity | `lib/services/community_feed_service.dart`, `lib/screens/community_feed_screen.dart`, `lib/database/recovery_database.dart`, `firestore/firestore.rules`, `test/community_feed_service_test.dart` | Trusted moderation, deletion, reaction caps; avoid client-side authority |
| WO-02 Event ledger | `lib/services/xp_engine_service.dart`, `lib/services/recovery_pet_service.dart`, `lib/services/raid_service.dart`, `lib/services/constellation_service.dart`, `lib/database/recovery_database.dart`, relevant tests | One event -> one reward without regression |
| WO-03 RPG quests | `lib/screens/pet_trials_screen.dart`, `lib/screens/pet_home_screen.dart`, `lib/widgets/raid_boss_card.dart`, `lib/widgets/skill_tree_modal.dart` plus feature seam | Testable battle logic, recovery-specific missions, accessibility |
| WO-04 SDK bridge | `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/recoveryforall/`, new `lib/features/navigator/`, Metro `docs/SDK_INTEGRATION.md` (read-only) | Consume version-pinned Atlas; no source copying across repos |
| WO-05 Meeting reachability | `lib/screens/meeting_map_screen.dart`, `lib/services/meeting_finder_service.dart`, `lib/services/map_tile_cache.dart`, meeting tests | Valid destinations, honest offline/data freshness, safe route rendering |
| WO-06 Connected Circle quests | Circle implementation + Action ledger adapter, rules tests | Cooperative rewards with real trust gates |

**Execution discipline:** human Android builds under local repo `RULES.md`; don't edit generated `recovery_database.g.dart` by hand. Work order must state migrations and negative tests before touching the DB. No “big bang” rewrite.
