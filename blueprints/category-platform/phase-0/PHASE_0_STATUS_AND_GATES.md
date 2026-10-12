# Phase 0 implementation status and gates

**Status at package creation — 2026-10-11 (Updated 2026-10-12).** Static inspection and local test gate verification. Do not convert statuses to PASS without machine/test evidence.

| ID | Result at packaging | Evidence, next step |
| --- | --- | --- |
| P0-01 source-accurate README | **DELIVERED in overlay, not runtime-tested** | Replaces broad unsupported competitor/privacy/proprietary claims; links this hub |
| P0-02 privacy-policy clarification | **DELIVERED in overlay, not legally reviewed** | Records Open-Meteo coordinate requests, external map links, online tile providers, Firebase anonymous sign-in at boot; does **not** create consent UI |
| P0-03 license resolution | **BLOCKED by owner/legal decision** | `LICENSE` remains MIT with Toxic Creationz copyright; old README proprietary claim corrected, license not modified |
| P0-04 Circle trust design | **DESIGNED only** | See threat model and protocol; current Firestore rules remain unchanged; existing posts may still be remotely visible after local deletion |
| P0-05 remote moderation, deletion, reactions, block/report | **NOT IMPLEMENTED** | Must modify app plus Firestore rules with security tests; deployment is a separate action |
| P0-06 actual network consent / cloud auth opt-in | **HARDENED IMPLEMENTATION** | Fail-closed `PrivacyCapabilityService` single authority (`_effectiveConsents`), synchronous revocation blocking, per-capability revision tracking eliminating stale grant completion races, subscribed sponsor stream teardown upon cloud revocation, 736 tests passing. **Open security acceptance issue:** persistence failure during revocation across cold restart |
| P0-07 CI configuration recovery | **PASSED (CI run 38279584827)** | Remote GitHub Actions run 38279584827 completed successfully in 1m48s. Flutter analyze clean, 724 tests passed, 14 architecture invariants hold |
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
- [x] `flutter analyze`, `flutter test` (736 tests) and all project invariant/self-tests pass at the end of implementation; correct GitHub Actions workflow reaches jobs and reports real results.
- [ ] Resolve open security acceptance issue: failed revocation persistence handling across cold application restarts.
- [ ] Latest design/source SHA, local test logs, device models and known remaining risks recorded in a verification handoff.

## Architectural Notes & Security Invariants

### 1. Authoritative Capability Authorization Architecture
- **In-Memory Authority (`_effectiveConsents`):** `PrivacyCapabilityService` maintains an in-memory map of effective capability states consulted first by `isGranted()`.
- **Immediate Synchronous Revocation:** When `setConsent` is invoked with a non-granted state, `_effectiveConsents[capability]` is updated synchronously and change callbacks fire immediately before disk persistence begins.
- **Request Revision Monotonicity:** Each `setConsent` invocation increments a per-capability revision counter. Asynchronous persistence completions verify the revision; superseded grants are discarded and never update effective authorization or emit callbacks.
- **Subscribed-Stream Teardown:** Service stream listeners (e.g., `SponsorLinkService.watchPendingBundles`) subscribe to `onConsentChangedCallbacks` and synchronously cancel underlying Firestore streams and close broadcast controllers upon cloud revocation.

### 2. Explicit Unresolved Security Acceptance Issue — Failed Revocation Across Cold Restart
- **Scenario:** The user revokes consent for a capability (e.g. `cloudSync`), but the underlying persistent storage write fails (e.g., storage corruption, disk full, or `SharedPreferences` write error).
- **Session Behavior:** The application retains session-level denial in `_effectiveConsents`, blocks all subsequent network requests for that session, and reports `false` to the caller.
- **Restart Risk:** Because the physical persistent storage medium was not updated, a cold application restart will reload the older granted state from storage.
- **Status:** **This scenario is NOT fully fail-closed across restarts and is NOT release-ready.** Documenting or reporting the failure does not eliminate the vulnerability. It remains an explicit unresolved security acceptance issue until durable storage failure handling (e.g. durable quarantine, secondary secure storage write, or forced session revocation) is implemented and verified.

**Do not ship Phase 0 as 'complete' on README update alone.**
