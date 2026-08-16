# Recovery Pet — Blueprint Checklist
## System: Path Companion (working name)
## Document Version: 1.0.0
## Date: August 15, 2026

> **Guiding rule:** The pet *thrives* with care. It never “dies” to shame the user.
> Low activity → restful / sleepy / “I’m here when you are.”
> Crisis mood → prioritize Ground + SOS, never gamify distress.

Aligned with: *Recovery is not one path. Recovery is the path you build.*

---

## 0. Philosophy gates (must pass before any code)

- [ ] Pet never ranks recovery paths (AA vs Dharma vs Wellbriety, etc.)
- [ ] No punitive death / guilt streak mechanics
- [ ] Cosmetic rewards only (themes, outfits, backgrounds) — never paywall safety/SOS
- [ ] Works offline-first; pet state lives in Drift / local prefs
- [ ] Accessible: large taps, calm motion, reduce-motion option
- [ ] Name finalized (candidates: Path Companion, Ember, North, Sprout, Lumie, Kin)

---

## 1. Product definition

### 1.1 Role
- [ ] Daily emotional anchor on Home / Dashboard
- [ ] Incentive layer for toolbox use + gentle movement
- [ ] Visual story parallel to Constellation (daily vs long-arc)

### 1.2 User-facing promise
- [ ] One-sentence pitch written for onboarding
- [ ] First-run “meet your companion” flow sketched (optional, skippable)

---

## 2. Core stats (v1)

| Stat | Fed by | Decay | UI |
|------|--------|-------|----|
| Energy | Toolbox actions, walks | Slow over idle days | Bar / glow |
| Bond | Consistent care (not perfection) | Very slow | Heart / trust |
| Mood | Daily check-in | Resets daily | Face / pose |
| Sparks | Currency from actions | Never decays | Wallet |

- [ ] Confirm v1 stats set (Energy, Bond, Mood, Sparks)
- [ ] Document decay formulas (compassionate, not aggressive)
- [ ] Define “resting” state when Energy low (not dead)

---

## 3. Feed actions → rewards

### 3.1 Recovery actions (primary)
- [ ] Daily mood check-in → Sparks + Mood update
- [ ] Journal entry save → Sparks + Energy
- [ ] Gratitude entry → Sparks
- [ ] Meditation / breath / Grounding complete → Sparks + Energy
- [ ] Meeting logged / finder used → Sparks
- [ ] Weekly goal progress → Sparks
- [ ] Constellation milestone earned → larger Sparks + Bond

### 3.2 Movement (secondary)
- [ ] v1: manual “I took a walk” button (no sensors required)
- [ ] v2: pedometer / Health Connect steps goal
- [ ] Cap daily movement Sparks (anti-obsessive)

### 3.3 Explicit non-goals
- [ ] No Sparks for doom-scrolling the feed
- [ ] No Sparks for opening the app only
- [ ] No punishment for relapse language in journal (safety first)

---

## 4. Sparks economy

- [ ] Base rewards table written (e.g. check-in 5, journal 10, walk 15, milestone 50)
- [ ] Daily Sparks soft cap (optional)
- [ ] Spend catalog v1:
  - [ ] Pet outfits / colors
  - [ ] Home theme packs (ties to GUI blueprint)
  - [ ] Background packs
  - [ ] Constellation skin accents
- [ ] Free starter outfit + theme always unlocked
- [ ] No real-money IAP in v1 (local only)

---

## 5. Visual / animation states

- [ ] Idle loop (breathing, subtle sway)
- [ ] Happy / celebrated (after Sparks earn)
- [ ] Resting / low energy
- [ ] Supportive / soft (user marked Struggling)
- [ ] Sleep (night or long idle)
- [ ] Milestone party (rare, not every tap)
- [ ] Reduce-motion: static pose only

**Art pipeline options**
- [ ] Lottie loops (preferred for polish + size)
- [ ] Rive (if interactive pet needed later)
- [ ] Sprite sheet + AnimationController (fully code-owned)
- [ ] Still PNGs + Ken Burns only (MVP)

---

## 6. Data model (Drift)

### Table: `recovery_pets`
- [ ] `id` TEXT PK
- [ ] `name` TEXT
- [ ] `species_or_style` TEXT
- [ ] `energy` REAL
- [ ] `bond` REAL
- [ ] `mood` TEXT
- [ ] `sparks` INTEGER
- [ ] `unlocked_items` TEXT (JSON)
- [ ] `equipped_outfit` TEXT
- [ ] `last_fed_at` INTEGER
- [ ] `created_at` INTEGER

### Table: `pet_events` (optional audit)
- [ ] `id`, `pet_id`, `event_type`, `sparks_delta`, `timestamp`, `meta_json`

- [ ] Schema version bump + migration planned
- [ ] Riverpod providers sketched (`petProvider`, `sparksProvider`)

---

## 7. Screens & surfaces

- [ ] Dashboard pet card (compact)
- [ ] Full pet screen (stats, feed log, shop)
- [ ] Shop / unlock grid
- [ ] Optional onboarding “Name your companion”
- [ ] Settings: mute pet motion, rename, reset cosmetics (not progress)

---

## 8. Integration map

| Feature | Pet hook |
|---------|----------|
| Onboarding complete | Hatch / first meet |
| Check-in | Mood + Sparks |
| Journal | Energy + Sparks |
| Grounding 60s | Energy + Sparks |
| SOS configured | Bond bonus (safety is care) |
| Constellation point | Celebration |
| Theme purchased | Apply GUI theme |

- [ ] Hook list implemented one-by-one, not big-bang

---

## 9. Safety & ethics checklist

- [ ] Struggling / Need Help check-in → pet soft mode + link Ground/SOS
- [ ] No “you neglected me” copy
- [ ] No comparison to other users’ pets
- [ ] Crisis text in journal does not reduce Bond
- [ ] Copy reviewed for non-punitive tone

---

## 10. Phased delivery

### Phase A — MVP (code + still art)
- [ ] Drift tables + providers
- [ ] Dashboard card with Energy / Sparks
- [ ] Earn Sparks from check-in + journal stubs
- [ ] One outfit unlock
- [ ] Resting vs active states (static images)

### Phase B — Motion
- [ ] Lottie or sprite idle/happy/rest
- [ ] Celebrate micro-animation on earn

### Phase C — Movement
- [ ] Manual walk button
- [ ] Optional pedometer

### Phase D — Shop & themes
- [ ] Sparks shop
- [ ] Theme packs tied to GUI blueprint

### Phase E — Polish
- [ ] First-run hatch story
- [ ] Accessibility / reduce-motion
- [ ] Balance pass on economy

---

## 11. Acceptance criteria (MVP done when)

- [ ] User can see pet on dashboard after onboarding
- [ ] Completing a check-in increases Sparks and updates Mood
- [ ] Idle days only move pet to Resting, never “dead”
- [ ] User can unlock one cosmetic with Sparks
- [ ] SOS / Ground remain reachable and unchanged by pet state

---

## 12. Open decisions

- [ ] Final name
- [ ] Art style (illustrated flat / soft 3D / line art)
- [ ] Single companion vs unlockable species
- [ ] Whether family/circle can send “encouragement” to pet (Phase 2+)
