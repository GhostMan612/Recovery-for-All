# Privacy Policy — Recovery for All

**Effective:** September 1, 2026  
**Contact:** privacy@recoveryforall.app

Recovery for All is built on one principle: **your recovery data stays on your device by default.** No ads, no analytics, no tracking identifiers, no sale of data.

## Summary

- **Offline-first:** Journal, counters, wellness check-ins, pet state, and constellation live in an encrypted Drift/SQLCipher DB on device. Keys are stored in `flutter_secure_storage` (Android Keystore / iOS Keychain).
- **Optional cloud sync:** If you add `android/app/google-services.json`, Firestore mirroring is enabled for Community Feed, sponsor bundles, and care alerts. If you don't, the app runs fully local. You can delete local data at any time via Android Settings → App Storage.
- **No analytics / crash reporting** is bundled in release.

## Data We Process On Device

| Data | Where It Lives | Encrypted? |
|------|----------------|------------|
| Journal entries, mood ratings | Drift `journal_entries` | Yes (SQLCipher + PIN-derived key) |
| Sobriety counters, wellness, goals, pet `recovery_pets` + `pet_events` | Drift | Yes (DB-level) |
| PIN / biometric gate | `flutter_secure_storage` + `local_auth` | OS-secured |
| GPS for Meeting Finder | Transient in memory; last fix cached in `shared_preferences` | No (ephemeral) |
| GGUF model files | `getApplicationDocumentsDirectory()/gguf_models` | No (public models) |

## Permissions

| Permission | Why | Required? |
|------------|-----|-----------|
| `ACCESS_FINE_LOCATION` | Find nearby meetings, 150m attendance check-in | No — app falls back to Twin Cities |
| `ACTIVITY_RECOGNITION` | Pedometer-verified walks (500 steps/30 min) | No — manual walk button remains |
| `POST_NOTIFICATIONS` | Gentle daily reminder, SOS foreground service | No |
| `USE_BIOMETRIC` | App lock | No |

Location is **never** uploaded. Distance checks for attendance happen on device via `Geolocator.distanceBetween`.

## Firebase (Only If You Configure It)

If `google-services.json` is present, the app enables anonymous auth
`FirebaseAuth.instance.signInAnonymously()`. Anonymous auth gives an install a
**session**, not an identity you can authorise against — being signed in is not
permission — so the Firestore rules partition access by binding a path segment
to `request.auth.uid`.

Collections:

- `community_feeds` — alias-only posts (rules reject real names / phone / location). Masked counts only. Writes are field-scoped, so a post cannot be rewritten to change its author.
- `sponsor_bundles` — Ed25519-signed check-in bundles, encrypted payloads, partitioned by **owner's uid in the path** (`sponsor_bundles/{ownerUid}/bundles/…`), so no authenticated user can read or write another user's bundle.
- `care_alerts` — **write-only** (`allow read: false`). Client cannot query this collection.
- `consultation_events` (planned) — 7th Tradition external routing logs are not stored.

Firestore rules: `firestore/firestore.rules`, deployed to `recovery-for-all-c2ee8`
via `firebase deploy --only firestore:rules` (the repo's `firebase.json` is
required for that and is deliberately minimal). We recommend enabling **App
Check** before open release.

**Known gap:** the ownership-partitioned bundle paths mean a *cross-account*
sponsor relay is not currently reachable; it would need a `sponsor_code` custom
claim that does not exist yet. The offline messenger path is unaffected and is
the default. See `SponsorLinkService.orphanedRelayDocIds()` and `AGENTS.md`
invariant 11.

## Data Safety for Google Play

- **Data collected:** None by default; if Firebase enabled, anonymous auth UID + alias + timestamp for feed posts
- **Data shared with third parties:** None
- **Encryption in transit:** HTTPS for tile downloads, meeting feeds, and Firestore (when enabled)
- **Data deletion:** Uninstall the app or Clear Storage deletes all local data. Firestore data can be deleted via email request to privacy@recoveryforall.app.

## Children's Privacy

This app is not directed at children under 13 and does not knowingly collect data from children.

## Changes

We will bump this file and the in-app `Settings > Privacy` link when policy changes. Continued use after an update constitutes acceptance.

---

*This policy does not constitute legal advice. Have counsel review before publishing to Play Console as your hosted privacy policy URL.*
