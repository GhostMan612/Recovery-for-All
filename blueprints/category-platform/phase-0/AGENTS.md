# AGENTS.md — Phase 0 scoped operating instructions

Applies to this subtree only. The root `RULES.md`, `AGENTS.md` and `SESSION_HANDOFF.md` override this file. Read them first. Never claim completed app security from these planning files.

**Focus:** protect recovery users from disclosure, abuse, false consent, and misleading deletion; do not expand RPG/Metro features in Phase 0. Never modify remote GitHub or the Metro repository without the owner's explicit request.

**Source inspection first:** read actual local code, tests and Firestore rules; verify the pinned baseline. List exact affected files and migration rules BEFORE edits. Do not hand-edit generated Drift code. Do not assume online mode is secure because of anonymous Firebase auth or App Check.

**Implementation discipline:** work in slices. Preserve current user data; write negative security tests before rule deployment; roll out v2 backend and client compatibly. Stop for owner decisions in `DECISION_LOG.md`. Distinguish *local saved*, *queued*, *shared*, *delete pending* and *server removed*; no false 'sent/deleted everywhere' UI.

**Verification discipline:** final, batched `flutter analyze`, `flutter test`, invariant checks, Firestore emulator, two-device tests, network trace. Do not declare green without evidence. The new `tools/verify_phase0_contracts.py` validates documentation only and does not certify safety.

**Handoff:** branch/SHA, changed files, diff summary, tests with actual output, undeployed rules, migrations, unresolved risks, owner approvals and next phase readiness.
