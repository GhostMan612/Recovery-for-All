---
description: Regenerate the unified code package document
---
Run `python tools/generate_code_package.py` from the repo root.

Verify: it reports the expected file count (should be 70+), and
`blueprints/recovery_all_code.md` was rewritten. Never hand-edit that
file — it is generated. Remind the user to commit it alongside any
code changes if they want the transfer package current.
