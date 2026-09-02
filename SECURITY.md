# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

We release security patches only for the latest Play Closed Testing track. Historical APKs/AABs are not patched retroactively.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email **security@recoveryforall.app** (or `ghostman612@` on GitHub) with:

- Steps to reproduce
- Affected version (`Settings > About` or `pubspec.yaml` version)
- Impact assessment (e.g., data exfiltration, auth bypass, local DB decryption)

We will acknowledge within 72 hours and aim to patch within 14 days for critical issues.

We practice **coordinated disclosure** — please give us time to ship before public disclosure.

## Scope

Recovery for All is **offline-first**. The primary attack surface is *local device access*:

- Encrypted DB (`sqlcipher_flutter_libs` + key in `flutter_secure_storage` / Android Keystore)
- Biometric + 6-digit PIN gate (`JournalCryptoService`)
- No analytics, no tracking SDKs, no third-party crash reporters

Firebase (`google-services.json`) is **optional**. If present, Firestore rules enforce `request.auth != null` and alias-only writes (see `firestore/firestore.rules`). If absent, the app runs fully local.

## What We Consider Out of Scope

- Physical device compromise with unlocked OS (we cannot protect against forensic extraction on rooted/jailbroken devices)
- Denial-of-service via `verify_resources.py` link health checks (staggered, cached, no retries)

## Secure Defaults in This Repo

- `android/app/google-services.json` is **gitignored** — never commit your own file
- `android/key.properties` and `*.jks` / `*.keystore` are **gitignored** — signing keys never enter git history
- `blueprints/` and internal prompts (`AGENTS.md`, `CLAUDE.md`, `RULES.md`) contain proprietary product reasoning and are gitignored before any public mirror
