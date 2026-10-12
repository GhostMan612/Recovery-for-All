# AtlasBridgeV1 — Platform Channel Boundary Contract (proposed)

**Namespace:** `recoveryforall/atlas_v1` · **Serialization:** Flutter platform-channel safe primitives (`Map<String, Object?>`, lists, String/num/bool/null). Do not serialize Kotlin `Instant`, `Duration`, `Flow`, `GeoPoint` or sealed class instances directly. All timestamps are epoch milliseconds UTC, and zone ID is a separate IANA timezone string.

## Calls

| Call | Arguments | Response | Behavior |
|---|---|---|---|
| `getCapabilities` | `{"apiVersion":1}` | `{version:1,staticTransit:boolean,localRouting:boolean,realtime:boolean,weather:boolean,offlineSnapshot:boolean,providerIds:[]}` | no network side effect |
| `loadStaticNetwork` | `{apiVersion:1,requestId,feedId,fromCacheOnly:boolean}` | `{state:"ready|missing|stale|error",feedHash?,fetchedAt?,expiresAt?,stopCount?,source?}` | cache-only must not contact network |
| `planJourney` | `{apiVersion:1,requestId,meetingId,origin:{lat,lon},destination:{lat,lon},departAtUtcMs,arriveBeforeUtcMs?,maxWalkMeters,allowRemote:false,transitModes:["bus","rail"]}` | `JourneyPreviewV1` (list of bounded legs/options) or a typed error | no remote fallback if `allowRemote:false` |
| `cancelRequest` | `{apiVersion:1,requestId}` | `{cancelRequested:boolean}` | best-effort cancel, no guaranteed interruption |
| `getOfflineStatus` | `{apiVersion:1,feedId}` | `{staticNetwork,basemap,routing,dataAgeSeconds,notes}` | do not conflate data/map/routing |
| `getWeather` (future) | `{apiVersion:1,consentToken,location...}` | versioned weather forecast or `unsupported` | only after P0 consent; no automatic call |

## Error types

`UNSUPPORTED_VERSION`, `SDK_NOT_INSTALLED`, `MISSING_FEED`, `FEED_EXPIRED`, `NO_ITINERARY`, `PERMISSION_REQUIRED`, `REMOTE_DISABLED`, `NETWORK_FAILURE`, `TIMEOUT`, `BAD_INPUT`, `NATIVE_FAILURE`, `CANCELED`. Never return raw stack traces or source URLs with credentials.

## Limits and validation

- Latitude [-90,90], longitude [-180,180], finite numbers; drop NaN/Infinity; reject missing origin/destination.
- Require nonempty `requestId`; cap options (e.g. 5), legs (e.g. 12 per option), polyline points (e.g. 5000 per response), total serialized payload (1 MB design budget; measure on device).
- Reject timestamps > reasonable planning horizon or far past; use absolute instants, zone-aware local UI; account for transit times beyond midnight/service days >24h.
- Every returned route has `source=static_gtfs|live_augmented|remote_opt_in|synthetic_fixture`, `fetchedAt`, validity/freshness, `isSynthetic`, and a distinct confidence/unknown state for transfers.
- Deliberately set remote opt-in false in bridge. To turn on remote fallback, separate **human-visible** consent with destination disclosure and a documented trusted provider; prevent flags alone from silently transmitting location.
- No native log of raw locations, journal, meeting attendance or user's Circle activity.

## Example

See `../contracts/journey_preview_v1.schema.json` and `../contracts/fixtures/journey_offline_synthetic.json`. Fixtures must remain visibly synthetic and can never be shown as an authentic itinerary.

## Compatibility test gate

V1 produces/consumes only versions declared; old clients reject unsupported new major versions safely. Kotlin-to-Dart field names, numeric types, optionality and timezones are covered by fixture parity tests on both sides. Use a single serializer, not four widget parsers.
