# Remote agent-handbook reference audit — 2026-11-11 local

**Repository:** `GhostMan612/Recovery-for-All`  
**Evidence:** complete, untruncated recursive Git tree for `main` at
`2a763ef6fafdfa9af64d8615691d8292279bb77a`
(739 tracked entries / 594 tracked blobs).

## Confirmed missing paths referenced by `AGENTS.md`

The following filenames appear in the remote handbook or operating-law notes,
but **do not exist as tracked paths** at the audited revision:

| Referenced path | Status and next action |
| --- | --- |
| `CLAUDE.md` | Not tracked. May exist only in a developer's local checkout. Apply `RULES.md` as canonical; do not invent or publish local agent instructions. |
| `blueprints/roadmap-v2.md` | Not tracked. Use `blueprints/category-platform/PHASED_EXECUTION_PLAN.md` for existing platform phase planning; no assertion it is the same roadmap. |
| `blueprints/pet-store-rules.md` | Not tracked. Use `blueprints/category-platform/phase-1/ECONOMY_AND_ETHICS.md` and `contracts/RECOVERY_SAFETY_AND_ETHICS.md` as **available references only**. |
| `blueprints/gguf-feasibility.md` | Not tracked. The actual `lib/services/gguf_model_service.dart` and GGUF work orders are the source for implemented state. |
| `blueprints/avatar-art-spec.md` | Not tracked. Active vector art and tests live under `lib/widgets/`, `test/cosmetic_vector_art_test.dart`, and `test/species_vector_art_test.dart`. |
| `blueprints/tacmap-extraction.md` | Not tracked. Available navigator and offline map work is in `blueprints/category-platform/phase-2/`. |
| `blueprints/firebase-setup.md` | Not tracked. Source configuration files are `firebase.json`, `firestore/firestore_v2.rules`, and Phase 0 privacy/security documentation. These do **not** replace a deployment runbook. |
| `blueprints/recovery-pet-checklist.md` | Not tracked. Phase 1 companion, reward, and quest work orders exist under `blueprints/category-platform/phase-1/`. |
| `blueprints/recovery-coach-checklist.md` | Not tracked. Safety contracts exist under `blueprints/category-platform/contracts/`; do not assume they cover the absent checklist. |
| `blueprints/resource-system.md` | Not tracked. Existing Resource Viewer plans live at `blueprints/resource-viewer/`; registries at `lib/data/recovery_literature.dart` and `lib/data/recovery_resources.dart`. |
| `blueprints/recovery_all_code.md` | Not tracked. `tools/generate_code_package.py` describes this as generated output; regenerate locally only if needed, and do not silently commit a large generated aggregation. |

## Source/agent-workflow implication

A fresh clone can follow tracked `RULES.md`, `AGENTS.md`,
`SESSION_HANDOFF.md` and the existing scoped `AGENTS.md` files.
It cannot obey instructions to **read non-existent tracked paths**. Preserve
the historical references above as provenance and do not fabricate their
content. The owner may later choose which local-only references belong in
the public repository after licensing, secrets, and provenance review.

This PR documents the discrepancy and corrects only the misleading
mandatory reference to `CLAUDE.md`. It does **not** delete institutional
history from `AGENTS.md`, alter agent execution permissions, or assert
that a missing historical file's requirements have been fulfilled.
