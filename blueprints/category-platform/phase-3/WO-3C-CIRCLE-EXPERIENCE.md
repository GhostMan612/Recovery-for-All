# WO-3C — Circle Interface: From Feed to Supportive Community

## UX layout

- **My Circle:** compact private home with accepted member count (not public rank), clear sharing status, and optional support intention.
- **Support Feed:** chronological posts, accessibility-first reaction semantics (Strength, Proud, Respect), visible local/delivered indicators, mute/report/author-delete, no sober-duration counters or 'trending trauma'.
- **Shared Adventure:** 1–3 opt-in ongoing cooperative quests, narrative milestones, no engagement pressure; disabled in no-game mode without hiding peer support.
- **Resource Door:** pinned one-tap SOS, local grounding and 'find another meeting' options; support actions not gated on sign-in.
- **Privacy Panel:** shows audience, metadata, last send, deletion status and consent revocation; no screenshots claiming fully anonymous network usage if Firebase operator receives metadata.

## Proposed touch points

`lib/screens/community_feed_screen.dart` becomes a navigational shell for supported sections or is split into `lib/features/circle/ui/` components. Extend `lib/services/community_feed_service.dart` only through tested P0 v2 models; avoid direct writes in `onPressed` without coordinator. Add `lib/widgets/` shared simple support cards if no extra package needed. Keep Wellbriety directory separate and culturally sensitive.

## Micro-interactions that reward rather than addict

- Member support reactions provide accessible language, not competition or a counter to grind.
- Group intent completion can animate the player's constellation *locally* only when allowed, not publish a timeline of actions.
- In-game companion may deliver a calm 'Your circle showed up' acknowledgment without suggesting that anyone is obligated to answer or is medically qualified.
- Be honest when no other Circle members are present or offline; do not simulate real peers, replies or messages.

## A11y/low-end

Text scale to 200%, TalkBack labels and focus order, optional animations, keyboard/back navigation, offline status semantics and sensible empty states. Large-font `FeedPost` card must remain scrollable. Avoid infinite background Firestore listeners after widget disposed; test app lifecycle and cancel subscriptions.

## Pilot scenarios

New anonymous consented user, quiet local-only user, disconnected user with queued draft, author deleting a post, receiving a report, blocked user attempting contact, supporter in no-game mode and first-time senior/large-text user. If users feel pressured to disclose a meeting/location or fear silent publication, withhold launch.
