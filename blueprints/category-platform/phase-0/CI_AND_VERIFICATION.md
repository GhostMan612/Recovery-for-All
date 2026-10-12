# Phase 0 CI repair and verification protocol

## Why GitHub Actions was red

At the inspected revision, `.github/workflows/cmake-multi-platform.yml` was only three indented CMake steps, with no `name`, `on`, `jobs`, `runs-on` or checkout. GitHub showed a failure for commit `6f985f3` and its parent, with zero jobs returned by the jobs API. The text also referenced an undefined build/matrix step and a nonexistent `android/app/src/main/ccp` directory. **The documentation push was not the root cause.**

## Overlay action

We replace that *same existing path* with a valid **Flutter Quality Gates** workflow triggered on pushes/PRs to `main`, using Flutter stable channel, `flutter pub get`, `flutter analyze --no-pub`, `flutter test --no-pub`, `tools/verify_no_hardcoded_colors.py`, `tools/verify_invariants.py`, `tools/selftest_invariant7.py`, `tools/selftest_invariant14.py`, `tools/verify_phase0_contracts.py` (Phase 0 documentation consistency only) and `tools/verify_category_overlay.py` (Phase 0–4 extracted-file hashes and synthetic fixtures). The last check requires the combined Phase 0–4 overlay to be present; it does not prove runtime behavior.

This verifies Dart/Flutter checks on the runner, not an Android Play-signed artifact, device sensors, optional local Firebase configuration, a deployed Firestore rule, clinical efficacy or end-to-end Circle privacy. Flutter stable/toolchain differences may expose pre-existing failures. If the workflow fails, inspect the actual runner logs and fix *that* specific error, rather than disabling tests.

## End-of-plan local commands (run once in the authorized shell at the final gate)

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
python tools/verify_no_hardcoded_colors.py
python tools/verify_invariants.py
python tools/selftest_invariant7.py
python tools/selftest_invariant14.py
python tools/verify_phase0_contracts.py
```

Following `RULES.md`, do not run one analyzer/build after every small edit. A build of a signed release and physical installs remain a separate user-owned gate.

## Required P0 runtime tests (not performed by overlay)

- Firebase emulator: A/B distinct authenticated users, illegal author edit, cross-owner delete, malformed posts, direct forged moderation and repeated reactions denied; legitimate owner delete succeeds.
- Two devices: A shares, B sees, A deletes, B no longer sees after backend ack and documented cache settlement; offline B must not be promised remote erasure before reconnection.
- On-device network capture: turn each opt-in off, enter map, toggle GPS, open Circle, reboot; check zero unwanted location or Firebase auth requests.
- Prepared/unprepared offline: local personal tools, cached meeting listings, sampled fixtures, map tile and direct navigation labels remain truthful.
- System regression: 3GB/4GB Android devices, screen readers, large text, minimized motion and all SOS paths.

## Evidence record

| Item | Result | Evidence location / SHA |
| --- | --- | --- |
| New CI workflow parsed by GitHub | NOT RUN | |
| Flutter analyze / tests | NOT RUN | |
| Static Phase 0 verifier | Run on overlay in author sandbox only | See package manifest |
| Firebase emulator negative tests | NOT RUN | |
| Privacy traffic/device test | NOT RUN | |
| Two-device delete test | NOT RUN | |
| Owner license consent decision | NOT MADE | |

Do not mark these green from source inspection or commit messages.
