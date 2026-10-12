# Phase 3 Acceptance, Tests and Security Evidence

**Prerequisite:** Phase 0 verified deployment or explicit local-only decision. CP-01, 07–09, 14–21, 23–24.

| Test ID | Case | Passing result |
|---|---|---|
| P3-001 | local new post, no network | draft/queued only, never misleading 'shared' |
| P3-002 | actor A/B with malicious forged owner | B cannot alter/delete A content |
| P3-003 | self-claimed moderator in prefs or payload | cannot change remote moderation status |
| P3-004 | 100 same post/reaction retries | one post/reaction per authorized actor/target |
| P3-005 | auth token expires during send | safe pending/rejected state, no silent duplicate |
| P3-006 | author delete while another device offline | local pending until authoritative ack; eventual permitted convergence |
| P3-007 | delete from one user's device; two-device sync | source/cached retention policy and user copy limitations accurately shown |
| P3-008 | blocked actor/nonmember attempts access | backend denial and UI hides sanctioned content |
| P3-009 | report privacy & audit | offender cannot read identity or report; moderator authorized |
| P3-010 | replay Circle quest contribution | one accepted contribution/reward; no unlimited XP |
| P3-011 | post/quest with coordinates or sensitive metadata | schema rejects, logs redacted |
| P3-012 | no-game mode, no-network and SOS | support tools remain and Circle behavior honest |
| P3-013 | sustained feed reload/pause/resume | no leaked subscriptions, overflow or runaway reads |
| P3-014 | hostile user, abuse/mod staffing pilot | documented safe policy and real human response, not fake promises |

Test stack: local `test/community_feed_service_test.dart` + new Circle model/widget/outbox suites + Firestore emulator rules tests with A/B/mod. Tests using only mocked Firestore **cannot** certify deployed remote rules. Capture emulator artifact version, local source hash, deployed rules hash, release rollout checklist, denial traces and redacted dual-device screenshots. On absence of trusted infrastructure, **phase stays blocked**, even if local UX tests pass.
