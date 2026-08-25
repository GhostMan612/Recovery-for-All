# Recovery for All

Offline-first addiction-recovery companion app (Android-first,
Minnesota-first). Flutter + Drift + SQLCipher, with an optional Firestore
mirror for community and sponsor transport.

Recovery is not one path. Recovery is the path you build.

## What's inside

- **Tailored onboarding** — 24 goals, 25 core values, 7 recovery pathways;
  choices drive dashboard cards, meeting fellowships, and downloads
- **Sobriety counters** — specific start dates, milestone chips
- **Meeting finder** — Minnesota-first (aaMinnesota AA + NA BMLT +
  curated pathway meetings), live/upcoming time filter, radius slider,
  offline tile prefetch, marker clustering (`flutter_map`, keyless tiles)
- **Recovery Constellation** — stars for milestones/steps/goals,
  phyllotaxis growth, zoom, shape-share
- **Recovery Circle feed** — alias-only local feed + optional Firestore
  mirror; guardrails C1–C5 enforced (`blueprints/pet-store-rules.md`)
- **Sponsor linking** — Ed25519 pairing codes, signed step-work bundles,
  clipboard or Firestore transport, Sponsor Mode screen
- **12 Steps** — guided worksheets, literature links, sign-off ledger
- **Recovery Coach** — scripted brain (floor) + TFLite INT8 intent model;
  safety pipeline is fixed order:
  guardrail → crisis keywords → GGUF/TFLite → skills → keyword fallback
- **Pet companion** — never dies, never guilts; Sparks economy
  (cosmetics only, caps enforced) + "Trials of the Path" minigame where
  losing means your companion learned something
- **GGUF deeper chat** (optional) — on-device LLM via `llama_cpp_dart`,
  RAM-gated, off by default, output re-passed through the guardrail

## Development

The human builds in Android Studio. Agents must NOT run
`flutter build apk|appbundle|run`. Agent gates:

```bash
flutter pub get        # resolve deps
flutter analyze        # must report: No issues found
flutter test           # host tests must pass
```

After any Drift schema edit: bump `schemaVersion`, add migration block,
then `dart run build_runner build --delete-conflicting-outputs`.

See `AGENTS.md` (operating law) and `RULES.md` (technical laws learned
the hard way) before touching code.

## Documentation map

| Doc | Purpose |
|---|---|
| `blueprints/roadmap-v2.md` | Feature queue + shipped reference (source of truth for progress) |
| `blueprints/SPRINT_PLAN.md` | Original MVP plan (complete, historical) |
| `blueprints/pet-store-rules.md` | Sparks economy laws + feed guardrails C1–C5 |
| `blueprints/gguf-feasibility.md` | Deeper-chat device tiers, models, implementation status |
| `blueprints/tacmap-extraction.md` | Map port plan (P0–P3 shipped) |
| `blueprints/firebase-setup.md` | Console walkthrough for cloud sync |
| `blueprints/recovery-pet-checklist.md`, `recovery-coach-checklist.md` | Per-system checklists (kept current) |

## Privacy posture

Offline-first by default. The journal is encrypted (SQLCipher, key in
system secure storage). The feed is alias-only — rules reject identity
and sober-time fields. Firebase is optional; without it the app runs
fully local.
