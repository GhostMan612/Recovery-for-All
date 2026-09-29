// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

/// Daily pledge surface (Phase 8 task 1).
///
/// Presentational by design: the caller owns both the state
/// (`dailyPledgeProvider`) and the persistence side effect, so this
/// widget can be rendered and tested without Riverpod or a database.
class PledgeCard extends StatelessWidget {
  final bool pledged;
  final VoidCallback onPledge;

  const PledgeCard({
    super.key,
    required this.pledged,
    required this.onPledge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (pledged) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.tertiary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pledge confirmed. Today is yours.',
                style: TextStyle(color: scheme.onSurface, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Today I pledge to stay the course.',
              style: TextStyle(color: scheme.onSurface, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onPledge,
            child: Text(
              'I pledge',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toolbox / library destination tile (Phase 8 task 2).
///
/// Moved out of `dashboard_screen.dart` without visual change so the
/// screen file stops owning its own card vocabulary.
class ToolCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
