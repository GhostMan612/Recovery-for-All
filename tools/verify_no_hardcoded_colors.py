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


def main() -> int:
    failures = []
    for path in sorted(LIB.rglob("*.dart")):
        rel = path.relative_to(LIB).as_posix()
        if rel.endswith(".g.dart"):
            continue
        hits = LITERAL.findall(path.read_text(encoding="utf-8", errors="ignore"))
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
        print("FAIL: raw color literals outside the token contract")
        for f in failures:
            print(f"  {f}")
        print(
            "\nUse Theme.of(context).colorScheme, AppColors.* tokens, or add a "
            "named token in app_colors.dart (Phase 3 classification rules)."
        )
        return 1
    print("PASS: no hardcoded color literals outside allowlist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
