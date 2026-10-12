# Recovery for All

**An offline-first, privacy-focused, multi-pathway addiction recovery companion.**

> Recovery is not one path. Recovery is the path you build.

## What this project combines

Recovery for All combines recovery tools, a gentle companion RPG, local-first personal data, a multi-fellowship meeting finder, and an optional connected Recovery Circle. This is a description of this project's feature set, **not a claim that competing apps do not offer these features**. Competitor evidence, boundaries and proposed extensions are documented in [the category-platform research hub](blueprints/category-platform/README.md).

| Area | Current project implementation | Boundary or planned extension |
| --- | --- | --- |
| Personal recovery | Counters, guided exercises, journaling, reflection, goal setting and recovery resources | Outcomes are personal; no clinical efficacy claim |
| Multiple pathways | Pathway-tailored resources and meeting feeds covering multiple fellowships | Source coverage and availability vary by area and pathway |
| Companion RPG | Sparks, Bond, Path XP, pets, cosmetics and turn-based Trials | A unified idempotent event/reward ledger is **planned**, not yet delivered |
| Peer support | Alias-based Recovery Circle, local feed and optional Firestore mirror; signed sponsor/fellowship workflows | Remote moderation, deletion and reaction integrity need hardening before expansion |
| Meeting discovery | Cached directories, map tiles, filters, local meeting markers, weather chip | Present directions may open an **external** map; native transit itinerary integration is **planned** |
| Offline capability | Local journal, companion, skills, cached meeting data and cached map tiles | A cold offline install cannot supply uncached meetings, live traffic, weather, transit or Circle messages |
| On-device AI | Scripted and TFLite guidance; optional local GGUF model with device and safety gates | AI is supportive, not an emergency or professional substitute |

## Feature map

**Recovery:** sobriety counters; 12-step resources and worksheets; sponsorship; grounding, HALT and breathing exercises; wellness check-ins; gratitude, journal and goals; resource directories and SOS entry points.

**Companion:** species and dresser, code-drawn vector cosmetics, nonpunitive rest, Sparks/Bond/Mood/Energy, Path XP, daily quests, Trials of the Path and raids. Not completing a quest does not revoke access to recovery tools.

**Meeting Finder:** multi-source data including Minnesota-focused directories, source/cache freshness handling, OpenStreetMap/Esri tiles, optional prefetch and a map with current-weather information. External web services are involved in some online modes.

**Recovery Circle:** a local-first alias feed with Strength/Proud/Respect reactions and optional Firebase synchronization. Offline composition does **not** imply a message has been delivered to another person. Remote post deletion and trusted network moderation are known gaps being addressed in Phase 0.

**Sponsor and fellowship verification:** Ed25519 signatures support exchange/approval workflows. Peer exchange signatures prove participation of signing keys, not the identity of a person or attendance at a specific meeting.

## Category-platform development

The current architecture initiative is **Recovery Adventure Network** (working category name): a shared, nonpunitive progression engine, a recovery-destination navigator using Metro IntelliTrip's Atlas SDK, and safe cooperative Circle experiences. These are **blueprints**, not claims of shipped functionality.

Start at **[Category Platform Blueprint Hub](blueprints/category-platform/README.md)**. Phase 0 is tracked in `blueprints/category-platform/phase-0/`.

The Metro IntelliTrip SDK implementation is in the separate repository's `master` branch, not its README-only default `main` branch. Any integration is local-first, version-pinned, and requires the documented host/SDK boundary; no source copying is implied.

## Local development

```powershell
flutter pub get
flutter analyze
flutter test
```

See [`AGENTS.md`](AGENTS.md) and [`RULES.md`](RULES.md) before executing changes. Those documents govern the build/test cadence, authorization boundaries, database migrations and evidence rules. The maintained design history is in `blueprints/UI-UX-themes-plan.md`, `blueprints/dashboard-ia.md` and `blueprints/lessons-learned.md`.

## Privacy and connectivity

Private recovery records are intended to remain in the encrypted local application database. Some optional or context-dependent features contact external providers: meeting directories, map tile hosts, weather services, external navigation and Firebase where configured. In particular, the current weather query passes latitude/longitude to Open-Meteo, and opening Google Maps shares a meeting destination with that external application. A connected Circle feed shares its selected post content and alias with Firebase.

**Offline-first is not the same as network-silent.** Review [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) and the [Phase-0 data-flow inventory](blueprints/category-platform/phase-0/DATA_FLOW_AND_CONSENT.md) before enabling connected features. Explicit per-capability consent and a network-off mode remain implementation work.

## Licensing — clarification pending owner/legal review

The checked-in [`LICENSE`](LICENSE) is an **MIT license** with a 2026 copyright notice for Toxic Creationz. Previous README language called the repository proprietary and prohibited commercial redistribution; that assertion conflicts with the currently checked-in license. **This README does not change, revoke or supersede LICENSE.** The owner must review provenance and intended licensing with qualified counsel before asserting exclusivity or changing licensing for future material. See [Phase-0 licensing decision](blueprints/category-platform/phase-0/LICENSE_AND_IP_DECISION.md).

Other assets, provider feeds, organization literature and dependencies may carry separate licenses or use conditions; no ownership over third-party materials is claimed.

---

*Built for the path you walk. No one else's.*
