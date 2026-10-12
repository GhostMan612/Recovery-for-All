# Phase 2 Acceptance, Tests and Evidence

**Applies:** CP-01, 06, 10–15, 21–24. Before declaring complete, require exact native SDK artifact/version/hash, Flutter+Kotlin bridge parity, tests and Android device run.

| Test ID | Setup | Required observable evidence |
|---|---|---|
| P2-001 | local Maven SDK `atlas-engine` resolved offline | dependency listing, version/checksum, no snapshot/dynamic dependency |
| P2-002 | minSdk/Gradle/Java/Kotlin audit | no unapproved device exclusion or build break |
| P2-003 | `getCapabilities` with no providers | routing/weather false; no network call |
| P2-004 | loaded static GTFS + local planner, airplane mode | one fixture route with bounded leg geometry |
| P2-005 | cold-first-run offline | explicit unavailable; no invented arrival or SAMPLE route |
| P2-006 | invalid GPS, NaN, malformed native DTO | typed error, no crash, no network exposure |
| P2-007 | actual cached provider meeting + local timezone DST test | correct occurrence, source/age visible |
| P2-008 | connection missed, cancellation, delay, stale realtime | warnings/unknown rather than 'on time' |
| P2-009 | invalid API version/cancel/unregister | no crash, no result double-completion or lifecycle leak |
| P2-010 | weather disabled, stale, NWS provider unavailable | routing still works; age/unknown visible |
| P2-011 | GPS denied, manual origin, locale accessibility | successful browsing/planning or clear limitation |
| P2-012 | external fallback with network capture | consent first; exact allowed domains/request data documented |
| P2-013 | tile cache quota/package validation, offline restart | map tiles correct or absence declared, no corrupted package |
| P2-014 | Moto 3 GB + offline map + transit planner, zoom and pan | no OOM/ANR, timings and memory recorded |

Run specific RFA tests (`test/meeting_finder_service_test.dart`, `test/meeting_finder_filters_test.dart`, `test/meeting_radius_test.dart`, `test/next_meeting_widget_test.dart`) plus new navigator tests. Metro's engine tests must be run under its own repository and rules as separately authorized local commands. Use simulated fixtures and real-world meeting tests separately; never present a fixture screenshot as genuine live service.

## Final human walkthrough

From the RFA dashboard open meeting map, choose genuine meeting from cached directory, read source and meeting time, request in-app trip, compare two route choices, inspect departure/walk/transfers/weather age, save plan, turn on airplane mode, reopen route with honest stale status, revoke GPS and repeat with manually entered origin, and confirm SOS and journal unaffected.
