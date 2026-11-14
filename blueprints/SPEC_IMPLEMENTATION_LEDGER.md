# Spec → Implementation → Verification Ledger

**Last reconciled:** 2026-11-13 · `main` @ `6c9dc3303f9`

> **A merged specification is not implementation.** `PLANNED` and
> `IMPLEMENTING` rows may have documentation, schemas, fixtures, or plan PRs on
> `main`; only `RELEASED` means code is merged and the required evidence is
> recorded. Do not infer delivery from a blueprint file, a plan PR, a fixture,
> a screenshot, or a successful build.

This is the status source of truth for the specs and work orders that have an
active implementation or release decision. Historical volumes, research,
checklists, and generated reference material are intentionally not assigned a
status here; their presence is not a delivery claim.

## Status definitions

| Status | Meaning |
|---|---|
| `PLANNED` | The spec or work order exists; no implementation is claimed. A docs-only PR stays here. |
| `IMPLEMENTING` | Code exists, but acceptance, device, security, or release evidence is incomplete. |
| `VERIFIED` | Implementation and automated gates pass on a branch or PR; not merged or not yet release-evidenced. |
| `RELEASED` | Merged to `main`, CI green on the merge commit, and the spec's required device/security evidence is recorded. |

**Evidence rules**

- A docs-only PR never advances a row past `PLANNED`.
- `flutter analyze` zero issues plus a green `flutter test` run are necessary,
  but not sufficient for release when the spec requires device, security, or
  emulator evidence.
- Link the PR and the CI run ID. A branch-only run is `VERIFIED`, not
  `RELEASED`.
- Change the status in the same PR that changes implementation or evidence.
  If a claim is retracted, retract it inline; do not silently delete it.
- `(local-only)` means the spec is gitignored and is absent from a fresh clone.
  The code and tests it points to are still tracked.

## Current ledger

| Spec / work order | Status | Implementation | Verification evidence | Notes |
|---|---|---|---|---|
| [UI/UX modernization plan](UI-UX-themes-plan.md) | `RELEASED` | 17 phases: M3 theme engine, semantic tokens, dashboard/nav/SOS work, accessibility, motion, hardening | Phases 0–17 device-verified (LG B160V, Moto G 2025); `flutter analyze` 0; current `main` CI `43535010913`; color gate and 14 invariants | Test counts inside the plan are historical phase records, not current counts. Do not restart a phase. |
| [Dashboard IA](dashboard-ia.md) | `RELEASED` | Path/Library tabs, modular tiles, four destinations; `dashboard_cards.dart` / `dashboard_sections.dart`; one live pet owner | Invariants 4 and 8; `test/dashboard_pet_liveness_test.dart`; current `main` CI | Phase 8/9 complete. Dashboard widgets are presentational; no Riverpod or DB reads. |
| Street routing (MF-01/MF-02) | `RELEASED` | `lib/features/navigator/application/street_route_provider.dart`; release routing resolves offline `unavailable`; debug-only ORS path; privacy capability fails closed | PR #36 merge `0431cb6`; merge-train CI `43521553927`; current `main` CI | Do not claim a remote route when the release path returns unavailable. |
| Journal structured-entry presentation (PR #37) | `RELEASED` | `lib/services/journal_presentation_formatter.dart`; journal list and Daily Reflection use it | PR CI `43527439668`; merge `46b6fa0`; `main` CI `43528748855`; 31 journal/security tests; analyze 0 | Presentation only. Stored/encrypted bytes are never altered; unknown or malformed JSON falls back to raw text. |
| [RPG sprite atlas manifest](../assets/game/sprites/README.md) (PR #38) | `RELEASED` | `lib/widgets/game_sprite_stage.dart`; Ember Kit and Craving Wraith atlases; avatar/trials integration; Blender sources and tools | PR CI `43534467537`; merge `6c9dc33`; `main` CI `43535010913`; full suite +1014 ~1; 9 sprite tests; color/invariants/art verification | Presentation only. Device-visual validation is not recorded; vector fallback remains for custom cosmetics and asset failure. |
| [Avatar art spec](avatar-art-spec.md) `(local-only)` | `RELEASED` | Vector species portraits, ~90 cosmetic icons, mood faces; emoji fields deleted | Invariant 12; `test/species_vector_art_test.dart`; `test/cosmetic_vector_art_test.dart`; current `main` CI | No new emoji features. Colour is identity only in the declared skin/hair colourways. |
| [Pet store and Sparks rules](pet-store-rules.md) `(local-only)` | `RELEASED` | Drift v13 pet tables; atomic pet/event writes; daily cap 150 with meeting/walk/milestone exemptions; feed guardrails C1–C5 | `test/community_feed_service_test.dart`; `test/dashboard_pet_liveness_test.dart`; current `main` CI | Local-only specification; code is tracked. Safety is never gated by Sparks. |
| [Resource Viewer Phases 00–06](resource-viewer/README.md) | `IMPLEMENTING` | Native PDF per Step, shared HTML WebView, safe router, resource policy; source and tests present | Host CI on `90394b3` and `e968dc1`; all twelve aa.org candidates returned PDF-format bodies | Release blocked: HTTP status/redirect/final host, chapter identity, AA viewing terms, and device/release checks remain. DNS preflight is not connection pinning. See [Phase 00](resource-viewer/phases/PHASE_00_RECON_AND_URL_PROOF.md) and [08 acceptance](resource-viewer/08_ACCEPTANCE.md). |
| [Category-platform Phase 0](category-platform/phase-0/README.md) | `IMPLEMENTING` | P0-A docs/CI, P0-B privacy capability authorization and cold-restart durability, WO-P0-CIRCLE-REAUTH | Index cites checkpoint `bfdaa1c` / run `38319189867` | Remaining: P0-C server-authoritative Circle security and migration, P0-D device/emulator acceptance, licensing/IP decision, final evidence. Partially implemented; **not accepted**. |
| [Category-platform Phase 1](category-platform/phase-1/README.md) — WO-1A–1D | `PLANNED` | Docs, contracts, fixtures only; no action ledger or idempotent reward receipt | None | Docs-only. Do not infer progression or reward implementation. |
| [Category-platform Phase 2](category-platform/phase-2/README.md) — WO-2A–2C | `PLANNED` | Docs/contracts only; no Atlas bridge, routing, weather, or normalization implementation | None | #28 is blocked on a reproducible Atlas artifact; #25 is spec-only. |
| [Category-platform Phase 3](category-platform/phase-3/README.md) — WO-3A–3C | `PLANNED` | Docs/contracts only; no Circle transport or cooperative quest implementation | None | Requires Phase 0 trust gates and Phase 1 deduplication; remote writes remain disabled/local-only. |
| [Category-platform Phase 4](category-platform/phase-4/README.md) — WO-4A–4C | `PLANNED` | Docs and scorecards only | None | Scorecards begin NOT RUN. A successful build is not release evidence. |
| [SR-B encrypted worksheet migration](category-platform/phase-0/SR-B-ENCRYPTED-WORKSHEET-MIGRATION.md) (PR #24) | `PLANNED` | Documentation PR merged; no migration code | None | Plaintext worksheet storage remains until the work order is implemented. |
| [Truthful offline meetings](category-platform/phase-2/WO-2D-TRUTHFUL-OFFLINE-MEETINGS.md) (PR #25) | `PLANNED` | Documentation PR merged; no implementation | None | No offline-truthfulness change is claimed. |
| [Atlas SDK bridge](category-platform/phase-2/WO-2A-ATLAS-SDK-BRIDGE.md) (PR #28) | `PLANNED` | Documentation PR merged; no bridge on `main` | None | Blocked: `com.intellitrip.atlas:atlas-engine:0.1.0` is not reproducibly published or vendored, and `android/settings.gradle.kts` still has the hardcoded `C:/Metro IntelliTrip` fallback. A WIP native channel exists on the local branch but cannot build from a clean clone. |
| [Resource-viewer network boundary](resource-viewer/09_NETWORK_BOUNDARY_HARDENING.md) (PR #30) | `PLANNED` | Documentation PR merged; no boundary implementation | None | WebView navigation interception does not by itself block third-party subresources or prove popup/download coverage. |
| [SOS care alert consent and nested rules](https://github.com/GhostMan612/Recovery-for-All/pull/4) (PR #4) | `IMPLEMENTING` | Draft PR #4; conflicting with `main` | None | Not ready: trusted-recipient/retention design, opt-in review, emulator matrix, and Android device validation are outstanding. Do not merge to make the open-PR count zero. |
| [TacMap extraction](tacmap-extraction.md) `(local-only)` | `IMPLEMENTING` | P0 map port shipped (`flutter_map`, cache-first tiles, offline packs); later phases not claimed | Navigator tests and current `main` CI | A partial port is not whole-spec acceptance. |
| [Resource system](resource-system.md) `(local-only)` | `IMPLEMENTING` | `lib/core/resources` router, policy, and registry; link-health/tailoring partially present | `test/resource_link_health_http_test.dart`; `test/resource_viewer/resource_router_test.dart`; current `main` CI | Not release-verified as a complete resource system; the Resource Viewer is separately blocked. |
| [GGUF deeper chat](gguf-feasibility.md) `(local-only)` | `PLANNED` | Deferred; no model-runtime delivery claim | None | 1 GB devices: never. The scripted coach remains the floor. |
| [Roadmap v2](roadmap-v2.md) `(local-only)` | `PLANNED` | Tiered feature queue; individual items are tracked separately | None | A queue is not a delivery claim. |

## Preserved local WIP (not on `main`)

- Local branch `wip/local-unshipped-20261113` holds four preservation commits
  and 36 files. It is **local-only** and is the sole copy of the unshipped
  Atlas/native and next-release work.
- Verified bundle: `C:\rfa-local-archive\rfa-unshipped-20261113.bundle`
  (430.5 MB; `git bundle verify` reports complete history and exit 0).
- The journal and RPG commits were extracted to PRs #37 and #38 and are now on
  `main`. The remaining unshipped content is the Atlas native channel/GTFS/
  Gradle stream and the next-release docs.
- Do not push or delete the WIP branch until the Atlas dependency is
  reproducible and the next-release docs have a tracked destination.

## Not status-tracked

The following are reference, research, checklist, or generated artifacts, not
delivery specs. Their presence must not be read as implementation:

- Historical volumes (`Volume_I`–`Volume_VII`, `architecture-blueprint`,
  `Technical_Architecture_Whitepaper`), research/competitive docs, onboarding
  and pathways specs, theme-engine notes, and UI phase baselines.
- Living checklists such as `recovery-pet-checklist.md`,
  `recovery-coach-checklist.md`, and `gui-backgrounds-animation-checklist.md`.
- `recovery_all_code.md` — generated by `tools/generate_code_package.py`;
  never hand-edit.
- `DOC_REFERENCE_AUDIT.md` — documentation audit, not a feature spec.
- `SPRINT_PLAN.md` — no longer exists; do not reference it.

## Update protocol

1. Update the row in the same PR that changes implementation or verification.
2. `PLANNED` → `IMPLEMENTING` only when code exists.
3. `IMPLEMENTING` → `VERIFIED` when analyzer, tests, and required gates pass on
   the PR branch; link the run.
4. `VERIFIED` → `RELEASED` only after merge to `main`, green CI on the merge
   commit, and any required device/security evidence is recorded.
5. A docs-only PR never advances a status.
