#!/usr/bin/env python3
"""Gate: no bare Colors.white / Colors.black pinning a widget to one mode.

Phase 9 follow-up. The existing color gate catches raw `Color(0x...)` literals
and the retired dark-pinned `AppColors` statics, but it did NOT catch
`Colors.white` used as a Text/Icon color. That is the single most common way a
screen looks fine in dark mode and becomes unreadable in light mode, and every
one of those instances passed all four gates.

CONTEXT MATTERS, so this gate is not a blanket ban:

  ALLOWED  a bare white/black that is a foreground ON A KNOWN FILL, because
           that pairing is correct in both brightness modes:
             foregroundColor:, checkmarkColor:, thumbColor:
             Color.lerp(...) toward white for a hit flash
             _spawnPop('Victory!', Colors.white)  (floats over the arena)
           ALLOWED  a bare white/black in a Canvas/Paint file. Those are art
           direction, not theme text.
           ALLOWED  app_colors.dart, which defines the AppPalette record.

  BANNED   Colors.white/black as a `color:` on a Text, Icon, IconTheme, or
           AppBar title/style. Those sit on whatever surface the theme gives
           them, so white text in light mode is white-on-near-white.

Use the theme instead: `colorScheme.onSurface`, `.onSurfaceVariant`,
`.primary`, or the appropriate `on*` counterpart of the surface behind it.

Usage: python tools/verify_no_hardcoded_colors.py [--report]
Exit code 0 = pass, 1 = fail. --report lists every hit without failing.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
TOKEN_FILE = "core/theme/app_colors.dart"

ALLOWLIST = {
    # Illustration/avatar species, aura, and clothing palettes are
    # intentionally theme-independent (Phase 3 special rule).
    #
    # The cap is an EXACT count, not a ceiling, and raising it is a deliberate
    # act: it means "I have looked at every literal in this file and each one is
    # art direction, not a theme mistake." It went 93 -> 116 when
    # `SpeciesPortraitPainter` added eight species palettes and four species
    # that previously had no entry at all (riverglass_otter,
    # prairie_ember_hare, north_star_loon were in the catalog but had no palette,
    # so they silently fell back to ember_kit). Do not round it up "to be safe" —
    # an inflated cap is how a real theme regression becomes invisible here.
    "widgets/avatar_painter.dart": 116,
    "widgets/avatar_visual_layer.dart": None,
    # Companion cosmetic + mood art. Pure geometry painting: 11 category
    # palettes (fill + accent each = 22), 12 declared colourway colours for
    # `skin/tone` and `hair/color`, 1 black for the colourway blend, 2 for the
    # shared fallback palette (written once, not inlined per use site), and 4
    # for the mood faces. The count is an EXACT reviewed total, not a ceiling --
    # see the note on avatar_painter above before raising it.
    "widgets/cosmetic_icon_painter.dart": 41,
    "core/theme/app_colors.dart": None,
    # Asset-internal / domain status scales retained as named tokens.
    "screens/journal_screen.dart": 0,
    "screens/constellation_screen.dart": 0,
}

LITERAL = re.compile(r"Color\(0x[0-9A-Fa-f]+\)")

# Phase 5: the dark-pinned top-level AppColors constants are gone from the
# token file. Any reference to them outside it is a regression that would pin
# a screen to dark mode, so the gate now fails on the *name* as well as the
# literal. Kept here (rather than only deleting the constants) so the failure
# mode is explicit when someone re-adds one.
RETIRED = re.compile(
    r"AppColors\.(bgDeep|bgCard|border|accent|success|danger|"
    r"textPrimary|textMuted|textDim|textHint)\b"
)

# Domain-scoped tokens that are intentionally brightness-independent and may be
# referenced from anywhere. Listed for documentation; the gate only checks that
# the retired names above stay unused.
DOMAIN_TOKENS = (
    "dangerSoft", "pink", "brandZoom", "accentSky", "monsterHound",
    "raidVictory", "raidVictorySoft", "raidVictoryDeep", "raidActiveDeep",
    "moodGood", "moodStruggling", "moodNeedHelp", "moodScale",
    "starfield", "pinOnline", "pinSoon", "housingMaternal", "housingDefault",
    "fellowAA", "fellowNA", "fellowSMART", "fellowWellbriety",
    "starMilestone", "starStepWork", "starCommunity", "starService",
    "starMindfulness", "starSpiritual",
)

# ---------------------------------------------------------------------------
# Phase 9: bare Colors.white / Colors.black as a theme-agnostic text color.
# ---------------------------------------------------------------------------

BASE = r"(white|black|white70|white60|white54|white38|white30|white24|white12" \
       r"|black54|black45|black38|black26|black12)\b"

# A `color:` argument anywhere on the line. Combined with the token above this
# catches TextStyle(color:), Icon(color:), IconThemeData(color:),
# AppBar title styles, and progress indicators.
MODE_PINNED = re.compile(r"\bcolor\s*:\s*(?:const\s+)?Colors\.%s" % BASE)

# Foregrounds that are legitimately white because the thing behind them is a
# known solid fill. These are correct in BOTH brightness modes.
FILL_FOREGROUND = re.compile(
    r"foregroundColor\s*:|checkmarkColor\s*:|thumbColor\s*:|Color\.lerp"
    r"|_spawnPop"
)

# Files that draw with Canvas/Paint. White and black there are art direction.
PAINTER_FILES = {
    "widgets/avatar_painter.dart",
    "widgets/cosmetic_icon_painter.dart",
    "widgets/trial_monster_painter.dart",
    "screens/constellation_canvas_3d.dart",
    "widgets/companion_guide_overlay.dart",
    "widgets/chronicle_share_card.dart",
}


def main() -> int:
    failures = []
    mode_pinned = []
    report_only = "--report" in sys.argv

    for path in sorted(LIB.rglob("*.dart")):
        rel = path.relative_to(LIB).as_posix()
        if rel.endswith(".g.dart"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        hits = LITERAL.findall(text)

        retired = sorted({m for m in RETIRED.findall(text)})
        if retired and rel != "core/theme/app_colors.dart":
            failures.append(
                "%s: references retired dark-pinned constant(s) "
                "%s" % (rel, ", ".join("AppColors." + r for r in retired))
            )

        if rel in ALLOWLIST:
            cap = ALLOWLIST[rel]
            if cap is not None and len(hits) > cap:
                failures.append(
                    "%s: %d literals exceeds cap %d" % (rel, len(hits), cap)
                )
            continue
        if hits:
            offenders = sorted({f for f in hits})
            failures.append(
                "%s: %d raw color literal(s): %s"
                % (rel, len(hits), ", ".join(offenders[:6]))
            )

        # --- mode-pinned text colors -------------------------------------
        if rel in PAINTER_FILES or rel == "core/theme/app_colors.dart":
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if not MODE_PINNED.search(line):
                continue
            if FILL_FOREGROUND.search(line):
                continue
            mode_pinned.append((rel, lineno, line.strip()))

    if mode_pinned:
        for rel, lineno, line in mode_pinned:
            msg = "%s:%d: mode-pinned text color -> %s" % (
                rel, lineno, line[:88])
            if report_only:
                print(msg)
            else:
                failures.append(msg)

    if report_only:
        print("\n%d mode-pinned text color(s)." % len(mode_pinned))
        return 0

    if failures:
        for f in failures:
            print("FAIL: %s" % f)
        print(
            "\nSee AGENTS.md and blueprints/lessons-learned.md L14. A white "
            "text color on a theme surface is unreadable in light mode and "
            "passes every other gate."
        )
        return 1

    print("PASS: no hardcoded color literals and no mode-pinned text colors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
