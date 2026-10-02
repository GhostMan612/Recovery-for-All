#!/usr/bin/env python3
"""Gate: architecture invariants that prose warnings cannot enforce.

The Phase 8/9 handoff documents several rules as markdown bullets. A
markdown bullet drifts; this file fails the build instead. Each invariant
below corresponds to a rule that has ALREADY caused or nearly caused a real
defect, so the failure mode is explicit rather than hypothetical.

Usage: python tools/verify_invariants.py
Exit code 0 = pass, 1 = fail.
"""
import io
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
MAIN = LIB / "main.dart"
PROVIDERS = LIB / "core" / "providers.dart"
CARD_FILES = {
    LIB / "widgets" / "dashboard_cards.dart",
    LIB / "widgets" / "dashboard_sections.dart",
}

failures = []
notes = []


def read(path):
    with io.open(path, encoding="utf-8", errors="ignore") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# 1. One database instance.
#
# `databaseProvider` lazily constructs a RecoveryDatabase. main.dart also
# builds one. Without the override, providers that watch databaseProvider get
# a SECOND SQLCipher connection to the same encrypted file, with its own key
# read. This was a real latent boot bug.
# ---------------------------------------------------------------------------
main_text = read(MAIN)
# Match the override INSIDE an overrides: list. A bare substring check would
# also be satisfied by a comment or by an override in some other provider
# list, so require the real shape.
override_re = re.compile(
    r"overrides:\s*\[[^\]]*databaseProvider\s*\.\s*overrideWithValue",
    re.S,
)
if not override_re.search(main_text):
    failures.append(
        "lib/main.dart: databaseProvider is NOT overridden. main.dart builds "
        "one RecoveryDatabase and databaseProvider lazily builds a second, "
        "giving two SQLCipher connections to the same encrypted file. "
        "Restore `overrides: [databaseProvider.overrideWithValue(database)]`."
    )

# The lazy constructor must still exist, but must not be the only path.
if "RecoveryDatabase()" not in read(PROVIDERS):
    notes.append(
        "lib/core/providers.dart: databaseProvider no longer constructs a "
        "RecoveryDatabase. Confirm the provider is still overridden in "
        "main.dart (invariant 1)."
    )

# ---------------------------------------------------------------------------
# 2. Exactly one SOS tile implementation.
#
# Phase 10 forbids a second SOS surface. A duplicate class would mean two
# places to fix when SOS behavior changes, and the risk of them diverging on
# a safety-critical path.
# ---------------------------------------------------------------------------
sos_decls = []
for path in sorted(LIB.rglob("*.dart")):
    text = read(path)
    for m in re.finditer(r"^class (_?SosTile)\b", text, re.M):
        sos_decls.append((path, m.group(1)))

if len(sos_decls) == 0:
    failures.append(
        "No SosTile class found. If it was intentionally removed, update the "
        "Phase 9/10 plan and this gate together."
    )
elif len(sos_decls) > 1:
    where = ", ".join("%s (%s)" % (p.relative_to(ROOT), n) for p, n in sos_decls)
    failures.append(
        "SOS TILE DUPLICATED: %d SosTile declarations (%s). Phase 10 forbids a "
        "second SOS surface. Keep the one in dashboard_cards.dart and delete "
        "the other." % (len(sos_decls), where)
    )

# The SOS entry point must remain exactly once, anywhere under lib/.
#
# Deliberately NOT pinned to dashboard_screen.dart: Phase 9 moves the shell,
# and a check that demands the function stay in one file would fail the gate
# on a correct refactor. What actually matters is that the definition exists
# exactly once and that the shell still exposes it, so assert both.
sos_defs = []
for path in sorted(LIB.rglob("*.dart")):
    for m in re.finditer(r"void (_showSosSheet)\s*\(", read(path)):
        sos_defs.append(path.relative_to(ROOT).as_posix())

if len(sos_defs) == 0:
    failures.append(
        "The _showSosSheet definition is gone from lib/. SOS must remain "
        "globally reachable from every destination (Phase 9/10)."
    )
elif len(sos_defs) > 1:
    failures.append(
        "SOS entry point DUPLICATED: _showSosSheet is defined in %s. Two "
        "definitions means two code paths on a safety-critical surface; keep "
        "one and route both callers to it." % ", ".join(sos_defs)
    )

# The shell that hosts the FAB must still be able to reach SOS. This is the
# check that would actually catch a Phase 9 regression, as opposed to a
# refactor that only moves the code.
#
# A CALL SITE is any reference that is not the definition itself. Checking for
# the bare name is not enough: the definition lives in the shell file, so a
# name-only check is satisfied by the definition even after every call site is
# deleted -- which would leave an SOS FAB wired to nothing.
CALL_SITE = re.compile(r"(?<!void )_showSosSheet\s*(?!\()")

shell_candidates = [
    p for p in sorted((LIB / "screens").glob("*.dart"))
    if "NavigationBar" in read(p)
]
if not shell_candidates:
    failures.append(
        "No shell screen found: expected a lib/screens/*.dart file that owns "
        "a NavigationBar. The app lost its primary navigation host."
    )
elif not any(CALL_SITE.search(read(p)) for p in shell_candidates):
    failures.append(
        "A navigation shell owns a NavigationBar but never CALLS "
        "_showSosSheet. The SOS FAB must be wired from the shell so it works "
        "on every destination; a dead definition is not a reachable SOS."
    )

# ---------------------------------------------------------------------------
# 3. SharedPreferences keys are live user data.
#
# Renaming any of these silently resets real users' layout, radius, or theme
# choices with no migration path.
# ---------------------------------------------------------------------------
# Each key is pinned to the file that must still read or write it. Pinning the
# owner rather than just the key means a PARTIAL rename is caught too: if the
# writer moves to _v2 but the reader still says _v1, the key still exists
# somewhere, and a set-only check would pass while real users silently lose
# their saved layout.
REQUIRED_KEYS = {
    "dashboard_tool_order_v1": "core/dashboard_providers.dart",
    "dashboard_hidden_tools_v1": "core/dashboard_providers.dart",
    "dashboard_library_order_v1": "core/dashboard_providers.dart",
    "dashboard_hidden_library_v1": "core/dashboard_providers.dart",
    "dashboard_enforce_radius_v1": "core/meeting_radius_logic.dart",
    # Load-bearing since the Oct tester round: without this the dashboard's
    # meeting card fell back to statewide results and the map's slider
    # disagreed with the dashboard's. A rename would silently reopen that bug
    # with no gate failure.
    "meeting_search_radius_miles_v1": "core/meeting_radius_logic.dart",
    "last_known_location_lat_v1": "core/meeting_radius_logic.dart",
    "last_known_location_lng_v1": "core/meeting_radius_logic.dart",
    "last_known_location_time_v1": "core/meeting_radius_logic.dart",
    "theme_mode_v1": "core/theme/app_colors.dart",
    "theme_preference_v1": "core/providers.dart",
}

# The prefix set must cover every REQUIRED_KEYS entry, or a key can be listed
# as load-bearing and still never be found — which is exactly what happened to
# `meeting_search_radius_miles_v1`: it was added to REQUIRED_KEYS and the gate
# failed, because KEY_PAT below only matched dashboard_/theme_/
# last_known_location_. A listed key that the scanner cannot see is not a pin.
KEY_PAT = re.compile(
    r"['\"]((?:dashboard_|theme_|last_known_location_|meeting_search_radius_)"
    r"[A-Za-z0-9_]*)['\"]"
)

found_keys = {}
for path in sorted(LIB.rglob("*.dart")):
    rel = path.relative_to(LIB).as_posix()
    for m in KEY_PAT.finditer(read(path)):
        found_keys.setdefault(m.group(1), set()).add(rel)

for key, owner in sorted(REQUIRED_KEYS.items()):
    holders = found_keys.get(key, set())
    if not holders:
        failures.append(
            "SharedPreferences key %s no longer exists anywhere in lib/. It "
            "holds real users' saved data; restore the exact string or migrate "
            "explicitly." % key
        )
    elif owner not in holders:
        failures.append(
            "SharedPreferences key %s is no longer read/written by its owner "
            "lib/%s (now only in %s). A partial rename silently desynchronises "
            "the writer from the reader and real users lose their saved "
            "settings." % (key, owner, ", ".join(sorted(holders)))
        )

unexpected = sorted(set(found_keys) - set(REQUIRED_KEYS))
if unexpected:
    notes.append(
        "New SharedPreferences key(s) present: %s. Intentional? If so add them "
        "to REQUIRED_KEYS here so a future rename is caught." % ", ".join(unexpected)
    )

# ---------------------------------------------------------------------------
# 4. Dashboard view ownership.
#
# Phase 8 moved the dashboard's visual vocabulary into two files. New UI
# added inline to the screen means the extraction silently regresses.
# ---------------------------------------------------------------------------
for path in sorted(CARD_FILES):
    if not path.exists():
        failures.append(
            "%s is missing. Phase 8 extracted the dashboard view layer into "
            "this file; do not re-inline it into dashboard_screen.dart."
            % path.relative_to(ROOT)
        )

# ---------------------------------------------------------------------------
# 5. Retired dark-pinned AppColors statics.
#
# These encode a dark background. Re-adding one pins a screen to dark mode
# in a system that now has six light/dark schemes.
# ---------------------------------------------------------------------------
RETIRED_COLORS = re.compile(
    r"AppColors\.(bgDeep|bgCard|border|accent|success|danger|"
    r"textPrimary|textMuted|textDim|textHint)\b"
)

for path in sorted(LIB.rglob("*.dart")):
    if path.name == "app_colors.dart":
        continue
    hits = sorted(set(RETIRED_COLORS.findall(read(path))))
    if hits:
        failures.append(
            "%s references retired dark-pinned constant(s): %s. Use the "
            "ColorScheme slot for the current brightness instead."
            % (path.relative_to(ROOT), ", ".join("AppColors." + h for h in hits))
        )


# ---------------------------------------------------------------------------
# 6. One motion policy.
#
# Phase 14 found the "reduce motion" decision being made in five places: a
# helper in themed_background.dart plus three raw
# `MediaQuery.disableAnimationsOf` reads. Each was individually correct, which
# is exactly why they drifted: a new animation had no single place to consult,
# so onboarding's page transition shipped animating for users who had turned
# animations off.
#
# The rule is deliberately narrow. It does not forbid *using* the setting; it
# requires the setting to be READ in exactly one file, so there is a single
# answer to "should this move?" and a single place to change the policy.
# HardwareTierService.isLowEnd is a different question (can this device afford
# to animate?) and is deliberately NOT folded in here.
# ---------------------------------------------------------------------------
MOTION = LIB / "core" / "motion" / "app_motion.dart"


def strip_comments(text):
    """Drop comments so documentation cannot satisfy or trip a scan.

    Crude on purpose: it only needs to be good enough that a doc comment
    mentioning the API is not mistaken for a call. The negative lookbehind
    keeps `https://` inside a string literal from truncating the line.
    """
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?<!:)//[^\n]*", "", text)


if not MOTION.exists():
    failures.append(
        "lib/core/motion/app_motion.dart is missing. Phase 14 consolidated the "
        "reduce-motion decision into this file so there is one place to look; "
        "do not go back to reading MediaQuery.disableAnimations at each call "
        "site."
    )
else:
    motion_readers = []
    for path in sorted(LIB.rglob("*.dart")):
        if "disableAnimations" in strip_comments(read(path)):
            motion_readers.append(path.relative_to(ROOT).as_posix())
    extra = [p for p in motion_readers if p != MOTION.relative_to(ROOT).as_posix()]
    if extra:
        failures.append(
            "REDUCE-MOTION READ OUTSIDE THE POLICY FILE: %s. The system "
            "animation setting is read in more than one place, which is how "
            "onboarding ended up animating for users who disabled animations. "
            "Use AppMotion.reduceMotionOf(context) (or "
            "AppMotion.platformReduceMotion in initState, where no MediaQuery "
            "exists)." % ", ".join(extra)
        )


# ---------------------------------------------------------------------------
# 7. No missing-brace string interpolation.
#
# `lib/screens/dashboard_screen.dart` shipped this for the whole UI/UX program:
#
#     Text('Welcome, $ref.watch(dashboardDataProvider).username')
#
# Dart interpolates ONLY the identifier `ref`. Everything after it -- the
# `.watch(...)` call and `.username` -- was LITERAL TEXT, so the app bar rendered
#   "Welcome, " + ref.toString() + ".watch(dashboardDataProvider).username"
# which is why it displayed "Welcome, DashboardScree…". The provider was never
# consulted, so the title could never show the user's name.
#
# This is the exact class of defect the analyzer cannot see: it is VALID Dart,
# just not the string anyone meant. The colour gate never reads strings, and no
# test asserted the title. It reached two devices and a clean install before a
# human read a screenshot. Hence a gate.
#
# The pattern that distinguishes the bug from correct code is a METHOD CALL or
# further chaining after the dot, not merely a dot:
#
#   BAD    '$ref.watch(x).y'      dot -> identifier -> '('   (missing brace)
#   GOOD   '$title. $subtitle'    dot -> space               (sentence separator)
#   GOOD   '$modelId.gguf'        dot -> identifier -> end   (file extension)
#   GOOD   '$tablePrefix.'        dot -> end
#
# So require the dot to be followed by an identifier and THEN a '(' or another
# dot. Generated *.g.dart files are skipped: they are build_runner output, must
# never be hand-edited, and legitimately build "prefix.name" identifiers.
BAD_INTERPOLATION = re.compile(
    r"""\$[A-Za-z_]\w*\.[A-Za-z_]\w*(?:\s*\(|\s*\.)"""
)

interp_hits = []
for path in sorted(LIB.rglob("*.dart")):
    if path.name.endswith(".g.dart"):
        continue
    text = strip_comments(read(path))
    for lineno, line in enumerate(text.splitlines(), start=1):
        # Only look inside single- or double-quoted string literals.
        for literal in re.findall(r"'([^'\n]*)'|\"([^\"\n]*)\"", line):
            segment = literal[0] or literal[1]
            if BAD_INTERPOLATION.search(segment):
                interp_hits.append(
                    "%s:%d: %s"
                    % (path.relative_to(ROOT).as_posix(), lineno, line.strip())
                )

if interp_hits:
    failures.append(
        "MISSING-BRACE STRING INTERPOLATION (invariant 7). In Dart, `$name` "
        "interpolates ONLY the identifier; anything after it is literal text. "
        "Each of these is a visible string that was never wired to its value: "
        + " || ".join(interp_hits)
        + " -- use `${name.field}` instead of `$name.field`."
    )


# ---------------------------------------------------------------------------
# INVARIANT 8 — riverpod single-owner: dashboardDataProvider owns pet state.
#
# AGENTS.md claimed this rule "is enforced, not merely documented", and for a
# while the gate did not check it. It was a prose rule only, and the violation
# existed: dashboard_screen.dart called RecoveryPetService.ensureHatched()
# directly (twice, to compute a Sparks delta) instead of reading the notifier.
#
# WHY a gate. A second owner is invisible to the analyzer and to every test: the
# service is a valid static call from a valid place. The failure mode is a
# split-brain read — the notifier's value and the raw service value disagree
# after any refresh, and the delta is computed from the stale one.
#
# The screen may still navigate to pet screens, and may legitimately call
# ensureHatched() during first-run bootstrap before the provider has produced a
# value. What it must not do is read the pet back out to compute state the
# notifier already owns.
# ---------------------------------------------------------------------------
PET_OWNER_ALLOWED_CALLERS = {
    # The notifier's own loader.
    "core/dashboard_providers.dart",
    # The service itself, and the widgets that render a pet handed to them.
    "services/recovery_pet_service.dart",
    "widgets/recovery_pet_card.dart",
    "widgets/dashboard_sections.dart",
    "widgets/skill_tree_modal.dart",
}

# Pushed-route and non-widget callers legitimately call ensureHatched() before a
# ProviderScope of the right kind is available, or to read a single stat for a
# one-off write. The rule that actually matters is narrower and is the one the
# original violation broke: the DASHBOARD — the screen that both watches the
# provider and renders its pet — must not read the pet back out of the service.
PET_OWNER_ENFORCED_CALLERS = {"screens/dashboard_screen.dart"}

owner_violations = []
for path in sorted(LIB.rglob("*.dart")):
    rel = path.relative_to(LIB).as_posix()
    if rel in PET_OWNER_ALLOWED_CALLERS or rel not in PET_OWNER_ENFORCED_CALLERS:
        continue
    text = strip_comments(read(path))
    for lineno, line in enumerate(text.splitlines(), start=1):
        if "ensureHatched" not in line:
            continue
        # A private `_pet` field is the other half of the same rule.
        if re.search(r"RecoveryPet\??\s+_pet\b", line):
            owner_violations.append(
                "%s:%d: private `_pet` field — dashboardDataProvider owns pet state"
                % (path.relative_to(ROOT).as_posix(), lineno)
            )
        # Read-back for state the notifier owns.
        if re.search(r"=\s*\(?\s*await\s+RecoveryPetService\.ensureHatched", line) or \
           re.search(r"await\s+RecoveryPetService\.ensureHatched\(\)\s*\.", line):
            owner_violations.append(
                "%s:%d: reads pet state back out of the service instead of the "
                "notifier" % (path.relative_to(ROOT).as_posix(), lineno)
            )

if owner_violations:
    failures.append(
        "PET-STATE SINGLE OWNER (invariant 8). dashboardDataProvider is the only "
        "owner of pet state; a screen reading it from RecoveryPetService is a "
        "split-brain source: "
        + " || ".join(owner_violations)
        + " -- read `ref.watch(dashboardDataProvider).pet` instead."
    )


# ---------------------------------------------------------------------------
# INVARIANT 9 — no `Colors.white` / `Colors.black` used as a paired foreground.
#
# The colour gate catches `Color(0x…)` literals and retired AppColors names, but
# a foreground that is hardcoded white against `colorScheme.primary` slips
# straight past it. M3 palettes flip tone with brightness: `primary` is a light
# tone in dark theme and a dark tone in light theme, so `Colors.white` on
# `primary` is correct in one brightness and unreadable in the other. The worst
# instance was the unverified step count in walk_tracking_dialog, drawn white on
# colorScheme.surface — invisible in the default light palette until the user
# passed 500 steps.
#
# Only flag a hardcoded foreground when a colorScheme background appears in the
# SAME STATEMENT, because a white icon on an avatar or inside a canvas painter is
# a legitimate constant, not a tone mismatch.
#
# The statement, not the line. This used to be a per-line regex pairing, and that
# is how four unreadable pairings shipped past it:
#
#   lib/screens/sponsor_mode_screen.dart   tertiary / Colors.white
#   lib/screens/meeting_map_screen.dart    tertiary / Colors.white
#   lib/widgets/companion_guide_overlay.dart  primary / Colors.black
#   lib/screens/splash_screen.dart         dangerSoft / Colors.white (a `side:`)
#
# In every case the two properties were on ADJACENT lines inside one
# `ElevatedButton.styleFrom(...)` call, which no same-line check can see. The
# scan below balances parentheses instead, so the window is the whole argument
# list — which is what "same statement" was always trying to mean.
# ---------------------------------------------------------------------------
HARD_FG = re.compile(
    r"(?:foregroundColor|labelStyle\s*:|checkmarkColor\s*:|thumbColor\s*:)"
    r"\s*(?:TextStyle\s*\([^)]*?color\s*:)?\s*Colors\.(white|black)\b",
    re.IGNORECASE,
)
SCHEME_BG = re.compile(
    r"backgroundColor:\s*Theme\.of\(\s*\w+\s*\)\.colorScheme\."
)
# `BoxDecoration(color:)` inside the same widget as a hardcoded white TEXT
# colour. This is the shape that produced the two worst bugs in the sweep:
# `const TextStyle(color: Colors.white)` on a `surfaceContainer` panel — the
# Companion Guide tutorial body and the entire Community Resources link list
# were invisible in light mode.
SCHEME_PANEL = re.compile(
    r"color:\s*Theme\.of\(\s*\w+\s*\)\.colorScheme\."
    r"\.(?:surface|surfaceContainer|surfaceContainerHigh|surfaceContainerHighest"
    r"|primary|tertiary|secondary|error)"
)
# A `side:`/`border:` carries the same tone question as a background: it is the
# edge of the same filled button, so a white label on a light border has the same
# contrast problem.
SCHEME_SIDE = re.compile(
    r"(?:side|border)\s*:\s*Border\.(?:all|side)\(\s*color\s*:\s*"
    r"(?:Theme\.of\(\s*\w+\s*\)\.colorScheme\.|AppColors\.)"
)
# Fixed, light domain fills whose only readable foreground is a dark one.
APP_ACCENT_FILL = re.compile(
    r"backgroundColor:\s*AppColors\.(?:pink|dangerSoft)\b"
)


def statements(text):
    """Yield (line_no, snippet) for each top-level-looking `(...)` argument list.

    Deliberately crude: track parenthesis depth from outside-in and treat each
    return to depth 1 as the end of one call's arguments. It does not need to
    understand Dart, only to keep a multi-line `styleFrom(...)` together, which
    is the whole job. Brace-delimited widget bodies are not separated, so a
    `foregroundColor:` in one card and a `backgroundColor:` in the next card
    cannot be joined — that over-reach would produce false positives.
    """
    depth = 0
    start = 0
    start_line = 1
    for i, ch in enumerate(text):
        if ch == "(":
            if depth == 0:
                start = i
                start_line = text.count("\n", 0, i) + 1
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                yield start_line, text[start : i + 1]
            if depth < 0:
                depth = 0


paired_fg = []
for path in sorted(LIB.rglob("*.dart")):
    if path.name.endswith(".g.dart"):
        continue
    text = strip_comments(read(path))
    # Two passes. The statement pass catches a `styleFrom(...)` whose properties
    # span several lines. The window pass below catches the `const TextStyle(
    # color: Colors.white)` form, where the text colour and the panel colour are
    # in *different* constructs with no shared parentheses — so there is no
    # statement that contains both, and only proximity can pair them.
    for lineno, stmt in statements(text):
        if HARD_FG.search(stmt) and (
            SCHEME_BG.search(stmt)
            or SCHEME_SIDE.search(stmt)
            or APP_ACCENT_FILL.search(stmt)
        ):
            snippet = " ".join(stmt.split())
            paired_fg.append(
                "%s:%d: %s"
                % (path.relative_to(ROOT).as_posix(), lineno, snippet[:110])
            )

    # Window pass: a hardcoded white/black text colour with a scheme panel or
    # accent fill within 12 lines, in either order. 12 is chosen to span a
    # `Text(...)` inside its parent's `Container`/`Card` decoration without
    # reaching the next widget on the screen — a wider window would start
    # pairing unrelated rows, and a gate that cries wolf gets ignored.
    LINES = text.splitlines()
    for i, line in enumerate(LINES):
        if not re.search(r"Colors\.(white|black)\b", line, re.IGNORECASE):
            continue
        lo = max(0, i - 12)
        hi = min(len(LINES), i + 13)
        window = "\n".join(LINES[lo:hi])
        if not (SCHEME_PANEL.search(window) or APP_ACCENT_FILL.search(window)):
            continue
        if path.name.endswith(".g.dart"):
            continue
        snippet = " ".join(line.split())
        entry = "%s:%d: %s" % (
            path.relative_to(ROOT).as_posix(),
            i + 1,
            snippet[:110],
        )
        if entry not in paired_fg:
            paired_fg.append(entry)

if paired_fg:
    failures.append(
        "PAIRED FOREGROUND MUST BE A colorScheme ROLE (invariant 9). M3 primary, "
        "tertiary, surfaceContainer and error flip tone with brightness, so a "
        "hardcoded white/black text colour is unreadable in one mode — and "
        "`const TextStyle(color: Colors.white)` cannot read the theme at all. "
        "Use onPrimary / onTertiary / onSurface / onSurfaceContainer, or "
        "AppColors.onDomainAccent for the brightness-independent pink and "
        "dangerSoft fills: " + " || ".join(paired_fg)
    )


# ---------------------------------------------------------------------------
# 10. Stack child order in the constellation canvas.
#
# A Stack hit-tests its LAST child first. The 3D view is an opaque
# `Positioned.fill` surface, so if it is declared after the controls it
# swallows every tap aimed at them: entering 3D mode became a ONE-WAY DOOR
# whose only exit was killing the app.
#
# This gate exists because the bug was invisible to both the analyzer and a
# careful read: the file carried a comment describing the CORRECT ordering
# immediately above the WRONG line. "The opaque 3D surface is declared BEFORE
# the toggle and the slider, not after" sat directly above the overlay, which
# was declared after. A comment is not an ordering guarantee.
#
# We compare the byte offset of the overlay's declaration against each
# interactive control's. `test/constellation_3d_controls_reachable_test.dart`
# pins the same behaviour behaviourally; this catches a revert at the source
# level, before anyone builds an APK.
#
# KNOWN LIMITATION, deliberately accepted: a raw `find()` offset scan cannot
# distinguish a declaration from a mention of the same text. It is the
# cheapest check that cannot silently pass on a missing widget (each needle
# raises if it is absent), and the behavioural test covers the real hit path.
# If this file is ever restructured so the ordering no longer appears in one
# `Stack(children: [...])`, the "could not locate" branch fires rather than
# quietly going green — that is the failure mode to preserve.
# ---------------------------------------------------------------------------
CANVAS = ROOT / "lib" / "screens" / "constellation_screen.dart"

if not CANVAS.exists():
    failures.append(
        "lib/screens/constellation_screen.dart is missing. Invariant 10 "
        "checks Stack child order there."
    )
else:
    canvas_src = read(CANVAS)
    # Matched on the widget name only, NOT on `Positioned.fill(child: ...` — that
    # exact single-line shape was reformatted when the fix landed, and a needle
    # pinned to it reported "the overlay is gone" instead of checking the order.
    # A gate that breaks on formatting is a gate that gets "fixed" by reverting
    # the formatting, which is how a gate stops gating.
    OVERLAY = "RecoveryConstellation3DWidget("
    overlay_at = canvas_src.find(OVERLAY)
    if overlay_at == -1:
        failures.append(
            "The 3D overlay declaration (Positioned.fill(child: "
            "RecoveryConstellation3DWidget) is gone from "
            "lib/screens/constellation_screen.dart. If 3D mode was removed on "
            "purpose, delete invariant 10 in this gate and in AGENTS.md in the "
            "same commit — do not leave the gate dangling."
        )
    else:
        # Each control is identified by a literal unique to its own
        # declaration site, so the offsets cannot drift onto a comment or a
        # different widget that happens to mention the same symbol.
        controls = {
            "3D view toggle": "label: _is3DView ? 'Switch to 2D view'",
            "zoom slider": "value: _zoom,",
            "focus info badge": "child: _buildFocusInfo(",
            "sky name label": "widget.skyName != null",
        }
        for name, needle in sorted(controls.items()):
            control_at = canvas_src.find(needle)
            if control_at == -1:
                failures.append(
                    "Could not locate the %s declaration in "
                    "lib/screens/constellation_screen.dart (searched for %r). "
                    "Invariant 10 cannot verify Stack order, so it would pass "
                    "without checking anything — a gate that cannot see is not "
                    "a gate. Update the needle here." % (name, needle)
                )
            elif control_at < overlay_at:
                failures.append(
                    "STACK ORDER (invariant 10): the %s is declared BEFORE the "
                    "opaque 3D overlay in lib/screens/constellation_screen.dart, "
                    "so it is painted over and cannot be tapped while 3D mode is "
                    "active. A Stack hit-tests its LAST child first — move the "
                    "`if (_is3DView) Positioned.fill(...)` line to sit directly "
                    "after the 2D canvas AnimatedBuilder and before every "
                    "interactive control." % name
                )


# ---------------------------------------------------------------------------
# 11. Firestore rules are ownership-scoped.
#
# `firestore/firestore.rules` shipped
#
#     match /sponsor_bundles/{docId} {
#       allow read, write: if request.auth != null;
#     }
#
# on a collection of clinical step-work bundles. `request.auth != null` is not
# an authorisation check, it is a "is anyone signed in" check — so every
# authenticated user could read, sign, and rewrite every bundle anyone else had
# shared. It survived because nothing tested the rules and nothing in the Dart
# client would have revealed it: the client only ever reads documents it just
# created, so the missing boundary never produced a wrong value, only a
# reachable one.
#
# Two things must hold, and the second is the one that is easy to get wrong:
#
#   a. No `allow` may be gated on `request.auth != null` ALONE. That expression
#      is a session check and must never be the whole condition.
#   b. Every `match` block over a collection holding user content must bind at
#      least one path segment to `request.auth.uid`. A field-based check
#      (`resource.data.ownerUid == request.auth.uid`) is NOT sufficient and is
#      the trap: the document is written BY the caller, so the caller chooses
#      that field. Only the path is not caller-chosen. This project has no Admin
#      SDK, so a custom claim cannot be used either — which is precisely why the
#      path is the partition.
# ---------------------------------------------------------------------------
RULES = ROOT / "firestore" / "firestore.rules"

if not RULES.exists():
    failures.append(
        "firestore/firestore.rules is missing. Invariant 11 checks that the "
        "cloud rules stay ownership-scoped."
    )
else:
    rules_src = strip_comments(read(RULES))

    # (a) An `allow` whose condition is exactly the session check.
    #
    # EXEMPT: `community_feeds`, whose read is intentionally shared — a Recovery
    # Circle is the product, not an inbox, so requiring a per-user path would
    # make the feed single-user. That collection's writes are constrained by the
    # immutability pins in (b) instead, which is the meaningful boundary there:
    # anyone may read the circle, nobody may rewrite anyone's post.
    SHARED_READ_ONLY = {"community_feeds"}

    for block in re.finditer(
        r"(match\s+/([A-Za-z_][A-Za-z0-9_]*)/\{(\w+)\}\s*\{)(.*?)\n(\s*)\}",
        rules_src,
        re.S,
    ):
        root = block.group(2)
        body = block.group(4)
        if not re.search(r"allow\s+", body):
            continue
        if root in SHARED_READ_ONLY:
            continue
        for m in re.finditer(
            r"allow\s+(?:read|write|create|update|delete)"
            r"(?:\s*,\s*(?:read|write|create|update|delete))*"
            r"\s*:\s*if\s+([^;{]+)",
            body,
        ):
            condition = " ".join(m.group(1).split())
            if condition == "request.auth != null":
                line = (
                    rules_src[
                        : block.start(4) + m.start()
                    ].count("\n")
                    + 1
                )
                failures.append(
                    "FIREBASE RULE at firestore/firestore.rules:%d (`/%s`) is "
                    "gated on `request.auth != null` ALONE. That is a session "
                    "check, not an authorisation check — it grants the operation "
                    "to every signed-in user. Add an ownership condition (a path "
                    "segment bound to `request.auth.uid`); do not rely on a "
                    "document field, because the caller writes that field."
                    % (line, root)
                )

    # (b) Per-collection requirements. Two shapes, because there are two kinds of
# collection here, and conflating them would either over- or under-enforce:
#
#   PRIVATE  — content only the owner may touch. `sponsor_bundles`,
#              `sponsorBundles`, `care_alerts`. MUST bind a path segment to
#              `request.auth.uid`. A `resource.data.<field> == request.auth.uid`
#              test is NOT accepted: for a document the caller itself created,
#              the caller chose that field.
#
#   SHARED   — `community_feeds` is a feed, not an inbox. Reads are meant to be
#              shared, so a path partition would be wrong (it would make the
#              Recovery Circle single-user). What must be protected instead is
#              authorship: no client may rewrite `authorAlias`, `body`, or
#              moderation `status` on a post it does not own. There is no
#              authorisable moderator claim in this project (`isModerator()`
#              reads a SharedPreferences flag, invisible to rules), so the only
#              safe posture is that those three are IMMUTABLE remotely.
PRIVATE_COLLECTIONS = {
    "sponsor_bundles": "clinical step-work bundles",
    "sponsorBundles": "the sponsor inbox (clinical step-work bundles)",
    "care_alerts": "distress signals",
}
IMMUTABLE_FEED_FIELDS = ("authorAlias", "body", "status")

for block in re.finditer(
    r"match\s+/([A-Za-z_][A-Za-z0-9_]*)/\{(\w+)\}\s*\{(.*?)\n\s*\}",
    rules_src,
    re.S,
):
    root, segment, body = block.group(1), block.group(2), block.group(3)
    if not re.search(r"allow\s+(?:read|write|create|update|delete)", body):
        continue

    if root in PRIVATE_COLLECTIONS:
        if ("%s == request.auth.uid" % segment) not in body:
            failures.append(
                "FIREBASE RULE: the `/%s/{%s}` block in "
                "firestore/firestore.rules grants access without binding `%s` to "
                "`request.auth.uid`. It holds %s, which is private, so the "
                "partition must be the PATH. Checking "
                "`resource.data.ownerUid == request.auth.uid` instead is not "
                "equivalent: the caller writes that field." % (
                    root, segment, segment, PRIVATE_COLLECTIONS[root])
            )
        # `allow read, write: if <auth-only>` is already caught above, but a
        # `write` alias can smuggle the same thing past that pass.
        if re.search(r"allow\s+(?:read\s*,\s*)?write\s*:\s*if\s+([^;{]+)", body):
            for m2 in re.finditer(
                r"allow\s+(?:read\s*,\s*)?write\s*:\s*if\s+([^;{]+)", body
            ):
                if "%s == request.auth.uid" % segment not in m2.group(1):
                    failures.append(
                        "FIREBASE RULE: `/%s/{%s}` grants `write` on a condition "
                        "that does not include `%s == request.auth.uid`."
                        % (root, segment, segment)
                    )

    elif root == "community_feeds":
        if re.search(r"allow\s+update\s*:", body):
            for field in IMMUTABLE_FEED_FIELDS:
                pin = "request.resource.data.%s == resource.data.%s" % (field, field)
                if pin not in body:
                    failures.append(
                        "FIREBASE RULE: `/community_feeds/{docId}` allows update "
                        "without pinning `%s` (`%s` absent). Without it any "
                        "signed-in user can rewrite a post's %s — for `status` "
                        "that means approving or hiding anyone's post, including "
                        "their own past moderation. Moderation is local-only by "
                        "design (pet-store-rules C5) because there is no "
                        "authorisable moderator claim."
                        % (field, pin, field)
                    )


def main() -> int:
    for note in notes:
        print("NOTE: %s" % note)

    if failures:
        for f in failures:
            print("FAIL: %s" % f)
        print(
            "\n%d invariant failure(s). See AGENTS.md and "
            "blueprints/UI-UX-themes-plan.md for the intent behind each rule."
            % len(failures)
        )
        return 1

    print("PASS: %d architecture invariants hold" % 11)
    return 0


if __name__ == "__main__":
    sys.exit(main())
