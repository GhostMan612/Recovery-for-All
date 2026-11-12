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

Firebase (`google-services.json`) is **optional**. The tracked [`firebase.json`](firebase.json) selects [`firestore/firestore_v2.rules`](firestore/firestore_v2.rules) as the rules file for the next CLI deployment. [`firestore/firestore.rules`](firestore/firestore.rules) is a separate, older tracked file; do not mistake it for the configured deployment target.

The **v2 rules in source** deny unlisted operations by default; bind Circle v2 post creation and deletion to the authenticated `ownerUid`; prohibit client post updates; restrict reactions to an actor UID and approved type; and prevent client reads of reports. Legacy `community_feeds` is readable to authenticated clients but not writable under v2. Sponsor bundles are restricted by UID-bearing paths. An authenticated Firebase session, including anonymous authentication, **does not independently prove membership in a trusted Circle or a person's identity**. See the [Phase 0 Circle threat model](blueprints/category-platform/phase-0/CIRCLE_THREAT_MODEL.md) for remaining trust limitations.

**Source code and deployment are different evidence.** This document does not establish that `firestore_v2.rules` is currently deployed to any live Firebase project. Verify the active Firebase project, deployed rules revision, emulator security matrix and rollback plan before a production cutover. The app currently **disables remote Circle mutations in release builds** through `CommunityFeedService.remoteWritesDisabled`; local compose and an outbox do not prove remote delivery or deletion. Firebase network operations must also satisfy the app's explicit privacy-capability gates. Without `google-services.json`, the app cannot initialize this Firebase integration.

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
- The repository is currently **public**. `AGENTS.md`, `RULES.md`, `SESSION_HANDOFF.md` and some `blueprints/` files are tracked and publicly visible; other sensitive strategy files are deliberately gitignored. Never assume a tracked document is private.
