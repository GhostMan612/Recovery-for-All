# WO-2A — Consume Atlas SDK from Flutter (high-priority integration spike)

## Baseline evidence

The active Metro `master` has `core/atlas-engine` (`AtlasEngine.kt`), provider-neutral static GTFS and routing, optional weather/radar and offline registry, `build.gradle.kts` Maven publication task, and [SDK_INTEGRATION.md](https://github.com/GhostMan612/Metro-IntelliTrip/blob/master/docs/SDK_INTEGRATION.md). SDK baseline `com.intellitrip.atlas:atlas-engine:0.1.0` is documented; verify actual local published artifacts and transitive dependencies. Some remote fallbacks call an external OTP provider: **disable or gate them explicitly**.

## Phase 2A isolation/compatibility gates

1. Before changing RFA, on the developer's local machine **read** Metro README/AGENTS/SDK guide. Under Metro's own rules, make versioned local SDK artifacts available using documented `publishAtlasToLocalRepo` only with the required owner authorization. Source repository remains separately managed: do not edit Metro or push to it.
2. Inspect RFA `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/recoveryforall/MainActivity.kt`, Flutter minSdk, AGP 9.1.0, Kotlin 2.4.0 at observed baseline and Java 17, and Metro's `build.gradle.kts`. Make compatibility matrix; stop on unresolved plugin/ABI conflict.
3. Before integration, record and verify the immutable SDK artifact coordinates, source revision/tag, exact artifact and transitive dependency set, SHA-256 digests, publication command and local repository layout. The cited `0.1.0` is a documented candidate version, not proof that the artifact exists or is reproducible. Stop if artifact bytes, checksum provenance, license or dependency graph cannot be independently established; do not invent a checksum. Add a **local Maven file repository reference** in settings using Gradle-supported syntax and a verified user filesystem path (do not hardcode a guessed `C:` drive path or check in a machine-specific absolute directory); keep a documented local-untracked property/env indirection and prove offline resolution of the verified bytes. Require exact version pins, no dynamic `+`.
4. Add `implementation("com.intellitrip.atlas:atlas-engine:<pinned_version>")` in RFA app dependencies, only after verifying `minSdk>=26` compatibility **without** silently dropping older devices; choose an opt-out/older branch strategy if incompatible.
5. Add **NEW** `android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasChannelAdapter.kt` and `AtlasProviderFactory.kt` if necessary; use `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recoveryforall/atlas_v1")` with a distinct namespace from step counter. Consider moving registrations out of MainActivity for readability but preserve existing `FlutterFragmentActivity` lifecycle.
6. Add **NEW** `lib/features/navigator/data/atlas_bridge.dart`, `atlas_dtos.dart`, `navigator_repository.dart`; typed errors, plugin/platform fallback and cancellable request IDs, bounded payloads. No direct Dart import of Kotlin classes. Avoid blocking Android main thread; `MethodChannel` async native calls execute in appropriate coroutine/worker, respect lifecycle and `result.success/error` exactly once.
7. Add **NEW** `test/navigator/atlas_bridge_contract_test.dart` with fake channel; test unsupported version, nulls, corrupt native JSON/map, no permission, timeouts, exception and fallback.

## Native channel V1 command set

See `BRIDGE_API_CONTRACT.md`. Minimum `getCapabilities`, `loadStaticNetwork`, `planJourney`, `cancelRequest`, `getOfflineStatus`. Weather can be stubbed `unsupported` until a provider is wired; do not report capability 'true' because a class exists.

**Critical distinction:** a Kotlin library published as `atlas-engine` **does not magically provide a configured GTFS provider, network snapshot, remote routing, or Flutter bindings.** `AtlasEngine(FeedId, AtlasProviders(routing=...))` must be constructed with a working local `StaticNetworkPlanner`, snapshot store and relevant provider factory. If this cannot be done from the public engine API, document the missing seam and request a separately authorized Metro SDK interface change; do not import inaccessible internals or force-copy engine code.

## UX fallback

If SDK unavailable/missing artifact/older Android/broken permissions: keep RFA map and meeting details functional; label route planning unavailable and offer **user-initiated** external directions as a clearly disclosed fallback, respecting P0 consent. No reboot/crash.

## Gate

Locally build native bridge; show one **synthetic** scheduled route fixture transferred Kotlin→Flutter and rendered correctly with legs; show null/permission/network-disabled errors; verify no HTTP from local-only plan using a network spy. Human Android Studio build, device smoke and Gradle dependency list must be attached. See tests in `ACCEPTANCE_AND_TESTS.md`.
