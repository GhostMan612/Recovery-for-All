# Network, privacy, capability and consent inventory

**Observed remotely at `6f985f3`**; this is not a packet-capture audit. Distinguish what is **local**, **provider-visible**, **shared to Firebase**, and **intentionally exported by the user**. A provider can see network metadata even when Recovery for All does not retain tracking identifiers.

| Surface / entry | Current source | Data / recipient | Current consent behavior | Phase 0 target |
| --- | --- | --- | --- | --- |
| App cold boot with Firebase configured | `lib/main.dart` | Firebase initialization and `signInAnonymously()` session | Attempted at boot regardless of whether Circle opened | Defer auth until explicit connected-Circle action/opt-in; private core remains accountless |
| Community feed read and publish | `lib/services/community_feed_service.dart` | Firebase UID, selected alias/post/body/timestamp and public reaction counters | Auto stream after authentication when Firebase installed | Distinct local-draft/shared states; explicit first-post disclosure; enforce server-side ownership/moderation |
| Sponsor cloud relay | `lib/services/sponsor_link_service.dart` | Selected bundle, uid and metadata to Firestore if used | Optional relay with ownership partition; cross-account limitations | Explain upload boundary; preserve offline messenger path; do not promise E2EE for cloud until verified |
| Map tiles | `lib/screens/meeting_map_screen.dart`, `lib/services/map_tile_cache.dart` | Tile coordinates/area, requests/IP to tile hosts | Request when online tile needed | Offline map mode and provider disclosure, lawful offline package sources and cache caps |
| Weather chip | `lib/screens/meeting_map_screen.dart::_loadWeather` | Latitude/longitude to `api.open-meteo.com` | Called when map view loads; no separate precise-location network consent | Off by default for precise coordinates until affirmative choice; coarse location possible if approved; explicit timestamp/source |
| Meeting feed refresh | `lib/services/meeting_finder_service.dart` | Requests to third-party meeting directories; some geo-bounded | Background refresh possible; map source metadata | Prefetch/refresh understandable; local cached data usable, freshness visible; avoid logging precise location |
| External directions | `lib/screens/meeting_map_screen.dart` | Selected meeting lat/lng or address to Google Maps URL / external app | User tapping directions triggers external app | Inform of handoff; optional local Atlas SDK route when shipped; do not silently route online |
| SOS/notifications | `lib/services/sos_notification_service.dart`, `lib/services/gentle_reminder_service.dart` | Local notification flows; optional user-selected calls, care alerts | Varies by feature setting | Keep emergency access immediate; no inferred attendance or game reward; audit remote destinations separately |
| AI model downloading | `lib/services/gguf_model_service.dart` | Model download and network metadata | User-initiated model workflow | Clear model size, provider and offline inference distinction |
| Existing local journal, pet, recovery records | `lib/database/recovery_database.dart` | Drift/SQLCipher local; journal app-level crypto for relevant flows | No cloud copy by default described for personal core | Preserve encryption, backups/deletion handling and key migration |
| GPS last fix | `lib/screens/meeting_map_screen.dart` / preferences | Coordinates retained in device preferences | Permission/last-known fallback | Consent to device location distinct from consent to send coordinates to weather/routing provider |

## Proposed capability flags (design contract, not yet wired)

`NetworkMode = offlineOnly | providerQueries | connectedCircle`, with separately persisted user choices for `remoteWeather`, `remoteRouting`, `directoryRefresh`, `onlineTiles` and `circleShare`. Default local-only **requires a behavior change**: present the user with a clear consent model and seek owner approval before switching current connected behavior. A one-time location permission is NOT consent to submit GPS to a weather endpoint.

Every provider call should return `fresh`, `stale`, `unavailable`, `deniedByPolicy`, `notYetPrepared` as appropriate. The app must not fabricate offline coverage from sample fixtures.

### Required tests

1. Cold boot with Firebase configured but Circle not enabled: prove no anonymous sign-in; no Circle network reads/writes.
2. Deny precise-weather sharing: prove zero weather HTTP calls even when map entered/reentered; still render cached map or a neutral no-weather state.
3. Deny external routing: no external intent or remote route request; a clear action permits it.
4. Opt into one provider only: avoid enabling unrelated providers or Firestore implicitly.
5. Rotate/deny location permission, kill/restart, start offline: no privacy mode regression; no assumption of available route.
6. Review requests using an emulator proxy/device logs; redact identifiers and actual coordinates in saved evidence.

### Caveats

Cloud data already shared may remain at the provider after this change. Local uninstall/clear does not delete cloud copies. Local alias does not guarantee anonymity; transport TLS is not content E2EE. Route endpoints, weather and map tiles require checking actual provider terms before caching or redistribution.
