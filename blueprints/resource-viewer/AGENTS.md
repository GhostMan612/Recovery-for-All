# AGENTS.md — Resource Viewer blueprint work orders

Scope: `blueprints/resource-viewer/` only. Read repository root `AGENTS.md`, `RULES.md`, `SESSION_HANDOFF.md` **first**. This document does not override them or invent a separate agent workflow.

- **Reconciled 2026-10-12:** source implementation is present; GitHub Actions host gates passed. Live fetches yielded PDF-format responses for all twelve Step candidates, but complete endpoint/chapter identity, physical-device behavior, and release acceptance remain pending or blocked. Source presence and CI are not phase acceptance.
- Review phases `PHASE_00` through `PHASE_06` in numeric order. Their original implementation scope is reconciled against the source; do not repeat completed work. Record any rephasing decision in `06_RISKS_AND_DECISIONS.md`.
- Inspect current source before changing it and preserve unrelated work. Root shell discipline defers Git status/diff and all verification to the single final batch; never infer the pre-change dirty state from a later diff.
- Every URL in `data/aa_step_pdf_registry.json` is **CANDIDATE / UNVERIFIED**. Never label as verified without a live content check on the current date.
- Preserve all source ownership, local imported workbooks, sponsor/step completion and reward behavior; no database or UI/UX architecture rewrite.
- No PDF content in Git; no background analytics; no arbitrary user-entered WebView URLs; no TLS bypass.
- Use existing app theme primitives, `ResourceLinkHealth` and `flutter_pdfview`; the WebView dependencies are already pinned. Do not change dependencies without a concrete compatibility finding and authorization.
- Root shell discipline governs: implement entire agreed plan, then run quality gates as **one batched** verification step and record results; no per-edit shell loops.
- Do not silently modify remote GitHub. Local changes and commits are controlled by repo's established workflow and the human operator.
