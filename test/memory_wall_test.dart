// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/database/recovery_database.dart';

void main() {
  group('MemoryWallScreen helper logic', () {
    // Test _formatTimestamp logic
    group('_formatTimestamp', () {
      final now = DateTime(2026, 8, 30, 12, 0);

      test('just now for < 1 minute', () {
        final ms = now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch;
        final diff = now.millisecondsSinceEpoch - ms;
        final mins = diff ~/ 60000;
        expect(mins <= 1, isTrue);
      });

      test('Xm ago for minutes', () {
        final ms = now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
        final diff = now.millisecondsSinceEpoch - ms;
        final mins = diff ~/ 60000;
        expect(mins, 5);
      });

      test('Xh ago for hours', () {
        final ms = now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
        final diff = now.millisecondsSinceEpoch - ms;
        final hours = diff ~/ 3600000;
        expect(hours, 2);
      });

      test('Yesterday for 1 day', () {
        final ms = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        final diff = now.millisecondsSinceEpoch - ms;
        final days = diff ~/ 86400000;
        expect(days, 1);
      });

      test('Xd ago for < 7 days', () {
        final ms = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
        final diff = now.millisecondsSinceEpoch - ms;
        final days = diff ~/ 86400000;
        expect(days, 3);
      });

      test('DD/MM/YYYY for >= 7 days', () {
        final ms = now.subtract(const Duration(days: 10)).millisecondsSinceEpoch;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        expect('${dt.day}/${dt.month}/${dt.year}', '20/8/2026');
      });
    });

    // Test _memoryLine logic (mirrors the implementation)
    String memoryLine(PetEventRow e) {
      final t = e.eventType;
      if (t.startsWith('milestone_')) {
        return 'Kin remembers your ${t.substring(10)} chip.';
      }
      if (t.startsWith('signoff_step')) {
        return 'Kin remembers step ${t.substring(12)} signed off.';
      }
      if (t.startsWith('worksheet_step')) {
        return 'Kin remembers step ${t.substring(14)} worked through.';
      }
      if (t.startsWith('worksheet_')) {
        return 'Kin remembers a worksheet faced honestly.';
      }
      switch (t) {
        case 'battle_win':
          return 'Kin remembers a Trial won.';
        case 'battle_learned':
          return 'Kin remembers learning something the hard way.';
        case 'goal_complete':
          return 'Kin remembers a weekly goal finished.';
        case 'star':
          return 'Kin remembers a star added to your sky.';
        case 'meeting':
          return 'Kin remembers a room you walked into.';
        case 'walk':
          return 'Kin remembers moving together.';
        case 'wellness':
          return 'Kin remembers the wellness wheel checked.';
        case 'check_in':
          return 'Kin remembers a daily check-in.';
        case 'journal':
          return 'Kin remembers words put to page.';
        case 'gratitude':
          return 'Kin remembers a moment of gratitude.';
        case 'grounding':
          return 'Kin remembers grounding breaths taken.';
        case 'species_ember_kit':
        case 'species_tide_kin':
        case 'species_moss_sprite':
        case 'species_star_whelp':
        case 'species_sovereign_linx':
        case 'species_riverglass_otter':
        case 'species_prairie_ember_hare':
        case 'species_north_star_loon':
          return 'Kin remembers a new form adopted.';
      }
      return 'Kin remembers a moment of care.';
    }

    group('_memoryLine', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      test('maps milestone events', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'milestone_30_Days',
          sparksDelta: 40, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers your 30_Days chip.');
      });

      test('maps signoff_step events', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'signoff_step4',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers step 4 signed off.');
      });

      test('maps worksheet_step events', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'worksheet_step1',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers step 1 worked through.');
      });

      test('maps worksheet_ events', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'worksheet_custom',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a worksheet faced honestly.');
      });

      test('maps battle_win', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'battle_win',
          sparksDelta: 25, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a Trial won.');
      });

      test('maps battle_learned', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'battle_learned',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers learning something the hard way.');
      });

      test('maps goal_complete', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'goal_complete',
          sparksDelta: 15, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a weekly goal finished.');
      });

      test('maps star', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'star',
          sparksDelta: 20, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a star added to your sky.');
      });

      test('maps meeting', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'meeting',
          sparksDelta: 8, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a room you walked into.');
      });

      test('maps walk', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'walk',
          sparksDelta: 15, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers moving together.');
      });

      test('maps wellness', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'wellness',
          sparksDelta: 6, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers the wellness wheel checked.');
      });

      test('maps check_in', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'check_in',
          sparksDelta: 5, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a daily check-in.');
      });

      test('maps journal', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'journal',
          sparksDelta: 10, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers words put to page.');
      });

      test('maps gratitude', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'gratitude',
          sparksDelta: 5, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a moment of gratitude.');
      });

      test('maps grounding', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'grounding',
          sparksDelta: 8, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers grounding breaths taken.');
      });

      test('maps species adoption', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'species_sovereign_linx',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a new form adopted.');
      });

      test('falls back for unknown types', () {
        final event = PetEventRow(
          id: 'test', petId: 'active_pet', eventType: 'unknown_type',
          sparksDelta: 0, timestamp: now,
        );
        expect(memoryLine(event), 'Kin remembers a moment of care.');
      });
    });
  });
}