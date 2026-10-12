# 05 — Verification, device matrix, and release gates

## Testing philosophy

This repository records analyzer-blind bugs, incorrect tests, and release-only failures. Gate assertions must have negative controls and must assert rendered/behavioral outcomes, not only that a widget exists. Under **root `AGENTS.md` SHELL DISCIPLINE**, design and implement everything before running the final **batched** shell suite; do not shell out after every phase. The work orders specify acceptance criteria but do **not** authorize a separate per-phase test run. If a step truly cannot proceed without a mid-plan observation, record a blocker/decision rather than silently violating that rule.

## Automated coverage present in the working tree

The following focused host tests are present; they are **not yet verified in this task's final gate batch**. The table describes coverage targets, not a claim that every listed edge case already has a test.

| Area | Tests |
|---|---|
| AA registry | Registry cardinality, sequential mapping, per-step request, range rejection, and no generic landing-page fallback |
| URL policy | Schemes, malformed system links, host-lookalikes, private/local targets, redirects, cross-origin and route decisions |
| PDF acquisition | Status/content checks, size ceiling, cancellation, private temp ownership, cleanup and redirect policy |
| Workbook regression | Shared reader accepts caller-owned local paths; preserve workbook storage and avoid deleting imported files |
| Step UI | Step action routes through exact `step.number`; no external launcher or reward-on-open behavior |
| HTML viewer | Fake-controller startup, JavaScript-off, live host, reload, browser escape, startup error and navigation policy |
| Literature/community | Both primary screens use the shared router and retain source-owned filtering/link-health behavior |
| Accessibility/theme | Explicit phase target; full multi-theme, device text-scale, TalkBack and low-end review remains pending |
| Privacy | No new identities, analytics, persistent PDF storage, or recovery context in requests; verify through source/tests and device evidence |

Full offline/network-failure, device rendering, cancellation during an active native view, popup/download, Android WebView redirect, large-text, and release-artifact behavior remain final acceptance work.

Prefer injectable `http.Client`, filesystem/temp factory, URI policy and launch adapter so route and error behavior can be tested on host without loading a native WebView/PDF plugin. Integration tests on devices cover platform rendering and downloads.

## Physical Android QA

| Device | Why | Minimum proof |
|---|---|---|
| Moto G 2025, Android 16 | Primary; normal hardware path | Step 1, 6, 12 PDFs open; scroll, pinch, page count; HTML site opens and navigates/back; no external browser; rotation/resume; external choice works |
| BLU View 5 / B160V, ~2.75 GB | Low-memory branch | Repeat Step 1, 12 & HTML reader, multiple open/close cycles; bounded memory, no OOM, correct no-blank failure/timeout |
| Release-signed APK/AAB from current tree | R8, resources, platform behavior | Signer identity, correct versionCode, actual installed version, no reflection crash, viewer rendering/scheme handling, all 14 invariants |

Examine screens manually: a network PDF should not cause a giant memory spike; test airplane mode before tap and during transfer; navigate away mid-download; return after a redirect; confirm no recovery data loss. Test official AA content from real device because automated fetch results may differ from Android WebView/network conditions.

## End-of-plan batch (document the result)

Use **the exact canonical commands in root `AGENTS.md`**. At the time of the blueprint they include:

```text
flutter pub get                (after an explicitly approved dependency addition)
flutter analyze                (zero issues)
flutter test                   (baseline was reported 651 tests on Oct 8 release commit)
python tools/verify_no_hardcoded_colors.py
python tools/verify_invariants.py
python tools/selftest_invariant7.py
python tools/selftest_invariant14.py
python tools/verify_resources.py  (required if registry URLs change)
python tools/generate_code_package.py (if any lib/ source changes)
```

Run and report as one batch when full authorized implementation is complete. All new tests must be part of full `flutter test`; no skipped/ignored platform tests presented as passing. Version and test counts are **historical baseline only**, never a promise about the final app.

## Artifact and deployment guardrails

- AAB must use the real release key. Never bypass the existing Gradle fail-closed guard. Verify signing identity and actual compiled code provenance exactly as root `AGENTS.md` requires.
- `webview_flutter` and its Android implementation are already pinned in the dependency manifest/lockfile. Native behavior and compatibility still require the current release/device checks; do not lower security or expand exported components to make them pass.
- Demonstrate actual installed release `versionCode` on device before testing; do not confuse stale installed APK with current code.
- Do not increment version or upload to Play as part of this blueprint package. Human handles version/release/console decisions under existing policy.
- Reconcile README and `SESSION_HANDOFF.md` with source changes and honest verification state. Do not mark the feature shipped, phase-complete, or release-ready until the required acceptance evidence exists.

## Evidence format

For each passing device case record: timestamp; branch + commit; APK versionCode/build flavor/signing certificate; device/build; link original/resolved host (query redacted); screenshot/behavior outcome; logcat error summary; remaining caveat. For a failure, record reproduction and blocker rather than setting green.
