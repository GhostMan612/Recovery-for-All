# Phase 04 — In-app website reader

**State (2026-10-12):** IMPLEMENTED IN SOURCE · **Final host/device validation pending** · **Depends on:** Phase 01 + plugin compatibility review

`webview_flutter` and `webview_flutter_android` are already pinned in the project dependencies, and the WebView screen, toolbar, policy interception, error states, explicit browser handoff, and fake-controller widget tests exist. The WebView now offers a destination-specific review action for unapproved main-frame links and a Continue action for valid phone/mail links; both re-enter the shared router/confirmation path. Native platform behavior remains unverified.

## Original implementation scope — present in source

`ResourceWebScreen`, the toolbar, injectable controller/view seams, navigation policy and error states are present. The `webview_flutter` dependencies are pinned, but native compatibility remains unverified.

1. Manifest and lockfile pin the plugin; current toolchain compatibility must be recorded through final checks.
2. The screen uses current Material 3 tokens and `WebViewController`, `WebViewWidget`, and `NavigationDelegate`.
3. Current host, loading, back/forward/reload, close, explicit browser handoff, and error states are implemented.
4. Reported main-frame PDF links route to the native reader. Off-origin and valid system links require the user to choose Review/Continue. Popup, download, and subresource behavior still needs device review.
5. Host tests use fake decisions/controllers where possible; their execution and native WebView behavior remain pending.
6. JavaScript remains disabled; no complete tracker-blocking claim is made.

## Required outcome

HTML recovery resource remains inside app, visibly labels source origin, supports navigation, and returns to prior recovery screen. Untrusted redirects require approval or are blocked. Failing to load is never an excuse for silent Chrome launch.
