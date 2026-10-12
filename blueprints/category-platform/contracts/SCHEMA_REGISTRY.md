# Proposed Wire/Data Contracts Registry

The `*.schema.json` files are **design schemas and synthetic examples**, not runtime service endpoints or generated Dart/Kotlin code. Version new breaking changes as V2; never mutate a published V1 payload meaning silently. The repository's actual Drift schema and Metro Kotlin types remain authoritative until code migration is approved.

## Shared database migration authority

This registry and `../phase-1/SCHEMA_MIGRATION.md` are the coordination points for all Phase 0–4 database changes. They do not replace `lib/database/recovery_database.dart` or its migration chain as runtime authority.

- Re-read the current checkout's `schemaVersion`, tables, indexes and every migration before choosing a version. The cited v13 value is a historical baseline, not an assumed current version.
- Phase 0 Circle outbox/delivery state and Phase 1 action/reward receipts must be reviewed as one data model and one migration sequence. Reuse a stable action ID when the actions are the same; do not create competing event IDs, receipts, or independent version bumps. Keep distinct delivery/authorization state only where its lifecycle is genuinely different.
- Before implementation, register each proposed table/index with owning work order, purpose, keys, dependency, migration version, data-preservation/backfill and rollback constraints, plus populated migration tests. Use additive migrations and generated Drift output; never hand-edit generated files.
- Required migration evidence covers populated v1-to-current and current-to-next paths, encrypted-data preservation, and recovery after an injected mid-migration failure. Empty `onCreate` tests alone do not satisfy this gate.

| Artifact | File | Producer/consumer | Required caution |
|---|---|---|---|
| RecoveryActionV1 | `recovery_action_v1.schema.json` | local recovery subsystem -> rewards | stable event ID, source, no secret text or location |
| JourneyPreviewV1 | `journey_preview_v1.schema.json` | native Atlas -> Flutter map | source, exact freshness, route legs, explicit capabilities |
| CircleQuestContributionV1 | `circle_quest_contribution_v1.schema.json` | local quest -> trusted remote Circle | pseudonymous actor identity, idempotency, no health disclosure |
| RecoveryAction fixture | `fixtures/action_check_in.json` | schema tests | synthetic only |
| Journey fixture | `fixtures/journey_offline_synthetic.json` | schema tests | clearly not live |
| Contribution fixture | `fixtures/circle_contribution_local_only.json` | schema tests | synthetic only |

Validation: `python tools/verify_category_overlay.py` loads schemas, verifies examples' constrained subset (types/required/enums/additionalProperties via built-in verifier), hashes every file and checks original source anchors exist. This is **not** a substitute for production JSON Schema validation or Dart/Kotlin model tests.

For code implementation: add field-compatible serializers with explicit version discrimination; redact user input in logging, log eventId by hash or short safe prefix, and treat all native->Dart results as untrusted at the boundary (limits, ranges, NaN/Inf, payload sizes).
