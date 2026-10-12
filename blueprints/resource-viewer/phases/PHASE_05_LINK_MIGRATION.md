# Phase 05 — Literature and Community Resources migration

**State (2026-10-12):** PRIMARY SCREENS MIGRATED · **Broader callsite dispositions documented; final verification pending** · **Depends on:** Phases 02–04

Literature Library and Community Resources call the shared router and use stable screen-level source IDs. The wider URL-launch inventory is recorded in `07_LINK_INVENTORY.md`; native safety, map, meeting-join, repository/legal, and flyer flows are deliberately not bulk-rewritten. Revisit a callsite only with its own UX/policy review.

## Original implementation scope — present in source

1. Literature Library uses the router while preserving pathway filtering, link health, and dead-link feedback.
2. Community Resources uses the router while preserving category behavior and protocol classification.
3. Other observed URL callsites have recorded dispositions in `07_LINK_INVENTORY.md`; SOS and native calls were not rewritten.
4. Labels and actions were migrated only within the scoped primary screens; final suite verification remains pending.
5. Host and device verification of categories, redirects, dead links, nested PDFs, browser escape and return state remains pending.

## Required outcome

Every scoped built-in recovery webpage/PDF link opens through shared router; safety-oriented system links retain intended OS behavior. All link-health and pathway-tailoring functionality remains.
