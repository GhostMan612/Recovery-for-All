# Recovery for All

**Offline-first, privacy-first, pathway-tailored addiction recovery companion.**

> "Recovery is not one path. Recovery is the path you build."

---

## What Makes This Different

| Category | Every Other App | **Recovery for All** |
|----------|-----------------|----------------------|
| **Architecture** | Cloud-dependent, tracking-enabled | **100% offline-first, zero tracking, zero analytics** |
| **Privacy** | Identifiers sold, plaintext storage | **AES-256 SQLCipher encryption, biometric + PIN lock, keys in system secure storage** |
| **Pathways** | Single (AA) or none | **9 fellowships**: AA, NA, Dharma, Wellbriety, LifeRing, WFS, CR, SMART, InTheRooms |
| **Meeting Finder** | Online-only, 1 fellowship | **Offline OSM/Esri tiles, GPS cascade, 9 fellowships, curated MN meetings** |
| **Companion** | None or generic streak | **Pet RPG** — Sparks/Bond/Mood/Energy, species, dresser, Lottie auras, **Trials of the Path** turn-based urge monsters using real coping skills |
| **Verification** | Tap = reward | **Pedometer-verified walks** (500 steps/30 min), meetings/milestones cap-exempt |
| **Guide** | None or external docs | **Full-app tutorial chatbot** with pet avatar — answers ANY feature question |
| **Journal** | Basic notes | **AES-GCM encrypted, PBKDF2 PIN, legacy fallback** |
| **LLM** | Cloud, $25/mo (Reframe) | **Optional on-device GGUF** via llama_cpp_dart, RAM-gated, off by default |
| **Constellation** | None | **3D phyllotaxis** — zoom, orbit, star memories, shape sharing |
| **Cost** | $120–$480/year | **$0 forever — no premium tier, no ads, no subscriptions** |

---

## Feature Map

### Core Recovery
- **Sobriety Counters** — specific start dates, milestone chips (24h → 2yr)
- **Meeting Finder** — Minnesota-first (aaMinnesota 1,900+ geo AA + NA BMLT), live/upcoming filter, radius slider, city filter, **offline tile prefetch**, marker clustering
- **9 Fellowships** — AA, NA, Dharma, Wellbriety, LifeRing, WFS, CR, SMART, InTheRooms
- **Sponsor Linking** — Ed25519 pairing codes, signed step-work bundles, clipboard/Firestore transport, Sponsor Mode screen

### Evidence-Based Tools
- **12 Steps** — guided worksheets, literature links, sign-off ledger
- **Recovery Coach** — 16 scripted skills + TFLite INT8 intent model + optional GGUF; safety pipeline fixed: guardrail → crisis keywords → GGUF/TFLite → skills → keyword fallback
- **Wellness Wheel** — 6 dimensions (PERMA-aligned), sponsor-shareable
- **Weekly Goals** — Monday reset, small promises, streaks
- **Gratitude + Daily Reflection** — streak tracks consistency, not perfection
- **Coping Tools** — urge surfing, box breathing, 5-4-3-2-1 grounding, HALT check (offline, haptic)
- **Grounding Exercises** — eyes open/closed, haptic cues
- **Literature Library** — 13 verified offline-downloadable texts (Big Book, NA Basic Text, Dharma talks, Wellbriety, SMART manual)
- **Community Resources** — 12 sections: hotlines, treatment locators, sober housing, legal aid (offline-first, pathway-filtered)

### Companion & Economy
- **Pet Companion** — never dies, never guilts; Sparks/Bond/Mood/Energy
- **Sparks Economy** — daily cap 150, walks/meetings/milestones **cap-exempt**, anti-grind caps
- **Dresser** — ~90 cosmetics, species-specific bodies, seasonal re-issue calendar, Lottie auras/moods
- **Trials of the Path** — turn-based urge monsters, coping skills as abilities, focus system, losing = "companion learned"
- **Step-Counter Verified Walks** — pedometer integration, 500 steps/30 min minimum, prevents tap-only abuse

### Visualization & Sharing
- **Recovery Constellation** — 3D phyllotaxis growth, zoom/orbit, star memories, shape sharing
- **Recovery Circle Feed** — alias-only, no sober-time numbers, reactions (Strength/Proud/Respect), guardrails C1–C5
- **Data Export** — CSV + summary, local-only
- **SOS Sheet** — one-tap 988, sponsor call, meeting finder

### Architecture
- **Flutter + Drift + SQLCipher** — local-first, optional Firestore mirror
- **Offline Map Tiles** — Esri Canvas (keyless), cache-first TileProvider, offline prefetch packs
- **GPS Cascade** — fresh fix → stale fallback → Twin Cities fallback
- **On-Device GGUF** — llama_cpp_dart, prebuilt arm64 native libs (NDK 28.2), RAM-gated, off by default
- **Self-Healing Tutorial System** — build-time route validation via Flutter test

---

## Quick Start

```bash
# Prerequisites
flutter --version        # 3.24+
dart --version           # 3.12+

# Setup
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Agent gates (human builds in Android Studio)
flutter analyze          # must report: No issues found
flutter test             # 90+ tests must pass

# Run
flutter run              # or open in Android Studio → Run
```

**Python 3.12 via uv** required for coach model training:
```bash
python -m uv venv .venv-tf --python 3.12
python -m uv pip install --python .venv-tf numpy tensorflow-cpu
.venv-tf\Scripts\python.exe tools\train_coach_intent.py
```

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| `AGENTS.md` | Operating law (build boundary, commit rules, gotchas) |
| `CLAUDE.md` | Token conservation, filtered CLI output, build boundary |
| `RULES.md` | Technical laws learned the hard way |
| `SESSION_HANDOFF.md` | Cold-start entry point — current state, next moves |
| `blueprints/roadmap-v2.md` | Feature queue + shipped reference (source of truth) |
| `blueprints/competitive-analysis.md` | Deep competitive moat analysis |
| `blueprints/RECOVERY_FOR_ALL_MASTER_PLAN.md` | Execution log + next moves |
| `blueprints/pet-store-rules.md` | Sparks economy laws + feed guardrails C1–C5 |
| `blueprints/gguf-feasibility.md` | GGUF device tiers, models, implementation status |
| `blueprints/tacmap-extraction.md` | Map port plan (P0–P3 shipped) |
| `blueprints/firebase-setup.md` | Console walkthrough for cloud sync |
| `blueprints/whitepaper.pdf` | **Comprehensive whitepaper (this repo's manifesto)** |

---

## Privacy Posture

**Offline-first by default.** The journal is encrypted (SQLCipher, key in system secure storage). The feed is alias-only — rules reject identity and sober-time fields. Firebase is optional; without it the app runs fully local. **No analytics, no crash reporting, no tracking identifiers, no cloud dependency.**

---

## Device Fleet

| Device | RAM | Role |
|--------|-----|------|
| Blu View 5 | ~3 GB | GGUF gate OFF |
| Moto G 2025 | 4–8 GB | Primary test target |
| Dell Latitude 5400 | 16 GB | Dev host |

---

## License

Proprietary — Recovery for All. Not for commercial redistribution without permission.

---

*Built for the path you walk. No one else's.*