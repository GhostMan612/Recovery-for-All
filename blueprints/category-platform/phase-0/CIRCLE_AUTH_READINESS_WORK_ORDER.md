# WO-CIRCLE-AUTH — Verified Firebase connection-state lifecycle

**State:** Design only / requires implementation and two-device sign-off  
**Priority:** P1 remote-state truth / network privacy  
**Parent:** [WO-P0-CIRCLE](CIRCLE_EXECUTION_WORK_ORDER.md)  
**Baseline:** Recovery for All `main` `2a763ef6fafdfa9af64d8615691d8292279bb77a`

## Source-confirmed inconsistency

`lib/services/community_feed_service.dart` defines `remoteReady` and
`isRemoteAvailable()` as a boolean network-readiness signal. Its
`initPrivacyListener` calls `onGrantCloud()` directly whenever current-session
`cloudSync` authorization is granted, and `onGrantCloud()` sets
`remoteReady = true`. Neither callback establishes that Firebase SDK
initialization succeeded, that a valid anonymous user exists, or that a
Firestore listener has connected. The actual `_ensureAuth` code may sign in
later and fail independently. `lib/main.dart` initializes Firebase on boot,
but *does not sign in* unless a current-session cloud grant exists (and
fresh launches normally lack one). `CircleConnectionStatus` already has
`localOnly`, `connecting`, `error`, and `connected` semantics, so the boolean
can contradict the truth displayed by a specific feed instance.

**This does not mean remote publishing is enabled:** the release guard
`CommunityFeedService.remoteWritesDisabled` remains true, and this work
order must preserve that guard.

## Implementation design, in order

**A1 — Define state, not intent.** Treat consent as *permission to attempt* a
connection, not evidence of an established one. Expose one read-only
connection snapshot: `localOnly`, `consentedUninitialized`,
`authenticating`, `authenticated`, `listening`,
`transientFailure`, `revoked` (names are proposed), with UID/session
identity, last transition and explicit retry. Never convert `granted` to
`connected` without a successful SDK/auth/listener gate.

**A2 — Reauth and revocation.** After consent, initialize Firebase only where
configured, then perform anonymous sign-in or refresh, validate the resulting
currentUser, and attach subscribed reads only after auth succeeds. Sign-in
failure must preserve local drafts and surface a retryable status. Revocation
must synchronously block network operations and unsubscribe; stale async
successes must not resurrect a connection after deny, navigation or process
restart. Use monotonic attempt IDs/generation tokens around every pending
Future/stream callback.

**A3 — Keep two boundaries separate.** `cloudSync` authorizes Firebase
community authentication/reads; `circleShare` additionally authorizes
outbound social writes, but **release writes remain disabled** until C1–C4
trusted server rules, deletion, moderation and receipt security are accepted.
Do not claim any journal encryption/backup or multi-device journal sync.

**A4 — Tests and acceptance.** Host tests must cover cold start with persisted
old granted preference, after-consent auth failure, retries, no Firebase SDK,
sign-out/token expiry, disconnected listener, two rapid consent reversals,
grant racing with disposal, offline recovery and local-only UI. Emulator tests
must verify auth scopes at actual Firestore client paths. Two-device sign-in
and connection-state smoke tests plus packet/network denial checks remain
required before release claims.

## Closeout

Show the exact Dart files, test evidence, CI SHA, actual Firebase project and
rules fingerprint, and device screenshots confirming that a granted
permission is never represented as a completed connection before auth.
Preserve fail-closed social writes and local journal access. No Firebase deploy
or signed Android acceptance is authorized by this document.
