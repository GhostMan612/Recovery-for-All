# Phase 06 — Final tests, release checks, and handoff

**State (2026-10-12):** NOT COMPLETE · **End-of-plan verification and device/release evidence pending** · **Depends on:** Phases 00–05

Source review and added tests do not satisfy this phase. Do not mark the acceptance list complete or the blueprint implemented until the single final gate batch and required device/release checks have actually run and their results are recorded.

## Tasks

1. Freeze approved diff; inspect newly changed source/document paths, ensure no unrelated code, database, SOS or signing rewrites and no pdf bytes checked into Git.
2. Execute one **end-of-plan gate batch** according to root `AGENTS.md` (analyze, full test suite, colors, all 14 invariants, both selftests, link verification as required, package generator after lib changes).
3. Validate actual release-signed artifact against signer identity, built code and installed versionCode. Stop if release key unavailable; never silently debug-sign a release.
4. On Moto G 2025 and BLU View 5: taps for steps 1,6,12, website, nested PDF, back/forward, offline/retry, cancellation, large text/rotation, input security and cross-origin handling. Observe performance/memory and native WebView crashes.
5. Verify existing imported workbooks, original step completion/worksheet/sponsor sign-off, session/dash state, emergency SOS and existing native telephone actions.
6. Update root README docs map, root SESSION_HANDOFF current-state/next moves, this plan phase statuses, and relevant resource docs using actual evidence. Do not replace historical data with invented current-state claims.
7. Human operator approves version bump and Google Play upload. Keep all results clearly marked `VERIFIED`, `PARTIALLY VERIFIED` or `BLOCKED` with artifact/device trace.

Current source has not yet passed the final gate batch in this task. The prior pre-change branch/dirty-state/toolchain snapshot was not recorded contemporaneously; do not reconstruct it from the post-change diff. No physical-device, signer, or current-artifact evidence is claimed.

## Final gate

`08_ACCEPTANCE.md` fully and honestly checked, no unacceptable blockers, release behavior demonstrated on device. Only then mark blueprint `IMPLEMENTED`, never when code merely compiles.
