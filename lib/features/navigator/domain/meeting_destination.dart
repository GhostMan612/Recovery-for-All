// lib/features/navigator/domain/meeting_destination.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

@immutable
class MeetingDestination {
  final String sourceId;
  final String sourceMeetingId;
  final String name;
  final String fellowship;
  final String meetingType;
  final double latitude;
  final double longitude;
  final String address;
  final String ianaTimeZone;
  final int? dayOfWeek; // 0 = Sunday .. 6 = Saturday, null if undated
  final int? minuteOfDay; // 0 .. 1439, null if undated
  final String? conferenceUrl;
  final String? seventhTraditionUrl;
  final bool isSynthetic;
  final String sourceFreshness; // 'fresh', 'stale', 'unknown'
  final int fetchedAtUtcMs;

  const MeetingDestination({
    required this.sourceId,
    required this.sourceMeetingId,
    required this.name,
    required this.fellowship,
    required this.meetingType,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.ianaTimeZone = 'America/Chicago',
    this.dayOfWeek,
    this.minuteOfDay,
    this.conferenceUrl,
    this.seventhTraditionUrl,
    this.isSynthetic = false,
    this.sourceFreshness = 'fresh',
    required this.fetchedAtUtcMs,
  });

  /// Canonical composite identifier per WO-2B: (feedProviderId, providerMeetingId)
  String get compositeId => '$sourceId:$sourceMeetingId';

  bool get isOnlineOnly {
    final hasNoCoords = latitude == 0.0 && longitude == 0.0;
    final hasOnlineUrl = conferenceUrl != null && conferenceUrl!.trim().isNotEmpty;
    final hasEmptyAddress = address.trim().isEmpty || address.toLowerCase() == 'online';
    return (hasNoCoords || hasEmptyAddress) && hasOnlineUrl;
  }

  bool get hasValidCoordinates {
    if (latitude.isNaN || latitude.isInfinite || longitude.isNaN || longitude.isInfinite) {
      return false;
    }
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
      return false;
    }
    // (0.0, 0.0) represents null island / missing coordinate
    if (latitude == 0.0 && longitude == 0.0) {
      return false;
    }
    return true;
  }

  /// Only authentic physical meetings with valid geodata are eligible for routing.
  /// Synthetic fixtures or online-only meetings cannot initiate native routing.
  bool get isEligibleForPhysicalRouting {
    return !isSynthetic && hasValidCoordinates && !isOnlineOnly;
  }

  bool get hasKnownSchedule => dayOfWeek != null && minuteOfDay != null;
}
