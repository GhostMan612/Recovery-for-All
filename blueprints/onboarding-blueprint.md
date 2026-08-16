# Product Specification & Onboarding Architecture (Volume II)
## System: Inclusive "Build Your Path" Onboarding Flow
## Document Version: 1.0.0
## Date: August 9, 2026

---

## 1. Core Architectural Philosophy
The onboarding flow is not a rigid medical intake questionnaire or a standard administrative registration. It is an active constructor. Grounded in the absolute law that **"Recovery is not one path. Recovery is the path you build,"** the onboarding experience acts as a visual and cognitive configurator. It builds a user-specific "Recovery Operating System" by mapping their selected goals, communities, tools, and values directly to their local on-device Drift SQLite database. This initializes a personalized home screen populated only by the widgets they choose.

---

## 2. Onboarding Flow Step-by-Step Specification

```
[Screen 1: Welcome & Philosophy]
             │
             ▼
[Screen 2: Goal Clarification (Limitless Menu)]
             │
             ▼
[Screen 3: Community Alignment (Unranked Modular Matrix)]
             │
             ▼
[Screen 4: Toolbox Construction (LEGO Block Selection)]
             │
             ▼
[Screen 5: Values Sorting (Schwartz Circular Framework)]
             │
             ▼
[Screen 6: Personality & Communication Assessment]
             │
             ▼
[Screen 7: Database Provisioning & Home Screen Delivery]
```

### Screen 1: Welcome & Philosophy
* **UI Pattern:** Fluid full-screen welcome with subtle, organic animations.
* **Header text:** "Welcome back. Recovery is built one choice at a time."
* **Sub-text:** "We believe that recovery is deeply personal. No single program holds the monopoly on healing. This space is yours to build the combination of practices, teachings, and supports that keep you well."
* **Action:** Single, prominent "Begin My Journey" button.
* **Privacy Assurance:** Explicitly states: "This app runs offline-first. Your entries, goals, and reflections are encrypted and saved strictly on your local device."

### Screen 2: Goal Clarification (Limitless Menu)
* **UI Pattern:** Categorized grid of selectable chips with multi-select enabled.
* **Header text:** "What are you recovering from?"
* **Instructional text:** "Select any areas of challenge or healing you want to focus on. We treat all struggles with equal respect."
* **Categories & Choices:**
  * **Substances:** Alcohol, Opioids, Nicotine, Cannabis, Stimulants, Prescriptions, Vaporizers.
  * **Behavioral Addictions:** Gambling, Gaming, Shopping, Social Media, Workaholism, Compulsive Behaviors.
  * **Life Challenges:** Trauma Healing, Grief & Loss, Relationship Friction, Family Support, Emotional Well-being.
* **Action:** "Next: Choose Communities" button (disabled until at least one choice is made).

### Screen 3: Community Alignment (Unranked Modular Matrix)
* **UI Pattern:** Unranked vertical list of cards with toggles. No single path is pre-selected or promoted over another.
* **Header text:** "Which recovery philosophies resonate with you?"
* **Instructional text:** "Choose as many programs as you like. The app will layer their materials and tools together seamlessly."
* **Modality Registry:**
  * **Twelve-Step (AA / NA / Al-Anon):** Grounded in mutual support, sponsorship, step work, and group fellowship.
  * **SMART Recovery:** Cognitive-behavioral and evidence-based self-management tools (CBT, REBT).
  * **Recovery Dharma / Refuge Recovery:** Mindfulness-based practices, guided meditation, and Buddhist recovery principles.
  * **Wellbriety Movement:** Culturally specific Native American healing practices, the Medicine Wheel, and Seven Grandfather Teachings.
  * **Create Your Own Path:** A blank canvas to select habits, values, and practices without aligning with an established organization.
* **Action:** "Next: Build My Toolbox" button.

### Screen 4: Toolbox Construction (LEGO Block Selection)
* **UI Pattern:** Interactive dashboard builder. Selecting a community on Screen 3 dynamically expands the selection menu here. Tapping a tool shows a preview of how its widget will render on the Home Screen.
* **Header text:** "Let's build your recovery toolbox."
* **Instructional text:** "Select the daily practices and visual blocks you want on your dashboard. You can modify these at any time."
* **Available Tool Blocks:**
  * *If AA Selected:* **Twelve Steps Progress Tracker**, **Daily Reflections Feed**, **Sober Anniversary Clock**.
  * *If SMART Selected:* **Cost/Benefit Analysis (CBA) Tool**, **REBT Urge Coping Logger**, **Daily Goal Matrix**.
  * *If Dharma Selected:* **Guided Meditation Timer (5/10/15 min)**, **Dharma Readings & Eightfold Path**, **Breathing Guide**.
  * *If Wellbriety Selected:* **Medicine Wheel Reflection**, **Smudging & Cleansing Reminders**, **Seven Grandfather Teachings daily cards**.
  * *Universal Blocks:* **Private Journal (AES-256 Encrypted)**, **Daily Gratitude Entry**, **Meeting Finder (GPS)**, **Red SOS Emergency Bypass Button**.
* **Action:** "Next: Core Values Assessment" button.

### Screen 5: Values Sorting (Schwartz Circular Framework)
* **UI Pattern:** 3-tier cascade sorting interface.
  * **Tier 1 (The 30):** User is presented with a circular array of 30 cross-cultural value domains (Self-Direction, Benevolence, Universalism, Security, etc.) derived from Shalom Schwartz's universal value theory.
  * **Tier 2 (The 10):** User drags and narrows their selections down to 10.
  * **Tier 3 (The 5):** User selects their top 5 core principles.
* **Heuristic Conflict Checker:** If there is an implicit tension between the selected values (e.g., *Achievement* vs. *Self-Care*), the UI displays a gentle prompt: "You value both rest and high performance. We will help you balance your goals to prevent burnout."
* **My Purpose Statement:** A simple, guided text field: *"I live my life guided by [Value 1], [Value 2], and [Value 3] so that I can [user-written purpose text]."*
* **Action:** "Next: Personality Baseline" button.

### Screen 6: Personality & Communication Assessment
* **UI Pattern:** Minimalist, empathetic sliding scale questionnaire (10 questions).
* **Header text:** "How do you process challenges?"
* **Instructional text:** "This is not a diagnostic test. This baseline helps our local, private AI companion understand your communication preferences, triggers, and motivators from day one."
* **Core Scales:**
  * *Tone preference:* Highly Direct (Action-oriented) <───> Empathetic & Soft (Reflection-oriented)
  * *Spiritual openness:* Highly Secular (Scientific/Behavioral) <───> Fully Open (Spiritual/Traditional)
  * *Stress response:* Withdraw & Reflect <───> Seek Out Connections & Accountability
* **Action:** "Initialize My Platform" button.

### Screen 7: Database Provisioning & Home Screen Delivery
* **UI Pattern:** Engaging, aesthetic progress circle showing the system building the local workspace.
* **Behind-the-Scenes Action:**
  1. Spins up local Drift SQLite schemas.
  2. Provision profiles entry (Seeds `Profiles` table with anonymous username, Top 5 Values, Goal arrays, and Community list).
  3. Activates and indexes selected `ActiveTools` in the local DB.
  4. Generates initial zero-node coordinate mappings for the **Recovery Constellation** milestone graph.
* **Transition:** The screen fades cleanly to the personalized Home Screen showing their customized counters, chosen LEGO tool blocks, and bottom Action Center.

---

## 3. Local-First Database Handoff Matrix
This table defines how the selections made in the onboarding flow map to our SQLite table schema:

| Onboarding Step | Target SQLite Table | Data Schema Column | Backend Action / Verification |
| --- | --- | --- | --- |
| **Goal Clarification** | `Profiles` | `selected_goals` | JSON serialized array of string IDs stored in `selectedGoals` column. |
| **Community Alignment** | `Profiles` | `active_paths` | JSON serialized list of pathways (e.g., `["AA", "DHARMA"]`). |
| **Toolbox Construction** | `ActiveTools` | `tool_id`, `program_affiliation` | Inserts separate records for each checked widget with sequential `order_index`. |
| **Values Sorting** | `Profiles` | `anonymous_username`, `mission_statement` | Saves mission statement to local DB; initializes vector space baseline. |
| **Constellation Init** | `ConstellationPoints` | `id`, `title`, `position_x`, `position_y` | Seeds origin milestone star "Began My Recovery Path" at (0.5, 0.5) coordinate. |
