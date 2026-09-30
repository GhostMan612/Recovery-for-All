---
description: Run every gate at the end of a task — analyze, tests, color, architecture invariants, code package
---
Run ALL FIVE gates in this order and report a compact summary. Filter output to
failures only — this is a token-conservation command.

**This command is for the END of a task, not the middle of one.** The standing
user directive is that no shell runs at all until the entire plan is complete
(see the "VERIFICATION CADENCE" block in `AGENTS.md`). Do not run individual
gates mid-plan to "just check" an edit; re-reading the enclosing block is
cheaper and is what actually catches the errors.

1. `C:\android\flutter\bin\flutter.bat analyze --no-pub`
   Must report **No issues found**. (The archived `Recovery-for-All-main/` copy
   is excluded; errors from only that path mean the exclude in
   `analysis_options.yaml` regressed.)

2. `C:\android\flutter\bin\flutter.bat test`
   All tests must pass. Report the final count.

3. `python tools/verify_no_hardcoded_colors.py`
   Must exit 0. Fails on raw `Color(0x...)` outside the token file AND on any
   reference to a retired dark-pinned `AppColors` constant.

4. `python tools/verify_invariants.py`
   Must exit 0. Enforces the six architecture invariants: the single
   `databaseProvider` override in main.dart, exactly one `SosTile`
   implementation, the ten load-bearing SharedPreferences keys and their owning
   files, the Phase 8 dashboard view files, no retired color constants, and the
   system animation setting being read **only** in
   `lib/core/motion/app_motion.dart`.
   These rules are also in AGENTS.md as prose — the gate is what makes them
   un-ignorable. If a rule is intentionally changing, update the gate AND
   AGENTS.md in the same commit.

5. `python tools/generate_code_package.py`
   Regenerates `blueprints/recovery_all_code.md` from `lib/`. Not a pass/fail
   gate, but it must be re-run whenever any `lib/` file changed, or the
   generated code package silently goes stale.

Report: one line per gate (status + key number), then any failures with
`file:line`. If all pass, say so in one line and stop.

NEVER run `flutter build` anything — the human builds in Android Studio.
