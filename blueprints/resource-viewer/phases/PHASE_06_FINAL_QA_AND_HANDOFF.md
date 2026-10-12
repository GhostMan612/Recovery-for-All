# Phase 06 — Final tests, release checks, and handoff

**State (2026-10-12):** NOT COMPLETE · **CI PASS; endpoint proof PARTIAL; physical-device/release evidence BLOCKED** · **Depends on:** Phases 00–05

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

## Verification observations (2026-10-12)

| Check | Result | Evidence / limit |
|---|---|---|
| GitHub Actions host gates | **PASS** | `Flutter Quality Gates` succeeded for `90394b3f1a5992a3f3b090238ebe8172e0c74a7d` (Resource Viewer implementation) and `e968dc1de49e63e61984f6a1ee33fd72123846b7` (current source-unchanged commit). The latter run includes dependency resolution, `flutter analyze`, `flutter test`, project invariants, and overlay gates. This is CI evidence, not device/release evidence. |
| AA endpoint PDF-format response | **PARTIAL PASS (12/12)** | Direct aa.org candidates returned `application/pdf` and `%PDF-1.7`; observed `/L` and `/N` values are logged in `PHASE_00_RECON_AND_URL_PROOF.md`. The fetch interface did not expose HTTP status, response headers, redirect chain/final URL, full transfer digest, or inspect encrypted chapter text. |
| Physical-device acceptance | **BLOCKED / NOT RUN** | No current-artifact evidence on Moto G 2025 or BLU View 5 is available for this verification. |
| Release artifact and signer | **BLOCKED / NOT RUN** | No artifact tied to the current source, signer identity, installed versionCode, or release WebView/PDF behavior was inspected. |
| Local host test batch | **NOT RUN LOCALLY** | Use the successful GitHub Actions run for host-gate evidence; do not represent this as a local run. |

Release remains blocked pending complete endpoint and chapter-identity evidence, review of AA's current transient-viewing terms, physical-device checks, and current release-artifact/signing evidence. The app registry remains `validated: false`; Phase 06 and the acceptance checklist remain incomplete.

## Remaining physical-device checks

Run these only on a confirmed current release-signed artifact, recording device model, Android build, artifact SHA-256, app version/versionCode, and signer identity with the results.

| Device | Required observations still outstanding |
|---|---|
| Moto G 2025 | Open and render Steps 1, 6, and 12 in the native PDF viewer; confirm scrolling/zoom and displayed page counts; open the official website in the in-app WebView and verify navigation/back behavior without automatic browser launch; rotate and resume; test offline/retry, cancellation, large text, cross-origin/input policy, workbook preservation, completion/worksheet/sponsor state, session/dashboard state, SOS, and native telephone actions. |
| BLU View 5 / B160V | Open and render Steps 1 and 12 and the official website; repeat open/close cycles; observe low-memory behavior, bounded memory, timeout/failure reporting, and absence of OOM/crash. Also verify workbook and recovery state, SOS, and native telephone actions. |
| Both devices | Exercise approved and blocked schemes/origins, redirects and third-party subresources; verify no user recovery data or app-auth identity is exposed to web content/logs; capture crashes, memory/performance and truthful offline/error states. |

## Final gate

`08_ACCEPTANCE.md` fully and honestly checked, no unacceptable blockers, release behavior demonstrated on device. Only then mark blueprint `IMPLEMENTED`, never when code merely compiles.
