# Decision Register — Owner/Architect Gate

Do not silently choose a different remote/social or SDK architecture just to save coding time. Default below is the least-surprising safe behavior; a choice must be recorded before relevant work begins.

| ID | Decision | Default until approved | Required before |
|---|---|---|---|
| D-01 | Are Phase 0 remote Circle ownership/deletion/moderation guarantees independently verified? | NO — keep connected expansion disabled | P3 remote rollout |
| D-02 | License mismatch: MIT LICENSE vs proprietary README/policy intent | do not change license or promise exclusivity; owner + legal review | external launch/public IP claims |
| D-03 | Historic XP/Sparks behavior and migration | preserve old totals/earned cosmetics; do not back-award ambiguous events | P1 DB migration |
| D-04 | Can battle losses grant safe, finite participation reward? | modest no-guilt participation, no infinite grind | P1 balancing |
| D-05 | Game opt-out | hide RPG surfaces; keep functional non-RPG recovery tools | P1/4 UI |
| D-06 | Destination source coverage | MN-first and explicit data provenance; no fabricated data | P2 real-world test |
| D-07 | Transit routing provider | offline static planner first; external OTP disabled until consent | P2 bridge |
| D-08 | License/terms for offline map/radar tile packaging | package only permitted data; do not bulk-prefetch prohibited public tiles | P2 offline maps |
| D-09 | Min Android SDK when consuming Atlas SDK (Atlas targets >=26) | keep Recovery's current supported devices; analyze incompatibility before change | P2 Gradle integration |
| D-10 | Circle transport & trust | Phase 0 server-owned v2 if verified; otherwise local-only | P3 remote launch |
| D-11 | Are Circle co-op quests global/public or small/private? | opt-in private/small groups, no public ranks | P3 UX |
| D-12 | Human moderation staffing, appeals & abuse response | no unstaffed claim of 24/7 monitoring | P3 live sharing |
| D-13 | Evidence and launch claims | product capability language only; no clinical/patent claims without study/counsel | P4 publishing |
| D-14 | Device/internet budgets | low-end 3 GB budget first, not cloud/model-dependent | P4 acceptance |

Record for each decision: selection, approver, date, source evidence, change set, fallback, and if required, user-facing policy update. Agent must not mark D-01/D-02/D-10/D-12 approved by inference.
