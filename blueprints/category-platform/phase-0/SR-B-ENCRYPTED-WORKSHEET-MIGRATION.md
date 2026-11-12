# SR-B — Lossless encrypted worksheet and sponsor-bundle migration

**State:** design-only / release NO-GO until implemented and tested  
**Priority:** P0 — private recovery writing stored outside SQLCipher  
**Parent:** [WO-SR-00](SPONSOR_RELAY_SECURITY_WORK_ORDER.md)  
**Code evidence:** `lib/screens/steps_viewer_screen.dart` (keys `steps_worksheets_v1` and `step_bundles_v1`; `_load`, `_saveWorksheet`, `_copyForSponsor`, `_bundleFor`); `lib/services/journal_crypto_service.dart`; `lib/database/recovery_database.dart`.

## Source-proven problem and protected data

The Step Viewer stores JSON answer arrays and complete sponsor bundle JSON strings in `SharedPreferences` under `steps_worksheets_v1` and `step_bundles_v1`. The bundles contain step number, title, questions/answers and timestamps. The application-level encryption and PIN/session gate used for journal entries do **not** protect these preferences. Removing them without migration would lose historical step work and the exact bytes needed to verify old signed confirmations. PR #12 only blocked implicit remote transport; it did not encrypt these local copies.

## Implementation contract — one feature slice, no cloud work

**SR-B1. Preserve legacy input.** Capture exact on-device JSON for both keys as read-only migration input. Treat malformed JSON, duplicate step numbers, partial records and missing keys as distinguishable states; never silently replace nonempty input with `{}`. Do not record answer text, hashes derived from answer text, or PINs in logs.

**SR-B2. Choose protected persistence.** Recommended default: typed tables in the existing SQLCipher Drift database with versioned step ID, sequence-preserving answers, exact original sponsor bundle bytes, local creation/edit timestamps and an explicit storage revision. If adding a table, bump `schemaVersion` from the current authoritative value, implement every upgrade hop and regenerate `recovery_database.g.dart` through build_runner. Decide whether additional `ENC2_` application-layer encryption/PIN gating is required for worksheet view/copy; *never* call `loadMasterKey` with a false claim that no existing protected data exists.

**SR-B3. Transactional migration.** In one idempotent migration coordinator:
1. Read a snapshot of both legacy keys, validate bounded decoded structure without mutating it.
2. Stage encrypted records under stable keys in a Drift transaction. Preserve original bundle JSON for signature verification; don't normalize or reserialize signed bytes.
3. Reopen and compare exact recovered strings and ordered answer lists with the legacy snapshot. Record a durable migration-complete marker only after verification.
4. Remove original plaintext preferences only after durable success. If cleanup fails, keep the encrypted data authoritative and retry deletion without duplicate records.
5. On crash, cancellation, corrupted legacy JSON or unavailable crypto key: retain original bytes, report a retryable/error state and do not falsely say migration finished.

**SR-B4. UI and export gates.** Reads/writes/copy/signoff must use the protected repository, not direct SharedPreferences. Define the unlock policy for worksheets separately from journal unlock if needed; verify app pause/background/restart revokes access. Clipboard export is explicit and disclosed, not a secure channel; warn that external clipboard history and recipient apps are outside the database boundary.

**SR-B5. Upgrade and recovery.** Test populated v13 database through v14 (or whichever version the chosen schema requires), reinstall/update preserving prefs, existing signed receipts, PIN not configured, PIN lost/secure storage inaccessible, storage full, malformed JSON, no entries, 12 populated steps, duplicate migration invocation, process death between database commit and preference deletion, and preference-delete failure. Do **not** auto-reset a PIN or generate a replacement key to overwrite history.

## Required evidence before merging code

- At least one red/green migration test for real legacy v1 JSON and exact content equality, including a crash-restart/failure path.
- Widget tests proving step answers remain editable and sponsor signature verification uses the exact preexisting bundle bytes.
- `flutter analyze` clean; full Flutter tests; all architecture invariants and both invariant self-tests; Firestore emulator unaffected.
- Device upgrade from a real populated closed-test installation with pre-upgrade offline backup, verified decryption, no plaintext preference artifacts left after successful migration.
- A privacy-policy update and rollback plan that **retains** old data if a newly written encrypted record cannot be read.

## Explicit exclusions

No new anonymous cloud reads, no Firestore sponsor relay activation, no user-data wipes, no claim of E2E security from SQLCipher alone, no non-consensual upload, and no use of synthetic data in real-device upgrade evidence. Completion of this work order does not close the other SR-C/SR-D/SR-E acceptance gates.
