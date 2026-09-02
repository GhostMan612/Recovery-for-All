// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import '../database/recovery_database.dart';
import 'recovery_pet_service.dart';

class RaidService {
  static const String weekendBoss = 'The Weekend Urge';
  static const String isolationBoss = 'The Isolation Phantom';
  static const int defaultMaxHp = 1000;
  static const int strikeDamage = 50;
  static const int victoryXp = 200;

  static bool _isWeekend(DateTime now) {
    return now.weekday == DateTime.friday || now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  }

  static int _weekendEndTime(DateTime now) {
    int daysToMonday = (DateTime.monday - now.weekday) % 7;
    if (daysToMonday <= 0) daysToMonday += 7;
    if (now.weekday == DateTime.sunday) daysToMonday = 1;
    if (now.weekday == DateTime.saturday) daysToMonday = 2;
    if (now.weekday == DateTime.friday) daysToMonday = 3;
    final end = DateTime(now.year, now.month, now.day).add(Duration(days: daysToMonday));
    return end.millisecondsSinceEpoch;
  }

  static Future<ActiveRaid?> getActiveRaid(RecoveryDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final raids = await db.getAllActiveRaids();
    final active = raids.where((r) => r.endTime > now && r.currentHp > 0).toList();
    if (active.isNotEmpty) {
      active.sort((a, b) => b.endTime.compareTo(a.endTime));
      return active.first;
    }
    final nowDt = DateTime.now();
    if (_isWeekend(nowDt)) {
      final raid = ActiveRaid(
        id: 'raid_${DateTime.now().microsecondsSinceEpoch}',
        bossName: weekendBoss,
        maxHp: defaultMaxHp,
        currentHp: defaultMaxHp,
        endTime: _weekendEndTime(nowDt),
        userContribution: 0,
      );
      await db.addActiveRaid(raid);
      return raid;
    }
    return null;
  }

  static Future<ActiveRaid?> dealDamage(RecoveryDatabase db, String raidId, int damage) async {
    final raid = await db.getActiveRaidById(raidId);
    if (raid == null) return null;
    if (raid.currentHp <= 0) return raid;
    final newHp = (raid.currentHp - damage).clamp(0, raid.maxHp);
    final updated = raid.copyWith(currentHp: newHp, userContribution: raid.userContribution + damage);
    await db.updateActiveRaid(updated);
    if (newHp <= 0) {
      final pet = await RecoveryPetService.ensureHatched();
      final withXp = pet.copyWith(pathXp: pet.pathXp + victoryXp);
      final leveled = RecoveryPetService.evaluateLevel(withXp);
      await RecoveryPetService.save(leveled);
      await db.addPetEvent(PetEventRow(
        id: 'pet_event_${DateTime.now().millisecondsSinceEpoch}_raid',
        petId: RecoveryPetService.defaultPetId,
        eventType: 'raid_victory',
        sparksDelta: 0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        metaJson: '{"boss":"${raid.bossName}","xp":$victoryXp}',
      ));
    }
    return updated;
  }
}
