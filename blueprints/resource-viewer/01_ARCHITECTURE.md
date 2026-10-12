# 01 — Architecture & integration contract

## Flow

```text
Dashboard (existing)
  -> StepsViewerScreen (existing, Step N)
  -> ResourceRouter.open(context, ResourceRequest.aaStep(N))
    -> ResourcePolicy.classify + reject unsafe
       | PDF -> ResourcePdfScreen -> HttpPdfAcquirer -> private temp file -> PDFView
       | HTML -> ResourceWebScreen -> WebViewController + NavigationDelegate
       | tel/mailto/sms -> explicit native handler (not WebView)
       | unknown/untrusted/blocked -> explain or confirm external handoff
  -> Navigator.pop -> same StepsViewerScreen state
```

## Component paths (reconciled with current source)

The following files exist in the current tree. This table describes observed responsibilities, not proof that the end-to-end behavior has passed its final acceptance gates.

| Target file | Responsibility | Side effects |
|---|---|---|
| `lib/core/resources/resource_request.dart` | Immutable request: URI, source ID, title, resource kind/intent | None |
| `lib/core/resources/resource_policy.dart` | Pure scheme/origin checks, redirect decisions and type routing | None |
| `lib/core/resources/resource_router.dart` | Navigation/launch coordinator, maps policy decisions to screen pushes | Navigation only |
| `lib/core/resources/pdf_acquirer.dart` | Bounded HTTP streaming, redirect check, magic/header proof, safe temporary file, cancellation, cleanup | Temporary storage and HTTPS |
| `lib/core/resources/aa_step_resources.dart` | 12 immutable per-step records and stable source metadata | None |
| `lib/screens/resource_viewer/resource_pdf_screen.dart` | Native PDF reader and loading/error/retry/toolbar state | No direct persistence |
| `lib/screens/resource_viewer/resource_web_screen.dart` | In-app WebView, navigation interception, back/forward/reload, host display | Website network via OS WebView |
| `lib/screens/resource_viewer/resource_toolbar.dart` | Consistent M3 accessibility controls | None |
| `test/resource_viewer/*_test.dart` | URL policy, per-step lookup, failure and widget behavior | Tests only |

Extract/reuse `_PdfViewerScreen` from `custom_workbook_screen.dart` carefully. Preserve its local imported-file semantics; do not move/delete existing private PDFs, workbook manifest data, or prefs. A new `ResourcePdfScreen` may accept a typed local-or-remote source, or delegate to a common `PdfDocumentViewer` widget. Do not duplicate native PDF view implementations.

## Source and state boundaries

1. `RecoveryDatabase`, Riverpod providers, pet rewards, and `SharedPreferences` keys **are out of scope**. Opening/closing readers may not mutate them.
2. Opening a reader pushes a route; it does not switch the global four-destination `IndexedStack` tab or re-create `DashboardScreen`.
3. ResourceRouter is called by screen UI; URL interpretation is in a pure policy with unit tests. Widgets never implement their own ad-hoc redirect allow/deny logic.
4. Keep PDF acquisition in a dedicated service (not directly in `build()` or a synchronous callback). Dispose and cancel requests on route exit; avoid synchronous main-thread I/O.
5. Preserve `ResourceLinkHealth` semantics, but **do not** use its `HEAD` success/failure as evidence a response is an actual PDF. GET verification is required by the loader.
6. Existing document-source registries remain source-owned; the per-step PDF set is a distinct explicit registry. Do not invent a second generic literature registry unnecessarily.
7. Never load a remote PDF into `flutter_pdfview` via a `https://` `filePath`: it expects on-device bytes/path; save privately first.
8. No new Android `Activity`, exported intent-filter, background service, manifest-permission broadening or database migrations for this feature. If needed, stop and justify a separate architecture decision.
9. DNS preflight on PDF hosts is not a connection pin; the HTTP client may perform a second resolution, and WebView host resolution is not inspected. Do not describe this as complete DNS-rebinding protection.

## Typed routing decisions

Prefer an exhaustive enum/sealed result equivalent to:

- `nativePdf(uri, sourceTitle, originPolicy)`
- `inAppWeb(uri, sourceTitle, originPolicy)`
- `systemScheme(uri, tel|sms|mailto)`
- `requiresUserApproval(reason, uri)`
- `blocked(reason)`

Avoid a Boolean `isPdf` and a Boolean `isExternal` that can both be true. URL extension may hint at type, but remote responses must be verified independently. All external actions require a visible user-triggered action or explicit approval.

## PDF loading contract

`PdfAcquirer` should return a disposable lease/handle containing a validated temporary path and metadata (source URL, resolved URL/host, content length if known). Lease's owner cleans up on dispose even after error/cancellation. A temporary document must never be removed while the PDF native view is still reading it; order: dispose/unmount renderer, then remove owned temp file. Retried loads use fresh handles, not stale paths.

## WebView routing contract

Reported top-level navigation requests are reclassified by ResourcePolicy. A NavigationDelegate may not cover all new-window/pop-up/download mechanisms on every platform; document and device-test those limitations. The current implementation allows page subframes to load and does not inspect subresource destinations or WebView DNS. **Do not equate intercepted top-level navigation with blocking all third-party traffic.** Embedded pages may request resources from CDNs and trackers.

## Failure behavior

Loading -> content OR nonblank actionable error. Back always works. Failure does not silently open Chrome, never exposes an unhandled exception or white screen, and never treats an HTML error page with `.pdf` in the URL as a successful PDF.
