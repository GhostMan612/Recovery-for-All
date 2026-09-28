#!/usr/bin/env python3
"""Gate: no new raw color literals outside the token file.

Fails when any lib/ file other than the theme token file introduces
Color(0x...) literals, or when the allowlisted illustration files grow.
Usage: python tools/verify_no_hardcoded_colors.py
Exit code 0 = pass, 1 = fail.
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
    "widgets/avatar_painter.dart": 93,
    "widgets/avatar_visual_layer.dart": None,
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



def main() -> int:
    failures = []
    for path in sorted(LIB.rglob("*.dart")):
        rel = path.relative_to(LIB).as_posix()
        if rel.endswith(".g.dart"):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        hits = LITERAL.findall(text)

        retired = sorted({m for m in RETIRED.findall(text)})
        if retired and rel != "core/theme/app_colors.dart":
            failures.append(
                f"{rel}: references retired dark-pinned constant(s) "
                f"{', '.join('AppColors.' + r for r in retired)}"
            )

        if rel in ALLOWLIST:
            cap = ALLOWLIST[rel]
            if cap is not None and len(hits) > cap:
                failures.append(
                    f"{rel}: {len(hits)} literals exceeds cap {cap}"
                )
            continue
        if hits:
            offenders = sorted({h for h in hits})
            failures.append(
                f"{rel}: {len(hits)} raw literals -> {', '.join(offenders[:4])}"
            )

    if failures:
        print("FAIL: color contract violated")
        for f in failures:
            print(f"  {f}")
        print(
            "\nUse Theme.of(context).colorScheme slots, or a named domain token "
            "in app_colors.dart (Phase 3 classification rules). Retired dark-pinned "
            "constants must not return (Phase 5); domain tokens such as "
            f"{', '.join(DOMAIN_TOKENS[:6])}, ... are allowed."
        )
        return 1
    print("PASS: no hardcoded color literals outside allowlist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
