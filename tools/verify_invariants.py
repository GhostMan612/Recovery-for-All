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
    "last_known_location_lat_v1": "core/meeting_radius_logic.dart",
    "last_known_location_lng_v1": "core/meeting_radius_logic.dart",
    "last_known_location_time_v1": "core/meeting_radius_logic.dart",
    "theme_mode_v1": "core/theme/app_colors.dart",
    "theme_preference_v1": "core/providers.dart",
}

KEY_PAT = re.compile(
    r"['\"]((?:dashboard_|theme_|last_known_location_)[A-Za-z0-9_]*)['\"]"
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

    print("PASS: %d architecture invariants hold" % 6)
    return 0


if __name__ == "__main__":
    sys.exit(main())
