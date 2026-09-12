// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/icon_registry.dart';

void main() {
  group('IconRegistry.eventIcon', () {
    test('known event types resolve to their mapped icons', () {
      expect(IconRegistry.eventIcon('battle_win'), Icons.shield_outlined);
      expect(IconRegistry.eventIcon('meeting'), Icons.groups_outlined);
      expect(IconRegistry.eventIcon('journal'), Icons.book_outlined);
      expect(IconRegistry.eventIcon('gratitude'),
          Icons.sentiment_satisfied_outlined);
    });

    test('prefixed families resolve without map keys', () {
      expect(IconRegistry.eventIcon('milestone_30_day'),
          Icons.emoji_events_outlined);
      expect(
          IconRegistry.eventIcon('signoff_step_4'), Icons.verified_outlined);
      expect(IconRegistry.eventIcon('worksheet_cba'),
          Icons.assignment_turned_in_outlined);
    });

    test('unknown events fall back instead of vanishing', () {
      expect(IconRegistry.eventIcon('nope_not_real'), Icons.circle_outlined);
      expect(IconRegistry.eventIcon(''), Icons.circle_outlined);
    });
  });

  group('IconRegistry.toolIcon', () {
    test('known tools resolve to their mapped icons', () {
      expect(IconRegistry.toolIcon('Encrypted Journal'), Icons.lock_outline);
      expect(IconRegistry.toolIcon('Cost-Benefit Analysis'), Icons.balance);
      expect(
          IconRegistry.toolIcon('Wellness Check-In'), Icons.donut_large_outlined);
    });

    test('unknown tools fall back instead of vanishing', () {
      expect(IconRegistry.toolIcon('Mystery Tool'), Icons.handyman_outlined);
    });
  });
}
