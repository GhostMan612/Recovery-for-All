"""Self-test for invariant 14 (release signing must not fall back to debug).

A gate that cannot fail is worse than no gate. Invariant 7's self-test exists
because a regex can silently stop matching; this one exists because the rule
being enforced is a *decision* in a build file, and decisions are easy to revert
by accident while fixing something else nearby.

The bug it guards is real and shipped:

    signingConfig = if (releaseSig.storeFile?.exists() == true) releaseSig
                    else signingConfigs.getByName("debug")

That line looks like prudent defensive code. It is the opposite. A debug-signed
release AAB builds cleanly, `jarsigner -verify` reports `jar verified.`, and the
only symptom is an opaque Play upload rejection -- or none at all, if nobody
checks the signer. Every step between the mistake and finding out is green,
which is precisely why it needs a gate rather than a code review.

Each case below mutates the real file's text and asserts the rule fires. The
negative controls matter as much as the positives: a rule that flags everything
would pass every "should fail" case above while being useless.
"""
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADLE_APP = ROOT / "android" / "app" / "build.gradle.kts"

sys.path.insert(0, str(ROOT / "tools"))
from verify_invariants import check_release_signing  # noqa: E402

with io.open(GRADLE_APP, encoding="utf-8") as fh:
    REAL = fh.read()

# (case name, mutated source, should_be_flagged)
CASES = []


def case(name, source, expected):
    CASES.append((name, source, expected))


# --- the real file must pass -------------------------------------------------
case("unmodified repo file", REAL, False)

# --- reintroduce the shipped bug --------------------------------------------
case(
    "the original silent fallback, restored",
    REAL.replace(
        """            if (!keystorePresent) {
                if (RELEASE_VARIANT_REQUESTED) {
                    throw GradleException(""",
        """            if (!keystorePresent) {
                if (false) {
                    throw GradleException(""",
    ),
    True,
)

# --- delete the fatal branch entirely ---------------------------------------
case(
    "throw block removed, flag left dangling",
    REAL.replace("throw GradleException(", "val ignored = GradleException("),
    True,
)

# --- delete the release detection -------------------------------------------
case(
    "release detection removed",
    REAL.replace(
        "gradle.startParameter.taskNames.any { it.contains(\"release\", ignoreCase = true) }",
        "true",
    ),
    True,
)

# --- remove the flag name entirely ------------------------------------------
case("guard removed entirely", REAL.replace("RELEASE_VARIANT_REQUESTED", "_unused"), True)

# --- over-correction: no debug fallback at all (debug builds need a signer) --
case(
    "debug fallback deleted too",
    REAL.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("nope")'),
    True,
)

# --- the subtle one: detect release, warn, but continue with the debug key ----
# This is the shape a "helpful" refactor produces, and it is still the bug.
case(
    "detects release but only warns",
    REAL.replace("throw GradleException(", "gradleLogger.warn(").replace(
        "RELEASE_VARIANT_REQUESTED) {", "false) {"
    ),
    True,
)

# --- negative control: comments alone must not satisfy the gate -------------
# If stripping every code line but keeping the prose passed, the rule would be
# matching a comment rather than the behaviour -- the L32 failure mode.
STRIPPED = "\n".join(
    line for line in REAL.splitlines() if line.strip().startswith("//")
)
case("comments only, no code", STRIPPED, True)

failed = 0
for name, source, expected in CASES:
    hits = check_release_signing(source)
    ok = bool(hits) == expected
    if not ok:
        failed += 1
    print("%-8s %-6s %s" % ("CAUGHT" if hits else "clean", "ok" if ok else "WRONG", name))
    if hits and not ok:
        for h in hits:
            print("           -> %s" % h.split("(")[0].strip())

print()
print("Known limits of this rule, stated so the boundary is explicit:")
print("  - It is a TEXT check on build.gradle.kts. It proves the guard is")
print("    present and that a GradleException is thrown on the missing-keystore")
print("    path. It cannot execute Gradle, so it cannot prove the throw is on")
print("    the path actually taken, nor that key.properties resolves correctly.")
print("    That is still covered by the manual check recorded in AGENTS.md §5 and")
print("    lessons-learned L41: read the signer identity, don't trust the exit")
print("    code. This gate catches the REGRESSION; only the build catches the")
print("    runtime truth.")
print("  - It cannot detect a keystore that exists but holds the wrong key.")
print("    A valid-but-wrong keystore is indistinguishable from the right one by")
print("    any static check.")
print()
if failed:
    print("FAIL: %d case(s) misclassified" % failed)
    sys.exit(1)
print("PASS: invariant 14 rule discriminates all %d cases" % len(CASES))