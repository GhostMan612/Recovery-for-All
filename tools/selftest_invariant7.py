"""Self-test for invariant 7's regex.

A gate that cannot fail is worse than no gate, so this proves the pattern
discriminates the real bug from the legitimate shapes that a naive
`\\$identifier\\.` check wrongly flagged on the first attempt.

It also declares, as `KNOWN_GAPS`, the shapes the pattern provably CANNOT catch.
That block is load-bearing: it is the written record of where this gate stops.
Do not widen the regex to close them -- that fails the build on `'$modelId.gguf'`.
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

# Shapes the pattern CANNOT catch, listed so the boundary is explicit rather
# than accidental. The Oct-2026 attestation bug was exactly this:
#
#   signingMessage = '$role.wire|$alias|$nonceA|$nonceB'
#
# All three legs then signed an IDENTICAL string, because Dart interpolates
# only the identifier and `.wire|...` was literal text -- so the role was not
# covered by the signature at all, and an answer signature verified as a
# confirm. The pattern above does not flag it, and CANNOT: `'$modelId.gguf'`
# is the same shape and is legitimate code, already listed as a must-not-flag
# case above. Broadening the regex to catch one would fail the build on the
# other.
#
# These are therefore covered by an ASSERTION, not a pattern: the protocol test
# asserts the exact expected signed string, and a tamper test rewrites one
# specific field and requires verification to fail. See lessons-learned L36.
KNOWN_GAPS = [
    "'$role.wire|$alias|$nonceA|$nonceB'",
    "'$kind.payload'",
    "'$prefix.suffix'",
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

for source in KNOWN_GAPS:
    hit = bool(BAD_INTERPOLATION.search(source))
    if hit:
        failed += 1
        print("%-8s %-6s %s" % ("CAUGHT", "ok", source))
    else:
        print("%-8s %-6s %s   <- covered by an assertion, not by this regex" % (
            "clean", "gap", source))

print()
print("Note: %d known gap(s) above are NOT covered by this pattern and never" % len(KNOWN_GAPS))
print("      can be, without breaking the must-not-flag cases. Do not 'fix' the")
print("      regex to close them -- that is what breaks '$modelId.gguf'.")
print()
if failed:
    print("FAIL: %d case(s) misclassified" % failed)
    sys.exit(1)
print("PASS: invariant 7 pattern discriminates all %d cases" % len(CASES))
