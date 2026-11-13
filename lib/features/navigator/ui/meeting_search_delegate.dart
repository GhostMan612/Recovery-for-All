// lib/features/navigator/ui/meeting_search_delegate.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../../../services/meeting_finder_service.dart';
import '../application/meeting_search_service.dart';

/// Flutter SearchDelegate providing instant, responsive, offline search across
/// cached recovery meetings.
class MeetingSearchDelegate extends SearchDelegate<RecoveryMeeting?> {
  final List<RecoveryMeeting> meetings;
  final (double, double)? userLocation;

  MeetingSearchDelegate({
    required this.meetings,
    this.userLocation,
  });

  @override
  String get searchFieldLabel => 'Search by name, city, AA, day…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(color: colorScheme.onSurface, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (query.isEmpty) return null;
    return [
      IconButton(
        tooltip: 'Clear search',
        icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Back to map',
      icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResultList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildResultList(context);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const chips = [
      'Hope',
      'Tuesday AA',
      '165 Western',
      'Saint Paul',
      'SMART',
      'NA',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Meeting Search',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${meetings.length} cached meetings available offline',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Suggestions',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sample in chips)
                ActionChip(
                  label: Text(sample),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  onPressed: () {
                    query = sample;
                    showResults(context);
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.offline_bolt_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Multi-term search is supported. For example, typing "Tuesday AA" finds Tuesday meetings matching the AA fellowship across the directory.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = MeetingSearchService.search(
      query: query,
      meetings: meetings,
      userLat: userLocation?.$1,
      userLon: userLocation?.$2,
    );

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No meetings found matching "$query"',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching by fellowship (AA, NA, SMART), street address, city, or day of the week.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (ctx, index) {
        final item = results[index];
        final meeting = item.meeting;
        final dayText = MeetingSearchService.formatDayName(meeting.day);
        final isOnline = !meeting.hasLocation || meeting.address.startsWith('Online');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              meeting.fellowship.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            meeting.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$dayText ${meeting.time.isNotEmpty ? "• ${meeting.time}" : ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meeting.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.distanceKm != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${(item.distanceKm! * 0.621371).toStringAsFixed(1)} mi away',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(
            isOnline ? Icons.videocam_outlined : Icons.place_outlined,
            color: isOnline ? colorScheme.secondary : colorScheme.primary,
          ),
          onTap: () => close(ctx, meeting),
        );
      },
    );
  }
}
