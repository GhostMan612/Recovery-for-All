# WO-1A — RecoveryAction + RewardLedger (Priority P1)

## Why this is first

At observed RFA `main` the `XpEngineService.grantXp` transaction atomically updates pet XP + PetEvent, but receives an externally supplied *amount* and generates a new timestamp event ID. Therefore a caller retry can double-credit. `processAction` retains unknown-action +10 XP compatibility. `RecoveryPetService` Sparks and raid damage take separate paths. We need **event-level** dedup and a replay-safe projection, while retaining historical totals.

## Proposed exact files

| Path | Intended change |
|---|---|
| **NEW** `lib/features/progression/domain/recovery_action.dart` | sealed/typed actions, immutable stable `eventId`, `schemaVersion`, source, timestamp, proof tier, redacted metadata; registered allowable types |
| **NEW** `lib/features/progression/domain/reward_policy.dart` | deterministic reward table + limits and manual-vs-verified proof behavior, no implicit fallback |
| **NEW** `lib/features/progression/data/reward_ledger_repository.dart` | one idempotent transaction on Drift, unique event ID; consistent receipt state |
| **NEW** `lib/features/progression/application/recovery_action_coordinator.dart` | single entry point, orchestrates grants, raid projection, constellation, downstream outbox |
| `lib/database/recovery_database.dart` | additive `RecoveryActions`, `RewardReceipts`, `RaidDamageReceipts` tables with indices, migration from v13 based on actual local version, not a hard-coded assumption |
| `lib/services/xp_engine_service.dart` | delegate new registered callers to coordinator; reject unknown *new* events; preserve legacy wrapper behind compatibility adapter until all call sites converted |
| `lib/services/recovery_pet_service.dart` | bridge Sparks and XP without double application; retire prefs dual-write only after migration verification |
| `lib/services/raid_service.dart` | introduce idempotent damage receipt per `(raidId, eventId)` and victory receipt per raid; protect from repeated defeat grants |
| `lib/services/constellation_service.dart` | use stable event IDs for event-backed stars while keeping legacy per-day semantics where required |
| `test/pet_economy_test.dart`, `test/schema_migration_test.dart`, **NEW** `test/progression/reward_ledger_test.dart` | replay/concurrency/reset/crash/migration and balance invariants |

## Storage/transaction contract

1. `RecoveryAction` uses a stable UUID **created at original user action**, not minted when handling a retry; UI carries the ID across navigation/retry/restart via durable intent or outbox.
2. Unique index on `eventId`; insert action receipt and allocate XP/Sparks once inside one transaction. Reject malformed type/negative amount/unsupported schema and do not mutate balance.
3. Derive balances from a snapshot plus ledger or track an atomically updated balance; **do not** recompute historical XP with a new policy. Negative corrections require explicit compensation events and auditing, not rewriting history.
4. A reward request may follow a domain action; if the domain action is created in a separate subsystem/transaction, use a durable recoverable pending state and replay worker, not a fake guarantee of atomicity across unrelated providers.
5. Projection: raid damage, stars and quest completion track `eventId`; each projection can retry after a crash but must apply once. For nested Drift calls avoid deadlocks and inconsistent competing transactions.
6. Each commit returns a typed outcome: `granted`, `alreadyApplied`, `notEligible`, `rejected`, `deferredProjection`, with safe public-facing reasons. No duplicate celebration snackbar for `alreadyApplied`.
7. Rate caps cover duplicate aliases, locale midnight changes and UTC/local-day behavior. **Do not use per-day source key as a stand-in for event identity** when multiple authentic events are allowed.

## Compatibility and rollout

- Record every `log*`, `grantXp`, `processAction`, milestone and raid caller before edits; convert a small core pathway first (e.g., check-in), test, expand to journal, gratitude, grounding, walk, meeting, fellowship, quests and battles.
- Legacy `PetEvents` have timestamp IDs and sometimes ambiguous metadata. They must remain historical without inferred dedup. Anchor new ledger activation to an explicit version, keep existing totals, no automatic replay of past events.
- DB schema migration creates new tables and indexes without deleting legacy tables. Run migration on populated v1→v13 and current→next snapshots; compare encrypted originals, profile, PIN, pet, journal, constellation and feed rows.
- Avoid `SharedPreferences` dual-write split brain by staged read-then-write cutover plus rollback.

## Negative cases to prove

- 100 sequential/concurrent same-event submissions, foreground/background and process-kill replay yield exactly one XP and one Sparks receipt.
- A repeated existing event never damages a raid twice; simultaneous victory produces one victory bonus.
- Unknown action `typo_step` cannot yield +10 XP through *new* API. Legacy compatibility remains test-covered until all caller migrations finish.
- Power loss after action stored but before raid projection resumes safely.
- Two unrelated unique events preserve both awards with concurrent transaction access.

**Exit gate:** [ACCEPTANCE_AND_TESTS.md](ACCEPTANCE_AND_TESTS.md) P1-A green, existing pet economy tests green, no balance/cosmetic loss on populated migration.
