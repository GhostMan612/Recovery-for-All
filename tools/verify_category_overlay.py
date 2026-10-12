#!/usr/bin/env python3
"""Read-only standard-library integrity checker for Recovery for All phases 1-4 overlay.

Usage (in extracted Recovery for All repo):
    python tools/verify_category_overlay.py
    python tools/verify_category_overlay.py --skip-sources  # validate a staging extract
    python tools/verify_category_overlay.py --root "C:\\Recovery for All"

Does not run Flutter, Gradle, Git or network commands. No files modified.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

MANIFEST = "PHASES_1_TO_4_OVERLAY_MANIFEST.json"
REQUIRED_REPO_PATHS = [
  "RULES.md", "AGENTS.md", "lib/services/xp_engine_service.dart",
  "lib/services/recovery_pet_service.dart", "lib/screens/pet_trials_screen.dart",
  "lib/services/raid_service.dart", "lib/database/recovery_database.dart",
  "lib/services/meeting_finder_service.dart", "lib/screens/meeting_map_screen.dart",
  "lib/services/community_feed_service.dart", "lib/screens/community_feed_screen.dart",
  "android/app/src/main/kotlin/com/recoveryforall/MainActivity.kt", "android/settings.gradle.kts",
]


def validate_schema(node, schema, context="$"):
    """Subset of JSON Schema checks: enough to validate the included flat/nested examples.

    Not a complete Draft 2020-12 validator; production code must use full parity tests.
    """
    if "const" in schema and node != schema["const"]:
        raise ValueError(f"{context}: expected constant {schema['const']!r}")
    if "enum" in schema and node not in schema["enum"]:
        raise ValueError(f"{context}: not in enum {schema['enum']!r}")
    t = schema.get("type")
    tests = {
        "object": lambda x: isinstance(x, dict),
        "array": lambda x: isinstance(x, list),
        "string": lambda x: isinstance(x, str),
        "integer": lambda x: isinstance(x, int) and not isinstance(x, bool),
        "number": lambda x: isinstance(x, (int, float)) and not isinstance(x, bool),
        "boolean": lambda x: isinstance(x, bool),
        "null": lambda x: x is None,
    }
    if t and (t not in tests or not tests[t](node)):
        raise ValueError(f"{context}: expected {t}, got {type(node).__name__}")
    if t == "object":
        props = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in node:
                raise ValueError(f"{context}: missing required {key}")
        if schema.get("additionalProperties") is False:
            unknown = set(node) - set(props)
            if unknown:
                raise ValueError(f"{context}: unknown properties {sorted(unknown)}")
        for k, v in node.items():
            if k in props:
                validate_schema(v, props[k], f"{context}.{k}")
    elif t == "array":
        if "maxItems" in schema and len(node) > schema["maxItems"]:
            raise ValueError(f"{context}: too many items")
        for i, val in enumerate(node):
            validate_schema(val, schema.get("items", {}), f"{context}[{i}]")
    elif t in ("string", "integer", "number"):
        if "minLength" in schema and len(node) < schema["minLength"]:
            raise ValueError(f"{context}: too short")
        if "maxLength" in schema and len(node) > schema["maxLength"]:
            raise ValueError(f"{context}: too long")
        if "minimum" in schema and node < schema["minimum"]:
            raise ValueError(f"{context}: below minimum")
        if "maximum" in schema and node > schema["maximum"]:
            raise ValueError(f"{context}: above maximum")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=None, help="Repository or staging root")
    parser.add_argument("--skip-sources", action="store_true", help="Do not require runtime repo paths (for isolated ZIP validation)")
    args = parser.parse_args()
    root = args.root.resolve() if args.root else Path(__file__).resolve().parent.parent
    manifest_path = root / MANIFEST
    if not manifest_path.is_file():
        print("FAIL: Overlay manifest missing; extract into repository ROOT, not inside blueprints/.")
        return 2
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = manifest.get("files", [])
    seen = set()
    failures = []
    for entry in entries:
        rel = entry.get("path", "")
        p = Path(rel)
        if not rel or p.is_absolute() or ".." in p.parts or "\\" in rel or rel in seen:
            failures.append(f"Unsafe or duplicate path: {rel}")
            continue
        seen.add(rel)
        target = (root / p).resolve()
        if not target.is_relative_to(root):
            failures.append(f"Path escapes root: {rel}")
        elif not target.is_file():
            failures.append(f"Missing overlay file: {rel}")
        elif hashlib.sha256(target.read_bytes()).hexdigest() != entry.get("sha256"):
            failures.append(f"Hash mismatch: {rel}")
    if not args.skip_sources:
        for rel in REQUIRED_REPO_PATHS:
            if not (root / rel).is_file():
                failures.append(f"Missing expected existing RFA source path: {rel}")
        p0 = root / "blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md"
        if not p0.exists():
            print("WARNING: Phase 0 overlay not found. Proceed with local-only P1/P2 design; remote Circle gates remain blocked.")
    fixtures = [
        ("recovery_action_v1.schema.json", "action_check_in.json"),
        ("journey_preview_v1.schema.json", "journey_offline_synthetic.json"),
        ("circle_quest_contribution_v1.schema.json", "circle_contribution_local_only.json"),
    ]
    base = root / "blueprints/category-platform/contracts"
    for sch, ex in fixtures:
        try:
            schema = json.loads((base / sch).read_text(encoding="utf-8"))
            example = json.loads((base / "fixtures" / ex).read_text(encoding="utf-8"))
            validate_schema(example, schema)
            if example.get("synthetic", example.get("isSynthetic")) is not True:
                raise ValueError("fixture must have synthetic:true")
        except (OSError, ValueError, TypeError) as exc:
            failures.append(f"Fixture {ex}: {exc}")
    if len(entries) != len(seen):
        failures.append("Duplicate or inconsistent manifest entries")
    print(f"Overlay files: {len(entries)} | inspected root: {root}")
    if failures:
        for issue in failures:
            print("FAIL:", issue)
        return 1
    print("PASS: overlay file hashes, safe paths and synthetic contract fixtures.")
    print("NOTE: This does NOT verify runtime Flutter/Gradle/Firebase functionality, migrations or device acceptance.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
