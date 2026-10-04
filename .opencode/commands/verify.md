---
description: Run every gate at the end of a task — analyze, tests, color, architecture invariants, invariant self-test, code package
---
Run every gate in this order and report a compact summary. Filter output to
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
   All tests must pass. Report the final count. **`dart` is not on PATH on this
   host** — if a gate needs it, prepend
   `C:\android\flutter\bin;C:\android\flutter\bin\cache\dart-sdk\bin`.

3. `python tools/verify_no_hardcoded_colors.py`
   Must exit 0. Fails on raw `Color(0x...)` outside the token file AND on any
   reference to a retired dark-pinned `AppColors` constant. Note the per-file
   allowlist: `widgets/avatar_painter.dart` is capped at **116** literals and
   `widgets/cosmetic_icon_painter.dart` at **41** — **those caps are real
   budgets, not exclusions**. If you add art, raise the number deliberately in a
   commit that says why. `Colors.white/black` as `foregroundColor:` is allowed
   *unless* paired with a `colorScheme` background — that pairing is
   invariant 9's job.

4. `python tools/verify_invariants.py`
   Must exit 0. Enforces the **thirteen** architecture invariants:

   1. a single `databaseProvider` override in `main.dart`
   2. exactly one `SosTile` implementation, and `_showSosSheet` still reachable
   3. the **twelve** load-bearing SharedPreferences keys, each still in its
      **owning file** (a partial rename desynchronises writer from reader and
      silently loses real users' settings)
   4. the Phase 8 dashboard view files exist
   5. no retired `AppColors` constant
   6. the system animation setting is read **only** in
      `lib/core/motion/app_motion.dart`
   7. missing-brace string interpolation, in its **unambiguous** forms only —
      `'$ref.watch(x).y'` silently renders as literal text and shipped a broken
      app-bar title to two devices before a human caught it
   8. pet state has one owner (`dashboard_screen.dart` must not read it back out
      of `RecoveryPetService`)
   9. a paired foreground must be a `colorScheme` role (`Colors.white|black`
      text near a `colorScheme` panel or fill is unreadable in one brightness)
   10. constellation `Stack` child order — the 3D `Positioned.fill` overlay must
      be declared **BEFORE** the controls, because a Stack hit-tests its last
      child first, so declaring it last made 3D mode a one-way door
   11. Firestore rules are ownership-scoped — no `allow` gated on
      `request.auth != null` alone, and every content collection binds a **path
      segment** to `request.auth.uid`; a document *field* is not equivalent,
      because the caller writes it
   12. no companion surface re-introduces a system emoji as artwork, and no
      companion **data** file declares a glyph (`PetCosmetic.emoji`,
      `PetMoodX.emoji`, `presetEmojis` are deleted, not deprecated)
   13. the fellowship reward is unreachable before
      `FellowshipAttestationService.verify`, and its 24-hour cooldown is keyed on
      the peer's **public key**, never the peer-chosen alias

   **Known gaps — do not trust blindly, and do not "fix" a regex to close one.**
   Invariant 8 scans `dashboard_screen.dart` only (three other screens still
   hold a private `_pet`); invariant 9 pairs by statement and by a ±12-line
   window, so a fill more than 12 lines from its text slips past, and a raw
   colour inside a `CustomPainter` is deliberately not flagged; invariant 10
   compares byte offsets, so it cannot tell a declaration from a mention of the
   same text — the behavioural half is
   `test/constellation_3d_controls_reachable_test.dart`; invariant 11 is a
   static scan of the rules text, not a rules-unit-test; invariant 12 scans for
   the **identifiers that were removed**, so a newly-named emoji would pass, and
   it does not forbid non-ASCII text because the UI legitimately uses `·`, `✦`,
   `—`; invariant 13 compares byte offsets within one method and checks two
   needles, so a helper that grants XP from elsewhere would not be seen.
   **Invariant 7 covers only the unambiguous subset and cannot be widened** —
   `'$modelId.gguf'` (a file extension) and the real bug
   `'$role.wire|$alias|$nonceA'` are the same token shape, only one of which is
   wrong. Every handshake leg signed an identical string because of that bug;
   it is caught by asserting the exact signed string, not by the pattern. See
   L36.

   These rules are also in AGENTS.md as prose — the gate is what makes them
   un-ignorable. If a rule is intentionally changing, update the gate AND
   AGENTS.md in the same commit.

5. `python tools/selftest_invariant7.py`
   Must exit 0. This is the gate that proves gate 4 **can go red**. It prints the
   known-unflaggable shapes as `gap` lines; that is expected output, not a
   failure. A checker that cannot fail is worse than no checker, so never delete
   this to make a run cleaner.
   Also run `tools/selftest_invariant7.py` after touching the invariant 7 regex.

6. `python tools/generate_code_package.py`
   Regenerates `blueprints/recovery_all_code.md` from `lib/`. Not a pass/fail
   gate, but it must be re-run whenever any `lib/` file changed, or the
   generated code package silently goes stale.

7. `python tools/verify_resources.py` — **only if a URL actually changed.**
   All links must be alive. Skip it otherwise; it is a network round trip.

Report: one line per gate (status + key number), then any failures with
`file:line`. If all pass, say so in one line and stop.

**Builds are PRE-AUTHORIZED** (standing, 2026-09-30): `flutter build apk --debug`,
`flutter build appbundle --release`, and signed release bundles via
`android/key.properties` + `upload-keystore.jks`. Do not re-ask. But builds still
belong in the **end-of-plan batch**, not mid-plan — pre-authorized is not
"whenever". After a release build, verify the signature rather than assuming it:
`jarsigner -verify -verbose:summary build\app\outputs\bundle\release\app-release.aab`
must print `s = signature was verified`. `build/` is gitignored, so re-verify the
artifact exists before anyone references it by name.