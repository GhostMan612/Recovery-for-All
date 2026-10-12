# Phase 1 Agent Scope

Read root `RULES.md`, `AGENTS.md`, `SESSION_HANDOFF.md`, Phase 0 status, `PHASES_1_TO_4_INDEX.md`, and Phase 1 `README.md` before editing.

**Authorized concept:** local Recovery for All code + tests for P1 work order only; no remote repo writes, no Firebase rule pushes, no changes to Metro. Require explicit owner choices for migration/backfill and economy changes. Do not rewrite entire game UI.

Work serially: inventory callers and existing `RecoveryPetService` Sparks hooks → present migration plan → tests first or alongside code → implement in small guarded slices → run the batched end-of-plan gate mandated by root rules → list files, migrations, test results, and remaining risks. Do not hand-edit `recovery_database.g.dart`; rerun build_runner only when permitted under existing repo constraints.

**Stop conditions:** corrupted/unknown old schema, unexpectedly decrypted personal data, nonreplay-safe grants, divergent balances, increased urge/disclosure rewards, inaccessible coping tools. No claim of verified if only lint passes.
