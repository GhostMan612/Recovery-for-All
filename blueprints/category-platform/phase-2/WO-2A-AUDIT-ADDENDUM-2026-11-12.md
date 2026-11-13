# WO-2A — Atlas SDK bridge scaffold audit addendum (2026-11-12)

**Parent work order:** [WO-2A](WO-2A-ATLAS-SDK-BRIDGE.md)

## Audit addendum — actual scaffold state (November 11, 2026 local / November 12 UTC)

This section supersedes the earlier **"Add NEW"** file instructions above as an
implementation-progress statement; those are historical instructions rather than
current missing files. The following files are already tracked on main at
`2a763ef6fafdfa9af64d8615691d8292279bb77a`:

- `android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasChannelAdapter.kt`
- `lib/features/navigator/data/atlas_bridge.dart`
- `lib/features/navigator/data/atlas_dtos.dart`
- `lib/features/navigator/data/navigator_repository.dart`
- `lib/features/navigator/application/meeting_journey_planner.dart`
- `test/navigator/atlas_bridge_contract_test.dart`

**They constitute a fail-closed bridge scaffold, not an integrated SDK.** The
native adapter reports `staticTransit=false`, `localRouting=false`,
`realtime=false`, `weather=false`, `offlineSnapshot=false`, with an empty
provider list. `loadStaticNetwork` returns `state=missing` and
`source=unlinked_sdk`, while `planJourney` returns `SDK_NOT_INSTALLED`.
`getOfflineStatus` returns a fixed "unavailable" status rather than querying
real Atlas data. `getWeather` reports unsupported.

**New concrete discrepancy:** `cancelRequest` returns
`{cancelRequested: true, requestId: ...}` despite having no outstanding Atlas
operation or cancellation token to cancel. This is at most a handler
acknowledgement, **not** evidence of actual cancellation. Do not surface that
boolean as a verified cancelled operation.

### Revised implementation sequence

1. **Artifact proof and compatibility (stop gate).** Inspect the current Metro
   `master` and immutable Atlas SDK publication from the *other* repo; verify
   Maven coordinates, actual local artifact bytes, Gradle plugin/Kotlin/Android
   API compatibility, SHA-256 and transitive libraries. The candidate version
   in the historical section is **not** proof it is published or consumable.
   Do not modify Metro as part of this PR.
2. **Real provider construction.** Supply a concrete, version-pinned
   `AtlasProviderFactory` that can build a real engine and read the local
   static GTFS snapshot in app-private storage. Map `FeedId` to its verified
   provider namespace and preserve source identities; do not generate
   plausible trip legs or live ETAs from absent data.
3. **Native transport.** Replace stub `getCapabilities` and
   `loadStaticNetwork` with actual engine capabilities and error states.
   Dispatch expensive work off the main thread, honor Flutter engine
   attach/detach, define timeout and cancellation ownership, and guarantee
   exactly one MethodChannel result per request. For `cancelRequest`,
   return true **only** if a registered in-flight request was actually
   cancelled; otherwise return a typed no-active-request response.
4. **Privacy, navigation and fallback.** Require explicit consent for any
   remote GTFS refresh, routing or location transfer; local `fromCacheOnly`
   must make zero network calls. Keep the existing clearly labeled,
   user-initiated external map fallback for SDK missing/unsupported/denied.
   Reject synthetic or unverified destinations.
5. **End-to-end evidence.** Add Kotlin tests for version negotiation, missing
   artifact, real cached network, successful cancellation, duplicate/late
   responses, engine lifecycle and denial of unconfigured remote providers.
   Add Dart host contract tests plus at least one on-device *real installed
   artifact* route fixture with stop identity, legs and provenance. Record
   the app and SDK SHAs, signed APK/AAB signer when release is in scope,
   installed test device and packet observations.

**Acceptance:** No new native "true" capability before its actual provider
works, no cancellation success for nonexistent work, no hidden network
requests in offline mode, and no declaration that Phase 2A is integrated
based solely on passing Flutter host tests. Until these gates pass, maintain
`SDK_NOT_INSTALLED` behavior and existing recovery flows.
