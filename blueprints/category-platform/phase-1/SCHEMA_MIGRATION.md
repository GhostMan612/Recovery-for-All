# Phase 1 Data Migration Plan (proposal, not SQL)

**Baseline observed:** Drift `schemaVersion` **13** on RFA revision `6f985f3`; validate local current schema before calculating next version. Preserve existing SQLCipher keys, PIN derivation and encrypted journal.

## New logical tables

| Table | Keys | Purpose |
|---|---|---|
| `RecoveryActions` | `eventId` PK, `actionType`, `actorScope`, `createdAt`, `origin`, `payloadVersion`, `proofTier`, `redactedMeta` | stable domain action, encrypted alongside DB |
| `RewardReceipts` | `eventId` PK/FK, XP, Sparks, status, policyVersion, awardedAt | idempotent award journal and balancing |
| `RaidDamageReceipts` | `(raidId,eventId)` unique | damage application once per event |
| `RaidVictoryReceipts` | `raidId` unique | victory bonus granted exactly once |
| `QuestProgress` | `(questInstanceId,eventId)` unique | local quest projection, no duplicate XP |
| `ProjectionCheckpoints` | `(projectionName,eventId)` unique | resume half-completed external/projection steps safely |

These are *candidate* tables: adopt only those necessary once ledger invariants and existing tables are analyzed. Establish migration in two steps: additive schema then traffic cutover; separate migration from UI changes.

## Migration decisions

- Historical Event rows are **not** presumed unique across natural activities; preserve them, label source `legacy`, never auto-credit/backfill new events on import.
- Existing balance snapshot is authoritative at cutover; new receipts account only for post-cutover events. Preserve pets, outfits, preferences and case-insensitive milestone limits.
- Time-based caps need deterministic timezone choices and protections against clock rollback. Maintain original timestamps for audit.
- Every schema step has **forward-only migrations** and a safe data-preserving rollback strategy (restore verified pre-upgrade backup for test devices only). Binary downgrade after schema upgrade is not promised.
- Encrypted backup/export cannot silently expose protected journal content; document user-controlled export policy.

## Migration gates

1. Make sanitized fixture for *each* supported real schema version. Run `test/schema_migration_test.dart` with populated v1→current and current→new.
2. Inject mid-migration exception and check transaction rollback.
3. Test one and two rapid launches against encrypted database open race; preserve app-profile and SOS accessibility.
4. Compare before/after: counters, journal record count/content hash, PIN lock, pet XP/Sparks/equipment, stars, community records, sponsor proof.
5. Do not manually edit generated `recovery_database.g.dart`; generate through approved build_runner and verify generated schema expectations.
