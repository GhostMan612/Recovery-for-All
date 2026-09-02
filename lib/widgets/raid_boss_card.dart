// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefeated ? const Color(0xFF10B981) : const Color(0xFFDC2626).withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: isDefeated
              ? [const Color(0xFF064E3B).withValues(alpha: 0.35), const Color(0xFF1E293B)]
              : [const Color(0xFF7F1D1D).withValues(alpha: 0.35), const Color(0xFF1E293B)],
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
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(isDefeated ? Icons.emoji_events_outlined : Icons.crisis_alert_outlined, color: isDefeated ? const Color(0xFF10B981) : const Color(0xFFDC2626)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(raid.bossName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(isDefeated ? 'Defeated • +${RaidService.victoryXp} XP awarded' : 'Ends in ~$hoursLeft h • Community Raid', style: TextStyle(color: isDefeated ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
                child: Text('${raid.currentHp}/${raid.maxHp} HP', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(isDefeated ? const Color(0xFF10B981) : const Color(0xFFDC2626)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text('Your contribution: ${raid.userContribution} DMG', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const Spacer(),
              Text('${(progress * 100).round()}% HP', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDefeated ? const Color(0xFF334155) : const Color(0xFFDC2626),
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
