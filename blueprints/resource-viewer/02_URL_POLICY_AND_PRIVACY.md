# 02 — URL routing, security and privacy policy

## Security defaults

- Accept `https:` only for embedded network content; reject `http:`, `file:`, `content:`, `data:`, `javascript:`, `intent:`, custom schemes, network-relative URLs without trustworthy base, loopback, link-local and private network hosts. For hostnames resolving into private IPs, enforce DNS/IP checks in the HTTP fetcher; a WebView cannot provide reliable DNS/IP resolution guarantees by itself, so **do not accept arbitrary user-entered URLs** in this initial scope.
- Normalize host with URI parser; compare **exact allowlisted origins/hosts** and carefully audited subdomains, not string-prefix matching. `aa.org.evil.example` must not pass `aa.org`. Exclude embedded credentials, unusually long URLs and unsolicited ports. `https://www.aa.org` and `https://aa.org` are first-party examples, not evidence every path is safe.
- The PDF fetcher disables the HTTP client's automatic redirects and manually follows HTTP redirects, canceling each redirect response body and rechecking trust at each hop, with a five-hop ceiling. For the WebView, the `NavigationDelegate` reclassifies reported main-frame navigation requests; an unapproved HTTPS destination is prevented and exposes a `Review` action whose handoff confirms the destination host before external launch. Valid `tel:`, `sms:`, or `mailto:` main-frame links are prevented until the user chooses `Continue`, then re-enter the shared router. Invalid/unsupported links remain blocked. No silent origin expansion.
- WebView enforcement is limited to navigation requests reported by the platform delegate. It does **not** inspect DNS answers, comprehensively intercept subresources, or establish coverage of every popup/download mechanism on every platform. Do not describe it as a network firewall or tracker blocker.
- UI uses a **source domain indicator** derived from the actual current URL, not merely the launch URL/title. Never put remote HTML into a first-party trusted-looking shell without host identity visible.
- `tel:`, `sms:`, `mailto:` are not rendered in WebView; preserve current native routes, including SOS dialing. Route through an explicit OS launcher only after user action.
- No automatic reader popups, arbitrary `window.open`, file pickers, camera/mic/location/notifications, JavaScript bridges, clipboard reads, or file URL access. Defer exceptions by documented site + capability and user approval.
- JavaScript default OFF where viable; enable only for a tested, supported site that needs it, with no injected app data and no privileged channels. Some modern sites will require a site-scoped exception.

## Privacy model

A page inside `WebView` is still an **external website**: its server and embedded third parties may receive IP address, user agent and request data. WebView may store cookies/cache unless expressly configured/cleared. The app cannot promise zero website tracking merely because the external browser stays closed.

- Do not send recoveries, counseling/journal/sponsor data, location, app auth state, Firebase identifiers, step completion, user-selected pathway, or device-specific identifying headers to remote hosts.
- No internal logs, analytics, telemetry, remote crash reports, or browsing-history DB. If debugging, redact URLs with query/fragment and never log PDF content or credentials.
- Prefer session-scoped browsing state/cookie handling. Explicitly evaluate WebView cookie manager/storage semantics and whether app-global WebView data could affect other embedded views before clearing. Do not clear unrelated app web sessions as a blind cleanup.
- PDF downloads go only to app-private cache, uniquely named, random identifiers, short lifecycle; never media scanner, Downloads directory, shared storage or exported ContentProvider. Limit count, size, and age. No hidden "save offline" feature.
- No bypass for TLS certificate or SSL errors; web TLS failure -> safe error and external escape only if user deliberately opts for it. Never silently ignore invalid certificates.

## UX decision table

| Incoming link | Default route | Notes |
|---|---|---|
| Official AA step chapter PDF (`https`, approved origin) | Native PDF reader | Download/prove bytes, preserve origin label |
| Official AA or registered recovery HTML page | In-app WebView | Safe scheme, supported platform and tested site |
| Off-domain main-frame navigation from trusted web page | Prevent; offer destination-specific review and confirmation before external handoff | Never silently trust or launch it |
| Other registered PDF (including literature library) | Native PDF reader | Verify MIME/magic, redirects and size |
| Redirect from PDF URL to HTML error/challenge | PDF error state with source link | Do not render as PDF |
| Valid `tel:`, `sms:`, `mailto:` main-frame link | Prevent in WebView; explicit Continue action then shared system handler | Malformed or prefilled links stay blocked |
| Unknown scheme / internal file / IP-local / credentials URL | Block | No automatic OS launch |
| User explicitly taps `Open in browser` | System browser | Visible explicit action; label the destination |
| Offline | In-app offline/error screen | Retry; may open external by deliberate choice |

## Threat-oriented tests

- `https://aa.org.evil.test/` and `https://evil.test/?next=https://aa.org` never receive trusted route.
- `http://aa.org`, `javascript:alert(1)`, `file:///etc/passwd`, `content://...`, `https://127.0.0.1`, `https://192.168.1.1`, `https://user:pass@aa.org` are rejected.
- A PDF URL returning `text/html` / 200 or PDF content with mismatched MIME is handled conservatively; never treat HTML as a PDF. For servers with wrong MIME but valid magic, define and document a deliberate rule; do not silently accept MIME spoofing.
- Redirect to unfamiliar host leads to prevented/approval outcome and no auto-load; test multiple PDF redirect hops, loops, >max hops, and cross-scheme downgrades. WebView redirect and popup coverage remains a device/platform verification item.
- PDF embedded links to other URLs are routed through policy, not automatically followed inside PDF viewer.
- Explicit external opt-in route yields exactly one external launch, never duplicate launch via both NavigationDelegate and caller.

## Compliance and user trust

Source-host identity, copyright/provenance, offline errors, and exit-to-browser are user-visible. Do not imply AA, NA, or other fellowships officially endorse the application. Crisis links should remain actionable and never be trapped by a nonworking WebView.
