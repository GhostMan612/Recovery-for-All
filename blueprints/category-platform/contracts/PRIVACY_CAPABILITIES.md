# Local-First Capability Policy — Design Contract

**Rule:** being signed in anonymously to Firebase is not *user consent*. Access to GPS, routing destinations, weather requests, cloud posts and peer proof is separately consented. There is no general 'cloud on' master switch that secretly changes behavior across features.

| Capability | Local behavior | Network behavior | Safe default | Revocation |
|---|---|---|---|---|
| Core recovery | encrypted local records | none required | enabled | clear/export with disclosure |
| Companion & quest | local event journal | no automatic game telemetry | optional enabled | disable animations/game surface, keep underlying recovery data |
| Meeting directory | cached items and explicit provenance | optional feed refresh, provider sees requesting IP | user-initiated or clear update setting | pause refresh, keep local cache |
| Map tiles | previously stored licensed tiles | tile server sees tile requests/IP; coordinates indirectly inferable | local tile preference if installed | disable network tiles; clear cached map separately |
| Location | on-device GPS/typed city | third-party not given raw GPS without specific feature action | off until permission/action | OS permission and in-app revoke |
| Atlas scheduled routing | installed static GTFS data, local origin/destination | none when local planner answers | on-device first | no further data sent |
| Atlas remote fallback | N/A | destination/origin exposed to routing provider | **disabled by default**; prompt before first request | disable + clear optional history |
| Weather/NWS | last cached forecast with timestamp | forecast location/IP sent to weather provider | opt-in for location-specific request | turn off network refresh |
| Circle draft | local encrypted draft/outbox | none until explicit publish | draft local | delete locally |
| Circle publish/reaction | read local history | identity/alias/body metadata on service; peers receive approved fields | opt-in, Phase 0 trusted protocol required | stop new publishing; delete remote under verified policy |
| Sponsor exchange | signed/encrypted local pair workflow | optional relay after consent | local first | revoke partnership and rotate relevant keys where supported |

**Implementation API proposal:** `PrivacyCapabilityController.canAccess(Capability, Context) -> GrantDecision`, backed by audited persisted decisions. Do not define per-feature private booleans that disagree. `ConsentRecord` stores capability, grant/revoke timestamp, policy version and UI evidence. Avoid storing location/protected details in the consent record itself.

**Requests made on behalf of user:** show who receives data, what is transmitted, whether cloud/OS transport persists it, when last used, how to revoke; cache-only view should remain available without surprise requests.

**Safety:** Care/SOS emergency call or externally routed emergency support must remain one tap, with explicit platform behavior (phone/SMS/988/911 as appropriate). Consent revocation must not block emergency UI.

**Traceability:** implement P0 privacy contract before Phase 2 network integration or Phase 3 remote expansion. Audit Android HTTP logs at the process boundary on a device (synthetic data) and third-party storage claims before publishing new privacy language.
