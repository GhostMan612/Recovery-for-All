# WO-SR-00 — Secure Sponsor Relay and Worksheet Privacy

**Status:** BLOCKED / DESIGN ONLY — no backend deployment, consent expansion or cloud relay enablement authorized  
**Priority:** P0 privacy + P1 broken delivery  
**Scope:** Sponsor/step-work transport and local worksheet storage. Preserve direct phone, copy/export and offline recovery workflow.

## 1. Verified remote-source findings (2026-11-11)

1. `lib/screens/steps_viewer_screen.dart::_saveWorksheet` serializes the answers map to `SharedPreferences` (`_worksheetKey`), not the encrypted journal database. `_copyForSponsor` also persists `step_bundles_v1` in preferences. Treat these as sensitive plaintext at rest until a migration proves otherwise.
2. `_bundleFor` constructs JSON containing step `text`, `answers`, `title` and `ts`. `SponsorLinkService.shareBundleViaCloud` writes that JSON directly under a `bundle` string field, not as an E2E-encrypted ciphertext. The visible “Bundle sent to sponsor via cloud” message would mean at most a successful Firestore write, not verified sponsor receipt.
3. `_ownerBundles(uid)` writes to `sponsor_bundles/{uid}/bundles/{docId}`. Checked-in `firestore/firestore_v2.rules` grants owner creation only at `sponsor_bundles/{uid}`; it has no nested `/bundles/{docId}` allow statement. Under those rules this actual client write is denied. Existing emulator matrix covers only the *parent* document.
4. `watchPendingBundles` queries `sponsorBundles/{sponsorUid}/inbox`, while `signBundleViaCloud` updates that inbox and `listenForConfirmation` watches the sponsee's *owner* bundle. No trusted owner-to-inbox fanout or signed-confirmation return path was identified in the inspected service. Client-side sponsorCode is not a verified identity or authorization credential.
5. The repo stores `firestore_v2.rules` in `firebase.json`, but the **active deployed ruleset has not been independently verified** in this audit. Never infer runtime denial or protection merely from tracked source.
6. Clipboard export in `_copyForSponsor` deliberately carries readable worksheet data as a user-directed action. It must be disclosed as such; it is not a cloud E2E-encryption mechanism.

**Evidence anchors:** `lib/screens/steps_viewer_screen.dart` (`_saveWorksheet`, `_bundleFor`, `_copyForSponsor`), `lib/services/sponsor_link_service.dart` (`_ownerBundles`, `_sponsorInbox`, `shareBundleViaCloud`, `watchPendingBundles`, `signBundleViaCloud`, `listenForConfirmation`), `firestore/firestore_v2.rules`, `test/rules/firestore_v2_security_matrix.mjs`.

## 2. Mandatory design decisions before implementation

- **Recipient identity:** How is sponsor identity bound to an authenticated UID and an independently validated public key? Pairing-code/alias lookup alone is inadequate.
- **Cryptography:** Define E2E authenticated encryption, separate recipient encryption key, key rotation/loss, associated data, versioned envelopes and recovery strategy. Ed25519 signing is not a replacement for an encryption protocol.
- **Scope of user consent:** Require a specific disclosure and opt-in for sending step-work/answers to a sponsor or relay. Generic cloud backup authorization is not enough.
- **Retention:** Agree on receipt TTL, deletion on revocation/unlink, and whether either participant may retain encrypted historical copies.
- **Legacy preference migration:** Preserve old worksheet answers. Define atomic migration to protected storage, rollback, duplicate reconciliation and failure recovery before deleting plaintext preferences.
- **Cloud topology:** Choose and audit an authenticated server-side fanout and reply transport (or an explicitly offline/manual-only product), never broad anonymous reads or path permissions.
- **Delivery truth:** Define states local-only, queued, committed, recipient-received, signed, imported, failed/expired. Do not show “sent to sponsor” on commit alone.

## 3. Implementation workchain — separate PRs

### SR-A — Immediate containment and truthful UI (first code PR)

- Keep relay disabled/fail-closed in release until its entire security contract is satisfied.
- Distinguish “copied to clipboard” from remote document stored, sponsor received and signed.
- Preserve manual copy/share, offline steps and crisis access; show an explicit, actionable cloud-unavailable state.
- Regression: no Firestore write without *specific* sponsor relay consent and verified remote readiness, even if generic cloudSync is granted. No false delivery toast.

### SR-B — Worksheet at-rest migration

- Inventory `_worksheetKey`, `step_bundles_v1`, journal PIN/secure key lifecycle, device backup behavior and export paths.
- Write versioned encrypted records into the existing protected persistence contract; migrate legacy preferences one-time and atomically.
- Crash/restart tests, PIN/key-loss tests, v1→current database upgrade preservation, large worksheet inputs, idempotent restart.
- Never silently discard or overwrite old answers; plaintext deletion only after verification that recovery succeeds.

### SR-C — E2E envelopes and recipient binding

- Enroll and verify recipient encryption public key separately from Ed25519 signing identity.
- Encrypt private step text/answers before transport; envelope contains only strictly necessary routing metadata.
- Authenticated, owner-scoped upload; sponsor read limited to cryptographically bound recipient UID; opaque stored payload; signed receipt bound to bundle hash and sender.
- Spoofed sponsor codes, alias collisions, replay and swapped-encryption-key attempts must fail closed.

### SR-D — Verified transport, acknowledgement and cleanup

- Server-authorized owner-to-inbox fanout; transaction/idempotency key and acknowledgement from recipient.
- Durable status machine with offline retry, revocation, cancellation, partial failure and reconnect deduplication.
- Sponsor signs original plaintext locally, returns signed receipt via authenticated owner-scoped channel.
- TTL, retention, unlink cleanup, deletion visibility, auditable errors and telemetry without sensitive payloads.

### SR-E — Security matrix, release and deployment gate

- Firestore emulator tests **at the exact client paths**, not substitute parent documents.
- Positive/negative cases: sponsee→owner upload, sponsor→own inbox read, third-party read/write denied, unauthorized recipient, field mutation, duplicate message, stale/future replay, revocation, update/delete, encrypted payload shape, expired records.
- Flutter unit/widget tests for consent, UI delivery statuses, migration, fail-closed errors and offline regression.
- End-of-plan batch: `flutter analyze`, `flutter test`, project invariants and selftests, emulator security matrix.
- Human operator must verify Firebase project and live rules fingerprint, deployment rollback, signed Android release on representative devices, and explicit user-facing privacy language **before** marking production safe.

## 4. Out of scope / no-go

- No blanket `allow read, write: if request.auth != null` rules for sponsor payloads.
- No plaintext step-work cloud upload or unverified recipient by pairing-code alone.
- No implicit cloud send when user merely copies a local step worksheet.
- No destructive wipe of preferences, migration guessing or unreviewed remote activation.
- No conflation of server-stored data with delivered, viewed or signed data.

**Completion definition:** This document is a work order, not a functioning relay. Each later code PR must state exact artifacts, evidence, security assumptions, unverified items and rollback.
