"""Self-test for invariant 7's regex.

A gate that cannot fail is worse than no gate, so this proves the pattern
discriminates the real bug from the four legitimate shapes that a naive
`\\$identifier\\.` check wrongly flagged on the first attempt.
"""
import re
import sys

BAD_INTERPOLATION = re.compile(r"""\$[A-Za-z_]\w*\.[A-Za-z_]\w*(?:\s*\(|\s*\.)""")

# (source string, should_be_flagged)
CASES = [
    # --- the actual shipped bug -------------------------------------------
    ("title: Text('Welcome, $ref.watch(dashboardDataProvider).username')", True),
    ("'${a} $widget.build()'", True),
    ("'x $p.name.y'", True),
    # --- legitimate code a naive check would wrongly flag ------------------
    ("label: '$title. $subtitle'", False),          # sentence separator
    ("File('${dir.path}/$modelId.gguf')", False),   # file extension
    ("tablePrefix != null ? '$tablePrefix.' : ''", False),
    ("'total: ${count} items'", False),             # correct brace usage
    ("'$name'", False),                             # plain interpolation
    ("'Costs $5 or $name'", False),                 # money + bare variable
    ("'100% $done'", False),
]

failed = 0
for source, expected in CASES:
    hit = bool(BAD_INTERPOLATION.search(source))
    ok = hit == expected
    if not ok:
        failed += 1
    print("%-8s %-6s %s" % (
        "CAUGHT" if hit else "clean",
        "ok" if ok else "WRONG",
        source,
    ))

print()
if failed:
    print("FAIL: %d case(s) misclassified" % failed)
    sys.exit(1)
print("PASS: invariant 7 pattern discriminates all %d cases" % len(CASES))
