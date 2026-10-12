# 06 — Risks, tradeoffs, and deferred work

| ID | Severity | Risk / unresolved question | Mitigation / exit condition |
|---|---|---|---|
| RV-01 | HIGH | Some `en_stepN.pdf` paths may be outdated, 403, or HTML redirects | Phase 0 validates N=1..12; record actual PDF evidence; update from AA official site only |
| RV-02 | HIGH | Reader fetch follows redirect to hostile/unexpected host | Re-check allowlist at every hop; explicit user approval, no silent trust expansion |
| RV-03 | HIGH | WebView cannot guarantee zero third-party tracking | Disclose origin; no user data bridged; avoid broad browsing; browser escape |
| RV-04 | HIGH | Streaming PDF download unbounded/memory pressure | Streamed bytes cap, timeout/cancel, temp storage, low-end device test |
| RV-05 | HIGH | Workbook refactor deletes imported PDFs or prefs | Reuse renderer with explicit file ownership; regression tests, no schema/prefs edit |
| RV-06 | HIGH | Platform/R8 release-only WebView or PDF failure | Release-signed physical device matrix; no assumptions from host tests |
| RV-07 | MED | AA copyright/distribution misunderstandings | Link/fetch per user; no bundling/publishing; rights review for persistent offline mode |
| RV-08 | MED | PDF URI returns HTML challenge/interstitial | Verify content-type and PDF magic, show failure/source escape |
| RV-09 | MED | `webview_flutter` dependency incompatibility | Resolve installed Flutter/Gradle/Kotlin/minSdk first, pin version at code phase |
| RV-10 | MED | PDF hyperlinks/target=_blank bypass routing | Intercept as supported; deny unsupported auto-launch; physical test |
| RV-11 | MED | Material WebView content remains inaccessible at larger type | Toolbar accessible, browser escape; test site rendering at 2x text |
| RV-12 | MED | Viewer route closes but underlying step scroll/expansion resets | Preserve State and Navigator stack; widget regression test |
| RV-13 | MED | WebView JS default OFF breaks sites | Per-site documented exception with tests and no privileged JS bridge |
| RV-14 | MED | No network in a recovery-critical moment | Honest offline state, local core tools remain accessible; no dependence on resource URLs for SOS |
| RV-15 | HIGH | Live fetches yielded PDF-format responses for all twelve AA candidates, but status, redirects/final host, complete response identity, chapter match and device behavior are not proven | Keep all twelve AA URLs unverified for release until complete response and Step N content evidence, plus device observations, are independently recorded |
| RV-16 | HIGH | DNS preflight does not bind the checked address to the HTTP connection; WebView resolution is outside the preflight | Describe as best-effort preflight only; do not claim DNS-rebinding resistance or general SSRF prevention |

## Non-negotiable sign-off points

- **AA URL evidence**: independently review/approve all resolved official PDF endpoints after Phase 0. Source wiring exists, but remains blocked for release until durable evidence is produced.
- **External browser policy**: decide if off-domain trusted partners get a confirmation or a hard block; default is confirmation, user-triggered handoff only.
- **Persistence/licensing**: no persistent offline content in this scope. A later feature requires its own rights, storage/encryption, deletion and lifecycle design.
- **Other registered domains**: decide per-domain JavaScript and redirect permissions from actual behavior, not a blanket permissive setting.

## Rejected shortcuts

- Globally change every `LaunchMode.externalApplication` to `inAppWebView` and hope that PDFs render. Android WebView does not guarantee PDF support; SOS/tel links break.
- Add twelve hardcoded URL strings inside widgets without a testable registry.
- Add `webview_flutter` to the planning overlay `pubspec.yaml` before toolchain compatibility verification; this would unexpectedly modify build inputs and violate a blueprints-only package.
- Mirror copyrighted AA PDFs into `assets/`, Git, Git LFS, public Firebase or Play Store package.
- Add a second recovery database/cache system just to remember browsing activity.
- Automatically retry failed WebView pages by switching to Chrome without a deliberate user action.
- Treat successful link-health `HEAD` as proof of valid `application/pdf` payload.
