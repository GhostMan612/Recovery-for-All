// lib/features/navigator/ui/widgets/journey_sheet.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../../application/meeting_journey_planner.dart';
import 'journey_weather_card.dart';

class JourneySheet extends StatelessWidget {
  final PlannedMeetingJourneyResult planResult;
  final JourneyWeatherData? weather;
  final VoidCallback? onLaunchExternalDirections;

  const JourneySheet({
    super.key,
    required this.planResult,
    this.weather,
    this.onLaunchExternalDirections,
  });

  @override
  Widget build(BuildContext context) {
    final destination = planResult.destination;
    final schedule = planResult.schedule;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${destination.fellowship} • ${schedule.statusDescription}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close journey details',
                ),
              ],
            ),
            const SizedBox(height: 16),
            JourneyWeatherCard(weather: weather),
            const SizedBox(height: 16),

            if (planResult.isRouteAvailableInApp && planResult.inAppPreview != null) ...[
              Text(
                'Available Transit Routes',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...planResult.inAppPreview!.options.map((opt) {
                return Card(
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${opt.legs.length} legs • ${(opt.walkMeters / 1000).toStringAsFixed(1)} km walk',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: opt.transferConfidence == 'scheduled_unknown'
                                    ? colorScheme.tertiaryContainer
                                    : colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                opt.transferConfidence == 'scheduled_unknown'
                                    ? 'Schedule Unverified'
                                    : 'Confidence: ${opt.transferConfidence}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: opt.transferConfidence == 'scheduled_unknown'
                                      ? colorScheme.onTertiaryContainer
                                      : colorScheme.onPrimaryContainer,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...opt.legs.map((leg) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    leg.mode == 'bus'
                                        ? Icons.directions_bus
                                        : leg.mode == 'rail'
                                            ? Icons.directions_railway
                                            : Icons.directions_walk,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${leg.fromLabel} → ${leg.toLabel} ${leg.routeLabel != null ? "(${leg.routeLabel})" : ""}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              Card(
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.tertiary, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        planResult.statusMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (planResult.fallbackExternalDirectionsUrl != null &&
                !destination.isSynthetic &&
                !destination.isOnlineOnly) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Open External Directions (Google Maps)'),
                onPressed: onLaunchExternalDirections,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
