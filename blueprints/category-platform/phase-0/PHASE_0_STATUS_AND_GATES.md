// blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md
# Phase 0 implementation status and gates

**Status at package creation — 2026-10-11 (Updated 2026-10-12).** Static inspection and local test gate verification. Do not convert statuses to PASS without machine/test evidence.

| ID | Result at packaging | Evidence, next step |
| --- | --- | --- |
| P0-01 source-accurate README | **DELIVERED in overlay, not runtime-tested** | Replaces broad unsupported competitor/privacy/proprietary claims; links this hub |
| P0-02 privacy-policy clarification | **DELIVERED in overlay, not legally reviewed** | Records Open-Meteo coordinate requests, external map links, online tile providers, Firebase anonymous sign-in at boot; does **not** create consent UI |
| P0-03 license resolution | **BLOCKED by owner/legal decision** | `LICENSE` remains MIT with Toxic Creationz copyright; old README proprietary claim corrected, license not modified |
| P0-04 Circle trust design | **DESIGNED only** | See threat model and protocol; current Firestore rules remain unchanged; existing posts may still be remotely visible after local deletion |
| P0-05 remote moderation, deletion, reactions, block/report | **NOT IMPLEMENTED** | Must modify app plus Firestore rules with security tests; deployment is a separate action |
| P0-06 actual network consent / cloud auth opt-in | **HARDENED IMPLEMENTATION (WO-P0-PRIVACY-DURABILITY)** | Fail-closed session-authorized `PrivacyCapabilityService` architecture (`_sessionAuthorizations`), synchronous revocation blocking, per-capability revision tracking eliminating stale grant completion races, subscribed sponsor stream teardown upon cloud revocation, preference accuracy under storage failure, and complete cold-restart safety under storage failure (744 tests passing). |
| P0-07 CI configuration recovery | **PASSED (CI run 38292706655)** | Remote GitHub Actions run 38292706655 completed successfully on main. Flutter analyze clean, 736 tests passed, 14 architecture invariants hold |
| P0-08 documentation/static contract check | **SCRIPT DELIVERED** | `tools/verify_phase0_contracts.py` checks reproducible overlay/documentation properties only, *not* runtime trust |
| P0-09 security/emulator/device acceptance | **NOT RUN** | See CI matrix; physical-device network capture and two-device evidence remain outstanding |

## Required acceptance gates to mark Phase 0 complete

- [ ] Human records licensing intention and counsel/provenance check where appropriate; public README and LICENSE no longer contradict in statements.
- [x] Every opt-in capability has explicit persisted local consent where required; opt-out prevents outbound requests, including first-run Firebase anonymous sign-in; tests cover cold boot.
- [ ] Remote Circle write/read/delete are authority-bound and version-migration safe. Shared feeds cannot be abused with a local moderator flag.
- [ ] A user deletes their cloud-mirrored post from two clients and verifies tombstone/delete convergence under planned cache policy.
- [ ] Remote reaction records are actor-bound and bounded; 50 rapid reactions from one anonymous identity do not inflate shared reward counts.
- [ ] Remote report/block/moderate flows are available and protected by server-issued authority, with a reliable safety fallback while offline.
- [ ] Firebase emulator rules negative tests fail on tampering and pass on legitimate flows; all rule changes deployed only via explicit human-approved process.
- [x] Airplane-mode private workflows unaffected; connected feature errors never misrepresent 'local saved' as 'sent'.
- [x] `flutter analyze`, `flutter test` (744 tests) and all project invariant/self-tests pass at the end of implementation; correct GitHub Actions workflow reaches jobs and reports real results.
- [x] Resolve open security acceptance issue: failed revocation persistence handling across cold application restarts resolved via session-authorization architecture (verified: 744 passing tests).
- [ ] Latest design/source SHA, local test logs, device models and known remaining risks recorded in a verification handoff.

## Architectural Notes & Security Invariants

### 1. Authoritative Capability Authorization Architecture (WO-P0-PRIVACY-DURABILITY)
- **Session-Only Network Authorization (`_sessionAuthorizations`):** Network operations consult `PrivacyCapabilityService.isGranted()`, which evaluates active in-memory session authorizations exclusively. Session authorizations initialize to denied on every fresh application process.
- **Durable Preferences Separated (`_persistedPreferences`):** Durable user preferences saved in device storage record previous user selections for contextual guidance in settings and prompts, but persisted `granted` preferences alone **never** authorize outbound network activity on a cold start.
- **Contextual In-Session Reauthorization:** Connected capabilities require explicit user authorization for the running application process. Once granted, permission persists throughout the running process session (including background/resume), eliminating repeated prompts while navigating.
- **Immediate Synchronous Revocation:** When consent is revoked, `_sessionAuthorizations[capability]` is updated synchronously and change callbacks fire immediately before disk persistence begins, instantly halting outbound network traffic.
- **Request Revision Monotonicity:** Each `setConsent` invocation increments a per-capability revision counter. Asynchronous persistence completions verify the revision; superseded grants are discarded and never update effective authorization or emit callbacks.
- **Preference Accuracy Under Storage Failure:** Failed storage writes do not overwrite `_persistedPreferences`. A failed revocation remains session-denied while accurately reporting storage failure without claiming the preference was durably saved.
- **Subscribed-Stream Teardown:** Service stream listeners (e.g., `SponsorLinkService.watchPendingBundles`) subscribe to `onConsentChangedCallbacks` and synchronously cancel underlying Firestore streams and close broadcast controllers upon cloud revocation.

### 2. Resolved Security Acceptance Issue — Failed Revocation Across Cold Restart
- **Scenario:** The user revokes consent for a capability (e.g. `cloudSync`), but the underlying persistent storage write fails (e.g. storage corruption, disk full, or write error).
- **Session Behavior:** The application retains session-level denial in `_sessionAuthorizations`, blocks all subsequent network requests immediately for that session, and reports `false` to the caller so the UI can warn the user.
- **Preference Integrity:** `_persistedPreferences` does not claim the preference was saved when persistence fails.
- **Cold-Start Protection:** Because every fresh application process initializes session authorization to `denied`, an unpersisted revocation on disk cannot leak network requests on subsequent launches. An old persisted `granted` preference will **never** automatically authorize outbound network activity.
- **Verification Evidence:** Verified deterministically in `test/privacy_capability_test.dart` (`Failed revocation write preserves session denial and accurately reports storage failure without claiming save`, `Failed revocation in Riverpod keeps session denied while preserving persisted preference accuracy`) and `test/privacy_network_gating_test.dart` (zero network calls on cold start with old persisted grants across weather, tiles, directory refresh, sponsor relay, and community feed).

**Do not ship Phase 0 as 'complete' on README update alone.**
