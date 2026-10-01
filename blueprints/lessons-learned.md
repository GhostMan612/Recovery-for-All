# Lessons Learned — The Mistake Ledger
## Purpose: never pay the same debugging tax twice.
## Format: Symptom → Root cause → Fix → **Prevention rule (the law)**.
## Update this file the moment we trip over anything. AGENTS.md points here.

---

## L21 — The rules said "permitted", so the shell got used every 5 seconds (Sep 30, 2026)

- **What happened:** the UI/UX program's final days were spent far longer on
  round-trips than on work. The pattern was visible in the transcript: a
  `read`, then a `grep`, then a `flutter analyze` or an `adb` probe, then
  `sleep`, then another probe — every few minutes, for hours. The user's
  assessment: this plan should not have taken three days, and they should not
  have to sit at their laptop watching it. They were right.
- **Root cause — and this is the part that matters: it was not a discipline
  failure, it was a *documentation* failure.** Three separate documents
  granted unconditional permission, and only one narrow paragraph anywhere
  forbade it:
  - `AGENTS.md`'s own auto-doc workflow said *"After **every** code or
    blueprint change the agent MUST… run this sequence"* with
    `flutter analyze` and `flutter test` in the list. That is a standing order
    to shell out after every single edit.
  - `CLAUDE.md`: analyze/test "are permitted and **expected** as code-quality
    gates" — with no cadence attached, which reads as licence, not as a
    closing step.
  - `RULES.md`: "Your gates are `flutter pub get`, `flutter analyze`, and
    `flutter test`", plus "no feature is done until…" — a *per-feature* rule.
  - `blueprints/SPRINT_PLAN.md`: "Run `flutter analyze` **after each task** to
    verify." Literal instruction to do the expensive thing, per task.
  - `.opencode/agents/debugger.md`: "After proposing, run `flutter analyze` to
    verify the fix compiles." An agent instructed to verify each fix.
  Meanwhile the no-shell rule existed, but it sat *below* the permission lines
  in `SESSION_HANDOFF.md` and was phrased as an override — which is a weaker
  device than being the first thing read. Rules that must be read *around*
  other rules will eventually be read around.
- **Fix:** restructured so cadence is attached to every grant of permission,
  and so the ban is a routing table rather than an exhortation:
  - `AGENTS.md` "SHELL DISCIPLINE" is now a hard gate with an intent→tool
    table (read/grep/edit/write for working; *nothing* for "does it compile"),
    the three named traps, and the instruction that a plan needing mid-flight
    verification is a plan to *report as blocked*, not to shell out on.
  - The per-change auto-doc list and the per-plan verification list are now two
    separate sections. Docs per change; gates once.
  - `CLAUDE.md`, `RULES.md`, `CONTRIBUTING.md`, `README.md`,
    `SESSION_HANDOFF.md`, `UI-UX-themes-plan.md`, `SPRINT_PLAN.md`,
    `.opencode/commands/{verify,commit}.md` and
    `.opencode/agents/{debugger,a11y-auditor,test-runner}.md` were all swept
    and relabelled as end-of-plan.
- **The two arguments that actually closed it,** because they are the reason
  this recurred four times: (1) the analyzer **cannot see the class of bug this
  project has** — a colour-slot typo, a wrong string, two widgets colliding in
  a fixed box all pass a clean analyze; and (2) each run costs 20–90s and
  **goes stale with the very next edit**, so a mid-plan result is not just
  wasteful, it is misleading. Neither argument is about the user's preference.
- **Law:** **when a rule is repeatedly violated, suspect the rule before the
  behaviour.** Grep the whole repo for every document that touches the tool in
  question, and fix *all* of them in one pass — because a single surviving
  "permitted" line is enough to license the old habit, and a future session
  will find it and reasonably follow it. Permission and cadence must be written
  together or not at all. And put the prohibition **first**, not as an
  override of something above it.

## L22 — Two Stack children in a fixed box can collide with no error at all (Sep 30, 2026)

- **What happened:** on a real B160V at 2.0× system text scale, the empty-state
  `SkyCrown` rendered the centred prompt "Plant your first star — name your
  sky" wrapping to two lines, and the bottom-left sky name "Your Constellation"
  painted straight through it. Unmistakable on screen; the two words overlapped.
- **Root cause:** `SkyCrown` pins `height: 150` and stacks its content. With no
  stars, the centred prompt renders *and* the `Positioned` bottom-left
  `skyName` renders — two independent `Stack` children that cannot see each
  other. On the dashboard the caller passes the fallback
  (`skyName: ref.watch(skyNameProvider) ?? 'Your Constellation'`,
  `dashboard_screen.dart:944`), so the label is never empty and the collision
  always happens at large text scales.
- **The part that generalises: no `RenderFlex` ever overflowed.** A
  `RenderFlex` overflow is loud — yellow/black stripes and a thrown
  `FlutterError`. Two positioned siblings landing on the same pixels is
  *silent*. The 3×2×4×3 matrix test that already covers `SkyCrown` at 2.0× was
  **green**, because the matrix asserts on `tester.takeException()` and there is
  no exception to take. The matrix was not missing a case; it was asserting the
  wrong *kind* of thing. A device screenshot found in about a minute what the
  whole matrix could not.
- **Fix:** don't render the bottom-left name until there is a sky to name —
  `if (hasStars)`, mirroring the existing `if (hasStars)` on the star count.
  The empty state then shows only the centred prompt, and the fallback name is
  not shown to anyone as though it were real.
- **Law:** **overflow tests catch overflow, not collision.** For any
  fixed-height box with multiple children, assert the *outcome* — non-empty
  `find.text` for mutually exclusive copy, and rect-intersection checks — not
  the absence of an exception. A widget test that only asserts
  `takeException()` is decoration: it is green precisely when the two things
  you care about cannot collide.

**Corollary, and the reason this was only found late:** a green host suite is
not evidence about a *pinned box with positioned children*. Those need a
rendered check, and until a device is in hand, the honest move is to say so
rather than let "292 passing" imply coverage it does not provide.

## L23 — `$ref.watch(x).y` is valid Dart that renders a literal (Sep 30, 2026)

- **What shipped:** the app bar on the dashboard read
  **"Welcome, DashboardScree…"** — truncated, and lengthening as the user
  raised the text scale. It reached the B160V, a clean install on a Moto G, and
  every screenshot taken in between.
- **Root cause:** one missing pair of braces.
  ```dart
  Text('Welcome, $ref.watch(dashboardDataProvider).username')
  ```
  Dart's `$identifier` interpolation substitutes **only the identifier**. The
  `.watch(dashboardDataProvider).username` after it is ordinary literal text, so
  the title rendered as
  `"Welcome, " + ref.toString() + ".watch(dashboardDataProvider).username"`.
  `ref` is the Riverpod `WidgetRef`, whose `toString` is the enclosing widget —
  hence "DashboardScreen…", and hence the truncation growing from
  "DashboardScree…" at 1.0x to "Dashboar…" at 2.0x. The provider was **never
  consulted**; the title could not have shown the user's name at any point.
- **Why nothing caught it, which is the entire point:**
  - `flutter analyze` was **clean**. It is valid Dart — just not the string
    anyone meant. The analyzer checks types and syntax, never intent.
  - The colour gate never reads strings. The invariant gate never read
    strings. Both were structurally incapable of it.
  - No test asserted the app bar title.
  - It is the single most visible piece of text in the app, and it survived a
    292-test suite, a 3x2x4x3 theme matrix, and an entire UI/UX program.
- **The reasoning trap, worth naming:** I first reported this as *stale data on
  that device* — someone had typed "DashboardScreen" into the onboarding alias
  field. The evidence for that was plausible (only one write site for the
  field, and it feeds straight from a text box). It was **wrong**, and the thing
  that disproved it was a clean install reproducing it. **A conclusion that
  depends on "this device is weird" must be tested by removing the weirdness,
  not argued for.** One grep — `$ref.` across `lib/` — would have found it in
  seconds; I had grep available and reached for a story instead.
- **Fix:** `'Welcome, ${ref.watch(dashboardDataProvider).username}'`.
- **Fix, structurally:** invariant 7 in `tools/verify_invariants.py` now fails
  the build on `$identifier.` inside any string literal in `lib/`, because that
  pattern is a missing brace essentially always.
- **Law:** **a gate that only covers what you already know will keep passing
  while the app is visibly wrong.** When a real user-visible bug appears, ask
  what class it belongs to, and if nothing enforces that class, add the
  enforcement before moving on. And when something looks like bad data, try
  reproducing it clean before concluding — "the device is weird" is a hypothesis,
  not a finding.

---

## L24 — Two zoom states that never talk: the slider moves, the sky slides (Oct 2026)

- **What testers reported:** dragging the constellation zoom slider "slid the
  stars to the right" instead of zooming. Separately, the dashboard's **"In
  progress now"** card showed meetings from across Minnesota during a 2-mile
  search, and the meeting map rotated when the user only meant to zoom.
- **Root cause 1 — the constellation had two owners.** The parent
  (`_ConstellationScreenState._zoom`) and the child
  (`_ConstellationCanvasState._zoomController`) each held a zoom. The slider wrote
  to the child's `AnimationController.value`, which (a) lived **outside** the
  `AnimatedBuilder` that repainted the canvas, so the thumb and the stars were
  rendered from two different values, and (b) never called `onZoomChanged`, so
  the parent's `_zoom` stayed at 1.0 forever. The `AnimationController` was also
  never *animated* — its 200 ms duration was dead weight on a value that was only
  ever assigned. Net effect: stars scaled about a fixed centre while the control
  moved independently, which reads as panning.
- **Root cause 2 — the radius was a screen-local field.** `_radiusMi` lived on
  `MeetingMapScreen`, was never persisted, and was invisible to the dashboard.
  The dashboard therefore invented its own 25/50/100 km tiers in
  `applyRadiusTiers`, and its fall-through branch returned the **entire** input
  list when nothing was nearby. So the card either ignored the requested radius
  or, worse, showed everything. "It shows all the meetings" was literally the
  code.
- **Root cause 3 — flutter_map rotates by default.** `MapOptions` declared no
  `interactionOptions`, so the default `InteractiveFlag.all` left the two-finger
  twist gesture enabled. On a phone that gesture competes with pinch-zoom, so a
  zoom that drifted sideways became a rotation. A `_mapController.rotate(0)` call
  existed but only fired from a manual button, so it could not keep up with a
  live gesture.
- **Why no gate caught any of it:** all three are *wiring and value* bugs, not
  type errors. `flutter analyze` was clean. The colour and invariant gates read
  neither widget state nor gesture flags. This is the **same** shape as L23 —
  the analyzer can only see types, and every real bug in this repo has been
  above the type level.
- **Fixes, and the pattern behind them:** one owner per value.
  - Constellation: zoom is now a plain `double` in state, written only through
    `_setZoom()`, which repaints canvas and slider together and notifies the
    parent on gesture *end* (not every frame).
  - Radius: promoted to persisted shared state — `radiusMiles` on
    `MeetingRadiusState`, written via `setRadiusMiles`, read by both the map
    slider and the dashboard. `applyRadiusTiers` now filters to the actual
    requested radius and returns an **empty** list plus a "widen the radius"
    hint instead of silently falling back to statewide.
  - Map: explicit `interactionOptions` with
    `flags: InteractiveFlag.all & ~InteractiveFlag.rotate` and
    `CursorKeyboardRotationOptions.disabled()`.
- **Law:** **before adding a second copy of a value, ask who owns the first.**
  Two `State` objects in a parent/child pair, or a widget field standing in for a
  user preference, is the defect — not the missing sync code you'd add to patch
  it. And a fallback branch that returns *everything* when a filter finds
  nothing is never a fallback; it is a bug that hides behind a success state.
  For gesture flags, always set them explicitly: library defaults are chosen for
  the general case, not yours.

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

## L19 — A curated `Semantics` label is CONCATENATED with the child's own text (Sep 30, 2026)

- **What happened:** Phase 12 of the UI/UX program added semantics coverage for
  the dashboard. Dumping the real semantics tree (rather than trusting
  `find.bySemanticsLabel`) showed `ToolCard`'s node label as
  `"Meeting Finder. Live and upcoming\nMeeting Finder\nLive and upcoming"`, and
  `SosTile` producing a curated node *plus* a redundant child node with the
  same words. Every SOS destination and every tool card was being announced
  **twice** by a screen reader.
- **Root cause:** `Semantics(label: ...)` annotates rather than replaces. The
  child `Text` widgets keep their own nodes, and the label is merged with them
  unless the wrapper sets `excludeSemantics: true`. It reads like a rename and
  behaves like an append.
- **Fix:** `excludeSemantics: true` on `SosTile`, `ToolCard`,
  `SupportLinkRow` and `SkyCrown` — each of which now repeats `onTap` on the
  wrapper, because excluding the child also drops its action and a button with
  a role but no action is worse than no button at all.
- **The trap, and the law:** `CompanionSection` was deliberately NOT changed.
  Its subtree contains `RecoveryPetCard`, which holds an `InkWell` plus two
  real buttons (check in, walk). Excluding those semantics would make daily
  care actions **unreachable**. It keeps a duplicated announcement instead.
- **Law:** **when you add `excludeSemantics: true`, you must re-supply every
  action, label, and state the child was carrying — and never apply it to a
  subtree that contains interactive controls.** A duplicated announcement is an
  annoyance; an unreachable action is a safety regression. Prefer the lesser
  defect, and pin the decision with a test so nobody "fixes" it backwards.

## L20 — `find.bySemanticsLabel` does not read the semantics tree (Sep 30, 2026)

- **What happened:** every `bySemanticsLabel` assertion in the new Phase 12
  tests found **zero** widgets, even though a tree dump proved a node with
  exactly that label existed. Nine tests failed for a reason that had nothing
  to do with the widgets under test.
- **Root cause:** the finder inspects
  `element.renderObject.debugSemantics` — the config on a *render object* —
  not the assembled `SemanticsNode` tree. When an annotation is merged into a
  child node (see L19), the render object's own `debugSemantics` is not the
  label a screen reader receives. The two are genuinely different things, and
  only the second is the user-facing truth.
- **Fix:** walk the tree instead, the way `flutter_test` does internally
  (`finders.dart`):
  `tester.binding.renderViews`' `owner!.semanticsOwner!.rootSemanticsNode!`,
  then recurse over `visitChildren` and match on `node.label`. **Getting the
  owner right is the whole trap**, and the two obvious answers are both wrong:
  - `binding.rootPipelineOwner.semanticsOwner` is **null** in a widget test.
    Modern Flutter hangs each `View`'s own `PipelineOwner` off the root, and
    *that* is the one holding the `SemanticsOwner`. Cost: every test in the
    file failed with "Null check operator used on a null value" (12 failures)
    while the widgets and the labels were entirely correct.
  - `binding.pipelineOwner` *works* but is a **separate legacy instance**, not
    an alias for the root. It is the expression the framework's own docs
    recommended for years, which is exactly what makes it dangerous — it works
    by accident and the deprecation is the only warning you get.

  This is the third time in this project that the "obvious" API was wrong and
  only reading the SDK source settled it (`AsyncSnapshot` has no `.data()`
  ctor; `SemanticsNode` has no `hasAction`; `PipelineOwner` has no `pipelineOwner`
  getter). **Read `flutter_test/lib/src/finders.dart` before hand-rolling
  anything against the test framework** — it is the reference implementation.
  Related API traps found in the same pass: `SemanticsNode.hasFlag` is
  deprecated (use `node.flagsCollection.<flag>`), `flagsCollection.isEnabled`
  is a `Tristate` rather than a `bool`, and `rootSemanticsNode` is literally
  `_nodes[0]`, so it throws rather than returning null on an empty tree.
- **Law:** **a test that asserts accessibility must read the same tree the
  platform does.** A finder that returns zero matches is not evidence that a
  label is missing — it may be evidence the finder is looking in the wrong
  place. Dump the tree before concluding anything, and dispose the
  `SemanticsHandle` with try/finally (`addTearDown` is too late; the check runs
  before tearDowns). And when a whole test file fails identically, suspect the
  harness before suspecting twelve widgets at once: one wrong accessor produced
  twelve separate-looking failures.

---

## L25 — Blinding device verification to scaled screenshots cost ~10 wasted probes (Oct 2026)

- **What happened:** verifying the four tester fixes on the B160V burned roughly
  ten screenshot/tap round-trips that accomplished nothing. Taps at
  `input tap 120 665` and similar simply did not land, and the app looked
  identical after each one, so each failure looked like "the fix didn't work"
  when in fact the tap had never reached the widget.
- **Root cause — two separate mistakes, both about not reading the screen's real
  geometry.** First: `adb exec-out screencap -p > file` through PowerShell
  **silently corrupted the PNG** (ANSI/CRLF mangling); `PIL` then raised
  `UnidentifiedImageError`, which reads like a bad capture rather than a bad
  redirect. Second, and worse: the images I was reasoning over had been
  *downscaled to 322 px wide for reading*, and I was then tapping in
  **scaled coordinates against a 720x1612 device**. Every tap was landing
  roughly 2.2x off target. I "fixed" this by guessing new coordinates several
  times instead of measuring once.
- **Prevention rule (the law):** *never reason about a screenshot you resized,
  and never tap in the coordinate space of a resized image.*
  1. `adb shell screencap -p /sdcard/x.png` then `adb pull` — **never**
     `exec-out` with a PowerShell `>` redirect.
  2. Resize **only a second copy** for viewing; tap in **device pixels**.
  3. Before the first tap, get the real geometry once:
     `adb shell wm size` and `adb shell wm density`. Scale factor is
     `device_width / resized_width`. Do this once per device, not per tap.
  4. When a tap produces no change, the correct next step is to **measure the
     target** (`uiautomator dump` + read `bounds`) or to navigate by a route you
     have confirmed in code — **not** to try another coordinate. I burned four
     probes on guessed taps that a single `wm size` would have prevented.
  5. `uiautomator dump` puts the whole tree on **one line**, so `grep` truncates
     it and inline `python -c` through PowerShell mangles the regex (again, see
     the PowerShell rule). Read bounds with a small `.py` file, not a shell one-liner.
- **Bonus finding, worth keeping:** a fresh profile's constellation is empty, and
  **mood check-ins do not create stars** — they only award sparks and bond. Stars
  come from walks (500 pedometer steps), 12-Step progress, trial wins, and goals.
  I initially read "3 check-ins, +5 sparks, sky still empty" as a bug. It is
  correct behaviour, and `constellation_service.dart` is the file that proves it.
  *A surprising empty state is a reason to read the service that owns it, not to
  file a bug.*
