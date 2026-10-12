# Phase 02 — Shared native PDF reader and bounded fetcher

**State (2026-10-12):** IMPLEMENTED IN SOURCE · **Host/device validation pending** · **Depends on:** Phase 01

The reusable PDF reader and streamed acquirer are present, including bounded writes, HTTP/PDF checks, redirect policy, temporary-file ownership, cancellation, and workbook-reader reuse. This task added atomic completion, aged prefix-scoped cleanup, active-file protection, DNS-answer preflight, and owned-client disposal. The browser escape now uses the final response URI when available. DNS preflight is not connection pinning; release/device proof remains outstanding.

## Original implementation scope — present in source

The shared renderer/acquirer, caller-owned workbook path, bounded streaming, manual redirect checks, cancellation and route lifecycle are present. These original requirements are recorded for audit; final host/device verification is still pending.

1. `PdfDocumentView` is shared with `custom_workbook_screen.dart`; imported-workbook ownership and preference keys are preserved.
2. `pdf_acquirer.dart` streams under size/time limits, validates status/content, manually rechecks redirect destinations, and owns only its prefixed temporary files.
3. `resource_pdf_screen.dart` provides source, progress, retry/error/offline, explicit browser escape, and back/close behavior.
4. Route teardown unmounts the PDF view before deleting the owned remote lease; caller-owned local workbook files are not deleted.
5. Focused tests cover failed/false PDF responses, streaming bounds, cancellation, redirect policy, cleanup, and workbook ownership; execution is pending the final gate batch.

## Required outcome

- App-native PDF works on a local imported workbook and a verified remote test PDF without launching system browser.
- No accumulation of unfinished temp files, no public storage access, no PDF content in repository or app assets.
- If live official site cannot be reached, UI displays honest failure with retry and user-invoked original link.
