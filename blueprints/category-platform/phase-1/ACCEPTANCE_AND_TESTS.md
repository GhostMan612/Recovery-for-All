# Phase 1 Acceptance, Tests and Evidence

**Must pass:** CP-01..09, CP-21..24 where applicable. `test/pet_economy_test.dart`, `test/schema_migration_test.dart`, `test/dashboard_pet_liveness_test.dart`, relevant widget tests.

| Test ID | Case / setup | Expected result |
|---|---|---|
| P1-001 | 100 replayed identical `eventId` sequential and concurrent | one XP and Sparks receipt; no unknown fallback |
| P1-002 | Kill app after ledger commit, before raid projection | resumable projection, damage once |
| P1-003 | Defeat weekend raid concurrently from two events | HP=0, victory bonus once |
| P1-004 | Unique simultaneous journal/check-in events | both awards persisted; no lost update |
| P1-005 | Unknown action/version or malformed metadata | rejected, no XP, actionable error |
| P1-006 | Legacy populated database v1→latest and 13→next | journal/counters/PIN/pet/stars intact, no back-credits |
| P1-007 | Trial golden seed N, repeat 100 times | same full deterministic transcript |
| P1-008 | Battle defeat and skipped quest | no harsh penalty; coping and SOS available |
| P1-009 | Accessibility: 200% font and TalkBack | battle, quests and reward summary usable |
| P1-010 | 3GB RAM device offline, kill/restart | pet, equipment, active quest, XP survive |
| P1-011 | Game disabled / quiet mode | recovery tools unaffected and notifications silenced |
| P1-012 | Clock change + timezone + DST boundary | once-only grants, caps do not reset illegitimately |

**Execution:** follow `RULES.md` batching. An agent should run focused Dart tests during development, but obey any stronger local shell discipline. End-of-plan `flutter analyze`/`flutter test` under root instructions; Android Studio human build/device smoke required. Provide command, timestamp, result, device/ABI, redacted logs, exact failed assertions; mark `NOT RUN` otherwise. Never call a plan complete with source review alone.

**Rollback:** all new behavior behind explicit local feature flag; old balance snapshot retained until tested migration and user accepts irreversibility. Do not delete data or downgrade an upgraded database file in place.
