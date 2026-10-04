---
description: Run every gate at the end of a task — analyze, tests, color, architecture invariants, invariant self-tests, code package
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
   Must exit 0. Enforces the **fourteen** architecture invariants:

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
   14. the release build cannot silently fall back to the **debug** signing key.
       `android/app/build.gradle.kts` must detect a release task from
       `gradle.startParameter.taskNames` and `throw GradleException` when the
       keystore is missing, while the debug build keeps its debug fallback. A
       debug fallback is correct for debug and wrong for release, and one `if`
       cannot serve both — that is why the build reads its own task name.

   **Known gaps — do not trust blindly, and do not "fix" a regex to close one.**
   Invariant 8 scans every `lib/screens/*.dart` for a private `RecoveryPet` field
   and now exempts only `PET_OWNER_LOCAL_EDIT_BUFFERS` (`avatar_dresser_screen`,
   which edits a caller-supplied pet and pops it back, so it never reads the
   database); its *second* half — the dashboard reading pet state back out of
   `RecoveryPetService` — is still scoped to `dashboard_screen.dart` alone, and
   `constellation_screen.dart` legitimately writes through the service, relying
   on the notifier's stream to stay current; invariant 9 pairs by statement and by
   a ±12-line window, so a fill more than 12 lines from its text slips past, and a
   raw colour inside a `CustomPainter` is deliberately not flagged; invariant 10
   compares byte offsets, so it cannot tell a declaration from a mention of the
   same text — the behavioural half is
   `test/constellation_3d_controls_reachable_test.dart`; invariant 11 is a
   static scan of the rules text, not a rules-unit-test; invariant 12 scans for
   the **identifiers that were removed**, so a newly-named emoji would pass, and
   it does not forbid non-ASCII text because the UI legitimately uses `·`, `✦`,
   `—`; invariant 13 compares byte offsets within one method and checks two
   needles, so a helper that grants XP from elsewhere would not be seen.
   **Invariant 14 is a text check on a build file, and it says so itself.** It
   proves the guard is present and that a `throw` sits *inside* the guarded
   branch — it requires the literal `if (RELEASE_VARIANT_REQUESTED)`, because a
   rule that merely greps for the flag name and for `GradleException` passes both
   `if (false) { throw … }` and `val ignored = GradleException(…)`, which are the
   original bug wearing a hat. It still cannot execute Gradle, so it cannot prove
   the throw is on the path actually taken, and it cannot detect a keystore that
   exists but holds the wrong key. **Only the build proves those** — see the
   signing note at the end of this file.
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

6. `python tools/selftest_invariant14.py`
   Must exit 0, and must run in the **same batch** as gate 4. Invariant 14 guards
   a *decision in a build file*, which is exactly the kind of rule that gets
   reverted by accident while someone fixes something unrelated nearby — that is
   how the silent debug-signing fallback shipped. Its negative control strips
   every code line and leaves only the prose comments: if that passes, the rule
   is matching a comment instead of the behaviour.
   Also run it after touching `check_release_signing` in `verify_invariants.py`
   or the signing block in `android/app/build.gradle.kts`.

7. `python tools/generate_code_package.py`
   Regenerates `blueprints/recovery_all_code.md` from `lib/`. Not a pass/fail
   gate, but it must be re-run whenever any `lib/` file changed, or the
   generated code package silently goes stale.

8. `python tools/verify_resources.py` — **only if a URL actually changed.**
   All links must be alive. Skip it otherwise; it is a network round trip.

Report: one line per gate (status + key number), then any failures with
`file:line`. If all pass, say so in one line and stop.

**Builds are PRE-AUTHORIZED** (standing, 2026-09-30): `flutter build apk --debug`,
`flutter build appbundle --release`, and signed release bundles via
`android/key.properties` + `upload-keystore.jks`. Do not re-ask. But builds still
belong in the **end-of-plan batch**, not mid-plan — pre-authorized is not
"whenever".

**After a release build, read the SIGNER — do not trust the exit code.**
`jarsigner` is not on PATH; it lives at
`C:\android\Android Studio\jbr\bin\jarsigner.exe`. Run
`jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab`
and read the identity. It must be
`CN=Glenn Lee Clark IV, OU=Recovery For All, O=Recovery`, **never**
`CN=Android Debug`. A debug-signed release builds cleanly and prints
`jar verified.` — the signature is genuinely valid, just not yours — so
"it built" and "it verified" together prove nothing about *whose* key was used.
The PKIX "certificate chain is invalid" warning beside `jar verified.` is
expected for a self-signed upload key and is harmless.

Then prove the artifact contains the code you think it does. Find a string
literal unique to the change (e.g. `PRAGMA table_info(`) and grep for it inside
`base/lib/arm64-v8a/libapp.so` in the signed `.aab`. A build directory can be
stale in ways nothing complains about, and "rebuilt from current source" is a
claim, not an observation. `build/` is gitignored, so re-verify the artifact
exists before anyone references it by name.