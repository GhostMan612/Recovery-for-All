# Phase 0 — Trust, Consent, Identity & Circle Integrity

**Baseline:** Recovery for All `main` at `6f985f393962b091d69cc003bb922c9fae9ae618` (2026-10-11); Metro IntelliTrip `master` at `a7d77e4a9de134bf8b20d5304dd349e3b29330be` (read-only dependency).\
**Package type:** direct-overwrite Markdown/documentation + malformed CI workflow repair + deterministic static-contract verification. No Git commands, remote actions, runtime feature flips, Firebase deployments, database migrations or permission prompts are executed by extraction.\
**Release gate:** **Phase 0 is NOT complete just because this ZIP has been committed.** The implementation backlog below includes security-critical code and cross-device work requiring an agent, device/emulator tests and owner decisions. Do not conflate *blueprint installed* with *security fixed*.

## Entry point and authority

Read `RULES.md` → `AGENTS.md` → `SESSION_HANDOFF.md` → `blueprints/category-platform/README.md` → this file. `RULES.md` prevails over this package. Existing local directory rules and end-of-plan batched tests still apply. Make no changes to Metro or the remote repositories without specific human approval.

## Package contents

| Document | Owner / purpose |
| --- | --- |
| `PHASE_0_STATUS_AND_GATES.md` | Exact installed/blocked/not-tested status and acceptance definitions |
| `DATA_FLOW_AND_CONSENT.md` | Real data destinations, gap matrix, explicit capability boundaries |
| `LICENSE_AND_IP_DECISION.md` | MIT/proprietary contradiction; owner decision required |
| `CIRCLE_THREAT_MODEL.md` | Attacker abilities, abuse and deletion failure modes |
| `CIRCLE_SECURITY_PROTOCOL.md` | Versioned server-trusted target protocol and staged migration |
| `CIRCLE_EXECUTION_WORK_ORDER.md` | Source-file and test-by-test executable work order |
| `NETWORK_PRIVACY_WORK_ORDER.md` | Consent and provider-policy changes for map/weather/external links |
| `CI_AND_VERIFICATION.md` | CI failure analysis, end-of-plan gates, cross-device tests |
| `DECISION_LOG.md` | Explicit owner decisions and safe defaults |
| `AGENTS.md` | Phase-scoped instructions for any coding harness |

## Execution order (no giant rewrite)

1. **P0-A documentation + CI repair** — delivered in this overlay: a source-accurate root README/privacy-policy clarification, blueprint indexing, and replacement of a malformed `.github/workflows/cmake-multi-platform.yml` with a Flutter quality-gates workflow. Quality gates remain **unverified** until GitHub and the user's local host run them.
2. **P0-B privacy contracts** — implement actual opt-in controls, avoid cloud anonymous auth at startup by default, and gate precise-location/network requests appropriately. A document is not an enforcement point.
3. **P0-C Circle safety** — enforce remote ownership, author deletion and moderation authority server-side, actor-bound reaction idempotency and block/report with emulator tests. Gate publication until server-side enforcement and the client are deployed compatibly. Preserve local content and migration safety.
4. **P0-D acceptance** — negative tests, cross-device deletion, airplane-mode behavior, actual on-device request traces and recorded owner decisions. Only then declare Phase 0 implemented.

## Non-negotiables

- No retroactive removal of user data; no unaudited SQLCipher migrations; don't hand-edit `recovery_database.g.dart`.
- No blanket `allow read,write` Firestore rule; `SharedPreferences` flag is never a remote moderator credential; global authenticated reaction updates are not acceptable.
- No 'Deleted everywhere' unless cross-device and remote cache policy is verified. No promises of anonymous E2EE; Firebase transport encryption is not end-to-end encryption.
- Do not silently disable existing cloud user functionality, change license terms, add paid services or alter Android `minSdk` without the owner approving the behavior shift.
- In a no-provider/no-network state, personal recovery tools still work; avoid routing to synthetic SAMPLE meetings.

## Shared foundation for Phases 1–4

Use the [Master Index — Phases 0–4](../PHASES_1_TO_4_INDEX.md) as the single dependency and acceptance map. Phase 0 consent and server-authority requirements apply to Phase 2 network/location providers and are prerequisites for Phase 3 connected Circle features; Phase 1 local-only progression and Phase 2 offline SDK proof do not require enabling remote Circle.

Coordinate any Circle outbox or delivery-state schema with [`contracts/SCHEMA_REGISTRY.md`](../contracts/SCHEMA_REGISTRY.md) and Phase 1 [`SCHEMA_MIGRATION.md`](../phase-1/SCHEMA_MIGRATION.md). Do not create a second action identity or independently bump Drift for Phase 0. A semantically shared recovery action keeps the same stable `eventId`; its reward is decided once by the shared event-keyed ledger, not once per feature, currency, policy version, retry, or phase.

**Related:** `../PHASED_EXECUTION_PLAN.md` (Phase 0), `../DECISIONS_AND_RISKS.md`, `../VERIFICATION_MATRIX.md` and `../PLATFORM_ARCHITECTURE.md`.
