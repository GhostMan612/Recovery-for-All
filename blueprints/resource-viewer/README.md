# Recovery for All — Internal Resource Viewer

**Status:** IMPLEMENTATION PRESENT IN WORKING TREE; CI PASS; RELEASE ACCEPTANCE BLOCKED<br>
**Baseline reconciled:** Local Resource Viewer source and tests reviewed 2026-10-12. The historical GitHub baseline below predates the current implementation and is retained as provenance, not as current-state evidence.<br>
**Change type:** Existing Flutter implementation hardened and reconciled with this blueprint. No database, Android manifest, signing, or remote GitHub changes are part of this work.<br>
**Source of truth:** this folder for the resource-viewer project; repository `AGENTS.md`, `RULES.md`, `SESSION_HANDOFF.md`, and applicable security/privacy documents remain authoritative. Resolve conflicts by stopping and recording a decision rather than overriding established rules.

## Mission

Keep users in **Recovery for All** while they read built-in recovery resources. The **Twelve Steps** screen must link each Step 1–12 to its corresponding official AA PDF chapter and render it in the existing native PDF technology. Ordinary approved website links will be rendered by an in-app WebView, while phone/SMS/mail, unsupported schemes, sensitive destinations, and user-selected "Open in browser" remain OS-handled.

**Critical distinction:** in-app web/PDF viewing does not mean the linked resource is offline, private from the destination website, licensed for redistribution, or bundled inside the app. Never describe it that way.

## Baseline findings confirmed in source

| Path | Current behavior | Integration intent |
|---|---|---|
| `lib/screens/dashboard_screen.dart` | "The Twelve Steps" tile routes internally to `StepsViewerScreen` | Preserve route/state |
| `lib/screens/steps_viewer_screen.dart` | Each step uses `ResourceRequest.aaStep(step.number)` | Exact per-step mapping is wired; official endpoint content proof remains pending |
| `lib/screens/literature_library_screen.dart` | Entries call `ResourceRouter.open` | Shared website/PDF routing is present |
| `lib/screens/community_resources_screen.dart` | Entries call `ResourceRouter.open` | Shared routing is present |
| `lib/screens/custom_workbook_screen.dart` | Imported local files use shared `PdfDocumentView` through `ResourcePdfScreen.local` | Preserve caller-owned workbook paths |
| `lib/data/recovery_literature.dart` | Registered URL inputs; existing link-health service consumes them | Preserve registry and health semantics |
| `pubspec.yaml` / `pubspec.lock` | `http`, `path_provider`, `flutter_pdfview`, `url_launcher`, `webview_flutter`, and Android implementation are present | Dependency resolution is present; platform/release compatibility is not verified here |
| `android/app/src/main/AndroidManifest.xml` | Existing `INTERNET` permission | No blanket manifest changes |

Line numbers and commit are *orientation pointers*, not frozen contracts. Agent must re-scan real source before editing.

## Deliverables and acceptance boundary

- **Shared, testable `ResourceRouter`**: present in source; GitHub Actions host gates passed; device acceptance remains pending.
- **Native `ResourcePdfScreen`**: present in source and reuses the existing native PDF renderer; device lifecycle and release checks remain pending.
- **Twelve Steps PDF registry**: explicit Step 1–12 mapping is wired; all twelve aa.org candidates yielded PDF-format live responses, but status/redirect/final-host and exact chapter-content verification remain blocked pending complete evidence.
- **In-app `ResourceWebScreen`**: present in source; platform behavior and accessibility acceptance remain pending.
- **Migrations**: Literature and Community Resources use the shared service; SOS phone calls and other explicitly dispositioned native actions remain outside this migration.
- **Proof**: GitHub Actions host gates passed for the implementation and subsequent source-unchanged commit; Moto G 2025/BLU View 5 device checks and current release-specific smoke test remain pending.

## Build order

Read `00_BASELINE_AND_DECISIONS.md`, `01_ARCHITECTURE.md`, `02_URL_POLICY_AND_PRIVACY.md`, `03_PDF_PIPELINE.md`, `04_WEBVIEW_UI.md`, and `05_VERIFICATION_AND_RELEASE.md`; review the work orders in `phases/` **in numeric order**. Their implementation scope is reconciled against current source below; do not repeat work already present. Use `data/aa_step_pdf_registry.json` solely as an unverified **proposed** manifest until Phase 0 checks it on network and device.

## Reconciled execution status — 2026-10-12

The router, URL policy, PDF acquisition/reader, Twelve Steps wiring, WebView, and Literature/Community routing exist in the working tree. This session hardened their failure and resource-lifecycle paths, corrected invalid system-scheme classification, added destination-specific review for off-origin WebView navigation, and reconciled the inventory and acceptance documents. GitHub Actions host gates passed; source presence and CI are not phase acceptance, and physical-device/release checks remain pending.

| Phase | Current state |
|---|---|
| 00 — Reconnaissance and URL proof | Partially reconciled; 12/12 live fetches returned PDF-format responses; complete HTTP/redirect/content identity and device evidence remain unavailable. |
| 01 — Router and policy | Implemented in source; CI host gates passed. |
| 02 — Native PDF reader and fetcher | Implemented in source; CI host gates passed; device lifecycle proof pending. |
| 03 — Twelve Step links | Wired to the explicit registry; PDF-format responses observed, but blocked for release pending independent HTTP/redirect and Step N content verification. |
| 04 — WebView | Implemented in source; CI host gates passed; Android device proof pending. |
| 05 — Literature/Community migration | Those two screens use the shared router. Other link launchers remain explicitly dispositioned in `07_LINK_INVENTORY.md`; the complete scope inventory is not a blanket migration authorization. |
| 06 — Final QA and handoff | Not complete; CI passed, while full endpoint identity, physical-device, and current release-artifact/signing checks remain outstanding. |

The package’s candidate manifest still says `UNVERIFIED_AS_OF_2026-10-09`. Partial live PDF-format observations are recorded in `phases/PHASE_00_RECON_AND_URL_PROOF.md`; do not treat the candidate mapping as fully verified.

This is an additive feature program. Existing [UI/UX modernization](../UI-UX-themes-plan.md) remains complete; do not reopen its 17 phases or change the dashboard layout as a side effect.

## Definition of done

Source implementation and focused host tests are present; GitHub Actions host gates passed. Final acceptance still requires measured route and error behavior, complete official URL evidence, physical-device checks, and the required artifact/release checks. Do not infer platform success from source or host tests. Record observed evidence instead of assuming the suite proves device behavior.

## Non-goals

No bulk offline mirroring of AA publications; no copyrighted PDFs embedded into APK/AAB; no new database/schema; no login/password manager; no arbitrary download manager; no collection of browsing history; no changes to the Recovery Coach, sponsor security model, SOS workflows, or companion economy. Defer user-requested persistent offline saves to a separately authorized, rights-reviewed phase.

## Implementation authorization

The user authorized implementation of Phases 00–06 in the current task. That authorization does not permit a build, release, device mutation, commit, or push beyond the standing repository rules. Follow root `AGENTS.md` and `RULES.md`; run the final verification sequence once, after the complete plan is finished. Do not mark phases verified from source review alone.
