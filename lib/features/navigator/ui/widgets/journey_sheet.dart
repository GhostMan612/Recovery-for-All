// lib/features/navigator/ui/widgets/journey_sheet.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../../application/meeting_journey_planner.dart';
import '../../data/atlas_dtos.dart';
import 'journey_weather_card.dart';

class JourneySheet extends StatelessWidget {
  final PlannedMeetingJourneyResult planResult;
  final JourneyWeatherData? weather;
  final VoidCallback? onLaunchExternalDirections;
  final void Function(String travelMode)? onLaunchModeDirections;
  final ValueChanged<JourneyOption>? onSelectOption;
  final VoidCallback? onSelectManualOrigin;
  final VoidCallback? onOpenFeedSettings;
  final ValueChanged<JourneyPlanningMode>? onTogglePlanningMode;
  final String? selectedJourneyId;

  const JourneySheet({
    super.key,
    required this.planResult,
    this.weather,
    this.onLaunchExternalDirections,
    this.onLaunchModeDirections,
    this.onSelectOption,
    this.onSelectManualOrigin,
    this.onOpenFeedSettings,
    this.onTogglePlanningMode,
    this.selectedJourneyId,
  });

  IconData _statusIcon(AtlasErrorCode? failureCode) {
    switch (failureCode) {
      case AtlasErrorCode.canceled:
        return Icons.cancel_outlined;
      case AtlasErrorCode.timeout:
        return Icons.timer_off_outlined;
      case AtlasErrorCode.feedExpired:
        return Icons.event_busy_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(int utcMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(utcMs).toLocal();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatRelativeArrival(int arriveUtcMs, int? meetingStartUtcMs) {
    if (meetingStartUtcMs == null) return 'Arrival timing unverified';
    final diffMin = ((meetingStartUtcMs - arriveUtcMs) / 60000).round();
    if (diffMin > 180) {
      final days = diffMin ~/ 1440;
      final remHours = (diffMin % 1440) ~/ 60;
      final span = days > 0 ? '$days d ${remHours}h' : '${remHours}h';
      return 'Arrives $span before meeting (leave-now preview)';
    } else if (diffMin > 0) {
      return 'Arrives $diffMin min before meeting (on time)';
    } else if (diffMin == 0) {
      return 'Arrives exactly at meeting start';
    } else {
      return 'Arrives ${-diffMin} min after start (late)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = planResult.destination;
    final schedule = planResult.schedule;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final meetingStartUtcMs = schedule.nextOccurrenceUtcMs;

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
                        '${destination.fellowship} \u2022 ${schedule.statusDescription}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                      if (destination.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          destination.address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
            const SizedBox(height: 12),

            // Planning mode indicator / toggle
            if (schedule.nextOccurrence != null && onTogglePlanningMode != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      'For Meeting (${_formatTime(meetingStartUtcMs!)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: planResult.planningMode == JourneyPlanningMode.arriveBeforeMeeting
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    selected: planResult.planningMode == JourneyPlanningMode.arriveBeforeMeeting,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    onSelected: (selected) {
                      if (selected) {
                        onTogglePlanningMode!(JourneyPlanningMode.arriveBeforeMeeting);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'Leave Now',
                      style: TextStyle(
                        fontSize: 12,
                        color: planResult.planningMode == JourneyPlanningMode.leaveNow
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    selected: planResult.planningMode == JourneyPlanningMode.leaveNow,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    onSelected: (selected) {
                      if (selected) {
                        onTogglePlanningMode!(JourneyPlanningMode.leaveNow);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            JourneyWeatherCard(weather: weather),
            const SizedBox(height: 16),

            if (planResult.isRouteAvailableInApp && planResult.inAppPreview != null) ...[
              if (!planResult.hasTransitOptions &&
                  (planResult.failureCode != null || planResult.canChooseManualOrigin)) ...[
                Card(
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _statusIcon(planResult.failureCode),
                              color: colorScheme.tertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                planResult.statusMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (onSelectManualOrigin != null &&
                            planResult.canChooseManualOrigin) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(color: colorScheme.primary),
                            ),
                            icon: const Icon(Icons.place_outlined, size: 18),
                            label: const Text('Choose Starting Point'),
                            onPressed: onSelectManualOrigin,
                          ),
                        ],
                        if (onOpenFeedSettings != null &&
                            planResult.failureCode == AtlasErrorCode.feedExpired) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(color: colorScheme.primary),
                            ),
                            icon: const Icon(Icons.sync_outlined, size: 18),
                            label: const Text('Refresh Schedule in Settings'),
                            onPressed: onOpenFeedSettings,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    planResult.hasTransitOptions
                        ? 'Available Transit Routes'
                        : 'Available Routes (Walk Only)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Scheduled times \u2022 Not live GPS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...planResult.inAppPreview!.options.map((opt) {
                final isSelected = opt.journeyId == selectedJourneyId;
                final relativeArrival = _formatRelativeArrival(opt.arriveUtcMs, meetingStartUtcMs);
                final isOnTime = meetingStartUtcMs == null || opt.arriveUtcMs <= meetingStartUtcMs;
                final isDirectWalk = opt.isDirectWalk;

                final transferLabel = isDirectWalk
                    ? 'Direct walk (no transit needed)'
                    : (opt.transferCount == 0
                        ? 'Direct (no transfers)'
                        : '${opt.transferCount} transfer${opt.transferCount > 1 ? 's' : ''}');

                final badgeText = isDirectWalk
                    ? 'Estimated Distance'
                    : (opt.transferConfidence == 'scheduled_unknown'
                        ? 'Schedule Unverified'
                        : 'Confidence: ${opt.transferConfidence}');

                return Card(
                  color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? BorderSide(color: colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatTime(opt.departUtcMs)} \u2192 ${_formatTime(opt.arriveUtcMs)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDirectWalk
                                    ? colorScheme.secondaryContainer
                                    : (opt.transferConfidence == 'scheduled_unknown'
                                        ? colorScheme.tertiaryContainer
                                        : colorScheme.secondaryContainer),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDirectWalk
                                      ? colorScheme.onSecondaryContainer
                                      : (opt.transferConfidence == 'scheduled_unknown'
                                          ? colorScheme.onTertiaryContainer
                                          : colorScheme.onSecondaryContainer),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isOnTime ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                              size: 14,
                              color: isOnTime ? colorScheme.primary : colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                relativeArrival,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isOnTime
                                      ? (isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant)
                                      : colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${opt.legs.length} leg${opt.legs.length > 1 ? 's' : ''} \u2022 $transferLabel \u2022 ${(opt.walkMeters / 1000).toStringAsFixed(1)} km walk',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const Divider(height: 16),
                        if (isDirectWalk) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.straighten, size: 16, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Estimated distance: ${(opt.walkMeters / 1000).toStringAsFixed(1)} km (straight-line estimate)',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No walking polyline drawn. Map preview displays origin and destination markers only. Select Walking below for street/sidewalk directions.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isSelected ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : colorScheme.outline,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...opt.legs.map((leg) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        leg.mode == 'bus'
                                            ? Icons.directions_bus
                                            : leg.mode == 'rail'
                                                ? Icons.directions_railway
                                                : Icons.directions_walk,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${leg.fromLabel} \u2192 ${leg.toLabel}${leg.routeLabel != null ? ' (${leg.routeLabel})' : ''}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: isSelected
                                                  ? colorScheme.onPrimaryContainer
                                                  : colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                              fontWeight: leg.isTransit ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                          if ((leg.distanceMeters ?? 0) > 0)
                                            Text(
                                              '${leg.distanceMeters}m \u2022 ${_formatTime(leg.startUtcMs)}',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: colorScheme.outline,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        const SizedBox(height: 8),
                        if (onSelectOption != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(color: colorScheme.primary),
                              ),
                              icon: Icon(
                                isSelected ? Icons.map : Icons.preview,
                                size: 16,
                              ),
                              label: Text(isSelected ? 'Route on Map' : 'Preview on Map'),
                              onPressed: () => onSelectOption!(opt),
                            ),
                          ),
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
                      Icon(
                        _statusIcon(planResult.failureCode),
                        color: planResult.failureCode == AtlasErrorCode.timeout
                            ? colorScheme.error
                            : colorScheme.tertiary,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        planResult.statusMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (onSelectManualOrigin != null &&
                          (planResult.canChooseManualOrigin ||
                              planResult.statusMessage.contains('Starting location not set'))) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                          ),
                          icon: const Icon(Icons.place_outlined),
                          label: const Text('Choose Starting Point'),
                          onPressed: onSelectManualOrigin,
                        ),
                      ],
                      if (onOpenFeedSettings != null &&
                          planResult.failureCode == AtlasErrorCode.feedExpired) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                          ),
                          icon: const Icon(Icons.sync_outlined),
                          label: const Text('Refresh Schedule in Settings'),
                          onPressed: onOpenFeedSettings,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (planResult.fallbackExternalDirectionsUrl != null &&
                !destination.isSynthetic &&
                !destination.isOnlineOnly) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Calculate In-App Street Route',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                          ),
                          icon: const Icon(Icons.directions_walk, size: 18),
                          label: const Text('Walking'),
                          onPressed: () {
                            if (onLaunchModeDirections != null) {
                              onLaunchModeDirections!('walking');
                            } else {
                              onLaunchExternalDirections?.call();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                          ),
                          icon: const Icon(Icons.directions_transit, size: 18),
                          label: const Text('Transit'),
                          onPressed: () {
                            if (onLaunchModeDirections != null) {
                              onLaunchModeDirections!('transit');
                            } else {
                              onLaunchExternalDirections?.call();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                          ),
                          icon: const Icon(Icons.directions_car, size: 18),
                          label: const Text('Driving'),
                          onPressed: () {
                            if (onLaunchModeDirections != null) {
                              onLaunchModeDirections!('driving');
                            } else {
                              onLaunchExternalDirections?.call();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open External Directions (Google Maps)'),
                    onPressed: () {
                      onLaunchExternalDirections?.call();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
