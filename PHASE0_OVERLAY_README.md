# Recovery for All — Full Phase 0 local overlay package

**Issued 2026-10-11.** Based on verified remote `Recovery-for-All/main` commit `6f985f393962b091d69cc003bb922c9fae9ae618`. The overlay is **read-only to your GitHub account**. It contains documentation and a CI workflow repair; extracting it does not run scripts or send data. It never changes the MIT `LICENSE`, Firebase rules, runtime Circle feed, remote repositories, journal data or DB schema.

**Consolidation note:** The named source ZIP was not available in this work session, and its archive bytes were not inspected. The extracted files and supplied manifest were used as the available inputs; their checksums are tracked separately from the reconciled working-copy checksums. Do not re-extract or treat this note as archive-level verification.

## Install on your local checkout

1. Confirm your local Recovery for All repo is at or ahead of the pinned baseline and that you have saved/committed any local changes to files this archive overwrites.
2. **Extract the contents of this ZIP directly into the root of your Recovery for All repository**, allowing file replacement for only the paths listed in `PHASE0_OVERLAY_MANIFEST.json`. Do not extract an extra containing folder; ZIP paths are repository-relative.
3. Review `git status --short` and `git diff --check` and inspect the diffs before staging.
4. Run `python tools/verify_phase0_contracts.py` locally. That script verifies documentation links and structural workflow content—not Cloud Firestore security. Flutter tests run only at the final authorized local gate under `RULES.md`.
5. Stage explicitly by path (no `git add -A` or `git add .`), commit and push yourself when satisfied. No code or Firestore rules are remotely modified by this ZIP creator.

## What changed immediately

- Root README: corrects false competitor/proprietary/offline claims; links Phase 0 hub.
- Privacy policy: clarifies real external provider requests, precise weather coordinates, Firebase anonymous sign-in at startup, remote deletion gaps.
- Old malformed `cmake-multi-platform.yml`: replaced **in place** with a well-formed Flutter CI workflow with analyzer, tests and project invariant gates. Not yet proven green on GitHub.
- New `phase-0/` subfolder: end-to-end research, risk, contract, exact file-level work orders, owner decisions, acceptance criteria, scoped agent guidance and security implementation protocol.
- `blueprints/category-platform/README.md` and `AGENT_HANDOFF.md`: updated to point to Phase 0 and correct cross-repository SDK publish authorization.
- New `tools/verify_phase0_contracts.py`: checks documentation/workflow links and claims; cannot certify privacy security.

## Important implementation boundary

**This package installs the entire Phase 0 blueprint and safe immediate documentation/CI fixes; it DOES NOT finish Phase 0 runtime implementation.** No credible remote moderation, cloud delete or consent mechanism can be certified solely by unzipping a Markdown overlay. Those remain explicit follow-up implementation work orders requiring source changes, Firebase emulator tests, human approval of changed behavior and deployment. See `blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md`.

## Pin / no claim of success

This overlay was constructed from read-only GitHub source inspection and cannot validate the local version of Flutter, local credentials, release builds or deployed Firestore rules. The Python documentation checker validates extracted documentation/workflow structure only; it does not validate ZIP archive bytes, CI execution or network security. Those runtime/CI checks remain unverified. Root `RULES.md` and `AGENTS.md` remain authoritative and are **not overwritten**.
