// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

import '../database/recovery_database.dart';
import '../services/raid_service.dart';

class RaidBossCard extends StatelessWidget {
  final ActiveRaid raid;
  final Future<void> Function()? onStrike;
  const RaidBossCard({super.key, required this.raid, this.onStrike});

  @override
  Widget build(BuildContext context) {
    final progress = raid.maxHp == 0 ? 0.0 : (raid.currentHp / raid.maxHp).clamp(0.0, 1.0);
    final isDefeated = raid.currentHp <= 0;
    final remainingMs = raid.endTime - DateTime.now().millisecondsSinceEpoch;
    final hoursLeft = (remainingMs / 3600000).ceil().clamp(0, 999);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefeated ? AppColors.raidVictory : Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: isDefeated
              ? [AppColors.raidVictoryDeep.withValues(alpha: 0.35), Theme.of(context).colorScheme.surfaceContainer]
              : [AppColors.raidActiveDeep.withValues(alpha: 0.35), Theme.of(context).colorScheme.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(isDefeated ? Icons.emoji_events_outlined : Icons.crisis_alert_outlined, color: isDefeated ? AppColors.raidVictory : Theme.of(context).colorScheme.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(raid.bossName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(isDefeated ? 'Defeated • +${RaidService.victoryXp} XP awarded' : 'Ends in ~$hoursLeft h • Community Raid', style: TextStyle(color: isDefeated ? AppColors.raidVictorySoft : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20)),
                child: Text('${raid.currentHp}/${raid.maxHp} HP', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(isDefeated ? AppColors.raidVictory : Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text('Your contribution: ${raid.userContribution} DMG', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              Text('${(progress * 100).round()}% HP', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDefeated ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: Icon(isDefeated ? Icons.check_circle_outline : Icons.flash_on_outlined, size: 18),
              label: Text(isDefeated ? 'Victory!' : 'Strike Boss (+${RaidService.strikeDamage} DMG)', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: isDefeated ? null : () async { if (onStrike != null) await onStrike!(); },
            ),
          ),
        ],
      ),
    );
  }
}
