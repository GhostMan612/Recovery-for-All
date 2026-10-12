# Phase 2 — Meeting Navigator powered by Metro IntelliTrip Atlas

**Status:** blueprint only. Three bounded implementation work orders. Metro IntelliTrip's implementation lives on **`master`** at baseline `a7d77e4`; default `main` is only an initial README.

## The promised user interaction

A user selects a **real, source-attributed meeting** → sees eligibility and schedule confidence → taps **Plan my journey** → gets options for walking/transit, stop names, transfers and *realistic arrival buffer* → sees heat/cold/rain/alert exposure with source age → can save an approved region/GTFS snapshot for prepared offline use. Planning never proves attendance; location and route history remain local.

## Work order order

1. [WO-2A-ATLAS-SDK-BRIDGE.md](WO-2A-ATLAS-SDK-BRIDGE.md): versioned local Maven SDK dependency; Android MethodChannel adapter; safe failures and no implicit remote fallback.
2. [WO-2B-MEETING-NORMALIZATION.md](WO-2B-MEETING-NORMALIZATION.md): source-scoped meeting identity, timezones/recurrence, freshness and SAMPLE guard.
3. [WO-2C-JOURNEY-WEATHER-UX.md](WO-2C-JOURNEY-WEATHER-UX.md): usable route cards/polylines and optional weather, transfer confidence, accessible alternatives.

Read [BRIDGE_API_CONTRACT.md](BRIDGE_API_CONTRACT.md), [OFFLINE_AND_LOCATION_PRIVACY.md](OFFLINE_AND_LOCATION_PRIVACY.md), [ACCEPTANCE_AND_TESTS.md](ACCEPTANCE_AND_TESTS.md), and [AGENTS.md](AGENTS.md).

## Architectural principle

**Do not replace Recovery for All's Flutter map** with IntelliTrip's Compose/MapLibre screen. Consume portable Atlas engine functionality via a dedicated Kotlin adapter, return small sanitized DTOs over one `MethodChannel`, render in Flutter with the existing `flutter_map` and offline tile provider. The SDK can have an independent release lifecycle; pin version/checksum and never compile by reaching into Metro source from RFA.

**Known constraints:** Atlas targets Android minSdk 26; RFA currently uses Flutter's minSdk variable. Verify minSdk, AGP/Kotlin/Gradle compatibility on the local host before adding dependency. IntelliTrip `AtlasEngine` providers are optional; `capabilities().routing == true` only after a *working configured provider* is wired. Offline GTFS does not imply offline basemap. Live weather/radar requires network freshness and consent.
