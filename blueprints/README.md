# Recovery for All — Blueprint Index

**Repository:** `GhostMan612/Recovery-for-All` · **Planning index created:** 2026-10-09. This document lists blueprints present at the time of this overlay; it does not assert code is shipped merely because a blueprint exists.

| Blueprint | Status | Scope |
|---|---|---|
| **[Spec → Implementation → Verification Ledger](SPEC_IMPLEMENTATION_LEDGER.md)** | **Living status ledger** | The status source of truth for specs and active work orders. A merged blueprint is not delivery. |
| [UI/UX modernization](UI-UX-themes-plan.md) | Completed according to existing project's phase record | Existing 17-phase Material 3, navigation, accessibility and dashboard program. **Do not reopen** for resource viewer. |
| [Dashboard IA](dashboard-ia.md) | Existing / historical portions superseded | Four destination dashboard, modular tool cards, global SOS. |
| [Category-platform Phases 0–4](category-platform/PHASES_1_TO_4_INDEX.md) | Phase 0 in progress; Phases 1–4 planned / not implemented | Privacy, progression, Atlas navigation, Circle cooperation, release evidence. Documentation only for Phases 1–4. |
| [Lessons learned](lessons-learned.md) | Existing living ledger | Concrete engineering failures, causes, prevention rules. |
| **[Internal Resource Viewer](resource-viewer/README.md)** | **Implementation present in working tree; final validation pending** | Native PDF per Step 1–12; shared HTML WebView; safe router; accessibility, privacy, tests and release verification. Source presence is not device/release acceptance. |

**Status authority:** use the ledger, not this index, for implemented versus
specified. This table records what a blueprint covers; it is not a release
claim.

## New resource-viewer package

Open [resource-viewer/README.md](resource-viewer/README.md), then [00 baseline](resource-viewer/00_BASELINE_AND_DECISIONS.md) through [08 acceptance](resource-viewer/08_ACCEPTANCE.md), and phase work orders in [resource-viewer/phases](resource-viewer/phases). Its candidate AA PDF manifest lives in [resource-viewer/data/aa_step_pdf_registry.json](resource-viewer/data/aa_step_pdf_registry.json).

The scoped `AGENTS.md` files at `lib/core/resources/`, `lib/screens/resource_viewer/`, and `test/resource_viewer/` now describe existing source and tests. The blueprint status matrix records which phase evidence remains pending or blocked; the candidate AA endpoint manifest and unverified source comments are not proof of successful live retrieval.
