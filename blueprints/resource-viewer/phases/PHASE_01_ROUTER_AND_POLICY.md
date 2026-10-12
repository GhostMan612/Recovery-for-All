# Phase 01 — Shared ResourceRouter and URL policy

**State (2026-10-12):** IMPLEMENTED IN SOURCE · **Final validation pending** · **Depends on:** Phase 00

`resource_request.dart`, `resource_policy.dart`, and `resource_router.dart` exist. The router handles approved PDF/HTML, valid native intents, blocked URLs, explicit off-origin approval, and launch failures. Malformed phone/mail schemes are now blocked rather than passed to the OS. Source review is not a substitute for the final test batch.

## Original implementation scope — present in source

The typed request/factory, pure policy, router, test seams, and scoped screen wiring listed below are already present. Preserve this boundary; only revisit implementation if final verification identifies a concrete defect.

1. `resource_request.dart` provides typed requests and explicit source identifiers, including `aaStep(n)`.
2. `resource_policy.dart` classifies HTTPS routes and system intents, validates trusted origins/redirects, and blocks invalid or dangerous schemes.
3. `resource_router.dart` pushes PDF/WebView routes, explains blocked inputs, and confirms external handoffs without automatically popping recovery screens.
4. Injectable routing and launcher seams support host/widget tests without native platform services.
5. Existing launch sites were not blanket-replaced; routed entrypoints preserve dashboard/SOS boundaries.

## Required tests / outcomes

- Mapping of PDF/HTML/system/blocked typed results exhaustive; no double launch.
- Lookalike-host, HTTP/file/javascript/content/data/intent/private-IP/embedded-credential test matrix, and cross-origin redirect decision.
- A fake router proves exactly one internal navigation for approved HTML/PDF, and no navigation for bad input.
- No user recovery context appears in a URL, log, or header.

**Verification cadence:** No per-phase Flutter command loop. Append tests while implementing; evaluate in single final batched gate.
