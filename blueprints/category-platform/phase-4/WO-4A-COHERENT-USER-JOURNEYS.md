# WO-4A — One Cohesive Dashboard-to-Recovery Experience

## Design objective

A first-time user can find help immediately, customize privacy/pathway, discover a real meeting, plan how to get there, optionally reflect and choose optional gameplay/Circle support. Navigation should be understandable as one product rather than six mini-apps.

## Exact paths and boundaries

- `lib/screens/onboarding_screen.dart`: accessible personalized pathway, permission explanations when needed, game on/off preference and Circle sharing consent separately; default functionality offline/anonymous.
- `lib/screens/dashboard_screen.dart`: one prominent immediate-help affordance, one 'Next meaningful step', shortcut to meeting reachability and optional game goal; respect existing Phase 9 destination shell/navigation contracts.
- `lib/widgets/dashboard_cards.dart`, `lib/widgets/dashboard_sections.dart`: progressive disclosure and concise status chips, no duplicate navigator cards/long text blocks.
- `lib/core/app_navigator.dart`: preserve established destinations/back stack; deep links for meeting → journey and game → quest with clear return behavior.
- `lib/screens/meeting_map_screen.dart` and new Phase 2 `journey_sheet.dart`: meeting selection, in-app route, honest offline/status, return-to-list.
- `lib/screens/pet_home_screen.dart` and Quest screen: one action receipt, predictable optional celebration; no clutter for users who opted out.
- `lib/screens/community_feed_screen.dart`: clear voluntary sharing, online scope and author-delete; do not make social login an onboarding gate.
- `lib/screens/settings_screen.dart`: privacy capabilities, offline storage/download sizes, game mode, data deletion and help.

## North-star paths to usability-test

**Path A: New user offline.** Launch -> onboarding no cloud -> choose a pathway or skip -> find coping/SOS -> journal -> optional pet -> privacy settings. No login, network-blocking splash or compulsory game tutorial.

**Path B: Attend a meeting.** Open directory -> select sourced meeting -> check location/date -> plan with bus using local GTFS when available -> see transfer/weather uncertainty -> save route and alternate meeting -> optionally mark as *self-reported* attended -> private quest receipt; no autopost.

**Path C: Mutual support.** Open Circle -> preview consent and audience -> compose local draft -> optional publish, verify delivered or queued state -> block/report/delete. Never prompt to publish private journey, sponsor proof or sobriety counter.

**Path D: No-game user.** Disable gamification -> all core tools are visible and equally accessible, no blocked feature due to XP.

## Gate

Independent usability sessions can accomplish A–D without developer coaching, recognize which things are offline/online, and correctly predict what Circle peers can see. Screen readers/large text work across full journeys; back/route state does not disappear on lifecycle rotation or tab switches.
