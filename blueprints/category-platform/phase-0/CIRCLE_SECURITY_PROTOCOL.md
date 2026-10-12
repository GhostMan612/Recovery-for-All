# Circle Protocol v2 — Proposed, NOT deployed

This is the exact security direction for the next execution agent. **It is not active Firestore configuration.** Do not introduce `v2` clients against `v1` permissive counter rules or flip collection readers until migrations and emulator tests pass.

## Required capabilities and low-cost architecture

**Option 1 (recommended launch-safe):** connected Circle temporarily remains read-only or is disabled **after human approval** until trusted moderation/abuse response exists. Keep local drafts. No new recurring cloud spending.\
**Option 2 (shared public feed):** Firebase Auth + ownership-aware Firestore rules + a trusted moderation capability, implemented using supported server credentials/custom claims and protected operations. If available, optional Cloud Functions can maintain aggregate counts, but this incurs operational burden and must be explicitly approved.\
**Option 3 (invitation-only circles):** separate scope and key management, with owner/participant ACLs; not a shortcut around abusive peers or deleting remote copies.

Do not mistake Firebase App Check for authorization: it reduces unauthorized client traffic but does not prevent a legitimate anonymous account from abusing a permissive rule.

## Proposed v2 collection model

```text
circle_v2/posts/{postId}
  schemaVersion=2, ownerUid, authorAlias, kind, text,
  createdAt(serverTimestamp), visibility, deletedAt?,
  supportFlag, audience, [non-sensitive optional shape]

circle_v2/posts/{postId}/reactions/{uid_kind}
  actorUid, kind, createdAt
  (doc id deterministic per actor + reaction kind, rules enforce ownership)

circle_v2/posts/{postId}/reports/{reporterUid}
  reporterUid, reasonCode, createdAt
  (private: reporters do not list the reports)

circle_v2/blocks/{blockerUid}/peers/{blockedUid}
  actorUid=blockerUid, targetUid, createdAt

circle_v2/moderation_actions/{actionId}
  serverActor, postId, action, reasonCode, createdAt
  (trusted backend only; moderator privileges NEVER from local preferences)
```

The **actual field list must be minimized and schema-validated**: reject unknown fields, missing owner, inappropriate type/length or embedded GPS, explicit email/phone/real-name fields and clients attempting server-only states. A stable client-generated event id can be used for idempotent outbox retry, but must be namespaced to an authenticated actor to prevent other users from preempting an id. `createdAt` from server timestamp for ordering; preserve a local enqueue timestamp for offline drafts.

## Remote authorization invariants

- A post can be created only with `ownerUid == request.auth.uid` and immutable owner; never permit a field chosen by a client to override the stored owner.
- Only the owner may delete/tombstone their own post. If using tombstones, a trusted job/TTL policy must define cleanup; Firestore `allow delete` alone does not force other devices to immediately discard cached content.
- No arbitrary `request.auth != null` update to counters or moderation status. Reaction doc path/fields must bind `actorUid` to `request.auth.uid`, and write semantics must define one reaction per actor/post/kind (or a toggle) without unlimited increments.
- Normal clients may not enumerate reports on others or see reporter identities.
- Reports do not directly hide a post; they enter a private review workflow. Moderation actions require a real server-issued role and a tested policy for compromised admin credentials.
- Block list controls rendering, mentions, engagement and any DM surface; client-side block alone does not prevent collection read in a globally shared feed, so privacy promises must explain that distinction.
- Read security by audience: publicly shared posts are visible to signed-in users; invitation-only material requires membership ACLs enforced in Firestore or a separate trusted service. Do not merely filter local UI after broad reads.

## Outbox and client state machine

```text
local draft --user confirms explicit sharing--> queued
  queued --network/send attempt--> sending
  sending --authoritative ack--> shared
  sending --error/time-out--> retryable (never 'shared')
  shared --owner requests delete--> deleting
  deleting --server accepted & snapshot converged--> deleted
  deleting --offline/error--> delete pending (honestly labeled)
```

The locally encrypted database remains the primary durable record; replace blanket local hard-deletion of mirrored posts with a status tombstone / source-of-truth row as appropriate to existing migration. Treat read-after-write and stream replays as normal. Stable event ids must survive process death/restart.

## Handling legacy v1 collection safely

Current `community_feeds` documents have no authenticated immutable `ownerUid`. Do not infer owner from an alias, local `isMine`, body hash or document ID. Prepare **one explicitly approved** strategy: (A) archival read-only legacy feed plus privacy disclosure and owner-assisted takedown, or (B) a secure consented migration backed by authentic mapping evidence, or (C) retirement with clearly communicated user-data outcome. Build a data-export/rollback path where legal and feasible.

Introduce `circle_v2` next to legacy; do not swap the Firestore rules live until a tested compatible app is available. Legacy v1 must not continue as an abusive alternative endpoint after v2 launches. Any rules deployment should be done by the human/authorized agent separately, with roll-forward/rollback and emulator evidence.

## Required verification

- Unauthenticated create/read/modify forbidden except explicitly public, no-Firebase reads if defined.
- A cannot rewrite/delete B; A cannot force post visibility or impersonate B as owner.
- A cannot report as B; A cannot see report identities; user-writable prefs do not change server authority.
- 100 repeated posts with same actor/id do not multiply records; 100 repeated reactions are still at most one per `(post,uid,kind)`.
- On multiple devices, author deletes; cached copies clear under documented policy; offline deletion shows pending until success.
- Authentication loss/reinstall, malformed payload, weird timestamps and rate limiting fail safely.
- Crisis/SOS UX and local journals remain available even if Firestore rejects every call.
