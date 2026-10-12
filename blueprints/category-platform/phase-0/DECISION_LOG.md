# Phase 0 decision log

These items are not settled by an architecture author. Owner can mark one path in a local ADR/issue and give it to the implementation agent.

| ID | Decision required | Safe proposed default | Owner decision |
| --- | --- | --- | --- |
| D0-01 | How should the MIT license and previous proprietary claim coexist? | Do not alter LICENSE; remove exclusive claims, request provenance/legal review | PENDING |
| D0-02 | Should remote Community Circle sharing continue during backend hardening? | Do not change current production behavior silently; submit risk and propose local/read-only fallback if no trusted moderation service | PENDING |
| D0-03 | Trusted moderation authority source? | Only server-admin-issued claims/gateway with tests; no local 'moderator' flag | PENDING |
| D0-04 | Remote post erasure and legacy v1 owner mapping? | v2 owner-bound protocol; legacy read-only until explicit migration/retirement strategy approved | PENDING |
| D0-05 | Precise location sharing defaults and weather UI? | User-visible explicit choice; local/manual search always works | PENDING |
| D0-06 | Firebase anonymous authentication at startup? | Defer until explicit connected feature use, subject to product behavior approval | PENDING |
| D0-07 | CI naming and execution? | Replace malformed legacy workflow in-place with Flutter quality gate, no release deployment | IMPLEMENTED AS FILE, UNVERIFIED |
| D0-08 | Metro integration now? | No: Phase 0 is trust-only; keep Metro read-only with pinned master SHA | DEFERRED TO PHASE 2 |

**Escalate before:** license change, Firebase rule deploy, migration affecting existing user posts, deletion of production docs, privacy-default change, adding server infrastructure/cost, editing Metro, changing minSdk, cloud auth flow changes, push or release.
