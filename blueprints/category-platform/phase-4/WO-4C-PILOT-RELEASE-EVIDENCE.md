# WO-4C — Ethical Field Pilot and Honest Product Claims

## Pilot purpose

Validate navigation comprehension, self-directed meaningful actions, voluntary Circle trust and privacy comprehension. **Do not** characterize usage metrics, game engagement or pilot self-report as proven abstinence, relapse reduction, clinical treatment efficacy or patentability.

## 4 controlled cohorts (synthetic prerelease test accounts)

1. **Offline/low bandwidth:** can create and keep local progress and use cached meetings/routes.
2. **Transit-dependent:** can choose a real meeting and understand transfer risk/weather exposure without unsafe assumptions.
3. **Privacy-focused:** can distinguish local, provider requests and remotely visible Circle actions; revoke/erase appropriately.
4. **Accessibility/no-game:** can reach same recovery outcomes with screen readers, large type and without companion gameplay.

Recruit actual pilot participants only with consent and appropriate research/privacy review. No sensitive questionnaires or precise location traces by default. Avoid collecting real support/confession content as testing artifacts; use nonidentifying aggregate observations and synthetic content in recorded demos.

## Evidence collection

- Completion rate/time (measured, not promised) for four paths in 4A, participant comprehension of data-sharing boundaries, self-reported perceived pressure/comfort, error recovery, missed route explanations and latency on low-end.
- Date/region/provider for meeting/GTFS/radar test; data age and actual permission setting; connection modes; confidence errors with examples.
- Two-identity Circle hostile-client security test, moderation staff response ability and deletion behavior across devices.
- Existing Flutter tests, native SDK tests, Gradle/Flutter builds, manual Android Studio and QA evidence with source hashes.

## Source-of-truth documents

`README.md`, `PRIVACY_POLICY.md`, `AGENTS.md`, `SESSION_HANDOFF.md`, `blueprints/category-platform/` and root release checklists. Reconcile prior competitive absolute statements ('every other app', '100% offline', 'zero data ever sent') with evidence. The `LICENSE` is MIT at inspected main, while prior README used proprietary language; do not change without owner's legal decision.

## Publication thresholds

No unresolved P0 security faults, no erroneous privacy/legal claims, no counterfeit/sample meeting routing, no unsupported attendance/medical claims, no known data-loss migration, and no untested downgrade/release signing assumptions. Mark uncertain components explicitly beta or unavailable. User makes final ship decision.
