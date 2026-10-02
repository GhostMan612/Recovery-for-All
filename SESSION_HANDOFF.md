# SESSION_HANDOFF.md — Cold-Start Entry Point

**Last updated:** October 30, 2026, latest (UI/UX program COMPLETE — **all 17 phases shipped**; the Oct tester round is device-verified on the LG B160V, and the **Moto G 2025 unblocked the two remaining hardware-gated items**: `[hardware] totalRamGb=3.56 isLowEnd=false` against a 3.0 GB threshold, plus real `step_count`/`step_detector` sensors and a **proven** sensor→plugin→Dart→prefs chain. A full structural audit then found and fixed **~40 real defects** the analyzer cannot see — data loss (the daily Spark ledger recorded *requested* rather than *granted*, permanently eating the user's allowance; equipping a cosmetic silently reset earned Trials XP; a Drift read error fabricated a default pet over real data), lost updates from unsynchronised read-modify-writes, an **infinite 60 fps rebuild loop**, a **1.19 MB meeting cache in SharedPreferences**, **zero database indexes**, dead dashboard controls from `ref.read` in `build()`, a first-run tutorial that never opened, an unverifiable sponsor signature that returned `true`, a **plaintext chronicle written into the encrypted journal column**, and a **GGUF free-space check that compared a 4096-byte directory entry against a 241 MB model — blocking 100% of model downloads** while reading as a working safety check. A **documentation audit** then found ~34 doc↔code contradictions, including a schema version stated as v9 (it is **v12**) and a build rule that forbade builds the user had pre-authorized. Suite at **511**, analyze clean, **eleven** invariants green, all links alive. Governing lessons: **L31** (a probe that has never been shown to work on a case where you know the answer is a guess with a colon; its corollary — *a listed-but-unscannable key is not a pin*) and **L32** (*a comment describing a fix is not the fix* — the 3D one-way door shipped alongside prose claiming it was already fixed).

**Release state:** the Play upload questionnaire is **complete** and the app is **awaiting approval for public publishing**. Device verification of the current source is owned by the user and has not been run for this batch.

**Firestore rules — READ BEFORE PUBLISHING.** `firestore/firestore.rules` was
restructured and the console copy is stale. The old
`match /sponsor_bundles/{docId} { allow read, write: if request.auth != null; }`
granted **every authenticated user** read, sign and write over every clinical
step-work bundle. It is now partitioned by uid **in the path**
(`sponsor_bundles/{ownerUid}/bundles/…`, `sponsorBundles/{sponsorUid}/inbox/…`)
because rules can compare a path segment to `request.auth.uid` but cannot compare
a *field* to the caller without a custom claim — and there is no Admin SDK here,
so the caller-written `ownerUid` field was never an authorisation check.
Consequences: flat-schema bundles are now unreachable (deliberate; see
`SponsorLinkService.orphanedRelayDocIds()`), and genuine **cross-account** relay
needs an `sponsor_code` custom claim, which does not exist yet — the offline
messenger path is unaffected and remains the default. The `community_feeds`
update rule is also now field-scoped, so a user can no longer rewrite another
user's alias or body.
**Purpose:** THE first file a fresh session reads. Everything needed to
resume without losing progress. Update it at every session end.

---

## 1 · Read order for any fresh session

1. `AGENTS.md` — operating law (build boundary, commit rules, gotchas)
2. `CLAUDE.md` §1–§5 — token conservation + build boundary details
3. `RULES.md` — technical laws learned the hard way
4. **This file** — current state, environment facts, next moves
5. `blueprints/UI-UX-themes-plan.md` — the UI/UX program, **all 17 phases
   complete**. Its "Resume Here" block records the final verification state
   and the one caveat about the last test run.
6. `blueprints/roadmap-v2.md` — feature status source of truth

## 2 · Hard rules (never violate)

- **⛔ NO SHELL UNTIL THE ENTIRE TASK IS COMPLETE.** Read this before the
  build boundary below; it overrides anything that reads like permission. The
  user has directed this repeatedly and unambiguously: while working through a
  plan, do not call the shell **at all** — not `flutter analyze`, not
  `flutter test`, not the Python gates, not git, not adb, not a scratch `.py`.
  Use `read`, `edit`, `write`, `grep` and subagents; those are the tools for
  working. Run verification **once, at the end, when the whole plan is done**,
  batched into a single shell block, or when explicitly asked. If unsure
  whether a file compiles, **read it again** instead of shelling out.
  Rationale: the analyzer is the wrong oracle for this work — a colour-slot
  typo compiles cleanly and looks wrong on a device, and two widgets colliding
  in a fixed box raise no type error at all — so mid-plan runs buy almost
  nothing and cost 20–90s each.
- **Build boundary**: NEVER `flutter build apk|appbundle|run` without explicit
  per-instance authorization. The human normally builds in Android Studio. (The
  user granted a one-off exception on 2026-09-30 to build and install a debug
  APK for device verification; that is not standing permission.) End-of-plan
  gates, when the plan is finished: `flutter pub get` → `flutter analyze`
  (**must be "No issues found"**) → `flutter test`.
- **Commits by explicit path only** (never `git add .`/`-A`). Commit
  messages report analyze/test status ONLY — never claim build success.
- **Safety pipeline order untouchable** (`chatbot_screen.dart:72`):
  guardrail → crisis keywords → GGUF → TFLite intent → skills → keyword
  fallback → unknown redirect.
- **PowerShell 5.1 corrupts UTF-8** — never round-trip source through
  `Get-Content | Set-Content`; use file tools or Python utf-8.
- **Drift schema v12** - bump `schemaVersion` + migration block +
  build_runner; never hand-edit `.g.dart`.
- **SQLCipher pin**: sqlite3 ^2.9.4 + sqlcipher_flutter_libs 0.6.8;
  drift 2.34 blocked by design until sqlite3 3.x migration path.
- **Cosmetics only / pet tone laws**: Sparks never gate safety; pet never
  dies, never guilts (pet-store-rules.md).
- **One database instance** (`main.dart`): `ProviderScope` overrides
  `databaseProvider` with the single `RecoveryDatabase`. Removing that override
  silently opens a SECOND SQLCipher connection to the same encrypted file.
- **Never round-trip source through PowerShell.** For bulk edits, write a
  `.py` to the temp dir and run it with explicit `encoding="utf-8"` +
  `newline="\n"`. Do NOT write `python -c "..."` through PowerShell — the
  quoting gets mangled and corrupts the file.
- **Do not use bare regex renames on a state class.** Twice this session a
  field-rename regex clobbered the enclosing class declaration
  (`_Profile? _profile;` -> garbage). Always `Select-String` the call sites
  first and hand-edit assignment sites; a regex cannot distinguish reads from
  writes.

## 3 · Where things stand

- **UI/UX modernization program: ALL 17 PHASES COMPLETE.** The
   phase-by-phase record, per-phase evidence, the three late-phase defects, and
   the final verification state are in `blueprints/UI-UX-themes-plan.md` —
   read that file before starting new work. Short version:
  - Color system is real: 875 raw literals and 390 dark-pinned `AppColors`
    statics are both gone. The retired top-level constants were **deleted**, so
    a screen can no longer pin itself to dark mode.
  - `tools/verify_no_hardcoded_colors.py` is a standing gate: it fails on raw
    `Color(0x…)` outside the token file **and** on any reference to a retired
    constant name. It must exit 0.
  - `lib/widgets/app_primitives.dart` holds 7 shared primitives (`AppCard`,
    `AppSectionHeader`, `AppLoadingState`, `AppEmptyState`, `AppErrorState`,
    `AppOfflineState`, `AppActionTile`). Reuse before adding new containers.
  - `lib/core/dashboard_providers.dart` owns dashboard state (layout/radius/
    pledge/sky-name/data notifiers). `_DashboardScreenState` went 22 mutable
    fields -> 3.
  - **Phase 8 is complete.** The dashboard view layer was extracted in four
    committed slices; `dashboard_screen.dart` is 1512 -> 1157 lines and is now
    almost entirely callbacks, navigation, and two tab bodies.
    - `lib/widgets/dashboard_cards.dart` (`PledgeCard`, `ToolCard`, `SosTile`, `SupportLinkRow`)
    - `lib/widgets/dashboard_sections.dart` (`PathChips`, `MeetingSpotlight`, `ToolGrid`, `SkyCrown`, `CompanionSection`)
    - Every extracted widget is presentational: plain values in, callbacks
      out. No widget reads Riverpod or a database, so all of them are
      renderable in tests without providers.
  - **Three real defects were found by tests during Phase 8**, not by review:
    1. `ToolCard` overflowed its grid cell at EVERY text scale (6px at
       1.0, 34px at 1.5, 61px at 2.0) because the toolbox grid pins a fixed
       `childAspectRatio: 1.35`. Fixed with `Flexible` + `FittedBox(scaleDown)`; do not revert.
    2. The meeting card showed "No meetings in the next 6 hours" while the
       cache was still loading, because the `FutureBuilder` used
       `snapshot.data ?? const []`. `MeetingSpotlight` now separates waiting / error /
       empty. This closed the last open Phase 6 gap.
    3. Hiding every toolbox tool collapsed the grid with no explanation and
       no way back. `ToolGrid` now explains that hiding is not deleting
       and offers "Restore all".
  - Suite was at **292 tests** at that point (now **511**), analyze clean.
  - **Phases 10-16 shipped after that.** Phase 10 (SOS) was an audit: added a
    dismiss control, moved the sponsor care-alert off sheet *open* onto real
    activation, and fixed a header overflow. Phase 11 found that the theme
    engine has supported System/Light/Dark since Phase 2 and
    `ThemeNotifier.setMode` persisted to `theme_mode_v1`, but **no UI ever
    called it** — the key was written at install and never again; the control
    now exists. Phase 12/13 added an onboarding step indicator and fixed three
    overflow sites. Phase 14 consolidated the reduce-motion decision into
    `lib/core/motion/app_motion.dart`. Phase 15 ran the 3x2 theme matrix.
    Phase 16's audit came back clean and added invariant 6.
  - **🐛 THREE MORE REAL DEFECTS found in Phases 12-15, by running the matrix
    rather than reading the code:**
    1. **Screen readers announced every SOS destination and every tool card
       TWICE.** `Semantics(label: ...)` without `excludeSemantics: true`
       concatenates the child's own text onto the curated label, so a tree dump
       showed the node label as
       `"Meeting Finder. Live and upcoming\nMeeting Finder\nLive and upcoming"`.
       Fixed with `excludeSemantics: true` on `SosTile`, `ToolCard`,
       `SupportLinkRow` and `SkyCrown` — each had to repeat `onTap`, because
       excluding the child also drops its tap action, and a button with a role
       but no action is unreachable. **`CompanionSection` must NOT use it**:
       `RecoveryPetCard` holds an `InkWell` plus two real buttons, so
       excluding them would make check-in and walk unreachable. That trade (a
       duplicated announcement vs. an unreachable care action) is deliberate
       and is pinned by a test.
    2. **Onboarding never said which step you were on.** Seven steps behind a
       non-scrollable `PageView` with no indicator anywhere; a screen-reader
       user could not even discover the flow had more pages. Now announced
       via a `liveRegion`.
    3. **`CompanionSection` overflowed at 2.0x on a 320dp screen** — the "Tap
       for Skill Tree" hint is a NON-flexible `Row` child, so it was laid out
       at intrinsic width before the `Expanded` level text got any space
       (~450dp needed in 292dp). The hint now steps aside above 1.3x; the
       essential level/XP stays.
  - **🎨 KNOWN PALETTE LIMITATION (found by the Phase 15 matrix):**
    `midnightSlate` and `oledPitch` share the accent `0xFF38BDF8`, and light
    mode is generated from the seed accent — so **those two palettes are
    indistinguishable while light**. Dark is unaffected (each copies its own
    `bgDeep` into `surface`). This is a property of the palettes as designed,
    not a regression, and it is asserted in `test/theme_matrix_test.dart` so it
    cannot change silently. Changing the palettes is out of scope.
- **Five gates now, and the fifth is new:** `python tools/verify_invariants.py`
  enforces the rules that used to be only prose in this file. It fails on a
  missing `databaseProvider` override, a second `SosTile` or a removed
  `_showSosSheet`, any load-bearing SharedPreferences key going missing OR
  drifting out of its owning file, a deleted Phase 8 view file, any retired
  `AppColors` constant, and — added in Phase 16 — the system animation setting
  being **read anywhere except `lib/core/motion/app_motion.dart`**. The last
  one exists because that decision had quietly been made in five places, which
  is how onboarding ended up animating for users who disabled animations. The
  partial-rename case is the valuable one for keys: the key still exists in the
  reader while the writer moved on, which loses real users' settings with no
  error anywhere.
- **Repo tooling** in `.opencode/`: two auditor subagents (`text-scale-auditor`,
  `a11y-auditor`) that report findings with `file:line` and never edit, plus a
  `/verify` command that runs all five gates. Both auditors earned their keep:
  the two-agent a11y/text-scale sweep found 117 issues, and only the
  *rendered* matrix found the Phase 13 overflow, which no amount of reading
  the code would have. Still the right first stop for a UI change, but treat
  their output as a review, not a gate — they do not run. Do NOT fan out
  parallel agents over navigation work touching SOS; that is single-threaded
  by nature.
- **A11Y + TEXT-SCALE AUDIT (Sep 28) — landed, device-unverified.** A
  two-agent audit of all 96 `lib/` files found 117 issues. Six were genuine
  FUNCTIONAL bugs, not accessibility polish, and all are fixed:
  1. First-run tutorial close button was a no-op (`onClose` never passed).
  2. `journal_screen` could hard-lock the app (un-dismissable dialog whose
     `Navigator.pop` was gated on `context.mounted`).
  3. `daily_reflection_screen` rendered RAW CIPHERTEXT in "Recent Reflections".
  4. Two sober-housing buttons were empty closures; `SoberHouse.phone` and
     coordinates were parsed and unused.
  5. The Wellness Check-In was unreachable by screen reader: its labels were
     `TextPainter` output inside a `CustomPainter`, which emits no semantics.
  6. The toolbox grid overflowed at EVERY text scale (6/34/61px at 1.0/1.5/2.0).
  Also fixed: ~187 `Colors.white`/`Colors.black` text colors migrated to
  scheme slots, 5 reduce-motion guards (incl. the craving-surface screen
  shake), 11 bottom sheets given `isScrollControlled`+`useSafeArea`, 12sp font
  floor on 13 sites, and button/state semantics across the SOS sheet, mood
  scales, QR pairing code, milestones, skill tree, and link health.
- **THREE audit claims were checked and found FALSE** — do not "fix" them:
  mood-rating scales are 0-based in BOTH screens (fixing it would corrupt
  saved journal data); `avatar_visual_layer.dart` already had a reduce-motion
  guard; all 15 `AlertDialog` sites already had dismiss affordances.
  `AppType.micro` (11sp) is a deliberate token, not a sub-floor bug.

- **Roadmap complete through R19**: Tier 1–2, R9 RPG, R11 GGUF, plus the
  Aug 25 marathon — R12 self-verifying resources (registries +
  verify_resources.py build gate + runtime link-health with 30-day TTL),
  R13 pathways v3 (LifeRing/WfS/CR; 9 paths now), R14 pet expansion
  (gentle quests, seasonal re-issue calendar, species pack II w/ North
  Star Loon apex, "Kin remembers" memory wall), **R15 Self-Healing Tutorial System** (CompanionGuideService + draggable pet-avatar overlay with Lottie aura, build-time route validation via test/companion_guide_validator_test.dart), **R16 Expanded Meeting Directories** (LifeRing/WFS/CR live TSML feeds + SMART Recovery/InTheRooms curated Minnesota meetings in lib/data/meeting_directories.dart), **R17 Full-App Tutorial Chatbot** (TutorialChatbotService with pet avatar, answers questions about ANY feature — meetings, journal, pet, constellation, trials, coach, settings, literature, resources, sponsor, dresser, coping, reflection), **R18 Step-Counter Verified Walks** (StepCounterService with pedometer verifies actual walks, walk tracking dialog with step count progress), **R19 Pet Gear & Path System** (gearScore from equipped cosmetics, pathLevelComputed from gearScore + pathXp, abilitySlots unlocks per Path Level, celebrate micro-animation on Sparks earn, StepCounterService with pedometer verification). R10 custom art = back-burner, do not raise unprompted.
- **Android debug build**: BUILD SUCCESSFUL — fixed MainActivity.kt NPE (`flutterEngine` null in `onCreate` → moved to `configureFlutterEngine`) + Kotlin compilation fixes.
- **Test suites** (143 tests, all green): R25 gentle evaluator (11), R27 pickNext (5)+widget (5), R26 narrative (6, 7-day + averages + window), Memory Wall (20 timestamp+memoryLine), GGUF services + fail-safe (yield every 15+30s), pet economy+manual 7 (Drift-backed R28), journal crypto, feed C1–C5, Lottie, validator, goldens (20). `flutter analyze` 0, `build_runner` v9 186 outputs, `verify_resources.py` 65 alive.
- **Gemini ASKs 1–9 triaged 2026-08-30:** ACCEPT yielding + HEAD + midnight + persist; MODIFY adaptive (opt-in+suggestion + persistent dismiss `gguf_download_dismissed_v1`); REJECT PowerSync/sqlite3mc; DEFER pet→Drift/RAM. Full in `blueprints/Gemini_Diagnosis_Response.md`. Whitepaper `blueprints/Technical_Architecture_Whitepaper.md`.
- **R25 Recovery-Aware Notifications SHIPPED:** `lib/services/gentle_reminder_service.dart:32` `evaluateNotificationPayload` pure (A→grounding B→pet C→reflection D→rotating) + `setSchedule` pulls pet/wellness/counters; tested `test/gentle_reminder_evaluator_test.dart`.
- **R27 Predictive Next-Meeting Widget SHIPPED:** `lib/widgets/next_meeting_card.dart` `pickNext` (live 2h>today 6h) + emerald/sky/empty; integrated `lib/screens/dashboard_screen.dart:1032` via `cachedMeetings()`. Tested `test/next_meeting_widget_test.dart`.
- **R24 Adaptive Model Router SHIPPED:** `lib/services/gguf_model_service.dart:204` tier auto-assigns `gemma3_270m` for ≥3GB (`needsDownloadForSuggested` + persistent dismiss `gguf_download_dismissed_v1` `lib/screens/chatbot_screen.dart:43`/`lib/screens/settings_screen.dart:119` clear); `lib/screens/chatbot_screen.dart:34` download card 300MB + fallback `lib/services/ollama_service.dart:14` Sovereign `http://192.168.4.144:8000` qwen2.5; yield every 15+30s `lib/services/gguf_inference_service.dart:60`.
- **R26 Narrative Export P1+P2 SHIPPED:** `lib/services/narrative_export_service.dart` 7-day McAdams engine (Agency/Communion/Redemption, Ollama→fallback scripted) + `lib/widgets/chronicle_share_card.dart` RepaintBoundary 3.0 PNG C2-compliant (no sober numbers/location, `share_plus`); tested `test/narrative_export_service_test.dart` (6: empty, averages, stars, window, journal save, eventType case).
- **Memory Wall UI SHIPPED:** `lib/screens/memory_wall_screen.dart` + `test/memory_wall_test.dart` — dedicated "Kin Remembers" view with StreamBuilder over `watchPetEvents`, icons/colors per eventType, timestamps, Spark deltas, empty state, paginated 50; wired into PetHomeScreen AppBar (auto_awesome_outlined).
- **RPG Soft-Lock Fix SHIPPED:** `lib/screens/pet_trials_screen.dart` `Take a Breath` 0-cost ability (+2 Focus, always enabled) escapes 0/1 Focus loops; tutorial updated; `MainActivity.kt:20` channel moved to `configureFlutterEngine` fixes NPE crash.
- **R28 Pet Drift Migration SHIPPED:** `lib/database/recovery_database.dart` v9 adds `equippedSlotsJson`/`pathLevel`/`pathXp` + migration `if(from<9)`; `lib/services/recovery_pet_service.dart` mappers `petFromRow`/`rowFromPet`, `ensureHatched()` Drift-first → prefs fallback → `save()` dual-write, atomic `db.transaction{upsertPet + addPetEvent}` in `_applyReward` (crash-safe), `watchPetStream()`; `test/pet_economy_test.dart` now `NativeDatabase.memory` + `bindDatabase` + `deleteAllPetData`.
- **Step-counter overhaul SHIPPED (uncommitted → this commit):** `step_counter_service.dart` sensor-offset baseline (`step_sensor_offset_v1`, daily = raw − offset, reboot/new-day reset → fresh install shows 0, no phantom); cadence filter (380 ms min interval, burst extra absorbed into offset + walk baseline → 5 shakes no longer 10–15); walk baseline from raw sensor (`_rawSensorValue`), `isTrackingWalk` getter; boot `initialize()` no longer `request()`s permission (status-check only, request deferred to Walk tap). `walk_tracking_dialog.dart` Stop Walk (red, always) + Cancel (both stop FGS + pop) + Finish (verified only). `dashboard_screen.dart` dialog passes `onStop`, back-dismiss stops tracking. `StepCounterForegroundService.kt` PendingIntent SINGLE_TOP/CLEAR_TOP (shade tap fronts task, no restart).
- **Fresh-install splash-hang hotfix SHIPPED (12 testers, 8 hung on splash):** `main.dart` — `signInAnonymously().timeout(8s)`, Sos/Gentle/StepCounter inits `.timeout(4s)` + try/catch (boot never stalls on `runApp`); `recovery_database.dart` secure-storage/workaround/folder `.timeout(4s)` fallbacks; `splash_screen.dart` `getProfile.timeout(15s)` + red `_bootError` with Retry/Continue fail-open to onboarding. Next: bump to 1.0.0+3, release AAB, testers clean-install.
- **Play warnings triage SHIPPED (this commit):** 16 KB audit over release intermediates (17 arm64 .so) — 15/17 clean (llama set, sqlcipher 4.10.0, LiteRT, engine); 2 offenders both ML Kit/CameraX via mobile_scanner 3.5.7: `libbarhopper_v3.so` (barcode-scanning:17.2.0) + `libimage_processing_util_jni.so` (camera-core:1.3.x). Fix = `resolutionStrategy.force` in `app/build.gradle.kts` (mlkit 17.3.0, gms 18.3.1, camera-core/camera2/lifecycle 1.4.2, minor-only). Edge-to-edge = `enableEdgeToEdge()` in `MainActivity.onCreate` (UI already SafeArea-heavy). Llama rebuild script pinned `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON` for future. Human: rebuild AAB, re-run ELF check on fresh intermediates, smoke-test QR handshake, confirm Play warnings clear.
- **POST_NOTIFICATIONS runtime prompt SHIPPED:** merged RELEASE manifest verified to already contain `POST_NOTIFICATIONS` + `VIBRATE` (flutter_local_notifications plugin manifest auto-merged; checked `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml` v4). What was missing: SOS never requested the Android 13+ runtime grant — GentleReminder only requests inside its settings toggle. Added `SosNotificationService.ensureNotificationPermission()` (one-shot, persisted `sos_notif_permission_requested_v1`, never at boot) fired from `_showSosSheet()` user gesture. Version bumped 1.0.0+4 → +5 for the next AAB.
- **Icon-tofu triage SHIPPED (partial, +6):** testers see box-with-X on ALL icons incl. back button. Verified against Sept-7 release intermediates: `MaterialIcons-Regular.otf` IS bundled (32 KB subset, 214 codepoints, FontManifest ok) covering 199/200 used codepoints — total tofu is IRRECONCILABLE with this bundle, so testers' installed build differs from source (stale/wrong upload suspected; splash hang previously masked it). ONE genuine shaker miss fixed: `gps_fixed` (U+E2DC, sober_housing_locator.dart:305) dropped despite const ref → swapped to verified-present `my_location`. Version +5→+6. Human must: (1) confirm versionCode on tester devices, (2) clean-reinstall test, (3) repro release build on Moto G, (4) add `--no-tree-shake-icons` to release build args (shaker demonstrably lossy; +1.6 MB on 105 MB is negligible).
- **Journal lockout fix SHIPPED (+7):** v3→v6 upgrades could leave PIN hash/salt keys present-but-empty → `hasPin()` true → verify-always-fails lockout. `hasPin()` now validates real values (non-null, non-empty, base64-decodable, 32-byte hash + 16-byte salt) — null/''/corrupt all route to Create PIN. Added `clearPin()` (deletes hash+salt, PRESERVES master key so old entries survive) + unlock-gate-only "Forgot PIN?" button wired to `local_auth` `authenticate(biometricOnly:false)` (fingerprint/face/device credential, fully offline); success → Create PIN flow → old entries decrypt. 2 new tests (empty-state lockout, clearPin-keeps-entries). Version +6→+7.
- **Icon registry SHIPPED (+8):** audit proved ZERO `IconData(` constructors in lib/ — all 201 icons are `Icons.*` consts; only 2 string→icon seams existed (`memory_wall._iconForEvent`, dashboard nested `iconFor`). New `lib/core/icon_registry.dart` (const eventIcons/toolIcons maps + methods, zero comments) now anchors both; call sites rewired, dead methods deleted. 5 registry tests. Version +7→+8. VERIFICATION GAP (honest): `flutter build bundle --release` in 3.47 does NOT tree-shake (flag deprecated, emits full 1.6 MB font) and appbundle/apk builds are agent-forbidden — release-shaker proof MUST come from human build (steps in queue). NOTE: build/ intermediates shifted mid-session (subset OTF replaced, odd mtimes) — human rebuilding concurrently; coordinate before trusting build/ reads.
- **PLAY STATE (human-confirmed Sep 12):** +8 AAB already built + uploaded, live in beta/Closed Testing with 11 of 12 testers onboarded. The journal-PIN lockout (+7 fix) was reported FROM this beta cohort. origin/main now = `1665d3a` (+8, pushed Sep 12).

## 4 · Human-side queue (agent cannot do these)

1. GGUF **download + load + latency** matrix on the Moto G — the gate is now
   open and the app is installed (`versionCode 10`), so this is the only
   remaining executable QA item. ~241 MB for Gemma 270M. Plan:
   `docs/qa/gguf_qa.md`.
2. **The 500-step walk award** — the sensor chain is *proven* on the Moto G
   (`step_sensor_offset_v1 = 120`), so only the physical walk remains: carry
   the phone ~5 min. Plan: `docs/qa/step_counter_qa.md`.
3. Re-publish `firestore/firestore.rules` in Firebase console.
4. Re-publish Firestore rules **after** the audit added `ownerUid` to
   `sponsor_bundles` — the rules must partition by `request.auth.uid` or the
   new field is decorative.
5. Play upload of `+10` + questionnaire + publication. Human-owned.

### Boxed — hardware or account-gated, NOT open work

| Item | Blocked by | Note |
|---|---|---|
| iOS / Apple App Store release | **no Mac + $99/yr** | Windows-only dev env. Full spec + unbox checklist in `roadmap-v2.md`. |
| Firebase rules publish | **console access** | No Firebase CLI credentials in this env. |

**Both previously-hardware-blocked items are now unblocked and were partly closed
on the Moto G 2025** (`ZT4222BMWN`, USB):

| Item | Before | Now |
|---|---|---|
| GGUF path | gated OFF everywhere (`isLowEnd` true on the B160V's 2.75 GB) | **`[hardware] totalRamGb=3.56 isLowEnd=false`** against a 3.0 GB threshold — path is live. All four catalog URLs return HTTP 200. Model download itself not yet run. |
| Step counter | no sensor on the B160V | **`flutter.step_sensor_offset_v1 = 120`** in SharedPreferences — a real cumulative count off the MTK sensor. sensor → pedometer plugin → Dart → prefs is proven. Only the 500-step threshold needs a human walking. |

The honest summary: **every feature is shipped.** What remains is verification
that requires a human with a phone and a Play account.

### Deferred pet items (with reasons — do not silently drop)
- **Pet-card share**: RepaintBoundary→share_plus; low risk, unscheduled.

## 5 · Machine/environment facts (NOT visible from repo)

| Fact | Value |
|---|---|
| Ollama | `OLLAMA_HOST=0.0.0.0:11450` / Sovereign `http://192.168.4.144:8000` qwen2.5 (primary) + fallback `127.0.0.1:11450` — R24 bridge, off by default, `preferDeepChat` toggle |
| Device fleet | Blu View 5 (~3 GB → GGUF gate OFF), Moto G 2025 (4–8 GB, primary test target), Dell Latitude 5400 dev host (16 GB) |
| TF training | System Python 3.14 has no TF wheels → use `.venv-tf` (Python 3.12 via uv); see AGENTS.md command |
| Firebase | Project `recovery-for-all-c2ee8`, package `com.recoveryforall`, anonymous auth live, `community_feeds` mirror confirmed working |
| Sovereign dirs | `C:\pathfinder_god`, `C:\Sovereign Nodes`, `C:\sovereign_mantle`, `C:\sovereign_tagger_2`, `C:\sovereign_tagger_bak` — **READ-ONLY by default.** Do not modify on your own initiative. If the user asks for work there, hand them a self-contained prompt to run in that repo, or get explicit per-repo authorization first. A past session edited four of these unprompted; `git revert` then deleted 30 tracked `.opencode` files from `pathfinder_god` and its agents/plugins/tools vanished. Everything was recoverable from history, but the detour cost hours. |

## 6 · Question → document map

| Question | Answer lives in |
|---|---|
| What do I build next? | This file §7 + roadmap-v2.md |
| Economy laws / caps / exemptions? | blueprints/pet-store-rules.md |
| GGUF status, models, QA matrix? | blueprints/gguf-feasibility.md §0 |
| Pet RPG spec vs reality? | blueprints/pet-rpg-design.md §0 |
| Map/tiles/offline packs? | blueprints/tacmap-extraction.md |
| Firebase console steps? | blueprints/firebase-setup.md |
| Feed guardrails C1–C5? | pet-store-rules.md §4 (+ community_feed_service_test.dart) |
| Original MVP plan? | blueprints/SPRINT_PLAN.md (complete, historical) |
| Original vision docs? | Volume_*.md + architecture/onboarding blueprints (marked HISTORICAL VISION — superseded) |
| Full source dump? | blueprints/recovery_all_code.md (GENERATED — never hand-edit) |
| What did we learn the hard way? | blueprints/lessons-learned.md (update when we trip) |

## 7 · Next moves (current)

**UI-UX Themes Plan COMPLETE** (Rewrote `UI-UX-themes-plan.md` to ground it in existing `AppColors`/`NavigationBar` implementation based on agent critique).
**UI/UX Program Phases 0-4 COMPLETE (Sep 28)** — see `blueprints/UI-UX-themes-plan.md` "Execution Status". Phase 0 baseline, Phase 1 semantic tokens, Phase 2 six-scheme M3 engine, Phase 3 migration 875→0 raw literals, Phase 4 shared primitives: `lib/widgets/app_primitives.dart` = `AppCard` / `AppSectionHeader` / `AppLoadingState` / `AppEmptyState` / `AppActionTile` (all consume ColorScheme + AppSpacing/AppRadii/AppType). Adopted in `memory_wall_screen.dart` + 11 headers in `settings_screen.dart`; 9 tests in `test/app_primitives_test.dart`. Deliberately NOT built: button/icon-button/chip wrappers (Material + centralized component themes already cover them), AppAvatar (exists), AppMetricCard/AppHeader (no repetition) — the "no unnecessary abstraction layer" rule. Gates: analyze 0, test 198, `tools/verify_no_hardcoded_colors.py` exit 0.
**✅ RESOLVED (was the big open risk):** the dark-pinned top-level `AppColors` statics are GONE. Phase 5 replaced 390 refs across 31 files with scheme slots and deleted `bgDeep/bgCard/border/accent/success/danger/textPrimary/textMuted/textDim/textHint` from `AppColors`. `AppColors.scrim(context, [opacity])` now takes the surface from the scheme. Only brightness-INDEPENDENT domain tokens remain in `AppColors` (`mood*`, `raid*`, `star*`, `fellow*`, `pin*`, `housing*`, `starfield`, `brandZoom`, `monsterHound`, `accentSky`, `dangerSoft`, `pink`) — never drain those, they encode meaning. The color gate now ALSO fails on any reference to a retired name. Light mode is real, not partial.
**PLAN RE-SEQUENCED (Sep 28):** two dependency bugs fixed. The statics drain became a new Phase 5 (cross-cutting — draining last meant touching 31 files twice), and Empty/Loading/Error moved to Phase 6 (ahead of dashboard decomposition) because Phase 4 primitives now make those states mechanical. Current order: 5 drain → 6 states → 7 dashboard state → 8 dashboard views → 9 nav → 10 SOS → 11 profile → 12 a11y → 13 responsive → 14 motion → 15 visual → 16 hardening → 17 final. Rationale recorded in the plan.
**Phase 6 (states) COMPLETE:** `app_primitives.dart` now has 7 primitives — added `AppErrorState` (retryable, non-blaming copy) and `AppOfflineState` (distinct from error: cached data is still on screen, copy says so). Adopted in `journal_screen` (empty), `constellation_screen` (empty + loading), `meeting_map_screen` (load failure → `AppErrorState` with real retry). `MeetingFinderService.isCacheStale()` added (missing or >24h `cacheTtl`) so stale network data can surface as an offline affordance instead of looking fresh. 3 new tests.
**Phase 7 (dashboard state) COMPLETE:** `lib/core/dashboard_providers.dart` now holds 5 notifiers — `DashboardLayoutNotifier` (order + hidden sets, owns the `_ordered` merge), `MeetingRadiusNotifier`, `DailyPledgeNotifier`, `SkyNameNotifier`, and `DashboardDataNotifier` (profile + pet + raid with explicit load order). `_DashboardScreenState` went from 22 mutable fields to **3** (`_editingPath`, `_editingLibrary` ephemeral; `_selectedIndex` nav) + `_skyNodes` (pure view model). File 1551 → 1449 lines. `DashboardScreen` is `ConsumerStatefulWidget`. 18 tests.
**Phase 8 (dashboard views) COMPLETE — four committed slices.** The view
vocabulary was extracted out of `dashboard_screen.dart` while state stayed in
`dashboard_providers.dart`. File 1512 → 1157 lines; it is now almost entirely
callbacks, navigation, and two tab bodies. New files: `lib/widgets/dashboard_cards.dart`
(`PledgeCard`, `ToolCard`, `SosTile`, `SupportLinkRow`) and
`lib/widgets/dashboard_sections.dart` (`PathChips`, `MeetingSpotlight`,
`ToolGrid`, `SkyCrown`, `CompanionSection`). Every one of them is
presentational — plain values in, callbacks out, no Riverpod or DB reads — so
all are renderable in tests without a provider scope. 28 new tests.
**🐛 THREE REAL DEFECTS, all found by tests rather than review:**
1. `ToolCard` overflowed its grid cell at EVERY text scale — 6px at 1.0, 34px
   at 1.5, 61px at 2.0 — because the toolbox `GridView` pins a fixed
   `childAspectRatio: 1.35`. Fixed with `Flexible` + `FittedBox(scaleDown)`
   around the copy block, a no-op at 1.0. Guarded by tests at all three
   scales. Do not revert.
2. The meeting card LIED while loading: the `FutureBuilder` used
   `snapshot.data ?? const []`, so a still-reading cache rendered "No
   meetings in the next 6 hours" — telling a user in a meeting-dense area
   that nothing was happening. `MeetingSpotlight` now separates waiting /
   error / genuinely-empty. This closed the last open Phase 6 gap.
3. Hiding every toolbox tool collapsed the grid to zero height with no
   explanation and no way back. `ToolGrid` now says that hiding is not
   deleting and offers "Restore all".
**⚠ Deliberately NOT done in Phase 8:** the two-tab Path/Library IA. Moving
to four destinations is Phase 9's job; Phase 8 added and moved nothing.
**🐛 BUG FIXED (was latent, boot-critical):** `databaseProvider` lazily built a SECOND `RecoveryDatabase` — a second SQLCipher connection to the same encrypted file with its own key read — while `main.dart` built its own; 6 providers watched it. `main.dart` now does `overrides: [databaseProvider.overrideWithValue(database)]` so everything shares one instance. If you ever add a provider that watches the DB, verify the override is still in place.
**Next: the UI/UX program is DONE. Nothing in Phases 0-17 is outstanding.**
Read the **"Resume Here"** block at the top of
`blueprints/UI-UX-themes-plan.md` — it carries the final gate results, the one
caveat about the last test run, and the API notes worth keeping.

Phase 10 is mostly an AUDIT, not a rewrite. SOS is already the strongest
surface in the app: `SosTile` is the only tile implementation, `_showSosSheet`
is the only entry point, and `tools/verify_invariants.py` fails on a duplicate
of either. Audit FAB placement, labels, contrast, dismissal, accidental
activation, and screen-reader semantics. **Do not build a second SOS surface** -
the gate will fail and Phase 10 forbids it.

### Session-boundary state (Oct 2026 — closed-test tester bug round, after Phase 17 + device verification)

- **NEW: builds are PRE-AUTHORIZED.** The user granted standing permission for
  `flutter build apk --debug` and `flutter build appbundle --release` (signed,
  via `android/key.properties` + `upload-keystore.jks`). `AGENTS.md` §5 was
  rewritten to say so. Do not re-ask for build authorization. Builds still happen
  only in the end-of-plan batch.
- **FOUR tester-reported bugs fixed in one pass.** All were *wiring / value*
  bugs — `flutter analyze` was clean and could not see any of them:
  1. **Constellation zoom slid instead of zooming.** Root cause: two owners.
     `_ConstellationScreenState._zoom` (parent) and
     `_ConstellationCanvasState._zoomController` (child) never communicated. The
     slider wrote to the child's `AnimationController.value` and lived *outside*
     the `AnimatedBuilder` that repainted the canvas, so the thumb and the stars
     rendered from different values; `onZoomChanged` was never called, so the
     parent stayed at 1.0. Fix: zoom is now a plain `double` in state written
     only through `_setZoom()`, with the parent notified on gesture **end**
     (not every frame). The `AnimationController` was never animated, so its
     200 ms duration was dead code and is gone.
  2. **"In progress now" card showed statewide meetings during a 2-mile search.**
     Root cause: `_radiusMi` was a plain field on `MeetingMapScreen` — never
     persisted, invisible to the dashboard. The dashboard therefore invented its
     own 25/50/100 km tiers in `applyRadiusTiers`, and the fall-through branch
     returned the **entire** input list when nothing was nearby. "It shows all the
     meetings" was literally the code. Fix: radius is now persisted shared state
     (`radiusMiles` on `MeetingRadiusState`, new pref
     `meeting_search_radius_miles_v1`, written via `setRadiusMiles`, read by both
     surfaces). `applyRadiusTiers` filters to the real radius and returns an
     **empty** list plus a "widen the radius" hint instead of silently widening
     itself. `MeetingMapScreen` is now a `ConsumerStatefulWidget`.
  3. **Meeting map rotated while zooming.** Root cause: `MapOptions` declared no
     `interactionOptions`, so flutter_map's default `InteractiveFlag.all` left
     the two-finger twist gesture live; on a phone it competes with pinch-zoom.
     The pre-existing `_mapController.rotate(0)` only fired from a button and
     could not keep up with a live gesture. Fix: explicit
     `InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
     cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled())`.
     NOTE `CursorKeyboardRotationOptions.disabled()` is **not** a const ctor —
     using `const` on that `InteractionOptions` fails analyze.
  4. **Bottom-nav order.** `DashboardDestination` enum reordered to
     `path, companion, library, profile`. Safe because nothing hardcodes an index
     (verified by grep before editing); every consumer iterates `.values`. This
     also makes the back target the FIRST destination, which is now pinned by a
     test.
- **Three tests were encoding the OLD behavior and had to be rewritten, not just
  updated.** `applyRadiusTiers cascades Nearby Regional Wider Area Statewide`
  asserted the exact tier cascade that was removed, and its companion asserted
  that the empty-radius case returns the whole list with a "Statewide — No local
  meetings" label — i.e. the tests **pinned the bug as the contract**. Replaced
  with 5 tests for the real contract (honours the radius, returns EMPTY,
  2 mi is the default, drops no-coord meetings, clamps input). The nav test's
  expected order was updated and a "back target is FIRST" test added.
- **fastlane scaffolding added** (`fastlane/Appfile`, `fastlane/Fastfile`) with
  lanes: `status`, `validate`, `upload`, `promote`, `set_rollout`,
  `promote_to_production`, `promote_to_closed`, `complete_rollout`, `halt_rollout`.
  **No `build` lane on purpose** — a `buildAppbundle` lane would silently turn
  `fastlane promote` into a release build and violate the build boundary.
  Service-account JSON is gitignored. **fastlane does not run on Windows** —
  WSL2 or a CI `ubuntu` runner only.
- **Release AAB built and verified**: `build/app/outputs/bundle/release/
  recovery-for-all-1.0.0+9.aab` (129.1 MB, from `app-release.aab`). Signature
  confirmed via `keytool` — `CN=Glenn Lee Clark IV, OU=Recovery For All,
  O=Recovery, L=Saint Paul, ST=Minnesota`, self-signed, valid to 2054, and
  `META-INF/UPLOAD.RSA` present. This is the **upload** key, not the Play App
  Signing key — back that up separately.
- **The `build/` tree was deleted at some point**, so the previously-referenced
  "stale" `recovery-for-all-1.0.0+9.aab` did not exist. Anything remembered
  about artifacts in `build/` must be re-verified before being trusted; it is
  gitignored and was never in the repo.
- **Flutter is NOT on PATH on this host.** The SDK is at `C:\android\flutter\bin`
  and is exposed only as the env var `flutter`. Prepend it in any shell that
  needs the toolchain: `$env:PATH = "C:\android\flutter\bin;" + $env:PATH`.
- Gates after this round: `flutter analyze` -> No issues found; `flutter test` ->
  **300 passing** (now **511**); `verify_no_hardcoded_colors.py` -> exit 0;
  `verify_invariants.py` -> exit 0 (**11** invariants; was 7 at the time — 8 is
  the pet-state single owner, 9 the paired-foreground colour role, 10 the
  constellation `Stack` child order, 11 Firestore-rule ownership);
  `selftest_invariant7.py` -> 10/10.

### Earlier session-boundary state (Sep 30, after Phase 17 + FIRST device verification)

- UI/UX Phases **0-17 complete**. No phase outstanding.
- Final gates: `flutter analyze --no-pub` -> No issues found; `flutter test` ->
  292 passing; `verify_no_hardcoded_colors.py` -> exit 0;
  `verify_invariants.py` -> exit 0 (now 7 invariants — the seventh is
  missing-brace interpolation, added Sep 30 after device testing found the app
  bar shipping `"Welcome, DashboardScree…"` because of `$ref.watch(...)` with no
  braces).
- **Honest caveat, now RESOLVED:** the final gate run caught a real defect that
  the earlier "13/13 passed" claim had hidden. All 12 tree-walking assertions in
  `test/accessibility_contracts_test.dart` were reading the semantics tree off
  the **wrong `PipelineOwner`**, so they threw on a null owner while the widgets
  and labels were perfectly correct. Both obvious accessors are wrong:
  `binding.rootPipelineOwner.semanticsOwner` is **null** in a widget test (each
  `View` hangs its own `PipelineOwner` off the root, and that is the one holding
  the `SemanticsOwner`), and `binding.pipelineOwner` is a *separate legacy
  instance*, not an alias — it merely happens to work. Correct expression, from
  `flutter_test/lib/src/finders.dart`:
  `tester.binding.renderViews`' `owner!.semanticsOwner!.rootSemanticsNode!`.
  Fixed, and the full suite now runs **292 passing, analyze clean**. Lesson
  recorded as L20 — and the meta-lesson is that "the file passed 13/13" was
  never independently re-verified after the accessor was changed.
- **🔴 FIRST HARDWARE RUN — LG B160V, Android 14 / SDK 34, arm64-v8a, 2.75 GB
  RAM, 411x921 dp.** This closes the biggest open risk in the program. The user
  granted a one-off exception to the build boundary to produce a debug APK and
  install it (commit `1ff936fb1d1`, `versionCode 9` confirmed on device).
  - **`isLowEnd` branch exercised for the first time on real hardware.**
    `[hardware] totalRamGb=2.75 isLowEnd=true`, matching the 3.0 GB threshold
    exactly as designed. The Lottie underlays are correctly absent from the
    avatar. This is the `isLowEnd` path that had only ever run on the host.
  - **Light mode verified on a real screen** — Settings and the Path dashboard
    both fully legible. The audit's worst bug class (screens invisible in light
    mode) is confirmed fixed. This is the check the compiler cannot do.
  - **🐛 NEW REAL BUG FOUND ON DEVICE, at 2.0x system text scale:** the
    empty-state `SkyCrown` rendered the centred prompt "Plant your first star —
    name your sky" wrapping to two lines, and the bottom-left sky name painted
    straight through it. Root cause: two independent `Stack` children inside a
    fixed `height: 150` box, so neither knows the other exists — and **no
    `RenderFlex` ever overflowed**, so the 3x2x4x3 matrix test was green and
    could not have caught it. Fixed by not rendering the bottom-left name until
    there are stars (mirroring the existing `if (hasStars)` on the star count);
    the dashboard passes the *fallback* name, so it was never empty. Regression
    tests added that assert the **rendered outcome** (mutually exclusive copy,
    rect containment) rather than the absence of an exception. Lesson: L22.
  - **🔴 SECOND REAL BUG, and the worst one in the program: the app bar read
    "Welcome, DashboardScree…".** Root cause was one missing pair of braces in
    `dashboard_screen.dart`:
    `Text('Welcome, $ref.watch(dashboardDataProvider).username')`. Dart
    interpolates only the identifier `ref`, so `.watch(...)` and `.username`
    were **literal text** and the provider was never consulted. It is the most
    visible string in the app and it survived a 292-test suite, a 3x2x4x3 theme
    matrix, and the whole UI/UX program, because `flutter analyze` is **clean**
    on valid Dart that is simply not the string anyone meant. Fixed with
    `${...}`; verified on device — the title now reads **"Welcome, Anonymous"**,
    the real value of the profile's alias field. Added **invariant 7** to
    `tools/verify_invariants.py` to fail the build on `$identifier.` followed by
    a method call inside any string literal in `lib/`, with
    `tools/selftest_invariant7.py` proving the pattern catches the bug shape
    while leaving `'$title. $subtitle'`, `'$modelId.gguf'` and `'$tablePrefix.'`
    alone. Recorded as L23.
  - **I got this one wrong first.** I reported the title as "stale data typed on
    this device in September". It was not: a **clean install reproduced it**,
    which disproved the theory. One `grep` for `\$ref\.` across `lib/` would
    have found it in seconds. Lesson recorded in L23 — a conclusion resting on
    "this device is weird" must be tested by removing the weirdness, not argued
    for.
  - **NOT a bug:** nothing else found on the Moto G. The full second install
    path is clean: `versionCode 9`, onboarding renders, "Step 6 of 7" indicator
    visible, toolbox/meeting cards render, no crash in logcat.
- **⚠️ DEVICE LEFT DIRTY — MUST BE RESTORED:** system `font_scale` was set to
  **2.0** on the B160V during testing and has been **restored to 1.0**. Screenshot
  files have been removed from `/sdcard` on both devices. The Moto G
  (192.168.4.202:40809, WiFi) has since dropped offline — reconnect with
  `adb connect 192.168.4.202:40809`.
- ~~The `+9` release AAB in `build/` predates all of this and is stale. Do not
  upload it. The only binary built so far is a **debug** APK.~~
  **SUPERSEDED (Oct 2026):** the `build/` tree had been deleted, so there was no
  AAB at all. A **fresh signed release AAB was then built after the four
  tester-bug fixes** — `build/app/outputs/bundle/release/
  recovery-for-all-1.0.0+9.aab` (129.1 MB), signature verified with `keytool`
  (`CN=Glenn Lee Clark IV, OU=Recovery For All`, valid to 2054,
  `META-INF/UPLOAD.RSA` present). That one is current and safe to upload.
  Note `build/` is gitignored, so re-verify the file exists before referencing it.
- **🟢 DEVICE VERIFIED (Oct round, LG B160V, versionCode 9, debug APK, font_scale
  1.0, fresh install).** All four Oct tester fixes confirmed on real hardware:
  1. **Nav order** — Path · Companion · Library · Profile, Path leading.
  2. **Meeting radius** — Meeting Finder header reads **"198 meetings · 2 mi"**,
     and the dashboard "In Progress Now" card shows **one** meeting 2.0 mi away
     with a real St. Paul address. It no longer lists statewide meetings during
     a 2-mile search. Radius survives navigation.
  3. **Map rotation** — map renders north-up and **stays** north-up after touch
     interaction; clustering and the "6 live · 198 shown" chip render correctly.
  4. **Title** — "Welcome, Anonymous" still correct.
  - **Constellation zoom: NOW device-verified, and the verification found a REAL
    REMAINING DEFECT — see §7a. Read that before touching the zoom code.**
    Getting a star onto the sky is the key that was missing: the empty-sky state
    has a **"Begin My Path"** `FilledButton` that writes a `milestone` star
    directly (`constellation_screen.dart:448`), and the **"Add Star"** FAB opens
    the manual dialog (title, hint, 0/40 counter, all six category chips). Both
    were confirmed on device. Note that mood check-ins do **not** create stars —
    they only award sparks and bond; stars come from walks (500 pedometer steps),
    12-Step progress, trial wins, and goals. That is correct, not a bug.
- **Incidentally verified while walking the flow:** Companion destination
  (pet card, dresser, Trials) — first hardware check of that destination;
  Library destination (6 tiles) — first hardware check; Avatar dresser renders
  with Soft Glow equipped; Kin Remembers memory wall empty state; splash
  resolves in ~12 s and **persists state across relaunch** (sparks/bond kept);
  the pedometer permission prompt fires on the Walk **gesture**, never at boot
  (R24 fix confirmed); walk dialog shows 0/500 on a fresh install with Finish
  correctly disabled (sensor-offset baseline fix confirmed).
- **🟢 SOS sheet — device-verified.** Opens from the Path-tab `SOS Help` FAB at
  measured bounds (447,1304,692,1402). Sheet contents, all four actions present:
  "You are not alone. / Immediate support, one tap away.", **Call 988** (Suicide
  & Crisis Lifeline · 24/7), **Call Sponsor** — correctly *disabled*
  (`clickable=false`) because no sponsor is set, **Nearest Meetings** (three
  rooms close to you), **Crisis Resources** (988lifeline.org), plus My Support
  Circle and Close. One SOS surface, as the invariant requires.
- **🟢 All three palettes — device-verified** (Profile → Appearance; measured
  chip bounds, Dark mode active): **Midnight Slate** (blue on near-black),
  **Deep Forest** (green accents on dark green — screenshot confirmed the whole
  screen re-tints, including SOS red and the switch), **OLED Pitch** (true
  `#000000` background, confirmed pure black on device). The
  `midnightSlate`/`oledPitch` light-mode accent limitation still stands and is
  unchanged.
- **Still unverified on hardware:** the 3D-constellation view. The onboarding
  flow was **completed on the device by hand** (it could not be walked blind —
  see the technique note below), and the result is a working profile; steps 1
  and 4 of 7 were seen rendering correctly, but 2-3 and 5-7 were not
  independently observed.
- **Device-verification technique that matters (see L25/L26/L27):** the
  constellation screen returns **zero** `uiautomator` nodes — its 4 s twinkle
  `AnimationController` never lets the window idle — so slider geometry there
  must be read off a *native-resolution* screencap. Onboarding likewise returns
  nodes with **empty labels**, so its CTA cannot be found by text either. Every
  tap must be preceded by a foreground assertion; a bare `back` can walk out of
  the app entirely and the next tap lands on whatever is behind it. And do not
  reuse a measured coordinate across layouts: **the empty-sky state replaces the
  whole body, so there is no legend and no zoom slider until a star exists** —
  six track taps against the empty state changed nothing and produced six
  byte-identical screenshots.
- Device left clean: `font_scale` confirmed 1.0, all `/sdcard` screenshots
  removed.

### 7a · FIXED: constellation zoom no longer strands stars

Found by hardware verification on Oct 30, 2026 — **not** caught by any test — and
fixed the same day. **Option 2 of the three candidates** (real pan + size
scaling) was chosen, because it is the only one where the control means what it
says.

**What was wrong.** The painter scaled star *position* about the canvas centre
by `zoom`, never scaled star *size*, and there was no pan gesture at all:

- `px = cx + node.x * size.width * 0.45 * zoom` — position only
- `starSize = 6.0 * focusScale` — **size ignored `zoom` entirely**
- `onScaleUpdate` read `details.scale` only, never `details.focalPoint`

So a star even slightly off-centre left the screen by about 2.5x with no gesture
that could bring it back, and `_maxZoom = 10.0` was unreachable for any
constellation with off-centre nodes. Note the earlier fix in `5f0ec393fcc` was
itself correct — it made the thumb and the canvas share one `_zoom` — but
sharing the value did not make the *semantics* right.

**The fix, in `lib/core/constellation_geometry.dart` (new) plus
`constellation_screen.dart`:**
- All the layout maths now lives in one module, so the painter, the tap
  hit-test and the tests cannot disagree — the painter and the hit-test used to
  compute star positions independently, which is how they drifted apart in the
  first place.
- `skyStarScale(zoom)` — star radius grows sub-linearly with zoom. Linear would
  be wrong: the range is 1x-10x, so a star would end up wider than the phone.
- `clampSkyPan(...)` — **the invariant that matters.** When the zoomed sky fits
  the canvas the pan is discarded and it is centred. When it is too big to fit,
  the pan is clamped to exactly the range that can bring either edge of the sky
  to the opposite edge of the canvas. Every star is therefore *reachable by
  construction*: you may not see them all at once, but none can be lost.
  Applied inside `paint`, so no caller can strand the sky.
- `gesturePan(...)` — one handler for pinch and one-finger drag, so a pinch
  zooms **about the fingers** and a drag pans. The grabbed point stays under the
  fingertip.
- `shouldRepaint` now includes `pan`; without it, panning repaints nothing and
  the sky appears frozen under the user's finger.
- The tap hit radius tracks the drawn star size, so a zoomed-in star stays easy
  to tap.

**Verified:** `test/constellation_geometry_test.dart`, 180 tests — the
reachability invariant across 3 canvas sizes (incl. a 320x568) x 3 node sets x
19 zoom levels, plus `clampSkyPan` idempotence, degenerate inputs, and the
focal-anchored pinch. Full suite **480 passing** at that point (now **511**),
`flutter analyze` clean, both Python gates exit 0.

**The new test caught a real bug in my own first attempt:** `gesturePan` was
missing a `basePan * k` term, which double-counted any pan already in effect and
made the grabbed star slide out from under the finger. Two earlier drafts of the
test were also wrong before that — one asserted that *some node* is on screen
(unknowable when the sky is larger than the canvas) and one "grabbed" empty sky
without ever placing a star under the finger. See L28.

**🟢 Now device-verified too.** Re-installed the debug APK on the B160V and ran
the decisive A/B — the *same* track tap at `x=438, y=1524` that lost the star on
the pre-fix build:

| | pre-fix | post-fix |
|---|---|---|
| the seeded star | **absent from the canvas** | **present, centred at (360, 917)** |
| star size | unchanged | visibly larger, wider glow |
| slider | thumb moves, star does not follow | thumb and star agree, reversibly |

Screenshot sizes confirm it is reversible rather than a one-way drift: low zoom
59947 bytes → high 63342/63410 → low 59947 again.

### 🐛🐛 Two more real defects, found by the same hardware pass

**1. The zoom slider was underneath the Add Star FAB — its right third was
untappable.** `Positioned(bottom: 12)` put the slider row across the bottom of
the canvas, and the extended FAB occupies roughly 16..72dp from the bottom
across the right half of the screen. About 30% of the track was covered: a tap
meant to zoom **opened the Add Star dialog instead**. Nothing overflowed, so the
3x2x4x3 theme matrix could not see it. Fixed to `bottom: 84`, which clears the
FAB for any FAB width rather than for today's label. Pinned by
`test/constellation_controls_layout_test.dart`, which asserts the non-overlap
**and** that the old inset *did* overlap, so the guard cannot go vacuous.

**2. The 3D view emitted no semantics at all.** It is drawn entirely with
`canvas.drawCircle`/`TextPainter`, which produce nothing for a screen reader, so
a blind user got an unlabelled region where the star list used to be — the same
class of bug as the Wellness Check-In. It now carries an explicit label with the
star count and the gesture ("3D constellation view. 7 stars. Drag to rotate."),
wrapped in `ExcludeSemantics` so the per-star titles are not announced twice.
Its star cores also used `Colors.white`, a raw literal the colour gate permits
only in the token file; that is now `colorScheme.onSurface`.
`test/constellation_layout_test.dart` — 8 tests.

### 🟢 Pan is now device-verified, and so is the 3D view

Seeding **six** stars in one category makes the sky genuinely wider than the
canvas at high zoom (phyllotaxis radii reach `0.42*sqrt(6)/sqrt(7)` = 0.398,
and `0.398 * kSkySpread * zoom` passes 1.0 at about zoom 5.6). With one star
the sky always *fits*, so `clampSkyPan` centres it and panning is a correct
no-op — which is why the earlier single-star pass could not have tested pan.

With seven stars on `versionCode 10`:

| check | result |
|---|---|
| slider reachable off the FAB | low 105140 → high 70466 → low 105140 bytes; thumb visibly clear of the FAB |
| pan moves the sky | 70544 → 82531 (left) → 70431 (right) → 82505 (left again) — all four distinct |
| pan brings stars back | a star off-canvas at high zoom is at (306, 917) after one drag left |
| low zoom re-centres | all 7 stars back and centred; `clampSkyPan` discards the pan when the sky fits |
| 3D view rotates | 66598 → 61713 → 66738 bytes across two drags, and returns to its original view |

The 26-byte differences between "identical" states are the 4 s twinkle
animation caught mid-phase, not state — see L30.

### 🧹 The device-pass trap that cost three runs — read this before scripting

Three consecutive device runs produced **false conclusions**, and the cause is
worth more than any of the fixes above.

The sequence went: the FAB/slider overlap was discovered → fixed in source →
two verification scripts were written and run. Both "confirmed" that the slider
still did not work, because low-zoom and high-zoom screenshots came back
**byte-identical**. That was read as "the fix did not work."

It had. **The installed APK predated the fix.** The taps landed in empty space
because the slider had moved and the APK had not, so nothing happened — and
"nothing happened" and "the control is broken" produce the *same* screenshot
evidence. It took a third run, against a freshly installed `versionCode 10`
build, for the slider to move at all.

The rules that come out of it, all enforced in `verify_final.py`:
- **Byte equality is not a diagnosis.** Before concluding a control is broken,
  confirm the *control moved*. For a slider that means reading the thumb
  position out of the frame; for a FAB it means checking that no dialog opened.
  A tap that opens a dialog and a tap that hits nothing are indistinguishable
  by screenshot size alone.
- **A device script must assert its own precondition** — which build is
  installed, and is the versionCode the one under test. `dumpsys package | grep
  versionCode` costs nothing and would have caught this on run one.
- **Re-measure after a layout change, never reuse a coordinate.** The slider's y
  moved by 147px with the fix. Reusing the old `y=1524` is exactly the L25 trap
  in a new costume, and I walked into it while documenting L25.
- **Never leave a dialog open between runs.** The stale Add Star dialog from a
  measurement step swallowed every tap in the run after it, which is how the
  FAB overlap was found in the first place — a genuine bug discovered
  accidentally, via a mistake.

**L29:** byte-identical screenshots mean *nothing happened*, not *the control is
broken*. Confirm the control actually moved before drawing a conclusion, and
assert which build is installed.
**L30:** a 26-byte delta between two supposedly identical frames is an
animation caught mid-phase, not state. Use real geometry, not file size, when
the screen has a running `AnimationController`.

**Not yet decided** — needs a human call, do not pick one unilaterally:
1. *Fit-and-clamp* — scale positions about the constellation's own bounding-box
   centre and clamp so no node can leave the canvas. Smallest change, no new
   gesture, but "zoom" then mostly tightens the cluster.
2. *Real pan + size scaling* — track `focalPoint` for translation and make
   `starSize`/`glowSize` scale with `zoom`. The honest zoom, but it is a
   gesture-arena change next to the existing pinch and needs multi-scale
   regression tests. **← This is the one that was built. See above.**
3. *Cap `_maxZoom`* to the largest value that keeps the current spread on
   screen, and scale star size with it. Cheap, but silently reduces the range
   the UI advertises.


## 8 · End-of-session checklist (every session)

1. Update §3 "Where things stand" + §7 "Next moves" + the date line up top
2. Tick affected checklist boxes (roadmap-v2, pet/coach checklists)
3. If ANY lib/ file changed: `python tools/generate_code_package.py`
4. **Once the whole plan is done** (and not before — see the shell rule in §2):
   `flutter analyze` (zero) + `flutter test` + both Python gates
5. Commit by explicit path, message = gates status only
6. Leave the tree clean — no uncommitted work overnight
