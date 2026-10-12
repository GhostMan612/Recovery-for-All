# Privacy Policy — Recovery for All

**Original effective date:** September 1, 2026\
**Documentation clarification:** October 11, 2026 (Phase 0; product behavior is not changed by this document)\
**Contact:** privacy@recoveryforall.app

Recovery for All is designed to keep sensitive recovery work on your device by default. **Offline-first does not mean all networking is disabled.** The distinction between locally stored information, external service queries and optional social sharing is explained below. This clarification is not a representation that new consent controls have already been implemented.

## Information on your device

- Journal and other recovery records, counters, check-ins, goals, companion/game progress and much of the Circle's local state are stored in a local Drift/SQLCipher database. Application encryption keys are held through platform secure storage.
- Journal content also uses application-level encryption in relevant workflows.
- A location fix used for meeting search may be retained in app preferences for fallback; this cache is not itself described as SQLCipher-encrypted. The map can work with a manual or fallback area when GPS is unavailable.
- Downloaded meeting-directory JSON, map tiles and optional public GGUF model files may be stored in app-specific files and are not all covered by the encrypted database. Cached public meeting data should not be confused with private diary records.
- PIN/biometric settings and other local preferences use their respective platform facilities. Clearing app storage or uninstalling generally removes locally stored content; restore/backup behavior depends on platform settings and app implementation.

## Connected features and service recipients

| Action or configuration | Data sent or exposed to a provider | Current implementation caveat |
| --- | --- | --- |
| Load an online map or tile | Requested map tile/area and network metadata (such as IP address) to the tile provider | Rendering an online map can initiate these requests. Map caching does not eliminate a first-use request. |
| Load map weather | Latitude/longitude sent to Open-Meteo to request current temperature/weather code | The current map screen can request weather when map view loads; an explicit separate weather-consent gate is **not yet implemented**. |
| Refresh meeting directories | Requests to third-party AA/NA/other directory feeds; providers receive network request metadata | Directory freshness depends on their availability. Certain feed requests can be geographically scoped. |
| Open directions externally | Selected meeting address/coordinates passed to an external navigation application or URL | External applications have their own policies; this is not yet a wholly in-app transit journey. |
| Use a configured community feed | Firebase initialization and anonymous-auth UID/session at startup on configured installs; selected author alias, post text, reactions and timestamps on connected Circle use | Firestore stores shared content when configured; this is not end-to-end encrypted. Remote post deletion and server-authorized moderation need improvement. |
| Share sponsor bundles through optional cloud relay | Auth/session and selected step-work bundle metadata or payload | The default messenger/export path can be used without the cloud relay. Owner-partitioned Firestore rules apply to supported relay paths. |
| Download a local AI model | Provider request metadata when fetching the public model | Once installed, local model generation can run on-device. |

There is no advertising SDK or analytics service claimed in the current release design. **No claim is made that these third-party providers receive no data**: they receive the specific requests described above when their connected features are used. We do not sell journal or recovery data to advertisers.

## Location

Location permission is optional. Meeting lookup may use a fresh device position or local cached fix, depending on permission and availability. The application does not intentionally upload a continuous GPS history as part of its private progress tracking; nevertheless **weather queries may send a precise location to an external weather provider, and routing links share the selected destination**. These are distinct from storing a GPS history on a Recovery for All server.

The product team has recorded a Phase-0 requirement for explicit, understandable controls over precise-location network calls, external routing and optional connected sharing. Until verified in a release, these controls must not be advertised as already enforced.

## Online community limitations

When Firebase is configured, `lib/main.dart` currently attempts Firebase initialization **and anonymous sign-in during startup, before the user opens the Circle**. This is a known Phase-0 consent issue, not a completed opt-in mechanism. The Circle is a shared feed for signed-in sessions (typically anonymous authentication), not an encrypted private inbox. Users should avoid posting identifying information or sensitive details they do not want other Circle participants to see. Display aliases alone do not provide anonymity against all observers or the service provider.

**Known limitation:** The current UI can remove a post from the local database without ensuring its previously mirrored Firestore copy is deleted for other users. Network moderation remains local-only, and remote reactions lack robust per-actor anti-abuse enforcement. Remote deletion, reporting, blocking and moderation are scheduled as security-gated engineering work; do not assume they are available today.

## Permissions

| Permission | Purpose | Optional? |
| --- | --- | --- |
| Location | Nearby meetings and local attendance-distance checks | Yes; fallback/manual discovery remains available where implemented |
| Activity recognition | Walk/pedometer features | Yes; manual alternatives exist |
| Notifications | Reminders and SOS notification features | Yes; behavior varies with permission |
| Biometrics | Local app access protection | Yes |

## Data deletion and control

Device-local data can generally be removed by clearing application storage or uninstalling. These actions **do not guarantee deletion of content already sent to a remote service or another person's device**. Connected-post deletion and remote-data erasure procedures require further verification. The contact address above is the currently documented privacy contact for deletion requests; do not treat a request as completed until verified.

## Children and safety

This app is not directed to children under 13. Recovery tools and AI responses are supplemental resources and do not replace clinical care or emergency response.

## Review status

This document records observed code behavior and known limitations, not an independent network audit or legal certification. It must be reviewed against the shipped build, providers' current terms and legal requirements before publication as a store policy. Material changes to actual collection or sharing require corresponding notices and controls.
