# WO-3B — Cooperative Recovery Adventures (without unhealthy competition)

## Core design

Allow a user to create/join a small invited Circle and volunteer for lightweight shared intentions. Example prompts:

- **Ground Together** — choose a private calming technique; send only a consented coarse 'I participated' signal.
- **Prepare a Good Week** — members complete a self-selected support intention; no requirement to identify meetings or providers.
- **Connection Quest** — send support words to the circle *without* collecting message volume or awarding reaction-count XP.
- **Show Up for Yourself** — complete any private recovery action, share optional generic support signal, no corroboration claim.

Progress is qualitative or capped collective milestones with equal-access alternatives; no pressure to disclose illness status, physical location, exact meeting or journal text. No rewards for an individual receiving/eliciting likes. A 'Circle Success' celebration must be private to willing participants.

## Proposed files

- **NEW** `lib/features/circle/domain/cooperative_quest.dart`, `quest_membership.dart`, `quest_contribution.dart`.
- **NEW** `lib/features/circle/application/cooperative_quest_coordinator.dart`: stable `(questInstanceId, actorId, contributionKind)` uniqueness, membership and consent validation, contribution receipts.
- **NEW** `lib/features/circle/ui/cooperative_quest_card.dart`, `circle_quest_detail_screen.dart`: accessible join/leave, pause, optional self/private quest alternative.
- `lib/features/progression/application/recovery_action_coordinator.dart`: *only* one optional local bounded action acknowledgement, triggered by accepted Circle contribution receipt and already unique per actor/quest; do not pass private act metadata to Circle.
- `lib/services/community_feed_service.dart`: isolated message adapter, no direct global mutable reward counts.
- **NEW** `test/circle/cooperative_quest_test.dart` + Firestore emulator contribution rules tests.

## Protocol

`CircleQuestContributionV1` transmits an opaque quest instance ID, actor-bound pseudonym or UID known to backend, coarse intent ID, consent policy version, client idempotency ID and allowed public visibility. No source action type (journal/meeting), contents, date of sober start, lat/lon, route or device identifiers. Server must enforce membership, rate limits, replay uniqueness and moderation.

The transport contribution is a Circle projection, distinct from the local `RecoveryAction` even if associated with one; server attestation verifies only membership/receipt, not sobriety, in-person presence or medical outcomes. If the contribution is linked to an already rewarded `RecoveryAction`, its acceptance/acknowledgment must not issue another XP/Sparks award. If the user performs a separately eligible action, create that action once with its stable event ID and route all eligible rewards through the shared ledger. Untrusted remote contribution cannot directly mint unlimited local XP. Local quest completion can occur without remote acknowledgment, but remote celebration remains pending until acknowledged.

## Gates

1. Two identities: can't contribute for another UID, nonmember can't read, removed member can't write.
2. 100 same contribution replays: at most one recorded contribution; at most one reward receipt for its underlying eligible action, with no second award for a linked action already credited.
3. Offline mode: local invitation view and pending intent are accurately labeled, never sent before consent.
4. Leave/delete/mute: no lingering public identity or forced loss of private quest progress.
5. No-game mode and screen reader: full Circle support still available without cooperative quests.
