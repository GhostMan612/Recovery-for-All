// lib/features/navigator/ui/widgets/journey_weather_card.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

@immutable
class JourneyWeatherData {
  final double? temperatureFahrenheit;
  final String conditionSummary;
  final int? precipitationProbability;
  final String source;
  final DateTime fetchedAt;
  final bool isStale;

  const JourneyWeatherData({
    this.temperatureFahrenheit,
    required this.conditionSummary,
    this.precipitationProbability,
    required this.source,
    required this.fetchedAt,
    this.isStale = false,
  });
}

class JourneyWeatherCard extends StatelessWidget {
  final JourneyWeatherData? weather;

  const JourneyWeatherCard({super.key, this.weather});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (weather == null) {
      return Card(
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: colorScheme.onSurfaceVariant, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weather forecast unavailable offline',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = weather!;
    final tempStr = data.temperatureFahrenheit != null
        ? '${data.temperatureFahrenheit!.round()}°F'
        : 'Temp unknown';
    final precipStr = data.precipitationProbability != null
        ? ' • ${data.precipitationProbability}% precip'
        : '';
    final freshnessStr = data.isStale
        ? ' (Stale forecast from ${data.fetchedAt.hour}:${data.fetchedAt.minute.toString().padLeft(2, '0')})'
        : ' (${data.source})';

    return Semantics(
      label: 'Weather condition: ${data.conditionSummary}, $tempStr$precipStr$freshnessStr',
      child: Card(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.conditionSummary} — $tempStr$precipStr',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Source: ${data.source}$freshnessStr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
