# Recovery for All — Competitive Differentiation & Technical Prior-Art Report

**Research date:** 2026-10-11  
**Scope:** recovery RPG, multi-pathway meeting discovery, trip routing/weather, Recovery Circle, offline privacy.  
**Evidence:** read-only inspection of `GhostMan612/Recovery-for-All` main (`604420d26baaafa25eb70b17d1bebac0b15ef896`) and `GhostMan612/Metro-IntelliTrip` master (`a7d77e4a9de134bf8b20d5304dd349e3b29330be`), plus vendor documentation, standards and patent publications cited below. No runtime build or claim-by-claim legal patent analysis.

## 1. Executive conclusion

Recovery for All is differentiated by its **potentially coherent combination** of four capabilities: (a) recovery-informed RPG and forgiving companion progression, (b) offline-first meeting data plus transit journeys and weather decisions, (c) peer support and verifiable offline sponsor/fellowship interactions, and (d) local retention of sensitive data. Not one of the four pillars alone establishes first-in-market originality.

**Suggested category hypothesis:** *Recovery Adventure Network* — a private, recovery-first life-navigation RPG that turns practical choices and meaningful real-world participation into non-punitive progress. This is a product-positioning hypothesis, not an established industry category or legal claim.

**Do not claim:** “first recovery RPG”, “only offline recovery app”, “competitors sell personal identifiers”, “GPS proves meeting attendance”, “all Circle messages are end-to-end encrypted”, “all navigation is offline”, or “patentable.” These claims are unsupported, contradicted, or not yet verified.

## 2. Competitive evidence and opportunities

| Comparator | Publicly documented strength | What NOT to claim | Recovery for All opportunity (proposed, not an existing competitor weakness proven by test) | Evidence |
|---|---|---|---|---|
| **A.A. Meeting Guide** | Over 150k weekly meetings; in-person/online search; established local feed partnerships; updates twice daily | Do not claim recovery meeting discovery or map-based access is new | Multi-pathway compare + **can I reach this meeting on time?** with walking, transit, transfer uncertainty and weather; offline fallback with staleness labels | [AA Meeting Guide](https://www.aa.org/meeting-guide-app) |
| **Sober Sidekick** | Free anonymous community, 24/7 meetings, peer responses, tracking | Do not claim online peer recovery communities are novel | Privacy-controlled cooperative quests and supportive circle rituals, without reply-time promises or leaderboards | [How it works](https://sobersidekick.com/how-it-works) |
| **Reframe** | Craving games, daily behavior-change lessons, private community, challenges | Do not claim craving games or an all-in-one recovery program are novel | Recovery-themed, persistent RPG with coping actions as abilities, plus an actual meeting journey | [Why Reframe](https://www.reframeapp.com/why-reframe) |
| **WEconnect** | Healthy routines, proof of meeting attendance, and eligible reward programs | Do not claim verified meeting proof or reward-linked recovery was invented here | Offline mutual-device attestation with strict wording about evidence limits, optional without any formal attendance demand | [WEconnect](https://weconnectrecovery.freshdesk.com/support/solutions/articles/25000034663-what-is-weconnect-) |
| **The Phoenix / NewForm** | Real-world and virtual sober events, communities, milestones | Do not claim location-aware sober events are unprecedented | Cross-program meeting reachability, transport barrier reduction and protected RPG/social progress | [The Phoenix app](https://thephoenix.org/app) |
| **Finch** | Caring virtual pet tied to self-care goals and gentle adventures | Do not claim pet care tied to habits is new | Deep recovery-specific abilities, coping skill practice, accessible no-guilt progression and optional peer quests | [Finch](https://finchcare.com/about-finch) |
| **Habitica** | Habits, Dailies, rewards, pets, equipment, cooperative parties and quests | Do not claim RPG quests and social tasks are new | Recovery safety constraints, coping mechanics and integration with actual meeting travel + fellowship | [Habitica product overview](https://translate.habitica.com/projects/habitica/overview/tl/) |
| **Transit** | Offline schedules, transit route maps, schedule-based trip plans and GPS-based stop alerts; live arrivals need connectivity | Do not claim offline transit trip planning was invented here | Recovery-destination specific planner with choice of meeting, travel buffer, weather/exposure, and accessible alternatives | [Transit offline support](https://help.transitapp.com/article/90-does-transit-work-offline) |

**Competitor gap standard:** A publicly documented feature's absence from a marketing page is **not proof** it does not exist. “Opportunity” means a differentiator to implement and test. Run hands-on evaluation of competing apps with the same benchmark scenarios before naming their “weaknesses” in public materials.

### Proposed benchmark scenarios

1. **Offline after prefetch:** airplane mode, cold restart, find a meeting and plan departure to reach it.
2. **No car / adverse weather:** identify meeting reachable by transit; compare walking exposure, transfer risk and arrival buffer; do not invent precise weather or live ETA.
3. **Difficult evening:** user practices a coping tool, continues a quest and contacts a trusted person without being punished for missed goals.
4. **Small anonymous support circle:** create a supportive interaction, hide a post, delete a post, leave the Circle and verify privacy expectations across devices.
5. **Low-end device:** memory-constrained Android phone; smooth map interaction, battle accessibility, offline continuity.

## 3. Source-grounded Recovery for All baseline

**Implemented in inspected code (not independently tested):**

- `lib/services/recovery_pet_service.dart`: Sparks, Bond, Energy, Mood, species/outfits, daily quest, progression and nonpunitive rest.
- `lib/screens/pet_trials_screen.dart`: turn-based Recovery Trials with coping-named actions such as breathing, grounding and gratitude; daily battle limit.
- `lib/services/xp_engine_service.dart`: transactionally grants XP + audit event, and strikes active raid. `processAction` still grants a fallback 10 XP for unknown action types (backward compatibility); new work should not use this ambiguous path.
- `lib/services/raid_service.dart`: weekend raid progression and rewards; exercise caution before expanding cooperative mechanics because raid state is local.
- `lib/services/meeting_finder_service.dart`: multi-source meeting feeds, on-device cache with staleness logic, location filtering and **SAMPLE** fallback listings when cold/offline. Synthetic fixtures must never be represented as actual meetings.
- `lib/services/map_tile_cache.dart`: cache-first tile handling, bounded cache and tile prefetch. Offline map coverage exists only where tiles have been cached and usage rights allow it.
- `lib/screens/meeting_map_screen.dart`: location-aware meeting map; current-condition weather chip; map directions currently open external Google Maps, NOT an in-app transit itinerary.
- `lib/services/community_feed_service.dart` and `lib/screens/community_feed_screen.dart`: alias-based Circle feed with three reactions, local Drift storage and optional Firebase mirror.
- `lib/screens/wellbriety_circles_screen.dart`: separate curated directory of Wellbriety group links; do not conflate with the interactive Recovery Circle feed.
- `lib/services/fellowship_attestation_service.dart`: signed two-device challenge/answer/confirm; it does not establish actual identity or attendance and can be gamed by two devices.
- `lib/services/sponsor_link_service.dart`: Ed25519 signed approval of recovery work, offline-transfer path and optional cloud relay with documented account limitations.

**Metro IntelliTrip / Atlas SDK** (`master`, not default `main`):

- `core/atlas-gtfs-static`, `core/atlas-gtfs-realtime`, `core/atlas-routing`, `core/atlas-map`, `core/atlas-weather`, `core/atlas-offline`, and `core/atlas-engine` are present.
- `core/atlas-routing/.../HybridRoutingProvider.kt` searches locally before optional remote routing. Thus potential recovery navigation can be offline for valid installed networks, with a distinctly labeled online enhancement.
- `core/atlas-routing/.../TransferConfidenceScorer.kt` handles canceled and stale realtime information conservatively, returning uncertain status instead of false reassurance.
- `core/atlas-weather/.../WeatherLayerComposer.kt` layers radar and alerts without obscuring transit.
- `docs/SDK_INTEGRATION.md` explicitly identifies Recovery for All as first intended SDK consumer and recommends Maven-published Kotlin SDK + narrow Flutter MethodChannel, not porting the native Compose screens.
- `docs/OFFLINE_MODEL.md` says offline **basemap packages are not bundled**. A freshly installed client cannot promise fully rendered offline map visuals until a permitted package is acquired.

## 4. Specific weak points to address first

| ID | Finding | Severity | Evidence and response |
|---|---|---|---|
| **P0-01** | Remote Circle moderation is not independently trusted | Critical before public community scale | `community_feed_service.dart` keeps moderation flag in user-writable `SharedPreferences`; Firestore `status` writes are intentionally denied. This is honest as an offline-local stopgap, not a network moderation solution. Implement trusted moderation + report/block before community growth. |
| **P0-02** | Feed deletes and remote reactions do not have mature integrity semantics | High | `community_feed_screen.dart` deletes local Drift row directly; Firestore rules deny remote deletion. Posts mirrored to remote may remain readable after apparent local deletion. Rules permit authenticated increments without enforcing a one-reaction-per-actor proof. Design revoke/tombstone and idempotent reaction events. |
| **P0-03** | Public license declarations conflict | High commercialization risk | `LICENSE` is MIT (copyright “Toxic Creationz”); README calls app proprietary and says commercial redistribution prohibited. This must be reconciled with legal review before any claim of exclusive distribution/IP control. Do not silently replace license. |
| **P0-04** | Marketing privacy statement is overly absolute | High trust risk | `PRIVACY_POLICY.md` says location is never uploaded, but `meeting_map_screen.dart` sends latitude/longitude to Open-Meteo for the weather chip and opens third-party mapping URLs; tile/provider queries expose at least IP/request context. Distinguish server collection by RFA from disclosure to providers; obtain consent and provide local/offline choices. |
| **P1-01** | In-app meeting journey absent | High product leverage | Meeting map currently deep-links to Google Maps instead of consuming Atlas `planJourney`. Build Meeting -> Journey UI with GTFS/timezone/freshness semantics. |
| **P1-02** | Multiplayer Circle not yet truly offline | High | Existing feed is local + optional Firestore mirror, not offline device-to-device sync. Community content from remote stream is merged for display, not clearly persisted to local DB on receipt. Define offline drafts, queued delivery and conflict rules; offline peer communication is a separate later feature. |
| **P1-03** | Reward and raid mutation boundaries need one canonical flow | Medium-high | `xp_engine_service.dart` owns XP + audit; `recovery_pet_service.dart` owns Sparks; `raid_service.dart` also awards direct victory XP. Consolidate action/reward accounting before cooperative quests or additional modes. |
| **P1-04** | Offline meeting data can be incomplete/stale | High user impact | Directory cache TTL 24h and synthetic fallbacks. Distinguish cached+timestamped real meetings, missing coverage and SAMPLE demo entries; never route to fixtures. |
| **P1-05** | README references missing blueprints and misleading categorical competition claims | Medium | Only three entries in `blueprints/` on current RFA main; README links to additional absent files and describes all rivals as cloud-only/trackers. Reconcile documentation and position honestly. |

## 5. Technical prior art — concrete references

These are search leads establishing **overlap and claim boundaries**, not freedom-to-operate clearance and not a patent attorney opinion. Publication records are potentially relevant even when a patent is abandoned, expired or not currently enforceable.

| Subject | Prior-art publication | Relevance / boundary |
|---|---|---|
| Location-rewarded RPG | [US8348768B2, Game-based incentives for location-based actions](https://patents.google.com/patent/US8348768B2/en) | In-game rewards for real-world location tasks are known. Broad “meeting visit earns XP” likely weak novelty. |
| Location questing | [US11148042B2, Geo location questing](https://patents.google.com/patent/US11148042B2/en) | Location-triggered multiplayer quests and check-ins are established. |
| Gamified therapeutics | [US20230395235A1, Personalized Cognitive Intervention](https://patents.google.com/patent/US20230395235A1/en) | Journal, social support, activity points and cognitive intervention coexist in earlier disclosures. |
| Multimodal trip planning | [US9594772B2, Multi-modal journey planner](https://patents.google.com/patent/US9594772B2/en) | Combining journeys and transit navigation is established. |
| Activity quests | [WO2023003978A1, Tracking user activity and managing quests](https://patents.google.com/patent/WO2023003978A1/en) | Physical/virtual task quests with incentives were already described. |
| Technical non-patent prior art | [GTFS standard](https://gtfs.org/documentation/overview/), [OpenTripPlanner](https://github.com/opentripplanner/OpenTripPlanner), [Habitica](https://habitica.com/apidoc/) | Open technical evidence for static/realtime data formats, multimodal trip planning and cooperative task rewards. |

**Higher-potential differentiation hypotheses requiring claim-chart research:**

- A recovery-specific, local-first *event provenance chain* combining optional human attestations, no coercive GPS, and idempotent nonpunitive RPG benefits.
- Offline recovery-destination journey selection incorporating meeting schedule, valid cached GTFS, accessibility/transfer confidence, exposure to weather and staleness quality.
- Privacy-preserving cooperative recovery quests with minimal shared proofs, local custody of journals, and voluntary cross-device participation.

**Caution:** Each of these is a combination of known elements and may be obvious under patent law. A legal novelty/nonobviousness/FTO review must search more than addiction apps, including games, transit, health platforms, identity credentials, privacy-preserving co-presence and offline mobile systems. Do not publish patentability percentages.

## 6. Category success criteria

1. One clear onboarding path from *find meeting* to *reach meeting* to *reflect privately* to *gain meaningful nonpunitive progress*.
2. Offline continuation after user has downloaded usable data; explicit “not available offline” on uncached capabilities.
3. Travel plans maximize **attendability** (reachable before start, transfer confidence, walking exposure, accessibility) rather than vanity shortest route.
4. Game progression celebrates practices and small choices, not abstinence duration ranking or amount of disclosure.
5. Circles make it easy to give/receive support; remote deletion and abuse handling must actually work before broad rollout.
6. Every advertised privacy/availability claim is tested and documented at the data-flow boundary.

## 7. Research quality, limits and validation plan

- Vendor feature claims are taken from vendor sources; not independently installed or benchmark-tested. No negative feature assertion is made solely from marketing silence.
- Two repositories inspected read-only at pinned revisions; source presence is not release verification. Build, smoke tests, Firestore emulator, on-device tests and actual privacy traces remain necessary.
- Clinical effectiveness is unproven. A [systematic review of game-based interventions for substance use](https://pmc.ncbi.nlm.nih.gov/articles/PMC11727488/) found mixed substance-use outcomes in adolescent studies; gaming features should not be described as treatment efficacy without outcome research.
- Formal patent search must inspect claims and family/citation chains, not just abstracts and titles. Consult qualified counsel, especially because public code release may have filing implications.

## 8. Primary sources and verification links

**Inspected source:**
- https://github.com/GhostMan612/Recovery-for-All/tree/604420d26baaafa25eb70b17d1bebac0b15ef896
- https://github.com/GhostMan612/Metro-IntelliTrip/tree/a7d77e4a9de134bf8b20d5304dd349e3b29330be
- https://github.com/GhostMan612/Metro-IntelliTrip/blob/master/docs/SDK_INTEGRATION.md

**Market/standards/prior art:**
- https://www.aa.org/meeting-guide-app
- https://sobersidekick.com/how-it-works
- https://www.reframeapp.com/why-reframe
- https://weconnectrecovery.freshdesk.com/support/solutions/articles/25000034663-what-is-weconnect-
- https://thephoenix.org/app
- https://finchcare.com/about-finch
- https://translate.habitica.com/projects/habitica/overview/tl/
- https://help.transitapp.com/article/90-does-transit-work-offline
- https://gtfs.org/documentation/overview/
- https://svc.metrotransit.org/
- https://patents.google.com/patent/US8348768B2/en
- https://patents.google.com/patent/US11148042B2/en
- https://patents.google.com/patent/US20230395235A1/en
- https://patents.google.com/patent/US9594772B2/en
- https://patents.google.com/patent/WO2023003978A1/en
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11727488/
