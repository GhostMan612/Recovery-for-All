# Phase 3 Agent Scope

Read root `RULES.md`/`AGENTS.md` and Phase 0 `CIRCLE_SECURITY_PROTOCOL.md`, `CIRCLE_THREAT_MODEL.md`, `CIRCLE_EXECUTION_WORK_ORDER.md` and release gate. A Phase 0 overlay installed without implementation is NOT approval to deploy Firestore rules or publish peer features.

Do all Circle code, rules-unit tests and migration planning locally; use emulator before deployed rules. No self-issued moderator token, no broad auth-is-enough writes, no public user location, no unreviewed display name/account link, no live community content in tests. Isolate all sensitive local actions from the remote queue. Keep service degraded/local when auth is unavailable.

Require owner consent before any live Firebase rules update. If trusted moderation cannot operate in reality, maintain local-only/read-only mode and mark Phase 3 incomplete rather than shipping sham safety controls.
