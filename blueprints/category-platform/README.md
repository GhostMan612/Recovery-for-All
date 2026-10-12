# Recovery for All — Category Platform Blueprint Hub

**Status:** architecture plans and Phase 0 documentation/CI changes; no application runtime feature code changed\
**Research date:** 2026-10-11  
**Repository baseline:** Recovery-for-All `main` @ `604420d26baaafa25eb70b17d1bebac0b15ef896`  
**SDK baseline:** Metro-IntelliTrip `master` @ `a7d77e4a9de134bf8b20d5304dd349e3b29330be`  
**Important:** Metro default `main` is a README-only initial branch. The implementation is on `master`.


## Active Phase 0 trust program

Start at **[`phase-0/README.md`](phase-0/README.md)** for the complete consent, licensing, Circle-security, CI, implementation work orders and acceptance gates. The Phase 0 documentation/CI overlay does **not** implement the network/security back-end, and does **not** prove a green Flutter build. Treat `phase-0/PHASE_0_STATUS_AND_GATES.md` as the status source of truth.

## Read in order

1. [Master Index — Phases 0–4](PHASES_1_TO_4_INDEX.md) — sole phase order, dependencies, boundaries, acceptance gates and current status.
2. `COMPETITIVE_DIFFERENTIATION_AND_TECHNICAL_PRIOR_ART.md` — competitor opportunities, evidence, actual prior art, defensibility caveats.
3. `PLATFORM_ARCHITECTURE.md` — single-app experience, Kotlin SDK integration via Flutter, privacy tiers and shared recovery events.
4. `PHASED_EXECUTION_PLAN.md` — priority-focused implementation packages and acceptance criteria.
5. `VERIFICATION_MATRIX.md` — offline, game-economy, travel, Circle, data protection and user-experience gates.
6. `DECISIONS_AND_RISKS.md` — unresolved decisions, ranked risk register, constraints.
7. `AGENT_HANDOFF.md` — copyable, harness-agnostic local-agent instructions.

## Overlay semantics

The Phase 0 overlay changes the root `README.md`, `PRIVACY_POLICY.md`, `.github/workflows/cmake-multi-platform.yml`, the category-platform hub/handoff and adds Phase 0 documents plus a documentation checker. The Phases 1–4 overlay adds its index, contracts, synthetic fixtures, phase work orders and a read-only validator; it does not add app source, tests, dependencies or runtime features. In this checkout the overlay files are already extracted. The named source ZIPs were not available for byte-level archive inspection, so the checked-in overlay manifests describe the available extracted-file provenance only; do not claim archive validation from them.

The root `README.md` now links to the Phase 0 hub and this unified index. Treat the category-platform `PHASES_1_TO_4_INDEX.md` as the sole Phases 0–4 master index (its legacy path is retained for existing phase instructions). Do not infer that Phase 0 is implemented from its documentation or CI workflow.

## Non-negotiable design intent

- The core loop is **recover -> travel -> connect -> grow**, not compulsive screen time.
- Local-first does not mean every social or live-transit function works without a network. Label the capability truthfully.
- No sobriety-duration leaderboard, relapse punishment, forced sharing, precise location publishing, or recovery-purchase mechanics.
- The app must still provide useful recovery content, saved meeting data and companion progression in airplane mode.
- Existing safety and migration invariants remain binding; `RULES.md` wins on conflicts.
- Neither repository is modified by this package; external directories remain read-only under current project operating law.
