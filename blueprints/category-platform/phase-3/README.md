# Phase 3 — Recovery Circle 2.0: Safe Peer Cooperation

**Status:** BLUEPRINT ONLY. **Do not enable or expand connected publishing until Phase 0 server-enforceable identity, deletion, moderation and consent are actually implemented and verified.**

## Difference from a social feed

A small private Circle can choose voluntary intentions, such as 'Ground together', 'Prepare for a meeting', 'Reach out to support', and receive noncompetitive cooperative progress. Nobody needs to disclose sobriety duration, medical condition, exact location or meeting attendance proof. Shared accomplishment is about mutual support, not public ranking or volume.

| Work order | Responsibility | Gate |
|---|---|---|
| [WO-3A-TRUSTED-CIRCLE-TRANSPORT.md](WO-3A-TRUSTED-CIRCLE-TRANSPORT.md) | P0 v2 trust, consent, offline outbox, deletion and controls | two-identity emulator and devices |
| [WO-3B-COOPERATIVE-QUESTS.md](WO-3B-COOPERATIVE-QUESTS.md) | cooperative intentions linked to local action proofs but not user data | at-most-once, peer opt-out |
| [WO-3C-CIRCLE-EXPERIENCE.md](WO-3C-CIRCLE-EXPERIENCE.md) | support cards, positive feedback, small circles, accessibility | usability + moderation pilot |

Read [IDENTITY_MODERATION_AND_SAFETY.md](IDENTITY_MODERATION_AND_SAFETY.md), [ACCEPTANCE_AND_TESTS.md](ACCEPTANCE_AND_TESTS.md), and [AGENTS.md](AGENTS.md).

## Separate similarly named features

`lib/screens/community_feed_screen.dart` is the Recovery Circle community feed. `lib/screens/wellbriety_circles_screen.dart` is a curated directory of culturally specific Wellbriety meeting circles and official links. Do not merge their data, apply game ranks to cultural meeting directories, or infer a person's faith/heritage from visiting the directory.
