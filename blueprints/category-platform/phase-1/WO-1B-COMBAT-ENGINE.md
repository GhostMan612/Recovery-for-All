# WO-1B — Testable Tactical Battles with Compassionate Outcomes

## Current source evidence

`lib/screens/pet_trials_screen.dart` owns `_BattleState`, `_Ability`, `_Monster`, RNG, three-battle/day preference counter, and animation/feedback, making logic difficult to test without widgets. The UI includes coping-skill abilities, Focus, Resolve, enemy HP, victory and 'companion learned' defeat messaging. `RaidService` is a separate weekend-boss ledger.

## File map

- **NEW** `lib/features/game/domain/battle_state.dart`, `battle_rules.dart`, `battle_action.dart`: immutable state + pure reducer `reduce(state, action, rng)` with no BuildContext, storage, DateTime.now or animation.
- **NEW** `lib/features/game/data/battle_catalog.dart`: versioned monsters, skill metadata, path-neutral alternatives, balancing constants.
- **NEW** `lib/features/game/application/battle_session_service.dart`: persist seed and session ID locally; one completion event to P1-A coordinator; no repeated victory grants.
- Modify `lib/screens/pet_trials_screen.dart` to render state, dispatch actions, manage animation and semantics without being the source of combat rules.
- Modify `lib/services/raid_service.dart` only where receipt integration requires it; do not merge single-player Trials into weekend raid state inadvertently.
- **NEW** `test/game/battle_rules_test.dart`, `test/game/battle_session_test.dart`, `test/game/battle_accessibility_test.dart`; preserve existing `test/pet_economy_test.dart`.

## Mechanics target

- Meaningful but gentle tactical loop: `Breath` replenishes Focus, `Ground` shields, `Gratitude` restores Resolve, `Step Strike` expresses practiced skill; defensive and escape actions are viable, not traps.
- Three clearly labeled difficulty bands chosen by user (guided, standard, challenge); all have a positive 'learned something' exit and comparable non-punitive rewards.
- Deterministic turns and seeded RNG; fixed-seed replay for debugging, user-visible battles need not expose seed.
- `No combat / quiet mode`: focus on reflection and coping practice with equivalent meaningful growth; no XP disadvantage forcing combat.
- No relapse or withdrawal symptom framed as a moral monster. Names should metaphorically represent hurdles, not people or conditions.
- Never suggest a game move is a treatment or crisis-response replacement. Direct support remains visible.

## Implementation sequence

1. Characterize old behavior in tests (battle caps, shield, enemy healing, victory, learned state).
2. Copy *logic*, not widget code, into pure reducer; inject RNG and clock providers. Maintain same visuals initially.
3. Switch screen to reducer behind local feature flag, compare transcript for identical seeded session.
4. Introduce new abilities/catalog with balance simulations and accessibility alternatives.
5. Route victory/participation reward through stable session completion `eventId`. Award exactly once; do not grant one reward from UI callback and another from reducer.

## Proof

One seed yields identical full turn transcript 100 times; illegal actions and negative Focus leave state unchanged; app rotation/rebuild cannot spawn duplicate battle; interruption restores or safely abandons without XP leak; 200% text / TalkBack can complete battle; reduced motion never hides status information; quiet mode reaches equal supportive outcome. Zero crash/overflow on Moto low-RAM target.
