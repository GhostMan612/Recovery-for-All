// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/xp_engine_service.dart
//
// The single owner of every XP grant in the app.
//
// Two invariants this file exists to hold:
//
//   1. **XP + audit event are one transaction.** R28's guarantee did not cover
//      the paths that predate it. They did two separate writes with no
//      transaction, and `save()` is a full-row `insertOnConflictUpdate` from a
//      snapshot read OUTSIDE the write. So (a) a process death between the two
//      granted XP with no audit event, and (b) a concurrent reward — journal and
//      check-in landing in the same frame — overwrote the other's
//      sparks/pathXp outright.
//   2. **Every XP source strikes an active raid.** Before this, the fellowship
//      handshake granted XP through a raw `save()` and so never touched the
//      boss: fellowship work was the one action invisible to the raid.
//
// [grantXp] is the only write path. [processAction] is a thin wrapper that adds
// the snackbar — it does NOT contain a second copy of the transaction, which is
// how the two drifted apart in the first place.

import 'package:flutter/material.dart';

import '../database/recovery_database.dart';
import 'raid_service.dart';
import 'recovery_pet_service.dart';

/// Result of an XP grant.
class XpGrantOutcome {
  /// `null` when there was no pet row at all, so nothing was written.
  final bool? leveled;

  /// The pet's level AFTER the grant, or null when nothing was written.
  final int? level;

  /// " | Boss Struck for 50 DMG" when an active raid absorbed the damage.
  ///
  /// Part of the result rather than a second raid lookup, deliberately: an
  /// earlier shape of this file damaged the boss in `grantXp` AND again in the
  /// snackbar helper, so every action hit the raid for double damage. The raid
  /// is touched exactly once, here, and the message is carried out with it.
  final String raidSuffix;

  const XpGrantOutcome.notGranted()
      : leveled = null,
        level = null,
        raidSuffix = '';
  const XpGrantOutcome.granted({
    required this.leveled,
    required this.level,
    this.raidSuffix = '',
  });
}

class XpEngineService {
  static const Map<String, int> _xpMap = {
    'journal': 25,
    'check_in': 15,
    'gratitude': 10,
    // A completed fellowship handshake. Kept in the same table so it cannot be
    // granted from anywhere else by accident — see xpFor().
    'fellowship_sync': 50,
  };

  /// XP for [actionType], or `null` when the type is not a known action.
  ///
  /// Exposed so callers can REJECT an unknown action instead of silently
  /// defaulting. `processAction` used to fall back to `_xpMap[type] ?? 10`, so
  /// a typo in an event name quietly awarded 10 XP forever — a number nobody
  /// chose and nobody could see.
  static int? xpFor(String actionType) => _xpMap[actionType];

  /// Grants [xp] XP atomically, writes one audit event, and damages an active
  /// raid by the same amount.
  ///
  /// [metaJson] is stored verbatim on the audit event — pass the peer alias for
  /// a handshake, so the event is explainable months later.
  static Future<XpGrantOutcome> grantXp(
    RecoveryDatabase db,
    int xp, {
    required String actionType,
    String? metaJson,
  }) async {
    final outcome = await db.transaction(() async {
      await RecoveryPetService.ensureHatched();
      final row = await db.getPet(RecoveryPetService.defaultPetId);
      if (row == null) return null;
      // Read INSIDE the transaction. Reading outside and writing back the whole
      // row is what lost concurrent grants.
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
        metaJson: metaJson ?? '{"xp":$xp}',
      ));
      return (level: next.pathLevel, leveled: next.pathLevel > before.pathLevel);
    });

    if (outcome == null) return const XpGrantOutcome.notGranted();

    // The raid is touched EXACTLY ONCE, right here. A raid failure must NOT
    // roll back or swallow a grant the user already earned — the XP and the
    // audit event are already committed — so failures here degrade to no
    // message rather than propagating.
    var raidSuffix = '';
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

    return XpGrantOutcome.granted(
      leveled: outcome.leveled,
      level: outcome.level,
      raidSuffix: raidSuffix,
    );
  }

  /// Standard XP grant for a known action, with the standard snackbar.
  ///
  /// Unknown [actionType] falls back to 10 XP for backwards compatibility with
  /// callers that predate [xpFor]; new code should check [xpFor] first.
  static Future<XpGrantOutcome> processAction(
    BuildContext context,
    RecoveryDatabase db,
    String actionType,
  ) async {
    final xp = _xpMap[actionType] ?? 10;
    final result = await grantXp(db, xp, actionType: actionType);
    if (!context.mounted) return result;

    final levelSuffix = result.leveled == true ? ' • LEVEL UP! Lv ${result.level}' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Action Logged! +$xp XP${result.raidSuffix}$levelSuffix',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return result;
  }
}
