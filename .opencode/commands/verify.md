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
   Must report **No issues found**. (`analysis_options.yaml` still excludes the
   archived `Recovery-for-All-main/` path, but that directory is gitignored and
   currently absent, so the exclude is a no-op — do not treat errors "from only
   that path" as a live diagnostic.)

2. `C:\android\flutter\bin\flutter.bat test`
   All tests must pass. Report the final count.

3. `python tools/verify_no_hardcoded_colors.py`
   Must exit 0. Fails on raw `Color(0x...)` outside the token file AND on any
   reference to a retired dark-pinned `AppColors` constant. Note the allowlist:
   `widgets/avatar_painter.dart` may hold 93 literals, and `Colors.white/black`
   as `foregroundColor:` is allowed *unless* paired with a `colorScheme`
   background — that pairing is invariant 9's job.

4. `python tools/verify_invariants.py`
   Must exit 0. Enforces the **eleven** architecture invariants: the single
   `databaseProvider` override in main.dart, exactly one `SosTile`
   implementation, the **twelve** load-bearing SharedPreferences keys and their
   owning files, the Phase 8 dashboard view files, no retired color constants,
   the system animation setting being read **only** in
   `lib/core/motion/app_motion.dart`, **no missing-brace string
   interpolation** (`$ref.watch(x).y` silently renders as literal text — this
   shipped a broken app-bar title to two devices before a human caught it),
   **pet state has one owner** (`dashboard_screen.dart` must not read it back
   out of `RecoveryPetService`), **a paired foreground must be a
   colorScheme role** (`Colors.white|black` text near a `colorScheme` panel or
   fill is unreadable in one brightness), and **constellation `Stack` child
   order** (the 3D `Positioned.fill` overlay must be declared BEFORE the
   controls — a Stack hit-tests its last child first, so declaring it last made
   3D mode a one-way door), and **Firestore rules are ownership-scoped** (no
   `allow` gated on `request.auth != null` alone, and every content collection
   binds a path segment to `request.auth.uid` — a document *field* is not
   equivalent, because the caller writes it).
   Known gaps, do not trust blindly: invariant 8 scans `dashboard_screen.dart`
   only (three other screens still hold a private `_pet`); invariant 9 pairs by
   statement and by a ±12-line window, so a fill more than 12 lines from its
   text slips past, and a raw colour inside a `CustomPainter` is deliberately
   not flagged; invariant 10 compares byte offsets, so it cannot tell a
   declaration from a mention of the same text — the behavioural half is
   `test/constellation_3d_controls_reachable_test.dart`; invariant 11 is a
   static scan of the rules text, not a rules-unit-test.
   These rules are also in AGENTS.md as prose — the gate is what makes them
   un-ignorable. If a rule is intentionally changing, update the gate AND
   AGENTS.md in the same commit.

   Two lessons worth re-reading before trusting any gate here:
   `blueprints/lessons-learned.md` **L31** (a listed-but-unscannable key is not
   a pin — `meeting_search_radius_miles_v1` was declared load-bearing while
   `KEY_PAT` could not match its prefix) and **L32** (a comment describing a fix
   is not the fix — the 3D one-way door shipped with prose claiming it was
   already fixed, directly above the wrong line).

5. `python tools/generate_code_package.py`
   Regenerates `blueprints/recovery_all_code.md` from `lib/`. Not a pass/fail
   gate, but it must be re-run whenever any `lib/` file changed, or the
   generated code package silently goes stale.

Report: one line per gate (status + key number), then any failures with
`file:line`. If all pass, say so in one line and stop.

NEVER run `flutter build` anything — the human builds in Android Studio.
