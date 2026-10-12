# 03 — Twelve Step PDF registry, acquisition and reader

## Source mapping

Per user-provided pattern, candidate URLs are `https://www.aa.org/sites/default/files/2022-01/en_step1.pdf` through `en_step12.pdf`. Treat `data/aa_step_pdf_registry.json` as **candidate URLs pending validation**, not as a runtime-proven inventory. Current `StepsViewerScreen` titles in order are Honesty, Hope, Faith, Courage, Integrity, Willingness, Humility, Brotherly Love, Justice, Perseverance, Spirituality, Service. Titles are app UX labels, not asserted titles of official PDFs.

The chapter documents are from the AA publication *Twelve Steps and Twelve Traditions*, not simply the step text. Link label must distinguish **“Read Step N — AA chapter (PDF)”** from completing a worksheet or sponsor sign-off. Do not award Sparks for opening/reading the PDF.

## Content retrieval process

1. Validate original URI via `ResourcePolicy`; reject unregistered origin or non-HTTPS.
2. Use the existing `http` dependency with streaming client. Disable the client's automatic redirect handling; manually apply a request timeout (15 s response timeout; separate bounded transfer timeout), cancellation, redirect-count cap, and explicit domain policy at **each** hop. Cancel each redirect response body rather than draining it without a byte bound. Follow only HTTPS approved origins (vetted official redirect/CDN if required).
3. Honor `Content-Length` when provided and enforce a **streamed-byte maximum** even when length is missing, compressed or false. Begin with a documented conservative cap (proposal: 25 MiB) after measuring actual largest chapter PDF. Avoid `response.bodyBytes` for unbounded payloads.
4. Capture status and `Content-Type`. Only accept expected HTTP success; check `%PDF-` header within first bytes and ensure minimal plausible payload, optionally verify EOF/trailer as a defense-in-depth clue. Avoid relying on URL suffix.
5. Write a uniquely named file to `getTemporaryDirectory()` via atomic partial path then rename after validation; fail closed on interruption.
6. Mount shared PDF view only after validated file ready. Show source title, actual host, loading progress, current/total pages, appropriate back/close, zoom via native gestures, retry and explicit original-link escape.
7. Dispose `PDFView` before removing the temporary file; catch I/O errors. Cleanup orphaned `rfa_resource_pdf_*` temp files on later reader entry/boot (bounded, scoped only to this prefix). On route exit abort in-flight download.
8. Do not persist file/document/browsing metadata beyond temporary reader lifecycle. Any persistent "Save offline" must be separately approved and rights-reviewed.

## PDF viewer reuse

`lib/screens/custom_workbook_screen.dart` already has private `_PdfViewerScreen`. Safest extraction: create a generic `PdfDocumentView` widget that accepts an **existing local path** and a title, and a dedicated remote controller `ResourcePdfScreen` that acquires file then calls same widget. Move page/loading/error behavior without modifying workbook storage, import/delete, file paths, or saved prefs. Ensure a workbook file is **never deleted** by the temporary remote-PDF cleanup. Distinguish `ownsTemporaryFile` from caller-owned file.

## Step screen wiring

Replace hardcoded `launchUrl(Uri.parse('https://www.aa.org/the-twelve-steps'), mode: LaunchMode.externalApplication)` within each expanded step with a `ResourceRequest.aaStep(step.number)` resolved through the explicit registry. The step tile stays on screen beneath the pushed reader. Return must preserve expansion/scroll position; do not toggle completion or sign-off.

Prefer preserving existing translated/accessibility semantics and touch target sizing; improve small underlined `InkWell` into a Material `TextButton` or labeled link tile with at least 48x48 dp target, visible PDF icon, `Semantics(button: true, label: 'Read official AA Step N chapter as PDF')`, and success/failure feedback.

## Document verification

For all N = 1..12, log to a **local, non-committed** release checklist: original URL, final URL/host, HTTP status, content type, first bytes, byte count, page count, hash (for local provenance only), timestamp and device. Do NOT check PDF bytes into Git; do not add bundled PDFs to Flutter assets. If any URL changes or fails, update explicit registry based on official AA links, run `tools/verify_resources.py` under existing repo policy, and document the corrected map.

## Licensing

Linking to and opening an official hosted AA chapter is not equivalent to having redistribution rights. Do not bundle, mirror, rehost, or publish stored chapter PDFs in APK/AAB or public repo without suitable permission. Temporary local per-user retrieval should be reviewed against AA's current terms before release. Keep official source attribution and allow the user to leave for the original site when the viewer is incompatible.
