# Phase 03 — Step 1 through Step 12 integration

**State (2026-10-12):** WIRED IN SOURCE · **Release BLOCKED pending independently evidenced official URLs** · **Depends on:** Phase 02 + official URL evidence from Phase 00

The Twelve Steps UI uses `ResourceRequest.aaStep(step.number)` and the explicit 12-entry candidate registry. No durable record substantiates the earlier 2026-10-11 probe claim. The checked-in candidate manifest remains `validated: false`; do not call this phase verified or release-ready until all mappings are substantiated and approved.

## Original implementation scope — wired in source

The explicit candidate registry and `step.number` router wiring are present. The manifest is not verified, so the current mapping is only a candidate and this phase remains blocked for release.

1. `aa_step_resources.dart` contains the explicit 12-entry candidate registry; it must not be treated as deriving from a verified manifest.
2. The expanded `StepsViewerScreen` routes through `ResourceRouter` for the corresponding `step.number`.
3. The action is accessible and labeled as a PDF chapter; step completion, worksheet and sponsor controls remain separate.
4. The Twelve Steps dashboard card remains an internal route.
5. Reader return preserves the underlying screen state; host tests are present, execution pending.
6. Registry invariants cover all 12 mappings. Test execution and official content matching remain pending.

## Required outcome

Tap Step N -> app-native reader for the mapped candidate PDF. Back -> same Step N panel and user data. No automatic Chrome/browser launch and no reward side effect from opening a document. Claiming the document is the official chapter N remains blocked until the endpoint and PDF content are independently verified.
