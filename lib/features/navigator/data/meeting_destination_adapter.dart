// lib/features/navigator/data/meeting_destination_adapter.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:recovery_for_all/services/meeting_finder_service.dart';
import '../domain/meeting_destination.dart';

class MeetingDestinationAdapter {
  static const String defaultTimeZone = 'America/Chicago';

  static MeetingDestination fromRecoveryMeeting(
    RecoveryMeeting meeting, {
    String? sourceProviderId,
    int? fetchedAtUtcMs,
    String? freshness,
  }) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final fetchedAt = fetchedAtUtcMs ?? nowMs;

    String resolvedSourceId;
    String resolvedMeetingId;

    if (meeting.id.contains(':')) {
      final parts = meeting.id.split(':');
      resolvedSourceId = parts[0];
      resolvedMeetingId = parts.sublist(1).join(':');
    } else {
      resolvedMeetingId = meeting.id;
      if (sourceProviderId != null && sourceProviderId.trim().isNotEmpty) {
        resolvedSourceId = sourceProviderId;
      } else {
        switch (meeting.fellowshipEnum) {
          case RecoveryFellowship.aa:
            resolvedSourceId = 'tsml_aa_minnesota';
            break;
          case RecoveryFellowship.na:
            resolvedSourceId = 'bmlt_na_minnesota';
            break;
          case RecoveryFellowship.dharma:
            resolvedSourceId = 'dharma_minnesota';
            break;
          case RecoveryFellowship.smart:
            resolvedSourceId = 'smart_minnesota';
            break;
          default:
            resolvedSourceId = 'curated_directory';
        }
      }
    }

    final isSynthetic = _detectSynthetic(meeting.id, meeting.name);

    // Sanitize coordinates: if either is invalid or out-of-bounds, reset both to 0.0
    double sanitizedLat = meeting.latitude;
    double sanitizedLon = meeting.longitude;
    final bool invalidLat = sanitizedLat.isNaN ||
        sanitizedLat.isInfinite ||
        sanitizedLat < -90.0 ||
        sanitizedLat > 90.0;
    final bool invalidLon = sanitizedLon.isNaN ||
        sanitizedLon.isInfinite ||
        sanitizedLon < -180.0 ||
        sanitizedLon > 180.0;

    if (invalidLat || invalidLon) {
      sanitizedLat = 0.0;
      sanitizedLon = 0.0;
    }

    return MeetingDestination(
      sourceId: resolvedSourceId,
      sourceMeetingId: resolvedMeetingId,
      name: meeting.name,
      fellowship: meeting.fellowship,
      meetingType: meeting.type,
      latitude: sanitizedLat,
      longitude: sanitizedLon,
      address: meeting.address,
      ianaTimeZone: defaultTimeZone,
      dayOfWeek: meeting.day,
      minuteOfDay: meeting.minutes,
      conferenceUrl: meeting.conferenceUrl,
      seventhTraditionUrl: meeting.seventhTraditionUrl,
      isSynthetic: isSynthetic,
      sourceFreshness: freshness ?? 'fresh',
      fetchedAtUtcMs: fetchedAt,
    );
  }

  static bool _detectSynthetic(String id, String name) {
    final idLower = id.toLowerCase();
    final nameLower = name.toLowerCase();
    return idLower.startsWith('sample') ||
        idLower.contains('fixture') ||
        idLower.contains('synthetic') ||
        nameLower.contains('sample') ||
        nameLower.contains('fixture') ||
        nameLower.contains('synthetic');
  }
}
