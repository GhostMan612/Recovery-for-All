# Integration Traceability Matrix

| User outcome | Existing touch points | New proposed boundary | Phase / work order | Proof |
|---|---|---|---|---|
| Check-in grants exactly once | `xp_engine_service.dart`, Drift PetEvents | `RecoveryActionCoordinator` + `RewardLedger` | P1-1A | replay100 + kill/restart + migration |
| Battle is deterministic and kind | `pet_trials_screen.dart`, `raid_service.dart` | pure Dart reducer with injected RNG | P1-1B | fixed-seed golden and CPU stress |
| Companion and constellation agree | `recovery_pet_service.dart`, `constellation_service.dart` | action projection listeners | P1-1D | one event -> one star + no double XP |
| Find a real meeting while offline | `meeting_finder_service.dart`, map screen | `MeetingRepository` with provenance | P2-2B | cached feed, stale clock, SAMPLE rejected |
| Route by bus to meeting | Metro AtlasEngine, static GTFS, RFA Flutter map | `AtlasBridgeV1` over MethodChannel | P2-2A/2C | offline fixture, device and return legs |
| See weather at departure/arrival | Atlas weather/NWS, Open-Meteo chip | conditional `JourneyWeatherPresenter` | P2-2C | fresh/stale/unknown, opt-in trace |
| Support Circle peers safely | `community_feed_service.dart`, Firestore | P0 trusted protocol + Circle domain v2 | P3-3A | two identities, hostile client, deletion |
| Cooperate without rankings | Circle + P1 action coordinator | co-op `QuestContribution` | P3-3B | actor uniqueness, opt-out, moderation |
| Start with one coherent journey | `dashboard_screen.dart`, `onboarding_screen.dart` | user-journey navigator/feature flags | P4-4A | first-run and 200%-text journeys |
| Works on 3 GB device | Flutter/Atlas/GGUF/mapping | budgets and staged load | P4-4B | low RAM, ANR/crash, offline restarts |
| All privacy claims true | README/policy/feature UI | consent evidence and release scorecard | P4-4C | network capture + doc diff |

**Test runner discipline:** follow existing project's `AGENTS.md` and `RULES.md` test/build batching. Phase 1/3 local Dart tests can run independently; Metro test suites must execute in Metro's repo under its own rules, not by editing that external repo during Recovery's implementation.
