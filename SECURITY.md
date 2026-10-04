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

Firebase (`google-services.json`) is **optional**. If present, Firestore rules
enforce per-owner access by binding a **path segment** to `request.auth.uid`
(`firestore/firestore.rules`) — not a blanket `request.auth != null`. Anonymous
auth establishes *a* session, never ownership, so a rules check that only asks
whether someone is signed in authorises every authenticated user for every
document; the deployed rules instead partition sponsor bundles by uid in the
path. Community-feed writes are field-scoped so one user cannot rewrite
another's alias or body. If `google-services.json` is absent, the app runs fully
local and no Firestore traffic occurs at all.

These rules are **deployed** to `recovery-for-all-c2ee8` via
`firebase deploy --only firestore:rules`, which requires the repo's
`firebase.json` (it is minimal on purpose — firestore rules only). Re-deploy
from source rather than editing in the console, or the console copy and the
repo will diverge again.

## Peer-to-Peer Attestation — What It Does and Does Not Prove

The fellowship QR handshake (`FellowshipAttestationService`) is a three-leg
Ed25519 nonce challenge/response over a per-install key in
`flutter_secure_storage`, held separately from the sponsor signing key. Each side
ends up holding a signature from the other over **both** nonces, and the 24-hour
reward cooldown is keyed on the peer's **public key**, not the peer-chosen
display alias.

**It is not identity verification.** There is no server and no third party, so
it proves *contemporaneous presence between two keys*, nothing more:

- One person with two phones can complete an exchange with themselves.
- A reinstall or a cleared keystore produces a new key, which is a new peer as
  far as the cooldown is concerned.
- It cannot establish that a key belongs to a real-world person, or that two
  keys belong to different people.
- Unsigned and legacy payloads are **refused**, not downgraded to a weaker path.

What it does buy is a real cost on farming the reward and an audit trail that
means something. Anything that needs to know *who* someone is requires a server
or an out-of-band check, neither of which exists here. Please do not describe
this feature as identity verification.

## What We Consider Out of Scope

- Physical device compromise with unlocked OS (we cannot protect against forensic extraction on rooted/jailbroken devices)
- Denial-of-service via `verify_resources.py` link health checks (staggered, cached, no retries)

## Secure Defaults in This Repo

- `android/app/google-services.json` is **gitignored** — never commit your own file
- `android/key.properties` and `*.jks` / `*.keystore` are **gitignored** — signing keys never enter git history
- `blueprints/` and internal prompts (`AGENTS.md`, `CLAUDE.md`, `RULES.md`) contain proprietary product reasoning and are gitignored before any public mirror
