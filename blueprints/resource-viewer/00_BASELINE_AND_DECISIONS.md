# 00 — Baseline, boundaries, and decisions

**Reconciled against local source:** 2026-10-12. This records source observations only; no claim of current APK, device, or live-network behavior is implied.

## Current source baseline

| Area | Reconciled source state |
|---|---|
| Twelve Steps | `steps_viewer_screen.dart` routes each expanded step through `ResourceRequest.aaStep(step.number)` and the explicit 12-entry registry. The UI path is present; the AA endpoint/PDF evidence remains unverified. |
| Literature and Community Resources | Both screens call `ResourceRouter.open`; pathway selection and existing link-health behavior remain in those screens. |
| PDF viewer | Remote documents use `PdfAcquirer` and the shared `PdfDocumentView`; the custom-workbook screen passes a caller-owned local path. Remote temporary-file cleanup is prefix-scoped and does not own workbook files. |
| Web viewer | `ResourceWebScreen` uses `webview_flutter`, keeps JavaScript disabled, displays the live host, and intercepts reported main-frame navigation. Subframes/subresources are not treated as fully filtered. |
| Other launches | SOS/dialing, maps/directions, meeting joins, housing, onboarding, Wellbriety, donation, and settings/legal launchers remain distinct; see `07_LINK_INVENTORY.md`. |
| Data and security boundary | No new database, preferences, auth identity, manifest permission, external browser history, analytics, or persistent PDF storage is part of this implementation. |

## Decisions fixed by this blueprint

| Decision | Choice | Reason |
|---|---|---|
| PDF renderer | Reuse the existing `flutter_pdfview` local-file path | Avoid duplicate native renderer and preserve imported-workbook behavior. |
| PDF acquisition | Stream HTTPS into a private temporary file and validate status, media type, PDF header/trailer, and byte ceiling | Avoid public storage and unbounded response buffering. |
| Per-step mapping | Explicit Step 1–12 registry; no URL construction in widgets | Keep each destination auditable and testable. |
| HTML renderer | Use the already pinned `webview_flutter` dependency | Avoid a new plugin/version change during this reconciliation. Platform compatibility still needs device/release validation. |
| Navigation | Shared typed router and central URL policy | Prevent independent callsite scheme/origin decisions. |
| URL trust | Exact registered HTTPS origin; bounded PDF redirect handling | No wildcard trust or silent origin expansion. |
| Back behavior | Web history first, route pop second | Preserve expected reader behavior and the recovery screen underneath. |
| Cache | Short-lived private temporary PDF only | Minimize retained activity and licensing exposure. |
| Analytics | None | Preserve the app's privacy posture. |
| Existing flows | Preserve workbook files, SOS, calling, maps, meeting joins, and other explicitly dispositioned routes | Avoid an unsafe blanket migration. |

## Release evidence still required

- Independently verify each official Step 1–12 candidate URL: redirect chain, final host, status, MIME, `%PDF-` magic, byte count, page count, date, and device. Keep a durable local release record; do not commit PDF bytes.
- No durable response evidence for the claimed 2026-10-11 endpoint check was found in the reviewed tree. The candidate manifest remains unverified; endpoint availability and content are not promoted to verified.
- Review current AA terms for transient per-user viewing, distinct from bundling/redistribution rights.
- Run final host gates once, after implementation edits. Then perform physical Android and current release-artifact checks; host tests do not establish native WebView/PDF performance or release signing.
- DNS checks in `PdfAcquirer` are preflight only: the HTTP client may resolve again at connection time. WebView host resolution is not inspected.

## Interaction and privacy contracts

- Tap Step N's literature action -> route to that exact chapter request. Opening it grants no Sparks and does not complete the step.
- If offline, show an actionable error and retry; do not claim the chapter is cached.
- Reject malformed, unsupported, local, credentialed, or dangerous schemes. A valid system link requires an explicit user action before invoking the OS.
- Unknown off-origin main-frame navigation never loads automatically; present a destination-specific review/handoff where supported. Invalid destinations remain blocked.
- Never put journal, recovery, sponsor, profile, location, app-auth, or pathway data in page URLs, request headers, logs, or JavaScript bridges.
- Embedded pages remain external websites and can contact third parties; no claim of tracker blocking, network silence, or privacy from the destination is made.
