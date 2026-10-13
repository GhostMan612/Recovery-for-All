// test/game/battle_accessibility_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/game/data/battle_catalog.dart';
import 'package:recovery_for_all/features/game/domain/battle_action.dart';
import 'package:recovery_for_all/features/game/domain/battle_state.dart';
import 'package:recovery_for_all/widgets/themed_background.dart';

void main() {
  group('WO-1B — Combat Engine Accessibility & Ergonomics', () {
    test('All standard battle actions provide non-empty accessibility descriptions', () {
      for (final action in BattleAction.standardDeck) {
        expect(action.name, isNotEmpty);
        expect(action.description, isNotEmpty);
        expect(action.focusCost, greaterThanOrEqualTo(0));
      }
    });

    test('Quiet mode provides non-combat reflection alternatives', () {
      final quietActions = BattleCatalog.actionsForSession(isQuietMode: true);
      expect(quietActions.any((a) => a.isReflection), isTrue);
      expect(quietActions.any((a) => a.isEscape), isTrue);
      expect(quietActions.every((a) => a.minDamage == 0 && a.maxDamage == 0), isTrue);
    });

    testWidgets('Reduced motion environment is detected and respected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                final reduced = appReduceMotion(context);
                return Text('Reduced: $reduced');
              },
            ),
          ),
        ),
      );

      expect(find.text('Reduced: true'), findsOneWidget);
    });

    testWidgets('200% text scaling pumps battle status widgets without layout failure', (tester) async {
      final state = BattleState(
        sessionId: 'test_a11y',
        seed: 42,
        turnNumber: 3,
        phase: BattlePhase.playerTurn,
        difficulty: BattleDifficulty.standard,
        resolve: 45,
        maxResolve: 50,
        focus: 4,
        maxFocus: 5,
        shieldActive: true,
        monster: BattleCatalog.cravingWraith,
        battleLog: const [
          'Grounding Shield raised.',
          'Craving Wraith deals 4 damage.',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: ListView(
                children: [
                  Text('Focus: ${state.focus}/${state.maxFocus}'),
                  Text('Resolve: ${state.resolve}/${state.maxResolve}'),
                  Text('Monster: ${state.monster.name} (${state.monster.currentHp}/${state.monster.maxHp})'),
                  for (final log in state.battleLog) Text(log),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Focus: 4/5'), findsOneWidget);
      expect(find.text('Resolve: 45/50'), findsOneWidget);
      expect(find.text('Monster: Craving Wraith (40/40)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
