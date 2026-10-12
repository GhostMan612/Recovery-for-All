# WO-4B — 3 GB Device, Offline and Accessibility Hardening

## Test fleet and instrumentation

Target: Blu View 5 (~3 GB RAM), Moto G 2025 (device variant dependent), and ordinary host JVM/Flutter emulator. Actual device OS/API/ABI/memory must be recorded at test run, not inferred from marketing specs. GGUF must remain RAM-tier gated; Atlas routing + map + local Pet + SQLite should run on lower-tier devices with optional heavy animations disabled.

## Candidate budgets (targets, not measured facts)

- Cold start to responsive dashboard: target under 3 seconds on low-end after warm caches, measure 10 cold starts and publish p50/p95 before committing target. Avoid hard crash/OOM; choose meaningful measurable baseline if device cannot meet target.
- Map interaction: target responsive scrolling/pan with no sustained frozen frames; record frame timing, especially vector/raster overlays, marker clustering and route geometry.
- Native channel: output <1MB per request and no large stop-time lists sent to Dart; emit only selected journey geometry/metadata.
- Static GTFS parser: background worker with cancel and progress, bounded memory via Atlas disk stop-time index; never parse on Flutter platform UI thread.
- Tile and offline snapshot budgets: enforce configurable quotas, eviction, checksums and atomically installed packages, not unbounded disk growth; fallback without wiping user data.
- Crash/ANR: **zero observed** during test matrix (not warranty); record logs and repro precisely.
- Battery: test transit/live refresh pause/resume with screen off, no runaway wake locks or aggressive background GPS.

## Accessibility verification

- Text scale 1.0, 1.5 and 2.0; TalkBack semantics, labels, logical traversal, live-region announcements for route/risk updates and battle state.
- 48dp actionable targets or higher when reasonable, contrast and distinguishable icons without relying on color alone, orientation and narrow display.
- Reduced-motion removes flashes/shakes/battle FX but maintains text cues; screen-reader battle and quiet Quest variant.
- Routes explain walking distance, number of transfers, local departure/arrival time, stale realtime/unknown accessibility, not just colored polyline.
- Circle updates have clear local vs sent/delivered states and accessible moderation controls.
- Anxiety/minimal mode: mute reminders/battle sounds, hide engagement badges and skip gamification; SOS remains accessible.

## Failure injection grid

Airplane mode mid-route, 500 error on weather, expired GTFS, no tiles, 1% battery, nearly full disk, app process killed during download, failed unlock, stale GPS, denied permission, logout during send, duplicate events, offline restart after schema upgrade, hot update across midnight/DST. Record exactly what happened and whether user data remained accessible.

## Key paths

`lib/screens/meeting_map_screen.dart`, `lib/services/map_tile_cache.dart`, `lib/services/gguf_model_service.dart`, `lib/services/hardware_tier_service.dart`, `lib/screens/pet_trials_screen.dart`, `lib/widgets/app_primitives.dart`, `test/accessibility_contracts_test.dart`, `test/theme_matrix_test.dart`, Phase 2 native bridge and Phase 3 feed.
