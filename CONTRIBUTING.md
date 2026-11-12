# Contributing to Recovery for All

> This repository is **public**, and its currently checked-in [LICENSE](LICENSE) is **MIT**, not “All Rights Reserved.” Ownership, provenance, and intended future licensing are still awaiting a decision; see [the licensing decision record](blueprints/category-platform/phase-0/LICENSE_AND_IP_DECISION.md). This document does not change the license. New feature PRs are not currently solicited; bug reports, documentation fixes, and coordinated security disclosures are welcome.

## Ways to Help

- **Report a non-sensitive bug** with `flutter doctor --verbose`, reproduction steps, and expected versus actual behavior
- **Report a security vulnerability privately** using [SECURITY.md](SECURITY.md); do not open a public security issue
- **Verify recovery resources** with `python tools/verify_resources.py` and report dead links
- **Propose a documentation correction** in an issue or focused pull request

## Contributing a Fix

1. Fork the public repository for an external PR, or request collaborator access for a direct branch.
2. Create a focused branch: `git checkout -b fix/short-name`.
3. Follow the gates in [AGENTS.md](AGENTS.md) and [RULES.md](RULES.md): run them **once, at the end of the entire plan**, not after each edit.
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   # If the Drift schema changed:
   dart run build_runner build --delete-conflicting-outputs
   # If code changed:
   python tools/generate_code_package.py
   ```
4. Stage by explicit path (`git add lib/...`); never use `git add .` or `git add -A`.
5. Open a focused PR with a change summary, verification evidence, and screenshots for UI changes.

## What We Won't Merge

- Changes that reorder the chatbot safety pipeline
- Cloud-dependent meeting finders that reintroduce `google_maps_flutter`
- Hand-edits to `lib/database/recovery_database.g.dart` or `blueprints/recovery_all_code.md`
- Tracking SDKs, analytics, or non-consensual cloud uploads

## License

The repository currently contains an [MIT LICENSE](LICENSE). Third-party assets, literature, feeds, and dependencies may have different licensing requirements. The [owner's licensing/provenance decision](blueprints/category-platform/phase-0/LICENSE_AND_IP_DECISION.md) remains pending. This contribution guide does not override the checked-in license or decide future licensing.
