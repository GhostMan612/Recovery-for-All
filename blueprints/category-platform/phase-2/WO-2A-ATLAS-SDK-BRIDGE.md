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

## Implementation record (2026-11-13)

**Owner authorization supersedes the local-only publication constraint in step 1.** The owner directed publication of the producer artifacts from Metro-IntelliTrip so a clean clone can resolve them. Producer work was done in the separate Metro repository and merged there; RFA consumed only the immutable published coordinates.

- **Producer:** Metro-IntelliTrip PR #19 merged to `master` as `781af81`; tag `atlas-v0.2.0`; publish workflow run `43554954525`; append-only `atlas-maven` branch at `d1aae736f08fdbecd8e3c65bc6fdf6e20d3d5045`. The remote POM `https://raw.githubusercontent.com/GhostMan612/Metro-IntelliTrip/atlas-maven/com/intellitrip/atlas/atlas-engine/0.2.0/atlas-engine-0.2.0.pom` returned HTTP 200 from a clean environment.
- **Consumer branch:** `feat/atlas-sdk-integration`, cut from `main`. The preserved WIP branch was not modified.
- **Coordinates:** `com.intellitrip.atlas:atlas-engine:0.2.0`, `atlas-gtfs-static`, `atlas-offline`, `atlas-routing`. The version is pinned once in `android/gradle.properties` (`atlasVersion=0.2.0`); no ranges, `+`, or SNAPSHOT. `android/build.gradle.kts` resolves the append-only branch, supports an `atlasMavenUrl` override for a staged repository, and applies a `com.intellitrip.atlas` content filter.
- `atlas-gtfs-realtime` is excluded: it pulls full `protobuf-java`, which collides with Firebase's `protobuf-javalite`. Realtime is disabled in this build.
- **API gate:** `AtlasChannelAdapter` contains no Atlas imports. On API 26+ it delegates through `AtlasBridgeFactory` to `AtlasNativeBridge`; API 24/25 keeps the typed `SDK_NOT_INSTALLED` fallback, so `minSdk` is unchanged. Narrow R8 keeps cover the factory and bridge.
- **Static feed:** `assets/gtfs/metro_transit_regional.zip` (948,264 bytes, SHA-256 `0164765858d353001f42d66a40430d2ed6b2085cb859e0574df08b6a5ddbe2d6`) plus `PROVENANCE.txt`. It is seeded through `StaticFeedRefresher` with an in-memory `HttpTransport`; no network request leaves the device. The snapshot's `fetchedAt` is the capture time, not app launch time.
- **Boundary note:** the current engine API does not expose static-feed loading or offline providers, so the app depends directly on `atlas-gtfs-static`, `atlas-offline`, and `atlas-routing`. This is a documented SDK boundary follow-up, not a claim that `atlas-engine` alone is sufficient.
- `fromCacheOnly=false` reports `remote_disabled` because no remote acquisition path exists. It does not download.

### Verified

- **Branch implementation & latency/fallback fixes (2026-11-14):**
  - `meeting_map_screen.dart` opens the modal bottom sheet immediately via `_openDirections` + `_prepareDirections` + `FutureBuilder`, rendering a themed loading state (`AppLoadingState`) and immediate Google Maps fallback button while route computation runs, plus a 4 s timeout on optional weather lookup.
  - `AtlasNativeBridge.kt` avoids double-parsing the bundled GTFS feed during `ensureEngine` (`seedFromBundledAsset` returns the activated `StaticFeed` directly and re-seeds when `active.metadata.fetchedAt < BUNDLED_FEED_CAPTURED_AT`), checks expiry against both `Clock.System.now()` and `effectiveDepartAt`, and plans with `maxTransfers = 1` first before falling back to `maxTransfers = 2` only when empty/unavailable.
  - `MeetingJourneyPlanner` enforces a cancellable `planTimeout` (12 s default calling `NavigatorRepository.cancelJourneyRequest`) and lets `AtlasErrorCode.noItinerary` fall through to the in-app direct-walk estimate when within range (`<= 5 km`), covered by unit tests in `test/navigator/meeting_journey_planner_test.dart`.
- **Earlier 2026-11-13 device checks (pre-fix APK):** Debug APK built against the remote repository and contained `assets/gtfs/metro_transit_regional.zip`, `PROVENANCE.txt`, `AtlasNativeBridge`, `atlas_static_planner`, and `metro-transit-regional`. On API 34 (LG B160V), the bundled feed seeded snapshot, `stop-times.dat`/`.idx`, and `static-feed.cache` under `files/metro-transit-regional`.

### Not verified / release blockers

- **API 24/25 fallback is not device-tested on this branch.** Attached devices are API 34 and 36. PR #42 adds API < 26 fallback correctness and records an API 24 AVD run; this branch's source contract tests cover the fallback shape only.
- **Journey UI is device-verified on API 34 (2026-11-14).** The refreshed debug build rendered 5 transit itineraries in 3,691 ms; in-flight Close and KEYCODE_BACK both cancelled natively; offline routing fell back without a crash. The earlier 2026-11-13 pre-fix APK timeout is retained above as history.
- **Feed expiry:** the refreshed bundled feed has 8,545 stops and is valid through **2027-01-01**. The earlier 2026-10-10–2026-11-27 window applies only to the 2026-11-13 snapshot. A live post-2027-01-01 refresh is still covered by deterministic injected-clock tests rather than a calendar-rollover device run.
- Debug APK only. This is not a release artifact and not a Play distribution.

### Later increments (2026-11-14)

The 0.2.0 record above is the original bridge landing and is retained as history. The producer subsequently published `atlas-v0.3.1` (PR #21, `af69792`, publish run `43601348105`) and `atlas-v0.3.3` (PR #23, `55eb754`, publish run `43633406068`); `atlas-maven` serves 0.2.0 through 0.3.3, and the 0.3.3 POM resolves HTTP 200. Consumer PR #41 moves the pin to 0.3.1 and adds request-ID cancellation, the immediate loading sheet, the 12 s timeout with walk fallback, and the refreshed 8,545-stop feed valid through 2027-01-01 with consent-gated refresh. Stacked PR #42 moves the pin to 0.3.3, adds Gradle dependency-verification checksums, Pass-2 budget/shape-free cache/index transcode hardening, and API < 26 `refreshStaticFeed` fallback correctness.

The earlier **2026-11-27** feed-expiry note is superseded by the refreshed feed; it remains accurate for the 2026-11-13 snapshot only. The remaining expiry gap is the live post-2027-01-01 refresh, covered by deterministic injected-clock tests.

PR #42 also records an ephemeral Android 7.0 (API 24) AVD run: the Settings transit-refresh path returns typed `PERMISSION_REQUIRED` / `SDK_NOT_INSTALLED` instead of `MissingPluginException`, `Get Directions` falls back to external navigation, and logcat shows no Atlas `VerifyError`/`NoClassDefFoundError`. The AVD was deleted after the run.
