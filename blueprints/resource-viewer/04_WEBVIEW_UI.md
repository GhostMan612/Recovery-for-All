# 04 — Embedded website viewer and Material 3 UX

## Dependency status

The working tree already pins `webview_flutter` and `webview_flutter_android` to `4.14.1`, and source uses `WebViewController`, `WebViewWidget`, and `NavigationDelegate`. The compatibility/build gate has not been run in this work session; do not claim Android compatibility solely from package constraints.

References: https://pub.dev/packages/webview_flutter ; https://pub.dev/packages/webview_flutter/changelog ; https://pub.dev/packages/webview_flutter_android/changelog

## Visual model

Reader remains a pushed Flutter page, not an external Android activity and not a persistent dashboard tab. Use theme `ColorScheme` and existing shared M3 primitives, **no new palette**. Layout:

```text
< back or close  Resource title                           ... >
Verified current domain (e.g. www.aa.org)   [open externally]
[thin loading progress bar while needed]
+-----------------------------------------------------+
|                    WebViewWidget                    |
|   remote site content (not controlled by app)        |
+-----------------------------------------------------+
< Back            Forward           Reload       Close
```

- Host/title is verified from actual loaded URL; never describe third-party HTML as an app-owned resource.
- Back/forward states are disabled appropriately; stop/reload loading state and progress reset on navigation; use `onPageStarted`, `onProgress`, `onPageFinished`, `onWebResourceError`, `onHttpError` as available/appropriate.
- App back gesture/button should attempt `canGoBack()` then `goBack()`, otherwise `Navigator.pop`. Avoid double pops across Android predictive-back support; pin widget tests and physical device cases.
- Screen has a reachable close action even if page hangs, redirects, or cannot load. A failed WebView never blocks return to recovery tools.
- Use shared `AppLoadingState`, `AppOfflineState`, `AppErrorState` where possible. No blank white-error page and no automatically opened browser after failure.
- Accessibility: proper labels/tooltips, 48dp targets, talkback/VoiceOver ordering, loading status live region without repeated announcements, correct large text/320dp scaling and portrait/landscape insets.
- Reduced-motion mode controls app chrome animations; do not attempt to rewrite third-party page animations behind website ownership. Explain accessible external-browser fallback if website's content itself is inaccessible.

## Security boundaries

`WebViewController` must start with JavaScript disabled unless a tested trusted site needs it. No JavaScript channels into recovery state. Do not expose credentials, auth tokens or app storage. No automatic file picker, upload, camera, mic, geolocation or notifications. URL redirects and top-level navigation follow `ResourcePolicy`; untrusted site -> approval/interstitial or block. Browser escape via explicit user action and domain label. Do not use `NavigationDelegate` alone as evidence that third-party images/scripts/cookies are blocked.

## Platform behavior to test

- WebView unavailable/outdated/disabled on low-end BLU: show meaningful error and explicit external escape.
- Link to PDF from inside HTML: navigate to **native PDF route** rather than rely on platform PDF viewing (Android WebView does not guarantee direct PDF rendering).
- New-window `target="_blank"` links, JS window open, downloads, form submissions, `intent://`, custom schemes, mailto/tel and embedded players: classify and consciously block or hand off.
- HTTP error returned with valid HTML body (404/403) must show an error/status rather than silently claim success.
- Application background/resume and screen rotation retain or safely recreate the reader with no crashes or unintended second navigation.

## Exit safety

Never reset `DashboardScreen`, `StepsViewerScreen` local state, journal state or recovery session when closing. No external app is launched except for consciously approved native/system actions. No universal intercept of Android system links; scope this change to built-in app-generated resource links only.
