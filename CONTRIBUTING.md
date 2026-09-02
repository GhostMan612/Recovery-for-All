# Contributing to Recovery for All

> This repo is **proprietary** (`LICENSE` — All Rights Reserved) and not currently accepting pull requests that introduce new features. Bug reports, security disclosures, and documentation fixes are welcome.

## Ways to Help Without Opening a PR

- **File an issue** with `flutter doctor --verbose`, reproduction steps, and expected vs actual behavior
- **Report a security vulnerability** via `SECURITY.md` (do not open a public issue)
- **Verify recovery resources** — run `python tools/verify_resources.py` and report dead links

## If You Have Been Invited to Contribute

1. Fork is disabled for the private repo. Ask for a collaborator invite.
2. Create a feature branch: `git checkout -b feat/short-name`
3. Follow the gates in `AGENTS.md`:
   ```bash
   flutter pub get
   flutter analyze          # must be "No issues found"
   flutter test
   dart run build_runner build --delete-conflicting-outputs  # if you touched Drift schema
   python tools/generate_code_package.py
   ```
4. Commit by explicit path (`git add lib/...`) — never `git add .`
5. Open a PR with screenshots for UI changes and test evidence for logic changes

## What We Won't Merge

- Changes that reorder the safety pipeline (`chatbot_screen.dart:72`)
- Cloud-dependent meeting finders that reintroduce `google_maps_flutter`
- Hand-edits to `lib/database/recovery_database.g.dart` or `blueprints/recovery_all_code.md`
- Additions that add tracking SDKs, analytics, or non-consensual cloud uploads

## License

By contributing, you agree that your contributions will be licensed under the same proprietary license as the project unless a separate CLA is signed.
