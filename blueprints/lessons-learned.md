# Lessons Learned — The Mistake Ledger
## Purpose: never pay the same debugging tax twice.
## Format: Symptom → Root cause → Fix → **Prevention rule (the law)**.
## Update this file the moment we trip over anything. AGENTS.md points here.

---

### L1 · PowerShell 5.1 UTF-8 mojibake
- **Symptom:** emoji/·/— turned into `Ã°Å¸` garbage in shipped files.
- **Root cause:** `Get-Content | Set-Content` round-trips decode ANSI.
- **Fix:** rewrote files via tools with explicit utf-8.
- **Law:** never round-trip source through PowerShell cmdlets; use file
  tools or Python `io.open(..., encoding='utf-8', newline='\n')`.

### L2 · Haversine fed raw degrees to cos()
- **Symptom:** map radius filter silently wrong (Mpls–StP computed 11 km,
  truth 14). Old test passed because local ordering survived the error.
- **Root cause:** only dLat/dLng got `_rad()`; lat1/lat2 went into cos() raw.
- **Fix:** `_rad()` everywhere + known-distance regression tests.
- **Law:** geo math gets unit tests against real city pairs, not just
  ordering assertions.

### L3 · AnimationController default bounds 0..1 ate the zoom
- **Symptom:** constellation slider/pinch did nothing.
- **Root cause:** controller used as a 1..3 value holder without
  `unbounded`; every write clamped to 1.0.
- **Fix:** `AnimationController.unbounded`.
- **Law:** controllers that hold VALUES (not progress) must be unbounded;
  controllers holding progress need explicit Tween mapping — pick one and
  say which in a comment.

### L4 · SingleTickerProviderStateMixin with two controllers
- **Symptom:** red error screen on Constellation ("multiple tickers").
- **Root cause:** mixin contract is one ticker; we created two controllers.
- **Fix:** `TickerProviderStateMixin`.
- **Law:** >1 AnimationController in a State ⇒ TickerProviderStateMixin,
  full stop.

### L5 · Four fabricated model URLs shipped to production UI
- **Symptom:** every GGUF download failed ("try again later").
- **Root cause:** research-phase URLs never checked: one case-mismatched
  filename (HF is case-sensitive), two repos that simply don't exist.
- **Fix:** verified live via HF API; corrected; errors now surface raw.
- **Law:** NO external URL ships unverified. Data-driven resources get
  `tools/verify_resources.py` (build gate) + runtime link-health flags.

### L6 · Missing INTERNET permission in main manifest
- **Symptom:** (latent) all network dead in release builds only.
- **Root cause:** debug/profile manifests auto-inject INTERNET; main didn't.
- **Fix:** added to `android/app/src/main/AndroidManifest.xml`.
- **Law:** any permission debug uses must be declared in main unless it is
  genuinely debug-only. Test release manifests before release builds.

### L7 · Computed-but-never-stored location
- **Symptom:** "live location doesn't work" while the debug chip looked
  healthy — user pin invisible, recenter hit fallback city.
- **Root cause:** `_resolveLocation()` returned coords that were passed on
  but never written into `_currentPosition`; downstream readers saw null.
- **Fix:** store the fix at the boundary; recenter forces fresh fixes.
- **Law:** when a value drives multiple consumers, store it once at the
  boundary — don't pipe return values past the state that owns them.

### L8 · Spread operator used as a statement
- **Symptom:** 133-error syntax cascade after an edit.
- **Root cause:** wrote `if (x) ...[ ... ]` — collection spread inside a
  statement block (legal only inside collection literals).
- **Fix:** plain `if (x) { ... }` block.
- **Law:** after ANY mechanical code transformation, analyze immediately —
  never stack edits on a broken tree.

### L9 · Hardcoded LAN endpoint without checking the machine
- **Symptom:** Ollama default "fixed" to 11434; user's fleet runs
  `OLLAMA_HOST=0.0.0.0:11450` because Windows blocks 11434.
- **Root cause:** assumed the default port instead of inspecting env.
- **Fix:** checked `GetEnvironmentVariable('OLLAMA_HOST')`, set 11450 with
  an explanatory comment.
- **Law:** environment-specific values get VERIFIED on the machine before
  being changed — read the system, then edit.

### L10 · Docs promised what code didn't do
- **Symptom:** four docs claimed milestone Sparks were cap-exempt; the cap
  tapered every reward type.
- **Root cause:** spec drift during rapid feature adds; nobody re-checked
  claims against implementation.
- **Fix:** implemented exemption + economy test suite pinning the laws.
- **Law:** every economy/safety claim in docs needs a host test that fails
  if the code stops matching. Docs are contracts.

### L11 · compute() isolate vs typed objects
- **Symptom:** TSML JSON parse via compute() crashed serializing typed
  Meeting results back.
- **Root cause:** isolate message passing needs sendable types.
- **Fix:** reverted to direct parse (fast enough at ~2 MB).
- **Law:** isolates exchange primitives/maps only, or use documented
  entrypoints — verify payload serializability before reaching for compute.

### L12 · Tests that can't fail for the right reason
- **Symptom:** sortByDistance "failure" that was really my fixture giving
  three cities identical coordinates (all distances 0 → stable sort).
- **Root cause:** lazy helper defaulted shared fields across fixtures.
- **Fix:** distinct per-city coordinates + known-pair distance assertions.
- **Law:** fixtures must vary every field under test; a passing test proves
  nothing if its inputs are degenerate.

### L13 · SQLCipher native-assets experiment (historical)
- **Symptom:** libsqlite3.so missing from device builds.
- **Law:** pinned line stays (`sqlite3 ^2.9.4` + `sqlcipher_flutter_libs
  0.6.8`); sqlite3mc hooks experiment is a dead end; migration path is
  sqlite3 3.x native cipher. See RULES.md.

### L14 · TF has no Python 3.14 wheels
- **Law:** train only inside `.venv-tf` (Python 3.12 via uv). See RULES.md.

### L15 ? The ledger's own law broken by its author
- **Symptom:** two screens corrupted after a "quick" PowerShell string replace.
- **Root cause:** used Get-Content | Set-Content on UTF-8 Dart sources ?
  the exact L1 mistake, minutes after writing this ledger.
- **Fix:** restored from last clean commit; redid edits with file tools.
- **Law:** there are NO quick exceptions to L1. Not even one-line replaces.
  File tools or Python io.open, always.

### L16 · Midnight reset race skews Sparks
- **Symptom:** `getDailyStepsAsync()` returned stale `daily_steps_v1` when app was killed at midnight and reopened — milestones double-awarded before `_resetDailyStepsIfNewDay` ran.
- **Root cause:** `initialize()` called reset once, but direct `getDailyStepsAsync()` readers bypassed it.
- **Fix:** `await _resetDailyStepsIfNewDay()` at top of `getDailyStepsAsync()` (`lib/services/step_counter_service.dart:101`). Added `logWalkManualFallback` 7 Sparks capped for accessibility (wheelchair/limited mobility) vs 15 exempt when verified.
- **Law:** any "daily" counter must reset at every read boundary, not just at boot — test the midnight crossing with a fake clock.

### L17 · TFLite forceKeywordOnly evaporates on restart
- **Symptom:** low-RAM device fell back to keywords, then on next launch retried TFLite and failed again — silent flap, no user signal.
- **Root cause:** static `forceKeywordOnly` never persisted; `loadModel()` respected in-memory flag only (`lib/services/coach_tflite_intent_service.dart:33`).
- **Fix:** persist to `coach_tflite_force_keyword_v1` via `SharedPreferences`; `loadModel()` now reads prefs before deciding; `setForceKeywordOnly()` is the only writer plus `debugPrint` one-time notice; goldens harness `test/intent_goldens.jsonl` + `test/intent_goldens_test.dart` pins ≥75% keyword accuracy and encode contract `sentenceLen 64`.
- **Law:** any "fallback" flag that changes behavior must survive restart (prefs) and be observable (log/toast), plus a goldens file that fails if vocab/labels drift.

### L18 · Trusting outside AI recommendations without device evidence
- **Symptom:** Gemini recommended PowerSync for feed sync and `sqlite3mc` hooks for encryption as "2026 standard" — both would have introduced vendor lock-in + shipped-`libsqlite3.so` regression we already survived (L13).
- **Root cause:** external models hallucinate ease/currency; they haven't seen our fleet (Blu View 5 3 GB, Moto G 2025 4–8 GB) or our `AGENTS.md` hard-won gotchas.
- **Fix:** verify every external recommendation against code truth (`file:line`) + device fleet + `blueprints/Gemini_Diagnosis_Response.md` pushback matrix; reject PowerSync (no backend, alias-only) and `sqlite3mc` (contradicts L13, breaks existing encrypted DBs) with evidence; keep `sqlcipher_flutter_libs` pin until `sqlite3 3.x` native cipher.
- **Law:** outside advice is hypothesis until validated against `lib/` and fleet. Document accept/modify/reject with evidence in `Gemini_Diagnosis_Response.md` before patching.

## L14 — Layouts that clip their own content are bugs, not polish (Sep 28, 2026)

- **What happened:** Phase 8 of the UI/UX program extracted the dashboard view
  layer. A test that rendered `ToolCard` inside a grid cell sized to the real
  `childAspectRatio: 1.35` showed it overflowing at **every** text scale: 6px at
  1.0, 34px at 1.5, 61px at 2.0. The toolbox grid was already clipping on
  default text settings for longer labels. Two more defects surfaced the same
  way: the meeting card rendered "No meetings in the next 6 hours" while the
  cache was still loading (`FutureBuilder` + `snapshot.data ?? const []`), and
  hiding every tool collapsed the grid with no explanation and no way back.
- **Root cause:** visual state was only ever verified by reading code. A
  `FutureBuilder` default and a fixed `childAspectRatio` both *look* correct
  in source. Nothing asserted what the user actually sees.
- **Fix:** `Flexible` + `FittedBox(scaleDown)` around the card's copy block (a
  no-op at scale 1.0). `MeetingSpotlight` now separates waiting / error /
  empty. `ToolGrid` renders a real empty state with "Restore all".
- **Law:** **when a layout pins a size, a widget test must assert it at more
  than one text scale.** And when a widget derives "there is no data" from a
  nullable future, that is a state machine, so test waiting, error, and empty
  as three different outcomes. Deferring a state distinction to a `?? []`
  default is how a user gets told there is nothing happening when the app just
  has not looked yet.
