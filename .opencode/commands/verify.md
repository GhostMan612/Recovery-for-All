---
description: Run every gate — analyze, tests, color, and architecture invariants
---
Run ALL FOUR gates in this order and report a compact summary. Filter output to
failures only — this is a token-conservation command.

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
   Must exit 0. Enforces the five architecture invariants: the single
   `databaseProvider` override in main.dart, exactly one `SosTile`
   implementation, the ten load-bearing SharedPreferences keys and their owning
   files, the Phase 8 dashboard view files, and no retired color constants.
   These rules are also in AGENTS.md as prose — the gate is what makes them
   un-ignorable. If a rule is intentionally changing, update the gate AND
   AGENTS.md in the same commit.

Report: one line per gate (status + key number), then any failures with
`file:line`. If all pass, say so in one line and stop.

NEVER run `flutter build` anything — the human builds in Android Studio.
