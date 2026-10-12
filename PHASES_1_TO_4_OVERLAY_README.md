# Recovery for All — Full Phases 1–4 Overlay

**Package date:** 2026-10-11 · **Type:** local planning/work-order/contract overlay · **Status:** implementation NOT performed.

This package **does not** build, fix or run the app. It gives an execution-ready, file-level blueprint, reference contracts, fixture tests, phased risk controls, and a read-only overlay validator. The execution agent must implement and verify the runtime changes locally before any release claim.

## Installation (Windows; repository root)

1. Back up your local work or commit your existing work under `RULES.md`.
2. Preview archive paths first (no app source files are present); extract this archive into **the root of `C:\Recovery for All`**. Preserve directory structure. No existing source or Phase 0 files are modified by extraction. A second extraction could replace the same Phase 1–4 planning files, so make your own edits in separate patches or back them up.
3. From the repository root, run `python tools/verify_category_overlay.py` (or `py -3 tools\verify_category_overlay.py`). The verifier uses only Python's standard library, checks file hashes and source prerequisites, and does **not** run Flutter, Gradle, Git or network commands.
4. Read `RULES.md`, `AGENTS.md`, `SESSION_HANDOFF.md`, `blueprints/category-platform/phase-0/PHASE_0_STATUS_AND_GATES.md` (if Phase 0 overlay is installed), then `blueprints/category-platform/PHASES_1_TO_4_INDEX.md`.
5. Give an agent **one phase work order at a time**, on the local repo. Require explicit test evidence and gate signoff before the next phase. Do not alter Metro's repository from a Recovery for All work order.

## What is installed

- `blueprints/category-platform/PHASES_1_TO_4_INDEX.md`: top-level roadmap, dependencies, source anchors and work-order table.
- `blueprints/category-platform/phase-1/`: idempotent action ledger; RPG engine, quests, economy, constellation, migration, tests.
- `blueprints/category-platform/phase-2/`: meeting destination trust; Metro Atlas Kotlin/Flutter SDK bridge; offline travel, weather and transit UX; tests.
- `blueprints/category-platform/phase-3/`: Circle consent, trusted transport, moderation, co-op adventures, offline outbox, abuse tests.
- `blueprints/category-platform/phase-4/`: product coherence, accessibility, pilot design, low-end verification, acceptance and documentation.
- `blueprints/category-platform/contracts/`: versioned JSON Schema examples + synthetic fixtures, reference contracts and cross-phase invariants.
- `tools/verify_category_overlay.py`: standard-library read-only validator.
- `PHASES_1_TO_4_OVERLAY_MANIFEST.json`: provenance and integrity hashes.

## Non-negotiables

- Phase 0 security/consent gate must be **implemented and verified** before remote Circle expansion. A Phase 0 ZIP being extracted is insufficient.
- `RULES.md`/`AGENTS.md` remain authoritative. Respect their build/test and human-device boundaries.
- No source-code, Firestore rules, native SDK, cloud configuration or dependencies are silently overwritten by this package.
- No live data, credentials, personal identities, exact locations or other sensitive material is embedded.
- A successful overlay validator means **the ZIP and document files are structurally intact**, not that Flutter tests, native builds, Firebase rules or field behavior pass.
- Preserve all local user data. Generated Drift `.g.dart` is build-generated; never edit it by hand.
- Runtime travel availability, meeting attendance and peer support outcomes must not be fabricated.

## Source checkpoints (read-only inspection)

- Recovery for All `main`: `6f985f393962b091d69cc003bb922c9fae9ae618`.
- Metro IntelliTrip **`master`** (active implementation; `main` is only a README): `a7d77e4a9de134bf8b20d5304dd349e3b29330be`.
- The executor must compare local HEAD/source against these checkpoints and rebase the *plan* if the implementation changed. Never reset the user's local branch or force-checkout an older commit.

## Human success criterion

An individual with a 3 GB Android phone can remain anonymous, use personal recovery tools without a network, discover a legitimately cached meeting, select a scheduled or live-qualified transit journey when supported, receive useful weather/transfer warnings, choose an optional gentle RPG activity, and participate in a voluntary Circle when consented and connected. None of these activities should reveal precise personal recovery histories to other members or silently transmit location to external services.
