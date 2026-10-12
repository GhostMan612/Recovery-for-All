#!/usr/bin/env python3
"""Phase-0 documentation and workflow consistency only. NOT a security test.

Run after overlay onto an existing repo: python tools/verify_phase0_contracts.py
Also supports standalone overlay smoke test with --overlay.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys


def validate(root: Path, overlay: bool = False) -> list[str]:
    errors: list[str] = []
    required = [
        'README.md', 'PRIVACY_POLICY.md', '.github/workflows/cmake-multi-platform.yml',
        'blueprints/category-platform/README.md',
        'blueprints/category-platform/AGENT_HANDOFF.md',
        'blueprints/category-platform/phase-0/README.md',
        'blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md',
        'blueprints/category-platform/phase-0/DATA_FLOW_AND_CONSENT.md',
        'blueprints/category-platform/phase-0/LICENSE_AND_IP_DECISION.md',
        'blueprints/category-platform/phase-0/CIRCLE_THREAT_MODEL.md',
        'blueprints/category-platform/phase-0/CIRCLE_SECURITY_PROTOCOL.md',
        'blueprints/category-platform/phase-0/CIRCLE_EXECUTION_WORK_ORDER.md',
        'blueprints/category-platform/phase-0/NETWORK_PRIVACY_WORK_ORDER.md',
        'blueprints/category-platform/phase-0/CI_AND_VERIFICATION.md',
        'blueprints/category-platform/phase-0/DECISION_LOG.md',
        'blueprints/category-platform/phase-0/AGENTS.md',
        'tools/verify_phase0_contracts.py',
    ]
    if not overlay:
        required += ['LICENSE', 'RULES.md', 'AGENTS.md', 'firestore/firestore.rules', 'lib/main.dart']
    for p in required:
        if not (root / p).is_file():
            errors.append(f'Missing required file: {p}')
    if errors:
        return errors
    read = lambda p: (root / p).read_text(encoding='utf-8')
    intro = read('README.md')
    privacy = read('PRIVACY_POLICY.md')
    hub = read('blueprints/category-platform/README.md')
    wf = read('.github/workflows/cmake-multi-platform.yml')
    status = read('blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md')
    for message, good in [
        ('README must link phase-0 hub', 'phase-0/' in intro and 'blueprints/category-platform/README.md' in intro),
        ('README must not claim exclusive proprietary code under existing MIT license', 'Proprietary — Recovery for All' not in intro),
        ('Privacy policy must mention startup Firebase anonymous auth', 'sign-in during startup' in privacy),
        ('Privacy policy must document weather coordinates', 'Open-Meteo' in privacy and 'latitude/longitude' in privacy.lower()),
        ('Privacy policy must document remote deletion gap', 'does not guarantee deletion' in privacy or 'without ensuring' in privacy),
        ('Hub must identify phase-0 source of truth', 'PHASE_0_STATUS_AND_GATES.md' in hub),
        ('CI must define real jobs', 'jobs:' in wf and 'runs-on:' in wf and 'steps:' in wf),
        ('CI must run analysis and tests', 'flutter analyze' in wf and 'flutter test' in wf),
        ('CI must run static phase0 verification', 'tools/verify_phase0_contracts.py' in wf),
        ('Status must not falsely assert Circle implemented', 'NOT IMPLEMENTED' in status),
    ]:
        if not good:
            errors.append(message)
    # Check local relative markdown links in all new phase0 documents and root README.
    docs = [root / p for p in required if p.endswith('.md')]
    mdlinks = re.compile(r'(?<!!)\[[^\]]+\]\(([^)]+)\)')
    for doc in docs:
        for raw in mdlinks.findall(read(str(doc.relative_to(root)))):
            target = raw.strip().split('#')[0]
            if not target or target.startswith(('https://', 'http://', 'mailto:', '#')):
                continue
            resolved = (doc.parent / target).resolve()
            if not resolved.is_relative_to(root.resolve()):
                errors.append(f'Link escapes checkout: {doc.relative_to(root)} -> {raw}')
            elif not resolved.is_file() and not (overlay and target in {'AGENTS.md', 'RULES.md','LICENSE','SESSION_HANDOFF.md','blueprints/UI-UX-themes-plan.md'}):
                # In overlay mode, target can refer to a file in the existing repo.
                if not overlay or doc.name not in {'README.md', 'AGENT_HANDOFF.md'}:
                    errors.append(f'Broken local link: {doc.relative_to(root)} -> {raw}')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--overlay', action='store_true', help='check overlay only, not a full checkout')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate(args.root.resolve(), args.overlay)
    if errors:
        for error in errors:
            print(f'FAIL: {error}')
        return 1
    print('PASS: Phase-0 documentation/CI structural contract only; no runtime or security assertions')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
