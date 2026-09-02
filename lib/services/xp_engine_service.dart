// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../database/recovery_database.dart';
import 'raid_service.dart';
import 'recovery_pet_service.dart';

class XpEngineService {
  static const Map<String, int> _xpMap = {
    'journal': 25,
    'check_in': 15,
    'gratitude': 10,
  };

  static Future<void> processAction(BuildContext context, RecoveryDatabase db, String actionType) async {
    final xp = _xpMap[actionType] ?? 10;
    final petBefore = await RecoveryPetService.ensureHatched();
    final levelBefore = petBefore.pathLevel;
    final withXp = petBefore.copyWith(pathXp: petBefore.pathXp + xp);
    final leveled = RecoveryPetService.evaluateLevel(withXp);
    await RecoveryPetService.save(leveled);
    await db.addPetEvent(PetEventRow(
      id: 'pet_event_${DateTime.now().millisecondsSinceEpoch}_${actionType.hashCode.abs() % 9973}',
      petId: RecoveryPetService.defaultPetId,
      eventType: 'xp_$actionType',
      sparksDelta: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metaJson: '{"xp":$xp}',
    ));
    String raidSuffix = '';
    try {
      final raid = await RaidService.getActiveRaid(db);
      if (raid != null) {
        final updated = await RaidService.dealDamage(db, raid.id, xp);
        if (updated != null) {
          raidSuffix = ' | Boss Struck for $xp DMG';
          if (updated.currentHp <= 0) raidSuffix += ' • Boss Defeated!';
        }
      }
    } catch (_) {}
    final didLevelUp = leveled.pathLevel > levelBefore;
    final levelSuffix = didLevelUp ? ' • LEVEL UP! Lv ${leveled.pathLevel}' : '';
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Action Logged! +$xp XP$raidSuffix$levelSuffix', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
