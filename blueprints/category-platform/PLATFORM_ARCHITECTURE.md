# Recovery Adventure Network — Reference Architecture (Proposal)

**Purpose:** make RPG, travel and Circle share a reliable privacy-preserving core, while preserving existing Flutter/Drift code and adopting Metro IntelliTrip's Kotlin Atlas engine through a narrow boundary. **No implementation has been performed.**

## 1. Core user loop

```text
Personal intention / support need
             |
   Recommended meaningful action
        /          |          \
  local coping   meeting trip  Circle support
        \          |          /
      RecoveryAction event (local journal of facts)
                  |
          Outcome + provenance
                  |
       RewardLedger (idempotent)
          /        |       \
    pet/skills    constellation   optional circle acknowledgement
                  |
         user's private progress
```

*RPG, Navigator, Circle are three interaction surfaces, not three independent currencies/databases.* No prize for raw GPS coordinates, emergency calls, a self-reported relapse, or the volume/intensity of sensitive disclosure.

## 2. Proposed module seams (Dart unless noted)

```text
lib/features/recovery_actions/domain/
    recovery_action.dart          # action schema, source, proof class
    reward_policy.dart            # nonpunitive caps, entitlement calculations
    action_outcome.dart            # source/freshness states
lib/features/recovery_actions/data/
    recovery_action_repository.dart  # transactional persistence; migration-aware
    reward_ledger_repository.dart
lib/features/rpg/domain/
    quest_definitions.dart
    ability_definitions.dart
    encounter_policy.dart
lib/features/rpg/application/
    rpg_orchestrator.dart          # existing pet/XP/raid adapters
lib/features/navigator/domain/
    meeting_destination.dart
    journey_candidate.dart
    route_exposure.dart
    nav_capabilities.dart
lib/features/navigator/application/
    meeting_journey_coordinator.dart
lib/features/navigator/infrastructure/
    atlas_bridge.dart              # Dart MethodChannel adapter
    meeting_source_adapter.dart
    forecast_adapter.dart
android/app/src/main/kotlin/com/recoveryforall/atlas/
    AtlasChannelAdapter.kt         # Kotlin MethodChannel, SDK consumes Maven artifacts
lib/features/circle/domain/
    circle_event.dart
    consent_policy.dart
    circle_visibility.dart
lib/features/circle/application/
    circle_coordinator.dart
    delivery_queue.dart
lib/features/privacy/
    network_permission_policy.dart
    data_sharing_receipt.dart
```

**This is a design map.** It should be implemented incrementally after inspecting current `lib/`, `lib/database/recovery_database.dart`, `lib/core/dashboard_providers.dart` and navigator routes. Do not create an entirely separate parallel state graph if reuse is possible.

## 3. Single canonical RecoveryAction contract

```text
RecoveryAction {
  eventId: UUID (stable idempotency key),
  type: coping|journal|gratitude|meeting_plan|meeting_reflection|
        completed_walk|peer_support|step_work|fellowship_attestation|...
  occurredAt: local timestamp,
  source: ui|pedometer|peer_signed|import,
  proofLevel: SELF_REPORTED|DEVICE_OBSERVED|PEER_ATTESTED,
  payloadRef: local encrypted record reference (no free-text in leaderboard),
  schemaVersion,
  userConsentFlags,
}
RewardLedger {
  eventId, ruleVersion, currency, amount, grantedAt,
  UNIQUE(eventId, ruleVersion, currency)
}
```

Use existing Drift encrypted database and migration tests, not a second writable store. Reuse `XpEngineService` and `RecoveryPetService` behind one action dispatcher; retain old persisted values during migration. Existing data cannot be silently lost. Keep raid reward bookkeeping within the ledger; source-of-truth and audit records update atomically. Make all supported event types explicitly registered; ban unknown-event automatic rewards for new flows.

### Safety-economy policy

- Never zero previous progress for missed days or return-to-use disclosure.
- Offer accessibility-equivalent non-movement quests (e.g. self-reflection or asking for support).
- No competitive sobriety counts, public relapse histories or pressure to attest meeting attendance.
- No randomized purchase loops, paid boosts, loot boxes, gambling or premium advantages.
- Reward caps prevent tap farming but do not discourage real support seeking; keep the two concepts separate.
- Offline actions are immediate locally and reconcile later, with stable event ids and conflict logs.

## 4. Recovery Navigator (Metro -> Flutter boundary)

### Proven implementation to reuse

Metro `master` includes `atlas-engine`, static and realtime GTFS, local `StaticNetworkPlanner`, hybrid routing, transfer-confidence scoring, map render pipeline, NWS alerts/RainViewer radar and an offline registry. `docs/SDK_INTEGRATION.md` describes publishing the engine and consuming it from Recovery for All via a **Flutter `MethodChannel`**; the native MapLibre/Compose UI is explicitly not part of the published SDK.

### Integration boundaries

1. Publish **versioned** Kotlin Atlas artifacts to a known local Maven repo from Metro (`publishAtlasToLocalRepo`); pin artifact version and commit in recovery integration documentation.
2. Read Recovery for All Android `minSdk`, Kotlin, Gradle and desugaring configuration before setting dependencies. Metro SDK targets Android API 26; **never raise Recovery for All minSdk without a conscious device-coverage decision**.
3. Add `AtlasChannelAdapter.kt` in the Recovery for All Android host; expose typed serializable narrow calls `capabilities`, `loadStatic`, `planJourney`, `evaluateTransfers`, `getWeatherLayerMetadata`, `getOfflineStatus`.
4. Keep Flutter's `flutter_map` and existing `MeetingMapScreen` initially. Convert returned route legs to Flutter polylines/markers; do not embed a second Compose map or port entire SDK source into Dart.
5. Derive origin/destination from the selected meeting and explicit user input; keep user's origin local unless a remote provider is explicitly requested and consented.
6. Use local routing first; when unsupported, show `Unavailable` or ask permission for remote fallback. Do not silently upload origin/destination to an OTP server.
7. Only claim “live” when timestamped realtime/alerts are fresh; stale schedule-based journeys remain usable with clear caveats.

### Journey ranking (goal: attendability)

`score = reachableBeforeStart + arrivalBuffer + fewestRiskyTransfers + accessibleRoute + weatherExposurePenalty + walkingComfort` (relative preference weights, **not** a clinical score). Hard constraints: user's mobility limits, service calendars, meeting timezone, reachability. Show candidate itineraries and honest uncertainty; weather forecast timestamp and radar source can differ. Allow user to disable weather and location services.

**Meeting ID hygiene:** compound key `(directoryProvider, providerMeetingId)`; reconcile recurring instances (date, start time, timezone, venue), feed freshness and canceled/changed meetings. Do not use coordinates alone to identify a meeting. **Never display synthetic SAMPLE fixture as a real routeable meeting.**

### Route privacy

- Online weather APIs often receive the location used in their query (in current RFA code, Open-Meteo does). API use should be disclosed and opt-in where location is user-specific.
- A third-party routing provider might receive origin/destination, so remote fallback is a separate consent gate.
- Do not upload route history to the Circle or record attendance based on route planning. Route planning is not proof of attending.

## 5. Recovery Circle = local trusted support + optional connected collaboration

### Product surface

- **My Circle**: trusted people, voluntary aliases, opt-in private support prompts and roles. Start with self-defined local entries; don't imply messages travel when offline.
- **Community Circle**: discoverable, alias-based posts, support reactions, follow-up prompts, gentle community quests; no follower ranking or sober-time league.
- **Fellowship Circles**: external, culturally specific program directories like `wellbriety_circles_screen.dart`; keep them distinct, don't claim affiliation.

### Cooperative mechanics

- Tiny support actions: “Send encouragement,” “Reflect together,” “Choose a meeting to attend,” and “Celebrate a completed action.”
- Optional **Circle quests** are collaborative but never reward public confession, precise location, or crisis disclosures. Personal rewards do not scale with number of friends.
- A signed fellowship handshake may evidence an interaction between keys, **not** the presence of a person at an actual meeting or a verified identity. Never call it geofenced proof of attendance.

### Required infrastructure before scaling

- Public community moderation and reporting must be **server-authorized** or the feature must remain limited/offline. A local `SharedPreferences` moderator toggle cannot govern shared data.
- Remote deletion semantics: author-scoped tombstones or trusted deletion, convergence tests, storage lifecycle, and explanation to users of residual cached copies.
- Rate-limit and authenticate reactions; use one user+post+kind idempotency record or comparable enforcement. Trust must not depend on a client-side count.
- Per-user blocking, mute, anti-harassment, spam defenses, abuse escalation, content policy and safety copy.
- Visibility states (`draft`, `queued`, `sent`, `received`, `deleted`), plus retry/backoff after reconnect.
- Transport security not equal to end-to-end encryption: do not claim E2EE for Firebase mirror unless actually designed/tested with per-circle key management.
- Explain that *offline Circle* initially means local drafts/previously stored content; device-to-device offline mesh is a separate, scoped R&D project, not assumed present.

## 6. Capability states as a first-class contract

| Tier | Required preconditions | Functions that MUST work | Must never be mislabeled |
|---|---|---|---|
| **A: fresh install airplane-mode** | app assets only | journal/coping/companion offline content; honest empty meeting coverage screen; SOS phone numbers usable if device has service | No invented live meetings, routes, circle replies or radar |
| **B: prepared airplane-mode** | fetched meeting directory, GTFS, permitted map pack | search downloaded meetings, locally planned static journeys where graph supports it, saved reflections, quest completion | No live arrivals, fresh weather, live peers or service alerts |
| **C: online with permissions** | optional network + location/remote consent | refreshed meeting feeds, realtime updates and radar; optional connected Circle | No silent data transfer, no forced account requirement for private core |

*Offline-complete* is a measurable scenario, not the claim that every feature requires zero bytes of connectivity.

## 7. End-to-end experience acceptance example

1. The user chooses an AA, NA, SMART, Dharma or other directory meeting with a known verified schedule.
2. Navigator proposes local-first transit journeys that can arrive before the session; weather changes *decision support*, not reward value.
3. User saves itinerary for offline use; if real-time drops, screen labels scheduled/static status.
4. User may optionally log attendance/reflection **without claiming an objective verification**.
5. Action emits one idempotent event; XP, Sparks, constellation and quest milestones update once.
6. Circle share is optional and redacted; the private meeting destination, route, exact address, diary and sobriety time remain on-device unless user deliberately selects fields to share.
