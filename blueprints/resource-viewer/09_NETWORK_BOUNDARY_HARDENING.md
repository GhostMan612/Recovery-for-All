# RV-17 / RV-18 — Origin-bound external resource and feed security work order

**Status:** design-only, release security acceptance pending  
**Priority:** P1 network trust and privacy  
**Related:** `02_URL_POLICY_AND_PRIVACY.md`, `06_RISKS_AND_DECISIONS.md` (RV-16), `05_VERIFICATION_AND_RELEASE.md`.

## Source-grounded risk

`lib/core/resources/resource_policy.dart` explicitly acknowledges that
preflight DNS resolution of an approved hostname does **not** bind the chosen
IP to the eventual HTTP socket. A second DNS resolution may return an address
that was not checked. The Android/iOS WebView has its own URL resolution,
redirects and subresource fetching, outside the PDF acquirer's preflight.
Source review cannot prove an exploit or any specific device's packet flow.

Separately, `ResourceLinkHealth.checkUrl` uses default `http.head` /
`http.get`, which can follow redirects automatically and does not share
the resource view policy's per-hop inspection. The new custom-feed HTTPS
validator in separate PR #21 guards **the initial URL**, not every redirect
or the final socket destination; `MeetingFinderService.refresh` similarly
uses high-level HTTP with automatic redirects. This is a multi-entrypoint
trust problem, not a justification for a blanket regex or a claim of SSRF
resistance.

## Audited scope and decisions before code

1. **Classification.** Separate (a) registered first-party AA PDF resources,
   (b) user-chosen arbitrary community HTML, (c) link health diagnostics,
   (d) custom meeting-directory fetches, and (e) OS external browser handoff.
   Each has different trust, consent, bytes, and UI expectations. Never
   override a human-approved external escape with a hidden in-app fetch.
2. **Origin/redirect invariant.** Classify URL before network use and on
   *every* redirect, downgrade, protocol change, port change, userinfo,
   IP literal or hostname alias. On any policy violation, stop automatic
   loading and require user action or block. Redirect count, response size,
   content type and total time must be bounded. Cross-origin AA apex/www
   exception requires exact documented registry behavior.
3. **Socket resolution.** Propose an implementation that actually binds the
   validated destination address to the connection while retaining TLS SNI
   and hostname validation, **or** fail closed with a narrower allowlist and
   acknowledge residual risk. DNS preflight followed by a new high-level
   socket is not address binding. Do not disable certificate verification.
4. **WebView subresources.** Audit actual `webview_flutter` platform hooks
   for navigation requests, links, target=_blank, JavaScript, redirects,
   mixed content and cross-origin subresources. Some platform WebView
   APIs cannot reliably intercept every subresource. Where enforcement is
   impossible, disclose that boundary and do not market it as a secured
   offline browser. No privileged JS bridge, file:// access or bearer tokens
   provided to untrusted pages.
5. **Privacy.** User-directed Open in Browser and manual Verify Links actions
   must disclose external IP/UA/cookie exposure. List browsing should not
   silently probe links (see separate PR #27). The directory fetcher must
   respect current-session `directoryRefresh` consent even if a persisted
   URL exists. Network denial on cold boot and revocation are independent
   acceptance gates.
6. **No large binary regression.** PDF fetch remains streaming with bounded
   disk budget, timeout and atomic cleanup; no copyrighted PDF bundling.
   Protect app startup and SOS from stalled network or DNS lookups.

## Test and release matrix

- Unit HTTP mocks: same-origin redirect, AA audited alias, third-party,
  HTTPS-to-HTTP downgrade, private/loopback/IPv6 literal, rebinding-resolved
  public→private address, redirect loops, 401/403, chunked over-limit,
  cancellation and response close.
- Native Android WebView tests: new windows, back/forward, JS toggle,
  mixed-content resources, off-origin navigation, file requests, app
  background/disposal, accessibility and stale PDF recovery.
- Device packet capture while browsing Literature/Community, opening
  internal PDF and clicking off-domain resources; confirm exact destination
  hosts, no journal/step content and no automatic silent egress.
- Flutter analyzer and host tests; 14 invariants and selftests; emulator
  rules suite; signed release and physical-device sign-off separately.

**Closeout rule:** Host CI green establishes code-level behavior only. It
does not establish DNS-rebinding resistance, WebView subresource isolation,
provider privacy, valid third-party AA rights, or a safe production release.
