// lib/features/navigator/ui/widgets/street_route_preview_sheet.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../../domain/street_route.dart';

/// Sheet displaying static street-network maneuvers, distance, and duration.
class StreetRoutePreviewSheet extends StatelessWidget {
  final StreetRoute route;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onOpenExternalNavigation;

  const StreetRoutePreviewSheet({
    super.key,
    required this.route,
    this.onShowOnMap,
    this.onOpenExternalNavigation,
  });

  IconData _iconForManeuver(StreetManeuverType type) {
    switch (type) {
      case StreetManeuverType.depart:
        return Icons.trip_origin;
      case StreetManeuverType.arrive:
        return Icons.place;
      case StreetManeuverType.turnLeft:
      case StreetManeuverType.turnSharpLeft:
      case StreetManeuverType.turnSlightLeft:
        return Icons.turn_left;
      case StreetManeuverType.turnRight:
      case StreetManeuverType.turnSharpRight:
      case StreetManeuverType.turnSlightRight:
        return Icons.turn_right;
      case StreetManeuverType.uturn:
        return Icons.u_turn_left;
      case StreetManeuverType.continueStraight:
        return Icons.straight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWalking = route.mode == StreetRouteMode.walking;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWalking ? colorScheme.secondaryContainer : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWalking ? Icons.directions_walk : Icons.directions_car,
                  color: isWalking ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.mode.displayName} Route • ${route.durationMinutes} min',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route.distanceMiles.toStringAsFixed(1)} mi (${route.totalDistanceMeters} m) • ${route.dataSource}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Turn-by-Turn Maneuvers',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: route.maneuvers.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (ctx, idx) {
                final m = route.maneuvers[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForManeuver(m.type),
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.instruction,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (m.distanceMeters > 0)
                              Text(
                                '${m.distanceMeters} m',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onShowOnMap != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on Map'),
                    onPressed: onShowOnMap,
                  ),
                ),
              if (onShowOnMap != null && onOpenExternalNavigation != null)
                const SizedBox(width: 10),
              if (onOpenExternalNavigation != null)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Google Maps'),
                    onPressed: onOpenExternalNavigation,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
