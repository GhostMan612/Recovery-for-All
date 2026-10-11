# Recovery for All — Category Platform Blueprint Hub

**Status:** design/research artifact only (no code changed)  
**Research date:** 2026-10-11  
**Repository baseline:** Recovery-for-All `main` @ `604420d26baaafa25eb70b17d1bebac0b15ef896`  
**SDK baseline:** Metro-IntelliTrip `master` @ `a7d77e4a9de134bf8b20d5304dd349e3b29330be`  
**Important:** Metro default `main` is a README-only initial branch. The implementation is on `master`.

## Read in order

1. `COMPETITIVE_DIFFERENTIATION_AND_TECHNICAL_PRIOR_ART.md` — competitor opportunities, evidence, actual prior art, defensibility caveats.
2. `PLATFORM_ARCHITECTURE.md` — single-app experience, Kotlin SDK integration via Flutter, privacy tiers and shared recovery events.
3. `PHASED_EXECUTION_PLAN.md` — priority-focused implementation packages and acceptance criteria.
4. `VERIFICATION_MATRIX.md` — offline, game-economy, travel, Circle, data protection and user-experience gates.
5. `DECISIONS_AND_RISKS.md` — unresolved decisions, ranked risk register, constraints.
6. `AGENT_HANDOFF.md` — copyable, harness-agnostic local-agent instructions.

## Overlay semantics

These are **new** paths below `blueprints/category-platform/`. The ZIP does not modify or overwrite `README.md`, `AGENTS.md`, `RULES.md`, `pubspec.yaml`, source, tests or CI configuration. Extract the ZIP **at the root of the local Recovery for All checkout**. The existing root `README.md` references some blueprint paths not present on the remote branch; reconcile those links under a dedicated approved work order instead of silently rewriting operating documents.

## Non-negotiable design intent

- The core loop is **recover -> travel -> connect -> grow**, not compulsive screen time.
- Local-first does not mean every social or live-transit function works without a network. Label the capability truthfully.
- No sobriety-duration leaderboard, relapse punishment, forced sharing, precise location publishing, or recovery-purchase mechanics.
- The app must still provide useful recovery content, saved meeting data and companion progression in airplane mode.
- Existing safety and migration invariants remain binding; `RULES.md` wins on conflicts.
- Neither repository is modified by this package; external directories remain read-only under current project operating law.
