# WO-2A — Consume Atlas SDK from Flutter (high-priority integration spike)

## Baseline evidence

The active Metro `master` has `core/atlas-engine` (`AtlasEngine.kt`), provider-neutral static GTFS and routing, optional weather/radar and offline registry, `build.gradle.kts` Maven publication task, and [SDK_INTEGRATION.md](https://github.com/GhostMan612/Metro-IntelliTrip/blob/master/docs/SDK_INTEGRATION.md). SDK baseline `com.intellitrip.atlas:atlas-engine:0.1.0` is documented; verify actual local published artifacts and transitive dependencies. Some remote fallbacks call an external OTP provider: **disable or gate them explicitly**.

## Phase 2A isolation/compatibility gates

1. Before changing RFA, on the developer's local machine **read** Metro README/AGENTS/SDK guide. Under Metro's own rules, make versioned local SDK artifacts available using documented `publishAtlasToLocalRepo` only with the required owner authorization. Metro IntelliTrip is a separate repository: do not edit it or push to it as part of this work order.
2. Inspect RFA `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/recoveryforall/MainActivity.kt`, Flutter minSdk, AGP 9.1.0, Kotlin 2.4.0 at observed baseline and Java 17, and Metro's `build.gradle.kts`. Make compatibility matrix; stop on unresolved plugin/ABI conflict.
3. Before integration, record and verify immutable SDK artifact coordinates, source revision/tag, exact artifact and transitive dependency set, SHA-256 digests, publication command, and local repository layout. The cited `0.1.0` is a documented candidate, not proof that the artifact exists or is reproducible. Stop if artifact bytes, checksum provenance, license, or dependency graph cannot be independently established; never invent a checksum or silently publish/consume an artifact. Add a **local Maven file repository reference** in settings using Gradle-supported syntax and a verified user filesystem path (do not hardcode a guessed `C:` drive path or check in a machine-specific absolute directory); use documented local-untracked property/env indirection and prove offline resolution of the verified bytes. Require exact version pins, no dynamic `+`.
4. Add `implementation("com.intellitrip.atlas:atlas-engine:<pinned_version>")` in RFA app dependencies, only after verifying `minSdk>=26` compatibility **without** silently raising RFA's Android minimum SDK or dropping older devices. If incompatible, stop for an explicit owner decision and document an opt-out/older-device strategy.
5. Add **NEW** `android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasChannelAdapter.kt` and `AtlasProviderFactory.kt` if necessary; use `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recoveryforall/atlas_v1")` with a distinct namespace from step counter. Consider moving registrations out of MainActivity for readability but preserve existing `FlutterFragmentActivity` lifecycle.
6. Add **NEW** `lib/features/navigator/data/atlas_bridge.dart`, `atlas_dtos.dart`, `navigator_repository.dart`; typed errors, plugin/platform fallback and cancellable request IDs, bounded payloads. No direct Dart import of Kotlin classes. Avoid blocking Android main thread; `MethodChannel` async native calls execute in appropriate coroutine/worker, respect lifecycle and `result.success/error` exactly once.
7. Add **NEW** `test/navigator/atlas_bridge_contract_test.dart` with fake channel; test unsupported version, nulls, corrupt native JSON/map, no permission, timeouts, exception and fallback.

## Native channel V1 command set

See `BRIDGE_API_CONTRACT.md`. Minimum `getCapabilities`, `loadStaticNetwork`, `planJourney`, `cancelRequest`, `getOfflineStatus`. Weather can be stubbed `unsupported` until a provider is wired; do not report capability 'true' because a class exists.

**Critical distinction:** a Kotlin library published as `atlas-engine` **does not magically provide a configured GTFS provider, network snapshot, remote routing, or Flutter bindings.** `AtlasEngine(FeedId, AtlasProviders(routing=...))` must be constructed with a working local `StaticNetworkPlanner`, snapshot store and relevant provider factory. If this cannot be done from the public engine API, document the missing seam and request a separately authorized Metro SDK interface change; do not import inaccessible internals or force-copy engine code.

## UX fallback

If SDK unavailable/missing artifact/older Android/broken permissions: keep RFA map and meeting details functional; label route planning unavailable and offer **user-initiated** external directions as a clearly disclosed fallback, respecting Phase 0 consent. Location-aware routing/weather/network calls require the applicable explicit consent and remain disabled when consent is denied or absent. No silent location upload, reboot, or crash.

## Gate

Locally build native bridge; show one **synthetic** scheduled route fixture transferred Kotlin→Flutter and rendered correctly with legs; show null/permission/network-disabled errors; verify no HTTP from local-only plan using a network spy. Human Android Studio build, device smoke and Gradle dependency list must be attached. See tests in `ACCEPTANCE_AND_TESTS.md`.


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
