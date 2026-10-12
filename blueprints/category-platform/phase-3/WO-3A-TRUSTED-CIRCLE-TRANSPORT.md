# WO-3A — Recovery Circle Protocol: Trust, Outbox and Ownership

## Required prerequisite

Phase 0 has **actually** deployed and verified a server-authoritative Circle v2 protocol and a consent policy, or the team explicitly chooses a safe local-only/no-remote-write implementation. There must be no client-writable 'moderator' privilege, unlimited counter updates or unowned shared feed documents. Reuse the P0 work—do **not** design competing Firestore collections or overwrite verified rules.

## File map

| Path | Change |
|---|---|
| `lib/services/community_feed_service.dart` | adapt to verified P0 v2 transport; implement explicit local draft/queued/delivered/rejected/deleting/deleted state and idempotent send IDs; never equate local write with remote success |
| `lib/screens/community_feed_screen.dart` | correct delivery, retry, delete and reporting UX; show connectivity/consent badges only where meaningful |
| `lib/database/recovery_database.dart` | additive outbox/receipt/consent fields only where not already in P0; no duplicate tables |
| `firestore/firestore.rules` | **only** reviewed delta against P0 trusted protocol; never loosen owner/reaction/report rules |
| **NEW** `lib/features/circle/domain/circle_event.dart`, `circle_member.dart` | separate local author identity vs public alias and remote actor/ACL metadata |
| **NEW** `lib/features/circle/data/circle_sync_coordinator.dart` | encrypted outbox, dedup, retry, conflict, delete tombstones, auth expiry handling |
| `test/community_feed_service_test.dart` + **NEW** `test/circle/circle_sync_coordinator_test.dart` | local/offline and actor conditions |
| `firestore/tests/` (if P0 established) | emulator hostile-client assertions and role authorization tests |

## Stateful behavior

1. New content starts as **local draft**. Explicit preview/consent then `queued` until network/identity ready. A genuine server acknowledgement changes it to `published`. Rejection/timeouts are distinguishable.
2. Stable post ID persisted across retries. Define ownership using server-authenticated identity, not public alias. Actor IDs cannot be client-forged. Use server-only moderation role/claims and field allowlist.
3. Deletion is a server operation with local tombstone, remote acknowledgement, device convergence and a transparent disclosure about other people's screenshots and caches. Old legacy v1 content requires explicit retention/migration decision; do not infer owner by alias.
4. A reaction is uniquely keyed to actor and post (and type policy), with anti-replay and rate limiting. No blind `FieldValue.increment` on global mutable counters by every authenticated user.
5. `block/report/mute` are per-actor privacy controls; a report reaches trusted moderation, is not shared with offender, and retains necessary audit according to approved retention policy.
6. Crisis content handling offers immediate local resources; never promise a staffed live responder. Peer responses are not emergency services.
7. When connectivity drops, draft/send/delete states remain honest and deterministic; all core recovery tools remain operational.

## Security acceptance

Malicious A cannot impersonate B, author-delete B's post, forge moderator role, alter reaction count without allowed actor doc, read confidential reports, see blocked accounts, or retrieve precise GPS through payload. Test rule changes with emulator A/B/moderator identities and simulated offline replay. If no backend supports server authority, **do not ship connected Circle expansion**.
