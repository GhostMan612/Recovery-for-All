# Recovery Circle — threat model and existing risks

**Boundary:** community feed is alias-visible in a shared Firebase collection whenever configured, while personal writing and progress otherwise live locally. Anonymous Firebase auth establishes a session, **not** trust, moderation authority, personhood, sobriety status or eligibility for unlimited reaction grants.

## Assets

- Private reflections, recovery timelines, aliases, consent state, post text and reactions.
- A member's ability to get help, delete voluntarily shared content and avoid unwanted contact.
- Integrity of support reactions, personal rewards and moderation status.
- App uptime, offline personal tools and the correct distinction between local and shared content.

## Attacker model

An attacker may use a normal anonymous account; modify their own client; directly call Firestore REST/SDK; submit malformed posts, repeated increments, impersonating aliases, or automated reactions; reinstall to rotate anonymous UID; record/copy publicly available content; exploit stale local caches. **Do not** assume that the Flutter UI or local `SharedPreferences` impose enforceable network policy.

| Threat | Current observation | Intended control |
| --- | --- | --- |
| Post falsely looks deleted | `community_feed_screen.dart` calls `database.deleteFeedPost` only; Firestore `allow delete: if false` | Owner-bound server deletion/tombstone and two-client convergence; honest residual-cache notice |
| Self-authorized moderation | `isModerator()` reads mutable prefs; cloud status changes intentionally blocked today | Server-issued moderator role/claims, server-enforced write paths, review history |
| Reaction inflation | `allow update` to counters for any auth caller; repeated `FieldValue.increment` | Immutable per-actor/post/reaction records, bounded UI counts, no client-maintained authoritative totals |
| Author spoofing | Alias client-specified | Never treat alias as credential; immutable `ownerUid` or private owner doc bound to `request.auth.uid` |
| Harassment / abuse persistence | Local flag updates are not visible to remote moderation | Server-owned reports queue, user block/mute and timely hide action |
| Excessive disclosure | Shared posts not content-E2EE | Per-post redaction, clear audience, consent and no precise route/location fields |
| Loss during migration | Existing `community_feeds` docs lack versioned owner ID | Do **not** auto-assign ownership or silently drop old content; quarantine/migrate with opt-in/export and TTL policy |
| Device reinstall / auth reset | Anonymous UID may change | Recovery options, explicit limits, do not assert an alias guarantees recovery of remote ownership |
| Replay/offline duplicate sends | Local mirrored record can retry with same doc id | Stable idempotency key, outbox state and deterministic retry/ack |

## Data misuse boundaries

Remote Circle can never be the sole emergency contact channel. Do not reward crises, return-to-use disclosures or sensitive confession volume. No public sobriety leaderboards. Never use exact meeting coordinates, route history or last-known GPS in post payloads. Limit logs to redacted diagnostics.

## Security release rule

No expansion to cooperative multi-user RPG, roles, circles or anonymous public sharing before authorization/rules emulator tests and deletion/reaction policy pass. If trusted backend is unavailable, **propose** a local-only fall-back to the owner; do not silently flip public functionality in an overlay.
