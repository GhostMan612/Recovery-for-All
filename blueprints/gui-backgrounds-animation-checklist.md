# GUI, Backgrounds & Animation — Blueprint Checklist
## System: Recovery Companion visual layer
## Document Version: 1.0.0
## Date: August 15, 2026

Aligned with onboarding blueprint (“subtle, organic animations”) and architecture
(theme engine, modular path UI). Primary palette already in app:

| Token | Value | Role |
|-------|-------|------|
| `bgDeep` | `#0F172A` | Scaffold |
| `bgCard` | `#1E293B` | Surfaces |
| `border` | `#334155` | Borders |
| `accent` | `#38BDF8` | Primary CTA |
| `success` | `#34D399` | Growth / calm |
| `danger` | `#DC2626` | SOS only |
| `textMuted` | `#94A3B8` / `#64748B` | Secondary |

---

## 0. Design principles

- [ ] Calm over spectacle (especially crisis-adjacent screens)
- [ ] Text always readable (scrim over every photo background)
- [ ] Motion is optional (`MediaQuery.disableAnimations` / reduce-motion)
- [ ] No path is visually “ranked” higher than another
- [ ] SOS remains high-contrast and unmissable
- [ ] Offline: all core UI assets local (no required CDN)

---

## 1. Asset inventory (current repo)

| File | Intended use |
|------|----------------|
| `assets/images/screen_background.png` | Default screen BG |
| `assets/images/screen_background (1).png` | Variant / alternate |
| `assets/images/splash_screen.png` | Splash |
| `assets/images/splash_screen (2).png` | Splash variant |
| `assets/images/app_icon.png` | Launcher |

### Hygiene
- [ ] Rename files to stable names (no spaces): e.g. `bg_default.png`, `splash_primary.png`
- [ ] Register every asset path in `pubspec.yaml`
- [ ] Document resolution targets (1x/2x/3x or single high-res + cacheWidth)

---

## 2. Shared widgets to build

### 2.1 `ThemedBackground`
- [ ] Full-bleed `Image.asset` or gradient fallback
- [ ] Configurable scrim opacity (default ~0.65–0.80)
- [ ] Optional Ken Burns toggle
- [ ] Optional path-based asset override (`AA` / `DHARMA` / `WELLBRIETY` / default)
- [ ] Used by: Onboarding, Dashboard, Settings, Journal, Grounding, Pet, Splash

### 2.2 `AppScaffold`
- [ ] Wraps `ThemedBackground` + SafeArea + optional AppBar styling
- [ ] Consistent horizontal padding token (24)

### 2.3 Design tokens file
- [ ] `lib/core/theme/app_colors.dart`
- [ ] `lib/core/theme/app_spacing.dart`
- [ ] `lib/core/theme/app_text_styles.dart`
- [ ] Dark `ThemeData` single source (already partial in `main.dart`)

---

## 3. Background strategy by screen

| Screen | Background | Motion |
|--------|------------|--------|
| Splash | `splash_*` | Fade in logo / soft scale |
| Onboarding welcome | `bg_default` | Ken Burns slow + fade text |
| Onboarding steps | `bg_default` or soft gradient | Minimal; chips static |
| Dashboard | `bg_default` | Optional subtle Ken Burns |
| Journal | darker scrim | None or very slow |
| Grounding | solid deep or soft gradient | Breath circle only (content, not BG) |
| SOS / Settings safety | solid / high scrim | **No** playful BG motion |
| Pet screen | themed pack | Pet animation, calm BG |

- [ ] Per-screen matrix approved
- [ ] Crisis surfaces use reduced motion always

---

## 4. Animation catalog (Flutter-native)

### 4.1 Allowed / preferred
- [ ] **Ken Burns** on still PNG/WebP (scale 1.0→1.06, 20–40s, reverse)
- [ ] **Opacity crossfade** between 2 backgrounds
- [ ] **Page transitions** (shared axis / fade through)
- [ ] **Lottie** ambient loops (stars, soft aurora) — small files
- [ ] **Implicit animations** (`AnimatedContainer`, `AnimatedOpacity`)
- [ ] **Staggered list entrance** on dashboard toolbox grid
- [ ] **Milestone confetti** (rare; package or custom)

### 4.2 Use sparingly
- [ ] Full-screen looping **video** backgrounds (battery)
- [ ] Heavy Rive on every screen
- [ ] Parallax tied to scroll on data-heavy screens

### 4.3 Accessibility
- [ ] Honor `disableAnimations`
- [ ] Setting: “Reduce motion” in app Settings
- [ ] No flashing / high-frequency strobe

---

## 5. Onboarding GUI checklist (Volume II alignment)

- [ ] Screen 1 Welcome: full-bleed BG + philosophy copy + privacy line
- [ ] Screen 2 Goals: multi-select chips, clear categories
- [ ] Screen 3 Paths: unranked cards (no featured path)
- [ ] Screen 4 Toolbox: LEGO-style selectable tools + preview copy
- [ ] Screen 5 Values: cascade UX (can be simplified v1)
- [ ] Screen 6 Tone scales: empathetic sliders
- [ ] Screen 7 Provisioning: progress + calm animation → Home
- [ ] Replace remaining “Placeholder” steps with real UI

---

## 6. Home / Dashboard GUI checklist

- [ ] Zone layout: greeting, intention, toolbox grid, action center / SOS
- [ ] Pet card slot (links Recovery Pet blueprint)
- [ ] Counter / milestone summary card
- [ ] Path-specific widgets injected from `active_paths`
- [ ] Settings + chat actions in AppBar consistent icons
- [ ] Empty states written with compassionate copy

---

## 7. Component library (minimum)

- [ ] Primary button (accent)
- [ ] Secondary / outlined button
- [ ] Danger button (SOS only)
- [ ] Choice chip / filter chip styles
- [ ] Card surface (radius 16, border `#334155`)
- [ ] Input fields (filled dark)
- [ ] Bottom sheet template
- [ ] Dialog template
- [ ] Snackbar success / error styles

---

## 8. Theme packs (ties to Pet Sparks)

- [ ] Pack structure: `assets/themes/<pack_id>/bg.png`, `preview.png`, `tokens.json`
- [ ] Default pack always free
- [ ] Unlock via Pet Sparks (see pet checklist)
- [ ] Runtime switch via Riverpod `activeThemeProvider`
- [ ] Path-inspired packs optional (Wellbriety earth, Dharma soft green, night constellation) — respectful, non-sacred appropriation

---

## 9. Typography & spacing

- [ ] Display / title / body / caption scales defined
- [ ] Line height ≥ 1.3 for body on emotional screens
- [ ] Min touch target 48dp
- [ ] Consistent 8pt grid

---

## 10. Implementation phases

### Phase 1 — Foundation
- [ ] Rename assets; fix `pubspec.yaml`
- [ ] `AppColors` / spacing tokens
- [ ] `ThemedBackground` + wire Onboarding + Dashboard
- [ ] Scrim readability pass

### Phase 2 — Motion
- [ ] Ken Burns optional flag
- [ ] Splash polish
- [ ] Reduce-motion setting

### Phase 3 — Ambient
- [ ] One Lottie starfield or aurora for Welcome only
- [ ] Dashboard grid entrance animation

### Phase 4 — Theme engine
- [ ] Theme pack loader
- [ ] Pet shop unlock hook

### Phase 5 — Path chrome
- [ ] Optional accent shifts per `active_paths` (subtle)

---

## 11. Acceptance criteria

- [ ] Every primary screen uses shared background widget or intentional solid
- [ ] Body text contrast acceptable on BG + scrim
- [ ] Animations disable cleanly when reduce-motion is on
- [ ] SOS UI never competes with decorative motion
- [ ] Asset load does not jank first frame (precache where needed)

---

## 12. Open decisions

- [ ] Single global BG vs per-path BGs at launch
- [ ] Lottie vs pure code for ambient stars
- [ ] Light theme ever, or dark-only v1
- [ ] Custom font (e.g. soft geometric) vs system
