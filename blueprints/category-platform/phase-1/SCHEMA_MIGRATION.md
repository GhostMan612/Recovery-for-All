# Phase 1 Data Migration Plan (proposal, not SQL)

**Baseline observed:** Drift `schemaVersion` **13** on RFA revision `6f985f3`; this is historical context only. Validate the local current schema and complete migration chain before calculating the next version. Preserve existing SQLCipher keys, PIN derivation, encrypted journal, balances, and user data. This file and [`contracts/SCHEMA_REGISTRY.md`](../contracts/SCHEMA_REGISTRY.md) coordinate all Phase 0–4 schema changes.

## New logical tables

| Table | Keys | Purpose |
|---|---|---|
| `RecoveryActions` | `eventId` PK, `actionType`, `actorScope`, `createdAt`, `origin`, `payloadVersion`, `proofTier`, `redactedMeta` | stable domain action, encrypted alongside DB |
| `RewardReceipts` | `eventId` PK/FK, XP, Sparks, status, policyVersion, awardedAt | idempotent award journal and balancing |
| `RaidDamageReceipts` | `(raidId,eventId)` unique | damage application once per event |
| `RaidVictoryReceipts` | `raidId` unique | victory bonus granted exactly once |
| `QuestProgress` | `(questInstanceId,eventId)` unique | local quest projection, no duplicate XP |
| `ProjectionCheckpoints` | `(projectionName,eventId)` unique | resume half-completed external/projection steps safely |

These are *candidate* tables: adopt only those necessary once ledger invariants and existing tables are analyzed. Phase 0 Circle outbox/delivery-state proposals must be reconciled with these candidates before any phase adds tables. Do not create duplicate event, receipt, or outbox identities or separate uncoordinated schema bumps. Maintain one additive migration sequence and one registered migration version for the combined change, then cut over traffic separately from UI changes.

`RewardReceipts.eventId` is the single reward idempotency key for an action. The receipt contains the complete eligible XP/Sparks award, while `policyVersion` is audit metadata only. A retry under a new policy, currency, battle, quest, raid, or cooperative activity cannot award the same event again. Any correction is a separately keyed and auditable compensating event.

## Migration decisions

- Historical Event rows are **not** presumed unique across natural activities; preserve them, label source `legacy`, never auto-credit/backfill new events on import.
- Existing balance snapshot is authoritative at cutover; new receipts account only for post-cutover events. Preserve pets, outfits, preferences and case-insensitive milestone limits.
- Time-based caps need deterministic timezone choices and protections against clock rollback. Maintain original timestamps for audit.
- Every schema step has **forward-only migrations** and a safe data-preserving rollback strategy (restore verified pre-upgrade backup for test devices only). Binary downgrade after schema upgrade is not promised.
- Encrypted backup/export cannot silently expose protected journal content; document user-controlled export policy.

## Migration gates

1. Audit the checkout's actual schema version and every migration; do not assume v13 remains current. Make sanitized fixtures for supported real schema versions and run `test/schema_migration_test.dart` with populated v1→current and current→next paths.
2. Inject mid-migration exception and check transaction rollback.
3. Test one and two rapid launches against encrypted database open race; preserve app-profile and SOS accessibility.
4. Compare before/after: counters, journal record count/content hash, PIN lock, pet XP/Sparks/equipment, stars, community records, sponsor proof.
5. Do not manually edit generated `recovery_database.g.dart`; generate through approved build_runner and verify generated schema expectations.
