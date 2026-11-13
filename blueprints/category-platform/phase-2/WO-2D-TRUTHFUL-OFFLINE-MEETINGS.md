# WO-2D — Truthful offline meeting discovery (no fabricated real-world results)

**Priority:** P0 recovery access and user trust  
**State:** design-only / implementation and device acceptance pending  
**Related:** `WO-2B-MEETING-NORMALIZATION.md`, `WO-2C-JOURNEY-WEATHER-UX.md`, `lib/services/meeting_finder_service.dart`.

## Verified defect and current behavior

`MeetingFinderService.findNearbyMeetings` calls `sampleDirectory(lat, lng)` when no verified cached/live directory exists. That function constructs **13 fictional 'SAMPLE' meetings**, made-up meeting names and addresses, and plausible-looking geographic coordinates derived from the **user's actual search coordinates**. Those objects enter the same UI type as real TSML meetings. `MeetingMapScreen` contains external directions and a 'Pass the Basket' action driven by meeting fields; native journey planning already recognizes synthetic records but that does not cover every direct UI handoff. Before a small containment patch, eight SAMPLE records also carried live-looking Venmo/PayPal links.

A recovery companion must not portray fabricated nearby meeting options as verified services, especially when the network is unavailable. No actual live feed failure, device behavior or real-world navigation outcome was tested in this audit.

## Execution slices

**2D-A — Separate demo/test fixtures from production search.** Replace production `sampleDirectory` fallback with an empty/explicitly unavailable state when there is neither a verified cache nor an authorized successful refresh. Move SAMPLE constructors into `test/fixtures` or a behind-explicit-debug-only demonstration path. Do not change authentic cached results or erase an existing cache when network access fails.

**2D-B — Provenance model.** Each meeting entering a view should have stable `sourceId`, `sourceMeetingId`, trust type (`live`, `cached`, `curated`, `synthetic`), last validated/fetched-at timestamp and errors. Prefer a typed provenance enum over name-string pattern detection. Real manual/community sources are unverified unless explicitly stated. Preserve existing saved meeting identity through migration.

**2D-C — UI failure truth.** Show 'No verified meetings available offline' or 'No results for this pathway/radius' rather than fabricated pins; expose a controlled, consent-gated retry and previously saved addresses. Distinguish the empty-source, denied-consent, stale-cache, all-filtered and feed-error states. Don't imply the app can fetch a new meeting when offline.

**2D-D — Defense in depth.** Prevent fake or unverified records from receiving external driving/walking directions, calendar reminders presented as confirmed real meetings, sponsor/user attendance proofs, and 7th-Tradition donation prompts. Both Flutter direct handoff and Atlas bridge must independently enforce provenance. Don't rely solely on `MeetingJourneyPlanner.isSynthetic` because other buttons open maps directly.

**2D-E — Tests and UX.** Unit tests for empty cache/no internet/denied consent, valid cached meetings while offline, 13 SAMPLE fixtures confined to test-only, every outgoing directions/donation path refusing synthetic records, accessibility labels and meaningful retry. Widget tests across the meeting map, dashboard card and nearby list at 100–200% text scale. Do not request location or connect to a feed without the appropriate current-session privacy permission.

## Acceptance and rollout

Run analyzer, all Flutter tests, existing 14 architecture invariants and both self-tests, and Firebase emulator matrix. Validate on representative Android devices with airplane mode on and off, clean install vs upgraded populated cache, disabled feeds and path-filter combinations. Take screenshots or logs proving zero false real-world destinations. Confirm any previously issued synthetic IDs do not corrupt saved authentic meeting records. Do not advertise this feature as verified or release it without manual acceptance.

## Explicit exclusions

Do not generate replacement fictitious meetings in another subsystem, silently widen fellowship filters to all providers, return synthetic results under a plausible `live` status, infer that an external navigation app validated the address, or invent live meeting times.
