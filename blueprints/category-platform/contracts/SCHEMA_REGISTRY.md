# Proposed Wire/Data Contracts Registry

The `*.schema.json` files are **design schemas and synthetic examples**, not runtime service endpoints or generated Dart/Kotlin code. Version new breaking changes as V2; never mutate a published V1 payload meaning silently. The repository's actual Drift schema and Metro Kotlin types remain authoritative until code migration is approved.

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
