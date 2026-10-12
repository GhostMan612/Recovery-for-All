# Phase 0 implementation status and gates

**Status at package creation — 2026-10-11.** Static inspection of the remote pinned revisions; no local Flutter/Firestore emulator available to the report author. Do not convert statuses to PASS without machine/test evidence.

| ID | Result at packaging | Evidence, next step |
| --- | --- | --- |
| P0-01 source-accurate README | **DELIVERED in overlay, not runtime-tested** | Replaces broad unsupported competitor/privacy/proprietary claims; links this hub |
| P0-02 privacy-policy clarification | **DELIVERED in overlay, not legally reviewed** | Records Open-Meteo coordinate requests, external map links, online tile providers, Firebase anonymous sign-in at boot; does **not** create consent UI |
| P0-03 license resolution | **BLOCKED by owner/legal decision** | `LICENSE` remains MIT with Toxic Creationz copyright; old README proprietary claim corrected, license not modified |
| P0-04 Circle trust design | **DESIGNED only** | See threat model and protocol; current Firestore rules remain unchanged; existing posts may still be remotely visible after local deletion |
| P0-05 remote moderation, deletion, reactions, block/report | **NOT IMPLEMENTED** | Must modify app plus Firestore rules with security tests; deployment is a separate action |
| P0-06 actual network consent / cloud auth opt-in | **IMPLEMENTED (8eede60d1ff)** | WO-P0-PRIVACY Slices A–D: fail-closed PrivacyCapability domain, WeatherService gating, boot auth decoupling, dynamic Circle sync & revocation, map tile cache-first enforcement, 22 unit & negative integration tests passing |
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
- [x] `flutter analyze`, `flutter test` and all project invariant/self-tests pass at the end of implementation; correct GitHub Actions workflow reaches jobs and reports real results.
- [ ] Latest design/source SHA, local test logs, device models and known remaining risks recorded in a verification handoff.

**Do not ship Phase 0 as 'complete' on README update alone.**
