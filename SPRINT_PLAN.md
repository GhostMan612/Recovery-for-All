# Recovery for All — Sprint Plan & Implementation Checklist

**Generated:** August 15, 2026  
**Status:** Ready to Execute  
**Target:** MVP with all core screens functional and `flutter analyze` clean

---

## Phase 1: Fix Breakage & App Health ⚡
**Priority:** 🔴 CRITICAL — Blocks all other work  
**Effort:** 3–4 hours  
**Owner:** First sprint

### Task 1.1: Fix journal_screen.dart analyzer errors
**Files:**
- `lib/screens/journal_screen.dart`

**Errors to fix:**
1. `const_constructor_param_type_mismatch` at line 121 (TextAlign.center in const constructor)
2. `deprecated_member_use` for `withOpacity()` → use `withValues()`
3. `prefer_final_fields` for `_savedPin`

**Done When:**
- [ ] TextAlign.center removed from const TextField decoration
- [ ] All `.withOpacity()` calls replaced with `.withValues(alpha: ...)`
- [ ] `_savedPin` marked as `final`
- [ ] `flutter analyze` shows 0 errors for this file

**Effort:** 30 minutes

---

### Task 1.2: Fix meeting_map_screen.dart — create missing service & model
**Files:**
- `lib/services/meeting_finder_service.dart` (CREATE)
- `lib/screens/meeting_map_screen.dart` (EDIT)

**Root cause:**
- Import of non-existent `meeting_finder_service.dart`
- Undefined class `RecoveryMeeting`

**Done When:**
- [ ] `meeting_finder_service.dart` created with `RecoveryMeeting` model class
- [ ] `RecoveryMeeting` has fields: `id`, `name`, `latitude`, `longitude`, `time`, `address`
- [ ] `meeting_map_screen.dart` imports corrected
- [ ] No analyzer errors for meeting_map_screen.dart
- [ ] Meeting list initializes without runtime errors

**Effort:** 45 minutes

---

### Task 1.3: Fix splash_screen.dart async BuildContext issues
**Files:**
- `lib/screens/splash_screen.dart`

**Issues:**
- Lines 48 & 63: Use BuildContext across async gaps without `mounted` check

**Done When:**
- [ ] `_routeToNextScreen()` checks `if (!mounted) return;` before all navigation
- [ ] `flutter analyze` info warnings cleared for this file

**Effort:** 15 minutes

---

### Task 1.4: Clean up unused imports & deprecations
**Files:**
- `lib/database/recovery_database.dart` (remove unused `dart:convert`)
- `lib/services/nwi_progress_service.dart` (remove unused `dart:math`)
- `lib/services/ollama_service.dart` (fix null-aware markers)
- `lib/widgets/sponsor_manager_widget.dart` (fix TextAlign const, deprecated value)

**Done When:**
- [ ] All unused imports removed
- [ ] All null-aware operators (`?`) used instead of manual nullchecks
- [ ] `flutter analyze` returns 0 errors (warnings/infos acceptable for now)

**Effort:** 30 minutes

---

### Task 1.5: Verify Phase 1 complete
**Done When:**
- [ ] `flutter analyze` returns exit code 0
- [ ] App builds without errors: `flutter build apk --debug` succeeds
- [ ] No runtime crashes on splash → onboarding transition

**Effort:** 15 minutes (verification only)

**Total Phase 1 Effort:** ~2–2.5 hours

---

## Phase 2: Complete Onboarding Flow 🎯
**Priority:** 🟠 HIGH — Must finish before dashboard can be personalized  
**Effort:** 5–6 hours  
**Dependency:** Phase 1 complete

### Task 2.1: Implement Step 2 — Goal Clarification screen
**Files:**
- `lib/screens/onboarding_screen.dart` (_buildStep1Goals → already started; complete it)

**Requirements from blueprint:**
- Multi-select chips for goals (Alcohol, Opioids, Nicotine, Cannabis, Stimulants, Prescriptions, Vaporizers, Gambling, Gaming, Shopping, Social Media, Workaholism, Trauma, Grief, Family, Emotional)
- At least 1 goal must be selected to proceed
- Visual feedback (selected = bright color, unselected = muted)

**Done When:**
- [ ] User can select multiple goals
- [ ] "Continue" button disabled until ≥1 goal selected
- [ ] Selected goals stored in `_selectedGoals` Set
- [ ] Chip styling matches dashboard color scheme (#38BDF8 primary)
- [ ] Screen displays all 15+ goal options (scrollable)

**Effort:** 1 hour

---

### Task 2.2: Implement Step 3 — Community Alignment screen
**Files:**
- `lib/screens/onboarding_screen.dart` (_buildStep2Paths → replace placeholder)

**Requirements from blueprint:**
- Unranked list of recovery modalities (AA, SMART, Recovery Dharma, Wellbriety, Custom Path)
- Each is a toggle/card
- No single path promoted
- Multi-select allowed

**Done When:**
- [ ] User can select multiple paths
- [ ] Each path displays with icon/description
- [ ] Selected paths stored in `_selectedPaths` Set
- [ ] Visual distinction between selected/unselected
- [ ] At least 1 path must be selected (enforce in next button logic)

**Effort:** 1 hour

---

### Task 2.3: Implement Step 4 — Toolbox Construction screen
**Files:**
- `lib/screens/onboarding_screen.dart` (_buildStep3Tools → replace placeholder)

**Requirements from blueprint:**
- Dynamically show tools based on selected paths from Step 3
- Show tool previews (simple icon + name)
- Multi-select tools
- Universal tools always shown (Journal, Gratitude, Meeting Finder, SOS button)

**Done When:**
- [ ] Tools list updates when returning from previous step (re-select path)
- [ ] Each tool displays with icon, name, program affiliation
- [ ] User can toggle each tool on/off
- [ ] Selected tools stored in `_selectedTools` (new Set)
- [ ] Preview of dashboard shows which tools will appear

**Effort:** 1.5 hours

---

### Task 2.4: Implement Step 5 — Values Sorting screen (Schwartz)
**Files:**
- `lib/screens/onboarding_screen.dart` (_buildStep4Values → replace placeholder)

**Simplified MVP version:**
- Show 10 core values (Self-Direction, Benevolence, Universalism, Security, Tradition, Conformity, Hedonism, Achievement, Power, Stimulation)
- User selects top 3–5
- Store in `_selectedValues`

**Done When:**
- [ ] User can select 3–5 values
- [ ] "Continue" button disabled until 3–5 selected
- [ ] Selected values displayed with checkmarks
- [ ] Values stored as list of strings

**Effort:** 45 minutes

---

### Task 2.5: Implement Step 6 — Personality baseline screen
**Files:**
- `lib/screens/onboarding_screen.dart` (_buildStep6Dynamics → refine existing)

**Current state:** Basic stress response slider exists  
**Enhance to:**
- 2–3 more sliders (tone, spiritual openness)
- Store all values for future AI personalization

**Done When:**
- [ ] 3 sliders present: tone, spiritual openness, stress response
- [ ] All slider values stored (0.0–1.0 doubles)
- [ ] UI labels clear and descriptive

**Effort:** 30 minutes

---

### Task 2.6: Finalize onboarding database handoff
**Files:**
- `lib/screens/onboarding_screen.dart` (_finalizeOnboarding)
- `lib/database/recovery_database.dart` (verify schema)

**Requirements:**
- Profile saved with all selections (goals, paths, values)
- Initial counter created for first selected goal
- Initial constellation point seeded ("Began My Recovery Path")

**Done When:**
- [ ] Profile row inserted into Profiles table
- [ ] `profile.selectedGoals` = JSON array of goal strings
- [ ] `profile.activePaths` = JSON array of path strings
- [ ] `profile.selectedValues` = JSON array of value strings
- [ ] Initial counter with label = first goal, start date = now
- [ ] Constellation point seeded at (0.5, 0.5)
- [ ] Dashboard loads without errors after onboarding

**Effort:** 45 minutes

---

### Task 2.7: Add onboarding → dashboard transition
**Files:**
- `lib/screens/onboarding_screen.dart`
- `lib/screens/dashboard_screen.dart`

**Done When:**
- [ ] Onboarding complete calls `onOnboardingComplete()` callback
- [ ] Dashboard loads user profile from database
- [ ] Dashboard displays selected username
- [ ] No crash on transition

**Effort:** 15 minutes

**Total Phase 2 Effort:** ~5–5.5 hours

---

## Phase 3: Wire Dashboard to Functional Screens 🎨
**Priority:** 🟠 HIGH — Core UX foundation  
**Effort:** 4–5 hours  
**Dependency:** Phase 1 & 2 complete

### Task 3.1: Show user's active recovery paths on dashboard
**Files:**
- `lib/screens/dashboard_screen.dart`

**Requirements:**
- Load profile from database
- Display banner showing selected paths (e.g., "AA • SMART • Dharma")
- Show dynamic toolbox based on `activePaths` from profile

**Done When:**
- [ ] Dashboard reads profile from DB on init
- [ ] Active paths displayed as badges/pills at top
- [ ] Toolbox cards are dynamically generated, not hardcoded
- [ ] Cards match the user's selected tools from onboarding

**Effort:** 1 hour

---

### Task 3.2: Wire "Private Journal" card → JournalScreen
**Files:**
- `lib/screens/dashboard_screen.dart`
- Verify: `lib/screens/journal_screen.dart` is complete

**Done When:**
- [ ] Tapping "Private Journal" navigates to JournalScreen
- [ ] Journal screen loads with PIN auth working
- [ ] User can write and save entries
- [ ] Entries persist in database
- [ ] Back button returns to dashboard

**Effort:** 45 minutes

---

### Task 3.3: Wire "Meeting Finder" card → Meeting map
**Files:**
- `lib/screens/dashboard_screen.dart`
- `lib/screens/meeting_map_screen.dart`
- `lib/services/meeting_finder_service.dart`

**Requirements:**
- Mock meeting data or wire to real API
- Map displays with user location
- Tap meeting marker → details

**Done When:**
- [ ] Tapping "Meeting Finder" navigates to MeetingMapScreen
- [ ] Map loads without crashes
- [ ] Markers display for 5+ mock meetings
- [ ] User can tap a marker and see meeting details

**Effort:** 1 hour

---

### Task 3.4: Wire "Urge Coping" card → CopingToolScreen (create)
**Files:**
- `lib/screens/urge_coping_screen.dart` (CREATE)
- `lib/screens/dashboard_screen.dart` (update card tap)

**Simple MVP:**
- Display a "TIPP" coping technique (Temperature, Intense exercise, Paced breathing, Paired muscle relaxation)
- Button to cycle through techniques
- Timer for breathing exercise

**Done When:**
- [ ] Screen created and navigable from dashboard
- [ ] Displays 4 basic coping techniques
- [ ] Breathing timer works (simple 4-7-8 pattern)
- [ ] Returns to dashboard cleanly

**Effort:** 1 hour

---

### Task 3.5: Wire "Daily Gratitude" → Gratitude entry screen
**Files:**
- `lib/screens/gratitude_entry_screen.dart` (exists, likely stub)
- `lib/screens/dashboard_screen.dart` (update card tap)

**Done When:**
- [ ] Tapping card opens gratitude screen
- [ ] User can enter 3 things they're grateful for
- [ ] Entries saved to database
- [ ] Returns to dashboard

**Effort:** 45 minutes

---

### Task 3.6: Wire "Step Tracker" → AA 12 Steps viewer
**Files:**
- `lib/screens/steps_viewer_screen.dart` (CREATE)
- `lib/screens/dashboard_screen.dart` (update card tap)

**Simple MVP:**
- Show list of 12 steps
- Tap step → expand details
- Optional: checkbox to mark completed (store in DB)

**Done When:**
- [ ] Screen created with all 12 steps listed
- [ ] Each step shows full text when tapped
- [ ] Completion state stored (optional for MVP)

**Effort:** 1 hour

---

### Task 3.7: Wire "Reflections" → Daily reflection prompt screen
**Files:**
- `lib/screens/daily_reflection_screen.dart` (CREATE)
- `lib/screens/dashboard_screen.dart` (update card tap)

**Simple MVP:**
- Show daily recovery prompt/meditation
- Rotate through 7 pre-written reflections
- User can view previous reflections

**Done When:**
- [ ] Screen displays today's reflection prompt
- [ ] Button to see next reflection
- [ ] Saves view history
- [ ] Returns cleanly to dashboard

**Effort:** 45 minutes

---

### Task 3.8: Verify dashboard phase complete
**Done When:**
- [ ] All 6 dashboard cards open real screens (no snackbars)
- [ ] Each screen has a back button / returns to dashboard
- [ ] No crashes during navigation
- [ ] Flutter analyze clean

**Effort:** 15 minutes

**Total Phase 3 Effort:** ~5 hours

---

## Phase 4: Build Core Recovery Features 💪
**Priority:** 🟡 MEDIUM — Delivers the core app value  
**Effort:** 6–8 hours  
**Dependency:** Phase 1, 2, 3 complete

### Task 4.1: Implement sobriety counter with multiple counters
**Files:**
- `lib/screens/sobriety_counter_screen.dart` (CREATE)
- `lib/database/recovery_database.dart` (already has Counter table)

**Requirements:**
- Show list of active counters (one per selected goal)
- Each counter displays: days, hours, minutes
- Tap to expand → reset option (with confirmation)
- Add new counter button

**Done When:**
- [ ] Counters load from database
- [ ] Counter displays formatted as "418 days, 12h 04m"
- [ ] Tap to see anniversary date
- [ ] Reset button works with PIN confirmation
- [ ] New counter dialog works

**Effort:** 1.5 hours

---

### Task 4.2: Build recovery chip/badge system
**Files:**
- `lib/widgets/recovery_chip_widget.dart` (CREATE)
- `lib/screens/sobriety_counter_screen.dart` (integrate)

**Chips to earn:**
- 24 hours, 30 days, 60 days, 90 days, 6 months, 1 year, 2+ years

**Done When:**
- [ ] Widget displays earned chips
- [ ] Calculates earned chips from counter start date
- [ ] Visual design polished (icons + dates)
- [ ] Tap chip to see earned date + share button (mock)

**Effort:** 1 hour

---

### Task 4.3: Build wellness wheel / daily check-in
**Files:**
- `lib/screens/wellness_check_in_screen.dart` (likely exists; refine)
- `lib/database/recovery_database.dart` (verify WellnessCheckIn table)

**Requirements:**
- 6-dimension wheel: Spiritual, Intellectual, Emotional, Physical, Social, Occupational
- Slider for each (1–10)
- Shows history (trend over last 7 days)

**Done When:**
- [ ] User can adjust all 6 dimensions
- [ ] Submission saves to database
- [ ] Historical view shows last 7 check-ins
- [ ] Simple line chart or bar chart display

**Effort:** 1.5 hours

---

### Task 4.4: Build sponsor manager & emergency contact screen
**Files:**
- `lib/screens/sponsor_manager_screen.dart` (exists; refine)
- `lib/widgets/sponsor_manager_widget.dart` (refactor/extend)

**Requirements:**
- Store sponsor name, phone, email
- Emergency contacts list
- Quick-dial buttons
- One-tap call to sponsor

**Done When:**
- [ ] Add/edit sponsor form works
- [ ] Sponsor phone saved to device storage
- [ ] One-tap call button triggers native phone app
- [ ] Multiple emergency contacts supported

**Effort:** 1.5 hours

---

### Task 4.5: Enhance crisis safety layer (SOS button)
**Files:**
- `lib/screens/sos_safety_sheet.dart` (CREATE)
- `lib/screens/dashboard_screen.dart` (wire FAB)
- `lib/services/safety_guardrail_service.dart` (already implemented)

**Requirements:**
- Large red SOS button on dashboard (already exists)
- Tap → show emergency options:
  - Call 988 Suicide & Crisis Lifeline
  - Call sponsor
  - Find nearest meeting
  - Emergency contacts
  - Crisis resources

**Done When:**
- [ ] SOS button taps open bottom sheet
- [ ] All 5 options present with icons
- [ ] Call buttons trigger native phone
- [ ] Meeting finder shows 3 nearest meetings
- [ ] Crisis resources include links

**Effort:** 1.5 hours

---

### Task 4.6: Integrate local AI chatbot (Ollama)
**Files:**
- `lib/screens/chatbot_screen.dart` (exists; refine)
- `lib/services/ollama_service.dart` (already implemented)
- `lib/services/safety_guardrail_service.dart` (already implemented)

**Current state:** Chatbot screen exists, safety guards in place  
**Enhance to:**
- Add offline fallback (when Ollama unavailable, show helpful text)
- Better error messages
- Optional: add typing indicator

**Done When:**
- [ ] Chat sends message to Ollama service
- [ ] Response displays in chat UI
- [ ] Crisis guardrail tested (triggers SOS on crisis phrases)
- [ ] Offline fallback works
- [ ] No crashes on network error

**Effort:** 1 hour

---

### Task 4.7: Build daily motivation feed
**Files:**
- `lib/screens/daily_motivation_screen.dart` (CREATE)

**Simple MVP:**
- Show rotating quote/affirmation
- Next/prev buttons
- Show 30 quotes (AA, NA, recovery, stoic)
- Save favorites to database

**Done When:**
- [ ] Screen displays one quote per page
- [ ] Swipe or button to next quote
- [ ] Favorite button saves to DB
- [ ] Favorites screen shows all saved quotes

**Effort:** 45 minutes

---

### Task 4.8: Constellation milestone tracker
**Files:**
- `lib/screens/constellation_canvas.dart` (exists; refine)
- `lib/database/recovery_database.dart` (ConstellationPoints table exists)

**Simple MVP:**
- Display 3D-ish canvas with milestone points
- Each point = achievement (completed step, anniversary, goal)
- Auto-generate initial points based on user path

**Done When:**
- [ ] Canvas renders without crashes
- [ ] Points display at saved coordinates
- [ ] Tap point to see milestone details
- [ ] New points can be added (manual + auto)

**Effort:** 1.5 hours

---

### Task 4.9: Weekly goals tracker
**Files:**
- `lib/screens/weekly_goals_screen.dart` (CREATE)
- `lib/database/recovery_database.dart` (WeeklyGoals table exists)

**Simple MVP:**
- Add weekly goals (e.g., "Attend 3 meetings", "Call sponsor")
- Check off as completed
- Progress bar
- Reset each Monday

**Done When:**
- [ ] User can create goal with target count
- [ ] Can check off completions
- [ ] Progress tracked visually
- [ ] Data persists across sessions

**Effort:** 1 hour

**Total Phase 4 Effort:** ~10 hours (note: more complex, so estimates higher)

---

## Phase 5: Production Polish & Documentation 🎁
**Priority:** 🟡 MEDIUM — Final touches  
**Effort:** 2–3 hours  
**Dependency:** Phase 1–4 complete

### Task 5.1: Test app-level settings (Ollama endpoint, PIN, etc.)
**Files:**
- `lib/screens/settings_screen.dart` (CREATE or refine)

**Done When:**
- [ ] User can change Ollama endpoint
- [ ] User can change journal PIN
- [ ] Settings persist across restarts
- [ ] About screen with app version

**Effort:** 45 minutes

---

### Task 5.2: Accessibility pass
**Done When:**
- [ ] All buttons have semantic labels
- [ ] Font sizes meet WCAG standards
- [ ] Color contrast ≥ 4.5:1
- [ ] No hardcoded text sizes blocking zoom

**Effort:** 30 minutes

---

### Task 5.3: App icon & splash screen polish
**Files:**
- `assets/images/splash_bg.jpg`
- `android/app/src/main/AndroidManifest.xml`

**Done When:**
- [ ] App icon professional (or placeholder acceptable)
- [ ] Splash screen animates smoothly
- [ ] No janky transitions

**Effort:** 30 minutes

---

### Task 5.4: Beta testing checklist
**Done When:**
- [ ] Onboarding flow tested (all paths work)
- [ ] Dashboard navigation tested
- [ ] Journal + encryption tested
- [ ] Counters increment correctly
- [ ] Safety guardrails trigger correctly
- [ ] No crashes during 5-minute user session
- [ ] `flutter analyze` clean

**Effort:** 45 minutes

---

**Total Phase 5 Effort:** ~2.5 hours

---

## 📊 Total Project Effort Summary

| Phase | Task Count | Effort | Status |
|-------|-----------|--------|--------|
| **Phase 1: Fix Breakage** | 5 | 2.5h | 🔴 START HERE |
| **Phase 2: Onboarding** | 7 | 5.5h | After Phase 1 |
| **Phase 3: Dashboard Wiring** | 8 | 5h | After Phase 2 |
| **Phase 4: Core Features** | 9 | 10h | After Phase 3 |
| **Phase 5: Polish** | 4 | 2.5h | Final |
| **TOTAL** | **33** | **~25.5h** | MVP Complete |

**Recommended approach:**
- Sprint 1 (Today): Phase 1 (2.5h) → Phase 2 partial (2–3h)
- Sprint 2: Phase 2 complete (2–3h) → Phase 3 start (1–2h)
- Sprint 3: Phase 3 complete (3–4h) → Phase 4 start (2–3h)
- Sprint 4: Phase 4 complete (7–8h)
- Sprint 5: Phase 5 (2.5h) → Release

---

## 🚀 Next Steps
1. Start Phase 1 now (30 min est.)
2. Run `flutter analyze` after each task to verify
3. Test each feature before moving to next phase
4. Commit to git after each phase completes

**Let's begin Phase 1 → Start with Task 1.1**
