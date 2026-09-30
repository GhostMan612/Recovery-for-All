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

/// One destination inside the SOS bottom sheet (Phase 8 task 2).
///
/// SAFETY: this is the ONLY SOS tile implementation. Phase 10 forbids a
/// second SOS surface, so anything that needs a row in the sheet reuses
/// this class rather than re-declaring a local copy. Behavior is
/// intentionally unchanged: a disabled tile still renders at reduced
/// opacity so the user can see *that* the action exists but is
/// unavailable (e.g. "Call Sponsor" with no sponsor linked).
class SosTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const SosTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: enabled
            ? scheme.surfaceContainer
            : scheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        // SAFETY: onTap used to sit on the InkWell wrapping a ListTile, so
        // ListTile's own `button: true` semantics never fired and EVERY SOS
        // destination announced to a screen reader as plain static text. The
        // tap now lives on the ListTile, which is what emits the button role.
        // The explicit Semantics carries the disabled state, which ListTile
        // does not express.
        child: Semantics(
          button: true,
          enabled: enabled,
          label: subtitle == null ? title : '$title. $subtitle',
          child: ListTile(
            enabled: enabled,
            onTap: enabled ? onTap : null,
            leading: Icon(icon, color: color),
            title:
                Text(title, style: TextStyle(color: scheme.onSurface, fontSize: 15)),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Full-width navigable row: icon plate + title/subtitle + chevron.
///
/// Consolidates the Fellowship Handshake and 7th Tradition rows, which
/// were two byte-identical `Material`/`InkWell`/`Container` blocks that
/// differed only in icon, copy, tint and destination. `tint` defaults to
/// `null`, which means "use the theme primary"; the 7th Tradition row
/// passes the brand pink to stay visually distinct.
class SupportLinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? tint;

  const SupportLinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tint ?? scheme.primary;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(height: 10),
              // Phase 8 task 6: the toolbox grid gives each cell a fixed
              // aspect ratio, so the copy must be allowed to shrink rather
              // than overflow when the user runs a large accessibility text
              // scale. FittedBox scales down only as far as it must; at 1.0
              // it is a no-op and the rendering is unchanged.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
