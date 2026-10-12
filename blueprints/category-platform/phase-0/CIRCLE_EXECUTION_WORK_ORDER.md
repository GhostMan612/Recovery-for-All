# WO-P0-CIRCLE — Implementation plan for an agent

**Status:** ready for local implementation planning, **not executed in this ZIP**. The owner must select shared feed vs temporary local-only/read-only operation, as well as a trusted moderation operating model. Do not start public-social release without these decisions. No Gemini/Claude/OpenCode harness assumptions.

## Files and exact intended changes

| Repository path | Change |
| --- | --- |
| `lib/services/community_feed_service.dart` | Separate local compose from explicit remote publish; durable outbox state, stable retry IDs, full delivery status; stop reporting remote failures as successful shares; authorize using dedicated domain events; remove untrusted remote count modifications |
| `lib/screens/community_feed_screen.dart` | Replace ambiguous `Shared` snackbar; display `Local draft`, `Queued`, `Shared`, `Delete pending`, `Deleted`, `Could not send` states. Confirm external publication and deletion consequences. Route delete through coordinator rather than raw `database.deleteFeedPost` |
| `lib/database/recovery_database.dart` | Design idempotent outbox/action tables and ownership/remote-state metadata; add additive schema migration, indexes and rollback/fixture tests before cutover. Do not hand-edit generated `recovery_database.g.dart` |
| `firestore/firestore.rules` | Add explicit owner-bound v2 schema and allowed fields, per-actor reactions, protected report path and trusted moderation; retire unsafe legacy operations at cutover; test exact positive/negative scenarios in emulator |
| `lib/main.dart` | Separate Firebase initialize from sign-in, defer connected Circle auth until verified explicit consent; do not block critical app boot with unnecessary cloud network attempts |
| `test/community_feed_service_test.dart` | Preserve C1–C5 behavior as currently expected where valid, add local/send/timeout/delete/duplicate/restart tests and change legacy expectations only with reviewed semantics |
| `test/schema_migration_test.dart` | Real populated older DB migration proof; preserve journal PINs, counters, pet, and prior posts |
| `test/` new Circle model tests | Multi-actor behavior, at-most-once outbox, blocked/crisis input, unsent local drafts, remote errors and moderation-display consistency |
| `firestore/tests` (new) | Emulator rules tests using clients A/B/moderator; authentication, invalid fields, replay, edit/delete, reports, role change, block and cache convergence |
| `PRIVACY_POLICY.md`, `README.md`, `AGENTS.md` | Update only after runtime behavior verified; avoid describing proposed controls as shipped |

**Cross-phase schema constraint:** Register Circle outbox/delivery-state changes in [`contracts/SCHEMA_REGISTRY.md`](../contracts/SCHEMA_REGISTRY.md) and coordinate them with Phase 1 [`SCHEMA_MIGRATION.md`](../phase-1/SCHEMA_MIGRATION.md) before editing Drift. Do not create an independent recovery-action identity, reward receipt, or competing migration version. Reuse the same stable event ID where the Circle action is the same domain event; keep distinct server delivery/authorization state only where its lifecycle requires it.

## Implementation slices

**C0 — freeze and compatibility:** export local and remote fixture shapes; record Firestore deployed rules version/hash; fixture both v1 and v2; choose migration policy. Collect screenshots and actor permissions without private user data.

**C1 — local outbox:** database migration with typed states, retry/idempotence, local-only fallback, tests. No remote-rule change yet.

**C2 — trusted remote protocol:** owner-bound v2 Firestore schema, per-actor reaction docs, reports and policy, emulator positive/negative tests. Moderator role only if trusted server issuance exists; otherwise withhold remote publish expansion. Do not implement a fake client-admin feature.

**C3 — UI and cutover:** explicit consent, status/authoritative ack in feed screen, owner-deletion coordination, cached state retention; deploy rules only in approved window with rollback plan.

**C4 — independent verification:** two physical installs + at least two anonymous UIDs; offline/reconnect; malicious update attempts; user deletion convergence and policy wording. Also verify the user can still access SOS and local recovery when all networking is down.

## Must not do

- Write new privileged claims from a client or secure role by local `SharedPreferences`.
- Set `allow update: if request.auth != null` on arbitrary post rows/counters.
- Grant RPG XP for remote post-count/reaction-count volume, crisis disclosures or negative status.
- Turn v1 content into owner-bound v2 content by guessing aliases; silently delete user posts.
- Label offline drafts as peer-delivered.

**Handoff contract:** list exact changed files, tests run/not run, schema versions, rule deployment state, pending owner decisions and rollback procedure. Use source hashes, not assurances.
