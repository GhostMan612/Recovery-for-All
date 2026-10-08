# AGENTS.md — Recovery for All (recovery_companion)

Flutter app (Android-first, offline-first addiction-recovery companion).

**Cold start: read `SESSION_HANDOFF.md` FIRST** — current state,
environment facts (Ollama port, device fleet), next moves, and the
end-of-session checklist. Keep it updated every session.

Read `CLAUDE.md` too — its §1–§4 (token conservation, filtered CLI output,
explicit-path commits) and **§5 Build Boundary** are binding:

- **Builds are PRE-AUTHORIZED.** On 2026-09-30 the user granted **standing
  permission** to build binaries without asking again: `flutter build apk
  --debug`, `flutter build appbundle --release`, and signed release bundles
  using `android/key.properties` + `upload-keystore.jks`. Do not re-request
  build authorization. The `flutter pub get` → `flutter analyze` → `flutter
  test` sequence remains the **end-of-plan** gate batch; see SHELL DISCIPLINE
  below for when it runs. Builds still happen only in the end-of-plan batch —
  authorization to build is not permission to build mid-plan. Release signing
  keys are never committed; `build/` is gitignored.
  **A missing release keystore USED TO silently produce a DEBUG-signed
  release.** This is fixed and gated (invariant 14), but the manual check below
  is still required, so the history matters. The line used to read
  `signingConfig = if (releaseSig.storeFile?.exists() == true) releaseSig else
  signingConfigs.getByName("debug")` — and a debug-signed bundle builds cleanly
  and passes `jarsigner -verify`. So "it built and it verified" does **not**
  prove the upload key was used. `android/app/build.gradle.kts` now computes
  `RELEASE_VARIANT_REQUESTED` from `gradle.startParameter.taskNames` and
  `throw`s a `GradleException` when a release build has no keystore; the debug
  build keeps its debug fallback, because release keys are gitignored and a fresh
  clone must still be able to build debug. Do **not** relax that throw back to a
  `logger.warn` — a warning is not a refusal, and it is invisible anyway because
  Flutter filters Gradle warnings unless you pass `--verbose`.
  Even so, after any release build, confirm the signer identity explicitly: it
  must be `CN=Glenn Lee Clark IV, OU=Recovery For All, O=Recovery`, never
  `CN=Android Debug`. Also note `jarsigner` is not on `PATH` — it lives at
  `C:\android\Android Studio\jbr\bin\jarsigner.exe` — and a self-signed upload
  key always prints a harmless PKIX "certificate chain is invalid" warning
  alongside `jar verified.`
  **Prove an artifact contains the current code; do not assume it.** A build
  directory can be stale in ways nothing complains about. Find a string literal
  unique to the new code and grep for it inside the AOT blob in the artifact —
  e.g. `PRAGMA table_info(` inside `base/lib/arm64-v8a/libapp.so` in the signed
  `.aab`. That is what separates "rebuilt from current source" from "re-emitted
  an old build".
- **Commit by explicit path only** — never `git add .` / `-A`.
- Commit messages: analyze/test status only; never claim build success.

## Commands

**These are the END-OF-PLAN batch. Do not run them mid-plan** — see SHELL
DISCIPLINE below, which binds harder than this list. This is a list of *what*
to run once the plan is finished, not a checklist to work through.

```bash
flutter pub get
flutter analyze                 # must stay at zero issues
flutter test                    # host tests; most drift tests use NativeDatabase.memory
dart run build_runner build --delete-conflicting-outputs   # after ANY schema edit
dart run flutter_launcher_icons                            # after icon config/asset changes
python tools/generate_code_package.py                      # after code changes (see below)
python tools/verify_no_hardcoded_colors.py                 # standing UI gate (must exit 0)
python tools/verify_invariants.py                           # 14 architecture invariants (must exit 0)
python tools/selftest_invariant7.py                         # proves the gate above CAN fail (must exit 0)
python tools/selftest_invariant14.py                        # same, for the signing guard (must exit 0)
python tools/verify_resources.py                            # only if a URL actually changed
```

- **`tools/selftest_invariant7.py` is a gate, not a debug script.** A checker
  that cannot go red is worse than no checker. Run it in the same batch as
  `verify_invariants.py`; if you ever change the invariant 7 regex, it is the
  only thing standing between you and a silently-broken gate. It prints its
  known-unflaggable shapes as `gap` lines — that is expected output.

- **⛔ SHELL DISCIPLINE — THE RULE THAT MATTERS MOST. Restated after being
  violated repeatedly; it is not a preference, it is a hard gate.**

  **During a plan, the Shell/Bash tool must not be called at all.** Not once.
  Not "to check one thing". The plan is not finished, so there is nothing to
  verify *for*. Verification is an end-of-plan activity, and calling it early
  does not make the work safer — it makes it slower and it produces stale
  signal that then has to be re-derived.

  **Route every intent to a tool. There is no judgment call here:**

  | You want to… | Use | Never |
  |---|---|---|
  | see a file, a block, line numbers, a value | `read` | Shell `type`/`cat` |
  | find where a symbol is defined or used | `grep` | Shell `find`/`Select-String` |
  | change text in a file | `edit` | Shell `Set-Content`, sed, python |
  | create a file | `write` | Shell `New-Item`, heredoc |
  | crop/zoom an image you already pulled | `read` on the image | Shell for it |
  | audit the repo for a pattern | `grep` / subagents | Shell loops |
  | **does it compile / do tests pass** | **NOTHING — queue it** | Shell |
  | **git status / diff / commit** | **NOTHING — queue it** | Shell |
  | **adb / screenshots / device probes** | **NOTHING — queue it** | Shell |

  **The three traps, named, because all three happened here:**

  1. **"Let me just check it compiles."** It does not tell you anything you
     cannot learn by `read`ing the enclosing block, and the analyzer cannot see
     a colour-slot typo, a wrong string, or two widgets colliding — it only
     sees types. It has never once caught the class of bug this project
     actually has. Meanwhile it costs 20–90s *every* time.
  2. **"One quick git status."** Git is a shell command, and the answer does
     not change any edit you are about to make. Batch it into the single
     end-of-plan commit.
  3. **"One screenshot / one adb probe to see what's going on."** Device work
     is end-of-plan verification like everything else. Queue the whole device
     checklist, then do it once, in one pass.

  **Batching is the entire point.** A correct plan for this repo is:
  *read → edit → read → edit … for the whole plan*, then **one** shell block at
  the end containing analyze, test, both Python gates, the device checklist, and
  the commit. If you notice yourself shelling out every 5–10 seconds, you have
  already broken this rule; the fix is to stop, not to justify the next call.

  **If the rule feels like it is costing correctness, that is the signal to
  report a blocked item, not to run the command.** A plan that cannot be
  completed without mid-flight verification is a plan that needs a decision from
  the user — say so and wait.

  Two further standing rules that follow from this:
  - **Never round-trip source through a shell.** Bulk edits go through `edit`,
    or a `write` of the whole file. `Get-Content | Set-Content`, `sed -i`, and
    `python -c` have each corrupted or mangled a file in this repo. PowerShell
    5.1 in particular decodes UTF-8 as ANSI and silently destroys emoji and
    typographic characters.
  - **Device state is left clean.** If you change `font_scale`, animations, or
    any other system setting on a test device, restore it in the same
    end-of-plan pass, and say that you did.

## Hard-won gotchas

- **Layouts that pin a size need a multi-scale text test.** Phase 8 found a
  card overflowing its grid cell by 6px at text scale 1.0 (34px at 1.5, 61px
  at 2.0). Any widget placed in a fixed-aspect-ratio grid or a fixed-height
  box must be tested at more than one `textScaler` — reading the code is not
  enough. Same for futures: a `?? []` fallback turns loading, error, and
  empty into one lie. See `blueprints/lessons-learned.md` L14.
- **A non-flexible `Row` child is laid out at intrinsic width BEFORE the
  `Expanded` child gets any space.** That is the Phase 13 bug in
  `CompanionSection`: the "Tap for Skill Tree" hint needed ~450dp in 292dp at
  2.0x on a 320dp screen, and the `Expanded` level text could not save it
  because it is laid out second. `Expanded` only protects the *flex* child.
- **`Semantics(label: ...)` CONCATENATES the child's text onto the label
  unless you pass `excludeSemantics: true`.** A tree dump showed `ToolCard`'s
  node label as `"Meeting Finder. Live and upcoming\nMeeting Finder\nLive and
  upcoming"` — screen readers announced every card twice. When you do set
  `excludeSemantics: true`, you must **repeat `onTap` on the `Semantics`**, or
  you drop the child's tap action and leave a button that cannot be activated.
  Do NOT use it on a subtree containing nested interactive controls
  (`CompanionSection` holds a pet card with two real buttons; excluding them
  would make check-in and walk unreachable).
- **`find.bySemanticsLabel` reads `element.renderObject.debugSemantics`, not
  the semantics tree** — it reports ZERO matches for a label that genuinely
  exists in the tree. To assert on semantics, walk
  `tester.binding.renderViews`' `owner!.semanticsOwner!.rootSemanticsNode!`
  (this is what `flutter_test` does internally in `finders.dart`). **Both
  `binding.rootPipelineOwner` and `binding.pipelineOwner` are the wrong
  accessors here**, and both look right: the root owner's `semanticsOwner` is
  **null** in a widget test (each `View` gets its own `PipelineOwner` hung off
  the root, and that is the one holding the `SemanticsOwner`), while
  `binding.pipelineOwner` is a *separate legacy instance*, not an alias. Cost
  12 tests failing with "Null check operator used on a null value".
- **Semantics API facts worth remembering:** `SemanticsNode.hasFlag` is
  deprecated — use `node.flagsCollection.<flag>`. `isButton`/`isSlider` are
  `bool`, but `isEnabled` is a `Tristate` (so "disabled" is
  `isNot(Tristate.isTrue)`). `SemanticsNode` has no `hasAction`; use
  `node.getSemanticsData().hasAction(...)`. `SemanticsFlag` comes from
  `dart:ui` via `package:flutter/semantics.dart` — `material.dart` does not
  export it.
- **Dispose a `SemanticsHandle` before the test body ends.** `flutter_test`
  verifies this in `_endOfTestVerifications`, which runs *before* tearDowns, so
  `addTearDown(handle.dispose)` is too late and fails every test. Use
  try/finally.
- **`AsyncSnapshot` has no `.data()`/`.error()` named ctors** in this Flutter
  version. Tests must use `AsyncSnapshot<T>.withData(state, data)` and
  `AsyncSnapshot<T>.withError(state, error, stackTrace)`. `.waiting()` and
  `.nothing()` do exist.
- **Never round-trip source through PowerShell.** For bulk edits, write a
  `.py` to the temp dir and run it with explicit `encoding="utf-8"` +
  `newline="\n"`. Do NOT write `python -c "..."` through PowerShell — the
  quoting gets mangled and can corrupt the file. This has broken files
  three times in one session.
- **PowerShell 5.1 corrupts UTF-8.** Never round-trip source files through
  `Get-Content | Set-Content` (ANSI decode mangles emoji/·/— into mojibake —
  this caused a real avatar bug). Use the file tools, or Python with
  `io.open(..., encoding='utf-8', newline='\n')`. Console showing `Ã°Å¸` is
  display-only; verify with a strict Python read, not the terminal.
- **Drift schema is at v13** (not v9 — v10 added `fellowship_syncs`, v11 added
   `active_raids`, v12 added seven `@TableIndex` annotations, v13 added the
   fellowship attestation columns `peerKeyB64`/`attested`/`role` plus the
   `idx_sync_key_ts` index). Schema edit =
   bump `schemaVersion` AND add an `if (from < N)` migration block, then run
   build_runner. Never edit `recovery_database.g.dart` by hand. v9 added
   `recovery_pets.equippedSlotsJson`/`pathLevel`/`pathXp` for the R28 atomic pet
   migration; v12's migration block is the template for adding an index.
- **Every schema bump must come with a migration test, and the test must be
  shown to go red.** `test/schema_migration_test.dart` covers v12→v13 on a
  *populated* database. Until it existed, `onUpgrade` had **zero** coverage,
  because every other test opens a fresh in-memory database and therefore only
  ever runs `onCreate` — so the code path every existing user executes on first
  launch after an update was never executed by the suite. That is not
  hypothetical: v3→v6 left journal PIN keys present-but-empty and locked real
  users out of their own journals.
  Two rules make it useful rather than decorative:
  1. **No hand-written old DDL.** The test lets Drift build the authoritative
     current schema and then subtracts exactly what the `if (from < N)` block
     adds, so the old schema cannot rot into a second source of truth that no
     longer matches reality. It sets `PRAGMA user_version` to fake the version.
  2. **Break the migration on purpose and confirm the test fails.** Removing
     `addColumn(peerKeyB64)` + `createIndex(idxSyncKeyTs)` from the v13 block
     turns it red in 3 places. A test that has never been observed failing is
     not evidence of anything — same law as `selftest_invariant7.py`.
  3. **Cover the WHOLE chain, not just the newest hop.** `onUpgrade` is one
     function holding **twelve** `if (from < N)` blocks. The second group in
     that file seeds a **v1** database and upgrades it to v13 in one launch,
     which is the path a first-release install takes and the only thing that
     executes the other eleven blocks. It asserts the four v1 tables keep their
     rows, the seven migration-created tables appear, all eight indexes are
     built, nullable columns come back `null` (the v3→v6 shape) and
     `counters.daily_cost` comes back `0.0` (added-with-default backfill), and
     that `recovery_pets` is **writable** — a column-presence check cannot tell
     you the table accepts what the real code writes.
- **GGUF native libs are prebuilt and committed.**
  `android/app/src/main/jniLibs/arm64-v8a/*.so` (libllama, libggml, libggml-base,
  libggml-cpu, libmtmd, libllama-common) were built from llama.cpp source with
  NDK 28.2 for `llama_cpp_dart`. Don't delete or casually rebuild; a release
  (non-debug) rebuild is still pending validation.
- **DB encryption** uses `sqlcipher_flutter_libs` (`openCipherOnAndroid`
  override + PRAGMA key from flutter_secure_storage). Do NOT reintroduce the
  `hooks: sqlite3mc` native-assets experiment — it fails to ship libsqlite3.so
  on device.
- **Python is 3.14 → no TensorFlow wheels.** Coach-model training uses an
  isolated env:
  `python -m uv venv .venv-tf --python 3.12` →
  `python -m uv pip install --python .venv-tf numpy tensorflow-cpu` →
  `.venv-tf\Scripts\python.exe tools\train_coach_intent.py`.
  Trained model artifacts in `assets/models/` ARE committed (tiny, INT8).
- **`flutter analyze` must stay clean** — `analysis_options.yaml` excludes the
  archived upstream copy (`Recovery-for-All-main/`, gitignored and currently
  absent from the tree, so the exclude is a harmless no-op) and platform dirs.
  Don't loosen excludes.
- **Never hand-edit `blueprints/recovery_all_code.md`** — it's generated by
  `tools/generate_code_package.py`; regenerate after code changes.
- **Architecture invariants are enforced, not merely documented — FOURTEEN of
  them.** `tools/verify_invariants.py` fails on: (1) a missing `databaseProvider`
  override in `main.dart` (a second SQLCipher connection to the same encrypted
  file); (2) a second `SosTile` declaration or a removed `_showSosSheet` entry
  point (Phase 10 forbids a duplicate SOS surface); (3) any of the twelve
  load-bearing SharedPreferences keys going missing **or drifting out of its
  owning file** (a partial rename desynchronises the writer from the reader, so
  real users silently lose saved settings); (4) the Phase 8 dashboard view
  files going missing; (5) any retired `AppColors` constant; (6) a reduce-motion
  read escaping `lib/core/motion/app_motion.dart`; (7) missing-brace string
  interpolation in its **unambiguous** forms (`'$ref.watch(x).y'` renders
  literally — the ambiguous `$id.field` shapes are deliberately NOT flagged and
  are covered by exact-value assertions instead, see the known-gaps list below
  and L36); (8) `dashboard_screen`
  reading pet state back out of `RecoveryPetService` instead of the notifier,
  now scanned across every screen rather than one file; (9) a hardcoded
  `Colors.white`/`Colors.black` **text or icon colour** sitting
  near a `colorScheme` panel, fill, or `Border` — M3 `primary`/`tertiary`/
  `surfaceContainer`/`error` all flip tone with brightness, so a hardcoded
  foreground is unreadable in one mode; and (10) the constellation 3D
  `Positioned.fill` overlay being declared **after** an interactive control in
  the same `Stack`, which makes 3D mode a one-way door (a Stack hit-tests its
  LAST child first); (11) any Firestore rule gated on `request.auth != null`
  alone, or a content collection that binds no path segment to
  `request.auth.uid`. `request.auth != null` is a *session* check, not an
  authorisation check, and a field-based ownership test is not equivalent —
  **the caller writes that field**, so only the path is not caller-chosen.
  (12) any companion surface re-introducing a system emoji as artwork
  (`displayEmoji`, `presetEmojis`, `.emoji`) or any companion **data** file
  declaring a glyph — an emoji is a per-device font dependency that is tofu on
  the low-end builds the reduced-motion path exists for, and no other gate can
  see it; (13) the fellowship reward being reachable before
  `FellowshipAttestationService.verify`, or its 24-hour cooldown being keyed on
  the peer-chosen **alias** instead of the peer's public key — the alias is
  chosen by the caller, so renaming it defeats the limit, which is exactly the
  trap invariant 11 documents for Firestore. **(14) the release build silently
  falling back to the debug signing key when the upload keystore is absent** —
  see §5 Build Boundary; the fallback stays legal for a debug build, so the gate
  pins the *separation* (a `startParameter.taskNames` release check that guards
  a thrown `GradleException`) rather than banning the fallback outright.
  When a rule changes on purpose, update the gate and this file in the same
  commit.
- **`tools/selftest_invariant14.py` must run in the same batch as
  `verify_invariants.py`.** Invariant 14 guards a *decision in a build file*, so
  it is exactly the kind of rule that gets reverted by accident while fixing
  something nearby — which is how it shipped. The selftest includes a negative
  control where every code line is stripped and only the prose comments remain;
  if that passes, the rule is matching a comment instead of the behaviour, which
  is the L32 failure mode. It also states its own limits out loud: a text check
  cannot prove the throw is on the path actually taken, and cannot detect a
  keystore that exists but holds the wrong key. Only the build proves that —
  which is why §5 still requires reading the signer identity.
- **Known gaps in those gates, so do not trust them blindly.** Deliberately not
  given a count: the number went stale the moment a rule was added, twice, and a
  wrong count reads as authoritative in a way the detailed text does not.
  Invariant 8
  scans every `lib/screens/*.dart` for a private `RecoveryPet` field and now
  exempts only `PET_OWNER_LOCAL_EDIT_BUFFERS` (`avatar_dresser_screen`, which
  edits a pet handed in by the caller and pops it back, so it never reads the
  database); its second half — the dashboard reading pet state back out of
  `RecoveryPetService` — is still scoped to `dashboard_screen.dart` alone, and
  `constellation_screen.dart` legitimately writes through the service, relying on
  the notifier's stream subscription to stay current. Invariant 9 pairs by
  statement and by a ±12-line window, so a fill declared more than 12 lines from
  its text still slips past, and a raw colour inside a `CustomPainter` is
  intentionally not flagged (white on a canvas is a constant, not a tone
  mismatch). Invariant 10 compares byte offsets, so it cannot distinguish a
  declaration from a mention of the same text; the behavioural test
  `test/constellation_3d_controls_reachable_test.dart` covers the real hit path.
  Invariant 11 is a static scan of the rules text, not a rules-unit-test — it
  catches the two shapes that shipped, and cannot prove the absence of every
  other path. Invariant 12 scans for the **identifiers that were removed**, so
  a newly-named emoji would pass; it also does not forbid non-ASCII text,
  because the UI legitimately uses `·`, `✦` and `—`. Invariant 13 compares byte
  offsets within one method and checks two needles, so a helper that grants XP
  from somewhere else would not be seen. **Invariant 14 is a text check on a
  build file**, and its own selftest states the limits out loud: it requires the
  literal `if (RELEASE_VARIANT_REQUESTED)` and a `throw` *inside* that branch,
  because a rule that merely greps for the flag name and for `GradleException`
  passes both `if (false) { throw … }` and `val ignored = GradleException(…)` —
  the original bug wearing a hat. It still cannot execute Gradle, so it cannot
  prove the throw is on the path actually taken, and it cannot detect a keystore
  that exists but holds the wrong key. **Only the build proves those**, which is
  why §5 still requires reading the signer identity.
  **Invariant 7 covers only the
  unambiguous subset of missing-brace interpolation and cannot be widened**:
  `'$modelId.gguf'` (a file extension) and the real bug
  `'$role.wire|$alias|$nonceA'` are the same token shape, and the former is
  correct code that the gate must not flag. That bug shipped — every leg of the
  fellowship handshake signed an identical string — and the regex missed it. The
  unflaggable shapes are listed as `KNOWN_GAPS` in
  `tools/selftest_invariant7.py`, and the coverage comes from asserting the
  **exact** signed string, not from a pattern. See L36. Do not "fix" that
  regex; broadening it fails the build on `'$modelId.gguf'`.
- **A listed-but-unscannable key is not a pin.** When you add a key to
  `REQUIRED_KEYS`, confirm `KEY_PAT` can actually *see* it — the prefixes in
  that regex are what the scanner matches on. This is how
  `meeting_search_radius_miles_v1` sat declared-and-ungated: adding it failed
  the gate, which is the gate working. See `blueprints/lessons-learned.md` L31.
- **A comment describing a fix is not the fix.** The constellation 3D one-way
  door shipped *and* was documented-as-fixed in the same file, in prose directly
  above the wrong line. A later pass read that comment, concluded the screen was
  handled, and skipped it. Pair every behavioural claim with a gate or a test —
  see L32.
- **A resource referenced only by name from Dart does not exist to the resource
  shrinker.** `flutter_local_notifications` resolves its icon with
  `context.getResources().getIdentifier(name, "drawable", packageName)`, so the
  argument must be a **bare drawable name** — `'ic_stat_sos'`, never
  `'@mipmap/...'`, which returns 0 in every build and throws `invalid_icon`.
  Worse, nothing references that drawable statically, so `--release` shrinking
  **deletes it**: the build compiles, installs, launches, and only fails on the
  device. `res/mipmap-*/ic_launcher.png` is already orphaned for the same reason
  (the manifest declares `@mipmap/launcher_icon`). Anything reached by a runtime
  name lookup needs a `tools:keep` in `res/raw/keep.xml` **and** verification
  against the built artifact — `aapt2 dump resources <apk>`, or `read`ing the
  file, which proves nothing about shipping. See L43.
- **Never XML-escape a `--` inside a comment.** Android's resource parser
  rejects it fatally at `parseReleaseLocalResources`, and the natural fix —
  quoting the error message in the comment — reintroduces it. Cost one wasted
  release build. See L44.
- **~~A Play versionCode is spent project-wide~~ — RETRACTED, and the retraction
  matters more than the rule did.** I once recorded that uploading to *any* track
  burns that versionCode project-wide, and used it to talk the user out of
  versionCode 10 for a production release. Wrong. Play's increase constraint is
  per **track**, and promoting open→production **reuses the same versionCode**.
  The console error that refuted it named **8** being shadowed by **10** inside one
  release — a within-release selection mistake, fixed by deselecting 8; 10 was
  publishable all along. Two rules that replace it:
  - **A versionCode is spent per track, not per project.** Promotion between
    tracks reuses it; that is the ordinary workflow. Never renumber downwards.
  - **Never write a numbered "lesson" from a plausible mechanism.** That entry
    had confident prose, a code block and an imperative, and read as evidence
    someone had already paid for it — so a later session would have acted on a
    rule I invented. State the observation *and* its source, or do not write it
    down. When a lesson is retracted, retract it **loudly and in place**; do not
    quietly delete it, because the L32 failure mode is a stale claim, not an
    absent one.
  - Corollary: read the error text literally. "Version code 8 is shadowed" cannot
    mean "version code 10 is spent". I had that evidence on screen and reasoned
    past it.
  - `versionCode` lives in `pubspec.yaml` and flows into Gradle automatically;
    never hardcode it in `build.gradle.kts`.

## Architecture (non-obvious wiring)

- **Entry**: `lib/main.dart` — guarded `Firebase.initializeApp()` (works
  without `android/app/google-services.json`; that file is gitignored and
  activates the google-services Gradle plugin conditionally).
- **DB**: Drift, `lib/database/recovery_database.dart`. Tables: profiles,
  counters, journal_entries, constellation_points, weekly_goals,
  wellness_check_ins, recovery_pets, pet_events, feed_posts,
  fellowship_syncs, active_raids.
- **Meetings**: `lib/services/meeting_finder_service.dart` parses the
  Meeting-Guide/TSML JSON spec — shared by aaMinnesota (AA), BMLT TSML
  endpoints (NA; note `coordinates` may be a `"lat,lng"` STRING), and
  curated MN pathway meetings in `lib/data/minnesota_pathway_meetings.dart`.
  Fellowship tags ('AA'/'NA'/'Dharma'/'Wellbriety') drive path-tailored
  filtering; time filter keeps live (2 h window) + 7-day upcoming only.
- **Map**: `flutter_map` + keyless OSM/CARTO/Esri/Topo tiles via
  `lib/services/map_tile_cache.dart` (cache-first TileProvider + offline
  prefetch packs, 150 MB oldest-modified-first eviction budget via
  `evictIfNeeded`, and a ±85.05° latitude clamp in `tileRange` — above the
  Mercator limit `log()` returns NaN and `.floor()` throws). `google_maps_flutter`
  was deliberately removed — do not re-add.
- **Feed**: `CommunityFeedService` = local Drift always + Firestore mirror
  when Firebase is up. Guardrails C1–C5 in `blueprints/pet-store-rules.md`
  are enforced in code + tests (`test/community_feed_service_test.dart`).
  Remote moderation writes are **local-only by design** (C5): there is no
  authorisable moderator claim, so the rules deny remote `status` writes.
- **Fellowship handshake**: `fellowship_sync_screen.dart` — a three-leg
  Ed25519 exchange over QR. Each install holds a keypair in secure storage
  (`fellowship_id_*`, deliberately separate from `SponsorLinkService`'s so a
  leaked attendance key is not a signing key). A shows an `offer` carrying
  `nonceA`; B verifies A's signature, shows an `answer` carrying
  `nonceB` + `echo: nonceA`; A verifies and shows a `confirm` echoing
  `nonceB`; B verifies. **Only after a signature over BOTH nonces is the
  handshake recorded and paid** — the screen's `_handleScanned` verifies before
  `_completeHandshake`, and invariant 13 fails the build if that is reordered.
  Codes expire in 5 minutes (`maxAge`) and carry a `v` field; an unsigned or
  legacy `{alias, ts}` payload is REFUSED rather than downgraded. The 24-hour
  cooldown is keyed on `fellowship_syncs.peerKeyB64`, not `peerAlias`, because
  the alias is peer-chosen and renaming it used to defeat the limit. Drift v13
  added `peerKeyB64`/`attested`/`role`.
  **It still is not identity verification** — there is no server or third
  party, so this proves contemporaneous presence between two keys, not who they
  are. One person with two phones can complete an exchange with themselves. Do
  not describe it as otherwise. Pinned by `test/fellowship_attestation_test.dart`
  (protocol, two real device identities) and `test/fellowship_handshake_test.dart`
  (screen wiring).
- **Coach**: scripted brain (`recovery_coach_service.dart`) is the floor;
  `coach_tflite_intent_service.dart` (optional TFLite) sits between crisis
  keywords and the keyword fallback. Safety order in `chatbot_screen.dart`:
  guardrail → crisis keywords → model → keywords. Never reorder.
- **Pet**: Drift primary (`recovery_pet_service.dart` + `recovery_database.dart` v9) — `recovery_pets` + `pet_events` with atomic `transaction{upsertPet+addPetEvent}` (R28), prefs dual-write fallback for migration. Sparks daily cap 150 (milestones, meetings, walks exempt), walk cap 2/day, milestone rewards cap-exempt.
- **Avatar**: `avatar_painter.dart` paints the creature (vector, no emoji in the
  composite); `SpeciesPortraitPainter` in the same file draws catalog
  portraits for the species picker. `cosmetic_icon_painter.dart` paints every
  cosmetic thumbnail and the mood faces (`CosmeticIconPainter`,
  `PetMoodGlyphPainter`) — this closed the last emoji surface, so
  `PetCosmetic.emoji`, `PetMoodX.emoji` and `presetEmojis` are **deleted**, not
  deprecated, and invariant 12 fails the build if any come back. Species and
  cosmetics both drive **silhouette first, colour second** (`speciesShapes` +
  `speciesColors`, `CosmeticGlyph.signature` + category palette);
  `test/species_vector_art_test.dart` and `test/cosmetic_vector_art_test.dart`
  fail on a same-outline pair. Colour is used as identity ONLY in the two
  declared colourway subcategories (`skin/tone`, `hair/color`), which the test
  pins so a third cannot be added without art. Lottie aura/mood underlays
  from `assets/lottie/` (`.lottie` DotLottie zip, thermal-gated via
  `HardwareTierService.isLowEnd` on <3GB — enforced by
  `test/aura_lottie_assets_test.dart` + `hardware_tier_service_test.dart`).
  The reduced-motion / low-end branch renders the static painted creature with a
  `CustomPainter` glow and **no** glyph of any kind, because that path is for
  devices least able to render a system font.
- **Tailoring doctrine**: onboarding choices (goals/paths/tools JSON in the
  profile) drive dashboard cards, meeting fellowships, and downloads.
  Minnesota-first: fallbacks center Twin Cities; MN feeds first; other
  states are additive.
- **Dashboard view layer** (Phase 8): `dashboard_screen.dart` is now almost
  entirely callbacks + navigation. The visuals live in
  `lib/widgets/dashboard_cards.dart` (`PledgeCard`, `ToolCard`, `SosTile`,
  `SupportLinkRow`) and `lib/widgets/dashboard_sections.dart` (`PathChips`,
  `MeetingSpotlight`, `ToolGrid`, `SkyCrown`, `CompanionSection`). All of them
  are presentational — plain values in, callbacks out, no Riverpod or DB
  reads. Add new dashboard UI to those files, not inline in the screen.
  `SosTile` is the ONLY SOS tile implementation; never add a second SOS
  surface.
- **Navigation shell** (Phase 9): `DashboardDestination` in
  `dashboard_providers.dart` is the single source of truth for the four
  destinations AND the Android back target. The shell uses an `IndexedStack`, so
  every destination stays alive; a persistent body must therefore be told to
  refresh explicitly (`SettingsScreenState.refreshState()` via a `GlobalKey`)
  rather than relying on `initState`. This is why the pet-owner rule below
  matters so much: a destination that stays alive for the whole session is also
  a screen that never re-reads anything on its own.
- **Pet state has ONE owner, `dashboardDataProvider`** — and the owner is
  **live**: `DashboardDataNotifier.build()` subscribes to
  `RecoveryPetService.watchPetStream()`, so a Spark awarded anywhere in the app
  reaches the dashboard without anyone remembering to call `setPet`. It is not
  just single-owner, it is single-*source*; never re-add a private `_pet` field
  or a second `ensureHatched()` read in a screen, and never add a
  `copyWith` that swallows an explicit null. `DashboardDataState.copyWith` uses
  an `_unset` sentinel precisely so `copyWith(pet: null)` can actually clear the
  pet; the obvious `pet ?? this.pet` makes clearing impossible and only fails
  when something needs to do it.
  `PET_OWNER_LOCAL_EDIT_BUFFERS` in `verify_invariants.py` is the one documented
  exception: `avatar_dresser_screen` keeps a local copy because the pet arrives
  as a constructor argument and is popped back to the caller, so it never reads
  the database and cannot disagree with anything.
  The `get _pet => ref.watch(...)` shape is read from event handlers as well as
  from `build` (`pet_home_screen._adoptSpecies` spends Sparks through it), which
  is safe on flutter_riverpod 3.4.3 — `ref.watch` outside `build` returns the
  current value without registering a dependency, and `build` registers its own.
  `test/dashboard_pet_liveness_test.dart` pins both halves of that, because a
  Riverpod upgrade that tightened it would otherwise crash on tap in the field.
- **M3 theme engine** (Phase 2): `lib/core/theme/app_colors.dart` holds
  `AppColors.themeDataFor(ThemePreference, Brightness)` for 3 palettes × 2
  brightness. `AppColors` top-level statics are DELETED; only
  brightness-independent domain tokens (`mood*`, `raid*`, `star*`, `fellow*`,
  `pin*`, `housing*`, `starfield`, `brandZoom`, `monsterHound`, `accentSky`,
  `dangerSoft`, `pink`) remain. Never re-add a brightness-pinned constant —
  `tools/verify_no_hardcoded_colors.py` fails on both raw `Color(0x…)` and
  on any retired name.

## Docs that are load-bearing

**Read the tracked ones — they are the only ones a fresh clone will actually
have.** This list used to read as a flat set, which was wrong in a way that
wastes a cold start: eleven of these are gitignored (see the note below), so a
new machine or a clean checkout receives none of them, and one does not exist
at all.

**Tracked (present in any clone):**
- `blueprints/UI-UX-themes-plan.md` — the 17-phase UI/UX program, **Phases 0-17
  all complete and device-verified**. It is history now, not a next-step
  pointer: do not restart a phase from it. Its test counts are historical
  records; the current figure is at the top of the file.
- `blueprints/dashboard-ia.md` — Path|Library tabs + modular tiles spec
- `blueprints/lessons-learned.md` — mistake ledger, update on every trip
- `SESSION_HANDOFF.md` — cold-start entry point, **update every session**
- `AGENTS.md` — this file

**Local-only (gitignored, present on this machine only).** Useful, and read them
if they exist, but never assume a clone has them:
- `blueprints/roadmap-v2.md` — tiered feature queue (work in progress)
- `blueprints/pet-store-rules.md` — sparks economy + feed laws (C1–C5)
- `blueprints/gguf-feasibility.md` — deferred LLM spec (1 GB devices: never)
- `blueprints/avatar-art-spec.md` — custom-art destination (SHIPPED; species
  portraits, ~90 cosmetic icons and mood faces are all code-painted. No new
  emoji features — that is the whole point of it)
- `blueprints/tacmap-extraction.md` — OSM map port plan (P0 shipped)
- `blueprints/firebase-setup.md` — cloud-sync walkthrough. **Prefer the CLI:**
  `firebase deploy --only firestore:rules` works from the repo because
  `firebase.json` is tracked. Editing rules in the console instead is what let
  the deployed copy and the repo diverge for weeks.
- `blueprints/recovery-pet-checklist.md`, `blueprints/recovery-coach-checklist.md`
  — tick boxes as items ship
- `blueprints/resource-system.md` — registries + link-health + tailoring

**Do not reference at all:** `SPRINT_PLAN.md` no longer exists. It used to be
listed here, which is the same class of error in miniature — a doc index that
points at nothing is worse than no index, because it reads as authoritative.

**Why this is worth stating:** an agent following the old list literally would
open ten missing files on a fresh clone and, finding nothing, have no way to
tell "this repo has no such doc" from "the index is stale". Distinguishing
those two is the entire job of this section.

## Auto-doc + auto-commit workflow (added Aug 25 — never ask again)

**Cadence: docs are per-change, verification is per-PLAN. Never mix them.**
The two halves below were originally one list that said "after *every* change
the agent MUST run this sequence", with `flutter analyze` and `flutter test`
sitting in it. That is a direct instruction to run the analyzer and the whole
suite after every single edit, it is what produced months of shell traffic, and
it is now split in two on purpose.

### Per change, and every one of these are free — do them as you go

1. `SESSION_HANDOFF.md` §3/§7 + the date line
2. Tick affected `blueprints/*.md` checklist boxes
3. Update the mistake ledger, `blueprints/lessons-learned.md`, if a trip happened

The human never needs to say "update docs" — it is automatic.

### Once, at the very end of the whole plan, in ONE batched shell block

4. `python tools/verify_resources.py` — **only if a URL actually changed**
5. `python tools/generate_code_package.py` (regen `recovery_all_code.md`)
6. `flutter analyze` (must be zero) + `flutter test`
7. `python tools/verify_no_hardcoded_colors.py` + `python tools/verify_invariants.py`
8. Device checklist, if the plan called for one
9. `git add` **by explicit path** + commit (message = gates status only)

Steps 4–9 are the only shell calls in a session's work, and they happen once.
If a plan is going to need a gate run in the middle, the plan is wrong — say so
and wait for a decision rather than running it.

`git push` remains manual (repo needs cleaning first).
