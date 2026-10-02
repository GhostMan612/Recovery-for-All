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
    // R28's guarantee — "pet + event in ONE drift transaction (crash-safe)" —
    // did not cover this path. It did two separate writes with no transaction,
    // and `save()` is a full-row `insertOnConflictUpdate` from a snapshot read
    // outside the write. So (a) a process death between the two granted XP with
    // no audit event, and (b) a concurrent reward — journal and check-in
    // landing in the same frame — overwrote the other's sparks/pathXp outright.
    // Both writes now happen in one transaction with the row re-read inside it.
    final outcome = await db.transaction(() async {
      await RecoveryPetService.ensureHatched();
      final row = await db.getPet(RecoveryPetService.defaultPetId);
      if (row == null) return (pet: await RecoveryPetService.ensureHatched(), leveled: false);
      final before = RecoveryPetService.petFromRow(row);
      final withXp = before.copyWith(pathXp: before.pathXp + xp);
      final next = RecoveryPetService.evaluateLevel(withXp);
      await db.upsertPet(RecoveryPetService.rowFromPet(next));
      await db.addPetEvent(PetEventRow(
        id: 'pet_event_${DateTime.now().microsecondsSinceEpoch}_xp_$actionType',
        petId: RecoveryPetService.defaultPetId,
        eventType: 'xp_$actionType',
        sparksDelta: 0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        metaJson: '{"xp":$xp}',
      ));
      return (pet: next, leveled: next.pathLevel > before.pathLevel);
    });
    final leveled = outcome.pet;
    final didLevelUp = outcome.leveled;
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
    final levelSuffix = didLevelUp ? ' • LEVEL UP! Lv ${leveled.pathLevel}' : '';
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Action Logged! +$xp XP$raidSuffix$levelSuffix', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
