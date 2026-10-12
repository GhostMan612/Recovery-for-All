# Phase 4 Product-Level Acceptance

| Test ID | End-to-end path | Required evidence |
|---|---|---|
| P4-001 | first-run local/offline Path A | works, no forced login, local data persists |
| P4-002 | cached meeting + offline Atlas route Path B | accurate source/age, sample rejection, valid route or clear absence |
| P4-003 | active weather/realtime network and permission revoked | downgraded status, no surprise external request |
| P4-004 | game action -> XP/Pet/Quest/Star and 100 replays | consistent once-only receipt, user sees one celebration |
| P4-005 | Circle local draft -> remote consent -> delete | server status honest, cross-device test, no location leakage |
| P4-006 | all features while Firestore service unavailable | SOS/local tools available, no app crash |
| P4-007 | 3 GB device, kill/restart/low-storage | no OOM, data preserved, timings/profile attached |
| P4-008 | TalkBack + 200% text, all four user paths | no unreachable controls, action labels correct |
| P4-009 | No-game mode and reduced motion | equivalent core recovery capability |
| P4-010 | release claims vs actual network traces | no contradictory privacy, license or offline wording |
| P4-011 | regression Flutter analyze/tests and native SDK tests | evidence logged for exact revisions |
| P4-012 | clinical/safety review and user feedback | concerns documented, no unverified efficacy statement |

**E2E signoff fields:** source commit(s), tested build/install package + versionCode, device/OS/RAM, network mode, timezone, test IDs, pass/fail/blocked/not-run, evidence artifacts, data-redaction confirmation, owner decision. Not-run is never equivalent to pass.

**Gate precedence:** Phase 0 trusted sharing must pass before P4-005; Phase 1 migration and replay test before P4-004; Phase 2 real/offline route evidence before P4-002. `RELEASE_SCORECARD.md` is a blank template, not populated test evidence.
