// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/drift.dart' show Value;

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
      // Deterministic id keyed on the weekend window. The old id used
      // microsecondsSinceEpoch, and getActiveRaid is called on every dashboard
      // open AND on every journal/check-in/gratitude via XpEngineService — so
      // three actions on a Saturday created three independent 1000-HP bosses,
      // each with its own contribution split. Re-inserting the same id is a
      // no-op conflict, so this is idempotent per weekend.
      final raidId = 'raid_weekend_${_weekendEndTime(nowDt)}';
      final existing = await db.getActiveRaidById(raidId);
      if (existing != null && existing.currentHp > 0) return existing;
      final raid = ActiveRaid(
        id: raidId,
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
    // Inside a transaction. The old version read the row, subtracted in Dart, and
    // wrote the whole row back with `replace` — two concurrent strikes both
    // read currentHp = 1000, both wrote 900, and one hit was silently lost
    // (and userContribution under-reported forever). A transaction makes the
    // read-modify-write atomic; note that `updateActiveRaid`'s `replace` is
    // still a full-row write, so the read must not escape the transaction.
    final result = await db.transaction(() async {
      final rows = await (db.select(db.activeRaids)
            ..where((t) => t.id.equals(raidId)))
          .get();
      if (rows.isEmpty) return null;
      final raid = rows.first;
      if (raid.currentHp <= 0) return raid;

      final newHp = (raid.currentHp - damage).clamp(0, raid.maxHp);
      final applied = raid.currentHp - newHp;
      final updated = await (db.update(db.activeRaids)
            ..where((t) => t.id.equals(raidId)))
          .writeReturning(ActiveRaidsCompanion(
        currentHp: Value(newHp),
        userContribution: Value(raid.userContribution + applied),
      ));
      return updated.isEmpty
          ? raid.copyWith(currentHp: newHp)
          : updated.first;
    });
    if (result == null) return null;
    if (result.currentHp <= 0) {
      final pet = await RecoveryPetService.ensureHatched();
      final withXp = pet.copyWith(pathXp: pet.pathXp + victoryXp);
      final leveled = RecoveryPetService.evaluateLevel(withXp);
      await RecoveryPetService.save(leveled);
      await db.addPetEvent(PetEventRow(
        id: 'pet_event_${DateTime.now().microsecondsSinceEpoch}_raid',
        petId: RecoveryPetService.defaultPetId,
        eventType: 'raid_victory',
        sparksDelta: 0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        metaJson: '{"boss":"${result.bossName}","xp":$victoryXp}',
      ));
    }
    return result;
  }
}
