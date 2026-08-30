// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// R27 — Predictive Next-Meeting Widget.
// Shows Live (in-progress ±2h) or Next Today (within 6h) from cached TSML.
// Placed on Dashboard Path tab above toolbox. Uses MeetingFinder schedule engine.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/meeting_finder_service.dart';

class NextMeetingCard extends StatelessWidget {
  final RecoveryMeeting? meeting;
  final bool isLive;
  final VoidCallback? onOpenMap;
  final VoidCallback? onFindMeetings;

  const NextMeetingCard({
    super.key,
    this.meeting,
    this.isLive = false,
    this.onOpenMap,
    this.onFindMeetings,
  });

  /// Pure selector: picks live or next today from cached meetings.
  /// Returns null when nothing within 6h (caller shows Empty state).
  static ({RecoveryMeeting meeting, bool isLive})? pickNext(
    List<RecoveryMeeting> meetings,
    DateTime now,
  ) {
    if (meetings.isEmpty) return null;
    // Live first
    for (final m in meetings) {
      if (MeetingFinderService.isInProgress(m, now)) {
        return (meeting: m, isLive: true);
      }
    }
    // Next today within 6 hours
    RecoveryMeeting? best;
    Duration? bestDelta;
    for (final m in meetings) {
      final occ = MeetingFinderService.nextOccurrence(m, now);
      if (occ == null) continue;
      final delta = occ.difference(now);
      if (delta.isNegative) continue;
      if (delta > const Duration(hours: 6)) continue;
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        best = m;
      }
    }
    if (best != null) return (meeting: best, isLive: false);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Empty / no filter matches
    if (meeting == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined, color: AppColors.accent, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No meetings in the next 6 hours',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Find a meeting near you — rooms are open daily.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onFindMeetings,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Find'),
            ),
          ],
        ),
      );
    }

    final m = meeting!;
    final fellowship = m.fellowship;
    final chipLabel = isLive ? 'In Progress Now' : MeetingFinderService.upcomingLabel(m, DateTime.now());
    final chipColor = isLive ? const Color(0xFF34D399) : const Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isLive ? Icons.circle : Icons.schedule, size: 14, color: chipColor),
                    const SizedBox(width: 6),
                    Text(chipLabel, style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Text(fellowship, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${m.type} · ${m.time}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (m.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(m.address, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(isLive ? 'View on Map — Join now' : 'View on Map'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: BorderSide(color: chipColor.withValues(alpha: 0.6))),
            ),
          ),
        ],
      ),
    );
  }
}
