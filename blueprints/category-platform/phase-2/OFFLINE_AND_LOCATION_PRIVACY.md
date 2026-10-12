# Phase 2 Offline, Provider Terms and Location Policy

## Four separate offline capabilities

1. **Meeting directory:** real source data cached; freshness/coverage known.
2. **Static transit:** valid cached GTFS snapshot + stop-time index + correctly configured local planner; without it routes cannot be computed offline.
3. **Basemap:** a legally cacheable tilepack with matching style. Transit snapshots do not render a map by themselves.
4. **Weather:** last known observation/forecast timestamp; no live update without network. Radar/alerts are fresh only within provider policy, not just while bytes are cached.

The UI should display these separately: `Meetings: cached 4h ago / Routes: offline-ready / Map: available / Weather: unavailable`. A single ambiguous “offline mode” chip is insufficient.

## Consent and threat model

- Local planner receives precise GPS coordinate only if permission granted, otherwise explicit manual origin. Coordinates remain device-local for offline results.
- Network tile servers may infer viewport, and weather/routing providers may receive coordinates or map tile geolocation, even if GPS is not directly uploaded. Document who receives what and honor explicit network permissions.
- Cloud Circle never receives route, visited stop IDs, departure times, home coordinates or planned meeting unless user previews explicit share content; source meeting names may also identify a person's recovery activity.
- Saved route plan remains in encrypted local storage or appropriately secured short-lived cache, with view/delete controls and retention policy. Do not create a telemetry trail of sensitive travel.
- Never embed raw provider API keys or claims of no external data processing when tiles/weather/network are used.

## Map license and storage caution

OSM data licensing does **not** automatically grant bulk-download rights to any hosted tile server. Check the terms for each chosen tile/style provider, attribution, rate limits and offline packaging. Use authorized extracts (e.g. self-generated or permitted offline packages) with provenance, checksum, manifest/path containment, size quota, integrity and cancellation. Metro fixed previously unsafe basemap identifier handling; preserve checks when adopting package APIs.

## Failure matrix

| Condition | Expected behavior |
|---|---|
| fresh device offline | personal app works; map/meeting/route capability truthfully missing |
| meeting cache only | show dated meetings; no fake route |
| GTFS static only | transit schedule available, but only when valid local planner configured |
| stale GTFS | warn/disable routes based on validity policy, offer safe alternatives |
| stale weather | mark 'last updated', do not call it now |
| denied GPS | manual origin/city and browse meetings still possible |
| no Atlas SDK | keep old meeting map, state native planner unsupported, ask before external maps |
| remote OTP blocked | return local route if available, otherwise unsupported; no leaked coordinates |
| app killed downloading tilepack | resumable/cancelable, atomic package activation and no partial claimed success |
| low storage | fail politely, preserve existing valid snapshot and journal |
