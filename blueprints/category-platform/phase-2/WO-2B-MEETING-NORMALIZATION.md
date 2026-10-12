# WO-2B — Turn the Meeting Directory into Trustworthy Destinations

## Baseline

`lib/services/meeting_finder_service.dart`: AA/NA and additional feeds, file-backed JSON directory cache, refresh coverage gate, `cacheTtl=24h`, sample fallback items. `lib/screens/meeting_map_screen.dart`: GPS cascade, filters, weather chip, detail sheet, external directions and locally logged attendance. Different feed formats encode recurring times/days inconsistently. We must not route to sample or malformed coordinates.

## Files and seams

| Path | Change |
|---|---|
| `lib/services/meeting_finder_service.dart` | wrap source parsing in stable source-scoped IDs, freshness and result provenance; don't break current curated directory |
| **NEW** `lib/features/navigator/domain/meeting_destination.dart` | `sourceId`, `sourceMeetingId`, meeting type, coordinate validation, address, IANA zone, recurrence/exception, source URL, `isSynthetic`, sourceFreshness |
| **NEW** `lib/features/navigator/data/meeting_destination_adapter.dart` | convert `RecoveryMeeting` into strict destination; reject bad geodata without crashing directory |
| **NEW** `lib/features/navigator/application/meeting_schedule_resolver.dart` | compute next actual occurrence, daylight saving, daylight crossing, exceptions if available; 'unknown schedule' when feed insufficient |
| `lib/screens/meeting_map_screen.dart` | true itinerary entry-point only for eligible destination; indicate data-age and stale times; don't invent route availability |
| `lib/services/map_tile_cache.dart` | preserve cache-first tile policy; do not reuse location history for automatic prefetch; check tile vendor download terms |
| **NEW** `test/navigator/meeting_destination_test.dart`, `meeting_schedule_test.dart` | synthetic BMLT/TSML fixture, DST and invalid coordinate tests |

## Important constraints

- Identity is `(feedProviderId, providerMeetingId)`; coordinates/name alone are not identity. Mergers across AA/NA sources require explicit equivalence rules and confidence; do not silently dedup different meetings.
- Unknown times are *unknown*, not '7pm today'; honor meeting's local timezone and source day-of-week, service-day differences, virtual-only meetings, open/closed accessibility and temporarily canceled statuses when available.
- Distance from location is not authorization to check in. A user-entered attendance record is self-report. Geofencing, peer attestation and signed sponsor artifacts are distinct and require transparent claims.
- Fixture/sample records have `isSynthetic=true`; no external directions, attendance XP, verified badge or live navigation CTA.
- Source metadata: fetchedAt, refresh status, last confirmed, feed coverage, provider and validUntil when meaningful. Show stale age in UI when 24-hour refresh missed.
- When geolocation denied, offer typed city/address and privacy-preserving map pan, not force Minneapolis GPS position to become user location.

## Gate

Use a *real cached meeting* (source provenance verified) plus a **synthetic** routing network. Display exact source and reasonable arrival target. Malformed feed coordinates, partial refresh and DST boundary must not create phantom nearby meetings. Offline first-run shows clear “No real meetings cached—connect to download” instead of fictional sample pins as actionable results.
