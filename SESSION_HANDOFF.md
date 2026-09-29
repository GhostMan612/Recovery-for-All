# SESSION_HANDOFF.md — Cold-Start Entry Point

**Last updated:** September 28, 2026 (UI/UX Program Phases 0-7 COMPLETE — Phase 7 fully decomposed dashboard state (22 fields → 3) + fixed a duplicate-SQLCipher-connection bug; analyze 0, test 219)
**Purpose:** THE first file a fresh session reads. Everything needed to
resume without losing progress. Update it at every session end.

---

## 1 · Read order for any fresh session

1. `AGENTS.md` — operating law (build boundary, commit rules, gotchas)
2. `CLAUDE.md` §1–§5 — token conservation + build boundary details
3. `RULES.md` — technical laws learned the hard way
4. **This file** — current state, environment facts, next moves
5. `blueprints/roadmap-v2.md` — feature status source of truth

## 2 · Hard rules (never violate)

- **Build boundary**: NEVER `flutter build apk|appbundle|run`. The human
  builds in Android Studio. Agent gates: `flutter pub get` →
  `flutter analyze` (**must be "No issues found"**) → `flutter test`.
- **Commits by explicit path only** (never `git add .`/`-A`). Commit
  messages report analyze/test status ONLY — never claim build success.
- **Safety pipeline order untouchable** (`chatbot_screen.dart:72`):
  guardrail → crisis keywords → GGUF → TFLite intent → skills → keyword
  fallback → unknown redirect.
- **PowerShell 5.1 corrupts UTF-8** — never round-trip source through
  `Get-Content | Set-Content`; use file tools or Python utf-8.
- **Drift schema v9** — bump `schemaVersion` + migration block +
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

- **UI/UX modernization program: Phases 0-7 COMPLETE, 8-17 not started.** The
  full phase-by-phase record, per-phase evidence, and a "Resume Here" block are
  in `blueprints/UI-UX-themes-plan.md` — read that file before starting Phase 8.
  Short version of what changed:
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
  - Suite is at **219 tests**, analyze clean.
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

1. Rebuild + smoke-test everything from rounds 1–2 (fresh GPS fix via
   recenter button, constellation slider/pinch, GGUF downloads with
   corrected URLs, journal PIN setup flow, quest card on Pet Home)
2. GGUF on-device QA matrix (`gguf-feasibility.md` §5)
3. Release (non-debug) rebuild validation of llama.cpp `.so` set
4. Re-publish `firestore/firestore.rules` in Firebase console
5. **Android debug build verified** — agent gates pass; human builds in Android Studio for device testing

### Deferred pet items (with reasons — do not silently drop)
- **Pet-card share**: RepaintBoundary→share_plus; low risk, unscheduled.

## 5 · Machine/environment facts (NOT visible from repo)

| Fact | Value |
|---|---|
| Ollama | `OLLAMA_HOST=0.0.0.0:11450` / Sovereign `http://192.168.4.144:8000` qwen2.5 (primary) + fallback `127.0.0.1:11450` — R24 bridge, off by default, `preferDeepChat` toggle |
| Device fleet | Blu View 5 (~3 GB → GGUF gate OFF), Moto G 2025 (4–8 GB, primary test target), Dell Latitude 5400 dev host (16 GB) |
| TF training | System Python 3.14 has no TF wheels → use `.venv-tf` (Python 3.12 via uv); see AGENTS.md command |
| Firebase | Project `recovery-for-all-c2ee8`, package `com.recoveryforall`, anonymous auth live, `community_feeds` mirror confirmed working |
| Sovereign dirs | `C:\pathfinder_god`, `C:\Sovereign Nodes`, `C:\sovereign_mantle`, `C:\sovereign_tagger_2`, `C:\sovereign_tagger_bak` — READ/COPY only, never modify |

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
**🐛 BUG FIXED (was latent, boot-critical):** `databaseProvider` lazily built a SECOND `RecoveryDatabase` — a second SQLCipher connection to the same encrypted file with its own key read — while `main.dart` built its own; 6 providers watched it. `main.dart` now does `overrides: [databaseProvider.overrideWithValue(database)]` so everything shares one instance. If you ever add a provider that watches the DB, verify the override is still in place.
**Next: Phase 8 slice 2 (Dashboard View Reconstruction).** Slice 1
shipped: `PledgeCard` + `ToolCard` extracted to
`lib/widgets/dashboard_cards.dart`; `dashboard_screen.dart` is
1512 -> 1409 lines; 6 new tests, 225 passing, all gates green. Remaining:
`_SosTile`, the Fellowship Handshake / 7th Tradition rows,
`AppSectionHeader` adoption, deliberate empty/error states, and a
large-text check on the tool grid. Phases 9-17 not started.
Read the **"Resume Here"** block at the top of `blueprints/UI-UX-themes-plan.md` first — it carries the standing gates and the five invariants a new session must not break.

### Session-boundary state (Sep 28)
- Working tree **clean**; gates green (analyze 0, test 219, color gate exit 0).
- **13 commits ahead of `origin/main` and NOT pushed** (Phases 0-7 + doc fixes).
  `origin/main` is still at `74b55da` (pre-Phase-0). The tree is clean, so the
  repo's "push manually once the repo is clean" precondition is now met — push
  is the one outstanding risk of ending the session, because the whole UI/UX
  program plus the database-instance fix currently exists only on this machine.
**R15 Self-Healing Tutorial System COMPLETE** (companion_guide_service.dart, overlay, validator).
**R16 Expanded Meeting Directories COMPLETE** (LifeRing/WFS/CR TSML + SMART/InTheRooms curated).
**R17 Full-App Tutorial Chatbot COMPLETE** (keyword, covers every feature).
**R18 Step-Counter Verified Walks COMPLETE** (pedometer 500/30m).
**R19 Pet Gear & Path System COMPLETE** (gearScore/pathLevel/abilitySlots).
**R20 Pet-Card Share COMPLETE** (share_plus, C1–C5).
**R21 Step-Counter QA COMPLETE** (plan in docs/qa/step_counter_qa.md).
**R22 GGUF QA COMPLETE** (plan in docs/qa/gguf_qa.md).
**SOS Layout Fix COMPLETE** (LayoutBuilder).
**R25 Recovery-Aware Notifications COMPLETE** (`gentle_reminder_service.dart` evaluatePayload + 11 tests) — Struggling→breathwork, Resting→"Kin resting", Milestone eve→reflection, Default→open-door; T1–T4 zero shame.
**R27 Predictive Next-Meeting Widget COMPLETE** (`next_meeting_card.dart` pickNext Live/Today/Empty, emerald/sky chips, View on Map) — integrated Path tab `dashboard_screen.dart:1032`.
**R24 Adaptive Model Router COMPLETE** (`gguf_model_service.dart` suggested/ensure/needsDownload + persistent `gguf_download_dismissed_v1` `chatbot_screen.dart:43`/`settings_screen.dart:119`; `chatbot_screen.dart` 300MB card; `ollama_service.dart` Sovereign `192.168.4.144:8000` fallback; `gguf_inference_service.dart` yield every 15 + 30s).
**R26 Narrative Export P1+P2 COMPLETE** (`narrative_export_service.dart` McAdams 7-day Agency/Communion/Redemption → Ollama → scripted fallback; `chronicle_share_card.dart` RepaintBoundary 3.0 `share_plus` C2) — 6 tests pass (window, averages, eventType case `battle_win` vs `battleWin`).
**Memory Wall UI COMPLETE** (`lib/screens/memory_wall_screen.dart` + `test/memory_wall_test.dart`) — "Kin Remembers" view with StreamBuilder over `watchPetEvents`, icons/colors per eventType, timestamps, Spark deltas, empty state, paginated 50; wired into PetHomeScreen AppBar.
**RPG Soft-Lock Fix COMPLETE** (`pet_trials_screen.dart:88` `Take a Breath` 0-cost +2 Focus + tutorial).
**MainActivity NPE Fix COMPLETE** (`MainActivity.kt:20` → `configureFlutterEngine`).
**R28 Pet Drift Migration COMPLETE** (`recovery_database.dart:9` v9 + `recovery_pet_service.dart` atomic txn + Drift-backed economy tests).
**R4 Constellation Auto-Stars COMPLETE (Sep 27)** (`constellation_service.dart` P0 pipeline: milestone/journal/meeting/goal/walk/battle-win stars wired into 5 screens + `logBattleWin`; P2 StreamBuilder live updates + P3 `_CategoryLegend` in `constellation_screen.dart`; P1 `constellation_canvas.dart` deleted, zero refs). NOTE: a follow-up commit (`313ce6e`) gutted the service file + P2/P3 + trials hook leaving 5 analyze errors; repaired by restoring the R4 files from `eb88f4a`, gates re-green. Lesson: never empty a file its callers still import.

Everything below is in the build you will test next: GPS cascade + chip
dialog, Trials monsters + juice + focus pips + tutorial + battle sounds,
two-tab dashboard with draggable/hideable tiles (+ Reset Layout in Settings),
**Trials breathe** + **Drift atomic** + **MainActivity launch**.

**iOS / Apple Store — 🔒 BOXED (Sep 9, 2026):** no Mac + $99/yr Apple fee;
full shelf state + unbox checklist in `blueprints/roadmap-v2.md` → "Boxed /
deferred". Play opt-in links NEVER work on iPhone (that's normal; iPhone =
Apple-only installs). NOT a bug in the app.

**NEXT UP — new fellowship (user research doc incoming):** Gemini deep-research
on community-requested fellowship(s); spec upload pending. When it lands:
meeting directories + curated MN meetings + TSML parsing + pathway tags +
onboarding/coach/literature tailors (see roadmap-v2 "Incoming").
**Agent independent research DONE (Sep 10):** `blueprints/soa-fellowship-research.md`
— headline: no "Sex Offenders Anonymous" fellowship exists (treatment is
clinical/corrections, not 12-step); real STAR is SAA/SA/SLAA/SCA (+S-Anon/COSA
for affected others). NO live JSON/TSML feed found for any S-fellowship (5
endpoint probes 404; SAA=Drupal, SA=WP map, SLAA=Teamup, SCA=TSML-UI w/ REST
off). Recommendation: SAA+SA curated MN (R16-pattern) + deep links; never ship
"SOA" label; no minors/S-Ateen; curate facilities never people; feed unchanged
(C1 alias-only, no fellowship badges); no offender-specific features. Awaiting
Gemini doc to compare (feeds? formal SOA? MN counts? SA dial-in inventory?).

1. Rebuild and smoke: Path tab **Next-Meeting Card** + Chatbot **download card** (≥3GB no .gguf → "Enable Offline AI Companion — 253MB" persist dismiss `gguf_download_dismissed_v1`); **Dismiss persists across restart** (Settings download/toggle clears); test notification copy (pet sad→grounding, resting→"Kin resting", 29-day counter→milestone eve); test R26 chronicle generation (offline fallback → 3 paragraphs) + share card (C2 no numbers/location); verify link-health footers, help icon, Walk dialog, Esri tiles, SOS; test **Memory Wall** (Pet Home → auto_awesome_outlined → Kin Remembers); test **Trials** — enter battle, burn to 1 Focus, verify `Take a Breath` appears, +2 Focus, then Strike; verify **drift** — earn Sparks, kill app mid-reward, relaunch → Sparks+event consistent.
2. **NEW since Phases 0-7 — the light/dark work has never been seen on a device.**
   Smoke both brightness modes across the top surfaces: dashboard, journal,
   constellation, meeting map, settings, SOS sheet. The 6-scheme matrix
   (3 palettes x light/dark) is proven by unit tests only. Pay attention to the
   avatar painter, the Lottie aura underlays on a light background, and any
   SnackBar that still reads as a dark slab.
3. Fix what surfaces; then **DotLottie Migration & RAM** (2 Lotties → .lottie) or **R23 Feed sync** deferred. Tool: `tools/build_llama_android.sh` (ASK-2 LTO+strip) + tok/s on Moto G.

## 8 · End-of-session checklist (every session)

1. Update §3 "Where things stand" + §7 "Next moves" + the date line up top
2. Tick affected checklist boxes (roadmap-v2, pet/coach checklists)
3. If ANY lib/ file changed: `python tools/generate_code_package.py`
4. Run gates: `flutter analyze` (zero) + `flutter test`
5. Commit by explicit path, message = gates status only
6. Leave the tree clean — no uncommitted work overnight
