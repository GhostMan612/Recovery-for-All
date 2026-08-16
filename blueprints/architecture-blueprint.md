# The Recovery Companion Project
## Technical Architecture Specification (Volume III)
### Document Version: 1.0.0
### Date: August 6, 2026
### Target Platform: Android (with iOS readiness via Flutter cross-platform architecture)

---

## 1. Executive Technical Summary
This document establishes the foundational technical blueprint for the **Recovery Companion App**, a modular "Recovery Operating System" built on the core principle: *"Recovery is not one path. Recovery is the path you build."* 

To realize this vision of fluid dynamics, absolute user privacy, and all-inclusive modular pathways, the platform utilizes:
*   **Frontend Framework:** **Flutter** (Dart) for high-performance Custom UI rendering, fluid animations (such as the Recovery Constellation), and future cross-platform scalability.
*   **Database Architecture:** A hybrid **offline-first local database** combined with **Cloud Firestore** for real-time community syncing and encrypted data transport.
*   **Local Storage Engine:** **Drift (SQLite)** to guarantee that deeply personal recovery data (such as private journals and mood tracking) remains stored strictly on the user's device unless explicit cloud backup is enabled.
*   **State Management:** **Riverpod** to coordinate the modular "LEGO block" injection of recovery path widgets (AA, SMART, Dharma, Wellbriety) into a unified UI context.

---

## 2. Directory Structure & Architecture
The codebase follows a Clean Architecture design pattern with strict Separation of Concerns (Presentation, Domain, Data) organized by feature slices to allow seamless adding of new recovery pathways over time.

```
lib/
├── core/
│   ├── constants/         # App constants, design tokens, color palettes
│   ├── theme/             # Dynamic theme engines (fluid palette shifts)
│   ├── services/          # Low-level service initializations (GPS, Local Auth)
│   └── network/           # API clients and offline synchronization queue
├── features/
│   ├── onboarding/        # Goal setting, path selection, and toolbox building
│   ├── home/              # CustomScrollView-based sliver dashboard (4-zone layout)
│   ├── recovery_tracker/  # Sobriety counter logic, anniversaries, milestone counters
│   ├── toolbox/           # Reusable tool engines (meditation timer, journals, CBT, etc.)
│   ├── community/         # Encrypted feed, anonymous circle coordination, local map finders
│   └── safety_gate/       # MIND-SAFE local classifier and hardware bypass routing
└── data/
    ├── local/             # Drift schema definitions, migrations, DAOs
    └── remote/            # Firebase service integrations & mapping logic
```

---

## 3. Database Schema Design (Cloud & Local)

### 3.1 Local Storage (Drift / SQLite DB)
Private tables are cached on-device to enforce user-level data sovereignty.

#### Table: `profiles`
*   `id`: TEXT (Primary Key)
*   `anonymous_username`: TEXT (Nullable)
*   `created_at`: INTEGER (Timestamp)
*   `biometric_lock_enabled`: BOOLEAN (Default: false)
*   `selected_goals`: TEXT (JSON serialized array of selected goals: alcohol, trauma, shopping, etc.)
*   `active_paths`: TEXT (JSON serialized array of recovery communities: AA, Dharma, Wellbriety, SMART)

#### Table: `counters`
*   `id`: TEXT (Primary Key)
*   `label`: TEXT (e.g., "Alcohol", "Nicotine", "Self-Harm")
*   `start_date_time`: INTEGER (Unix timestamp of last use)
*   `is_active`: BOOLEAN

#### Table: `journal_entries`
*   `id`: TEXT (Primary Key)
*   `timestamp`: INTEGER
*   `mood_rating`: INTEGER (1 = Need Help, 5 = Great)
*   `content_encrypted`: TEXT (AES-256 encrypted string containing private reflections)
*   `is_synced_to_cloud`: BOOLEAN

---

### 3.2 Remote Backend Schema (Cloud Firestore)
The database structure is designed using document-reference mapping to support complex user circles and modular path indexing while preserving strict privacy levels.

```
/users/{userId}
  ├── profile/
  │     ├── anonymous_username: "GhostMan G"
  │     ├── selected_paths: ["AA", "Wellbriety", "Dharma"]
  │     ├── active_tools: ["smudging", "meditation_timer", "daily_reflection"]
  │     └── registered_at: Timestamp
  │
  ├── recovery_circle/
  │     ├── sponsor_uid: "sponsorUserIdXYZ"
  │     ├── sponsees: ["sponseeUid1", "sponseeUid2"]
  │     └── trusted_supporters: ["supporterUidA", "supporterUidB"]
  │
  └── constellation_points/
        └── {pointId}/
              ├── title: "Completed Fourth Step"
              ├── category: "step_work"
              ├── timestamp: Timestamp
              ├── position_x: FLOAT (Normalized coordinate)
              └── position_y: FLOAT (Normalized coordinate)

/community_feeds/{feedId}
  ├── post_id: "postId123"
  ├── author_masked: "GhostMan G"
  ├── content: "Celebrating 6 months of clarity today! Grateful for this circle."
  ├── timestamp: Timestamp
  ├── likes_count: INTEGER
  └── support_reactions/  # masked counts for peer encouragement
        ├── sending_strength: 42
        ├── proud_of_you: 89
        └── respect: 15
```

---

## 4. Multi-Pathway "LEGO Block" Logic Engine
The core technical challenge is ensuring that when a user selects a combination of recovery paths, the UI dynamically displays the correct components.

```dart
/// System State Registry mapping recovery programs to their associated widgets
class RecoveryPathRegistry {
  static List<Widget> resolveActiveWidgets(List<String> activePaths) {
    final List<Widget> widgets = [];
    
    for (var path in activePaths) {
      switch (path.toUpperCase()) {
        case 'AA':
          widgets.add(const AADailyReflectionWidget());
          widgets.add(const TwelveStepsViewWidget());
          break;
        case 'DHARMA':
          widgets.add(const MeditationTimerWidget());
          widgets.add(const EightfoldPathReadingWidget());
          break;
        case 'WELLBRIETY':
          widgets.add(const MedicineWheelTeachingsWidget());
          widgets.add(const SevenGrandfatherTeachingsWidget());
          break;
        case 'SMART':
          widgets.add(const CostBenefitAnalysisToolWidget());
          widgets.add(const REBTUrgeCopingWidget());
          break;
      }
    }
    return widgets;
  }
}
```

---

## 5. Security & MIND-SAFE Guardrail Subsystem
To operate ethically in high-stakes situations, the app incorporates a local hardware-bypassing **MIND-SAFE guardrail subsystem** inspired by validated clinical frameworks.

1.  **Input Risk Classification:** At the input level (e.g., text journaling, chat, check-ins), a local regex-based keyword parser detects acute distress or self-harm markers (such as "end my life", "suicide", "want to die").
2.  **Deterministic Bypassing:** When a crisis threshold is crossed, the app immediately executes a **hard halt** on all generative, conversational AI elements.
3.  **Emergency Routing:** It programmatically forces a navigation route swap to the **SOS Safety Sheet** (Zone 4) to present:
    *   One-tap phone calls to the national **988 Suicide & Crisis Lifeline** or **1-800-662-HELP (SAMHSA)**.
    *   Immediate one-tap SMS/call dispatching to the configured **Sponsor Section**.
    *   Immediate redirection to local in-person crisis locations or virtual open meetings.
