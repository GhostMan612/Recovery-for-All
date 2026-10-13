// lib/features/navigator/application/meeting_journey_planner.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';
import '../data/atlas_dtos.dart';
import '../data/navigator_repository.dart';
import '../domain/meeting_destination.dart';
import 'meeting_schedule_resolver.dart';

@immutable
class PlannedMeetingJourneyResult {
  final MeetingDestination destination;
  final ScheduleResolutionResult schedule;
  final JourneyPreview? inAppPreview;
  final String? fallbackExternalDirectionsUrl;
  final bool isRouteAvailableInApp;
  final String statusMessage;

  const PlannedMeetingJourneyResult({
    required this.destination,
    required this.schedule,
    this.inAppPreview,
    this.fallbackExternalDirectionsUrl,
    required this.isRouteAvailableInApp,
    required this.statusMessage,
  });
}

class MeetingJourneyPlanner {
  final NavigatorRepository _repository;

  MeetingJourneyPlanner({NavigatorRepository? repository})
      : _repository = repository ?? NavigatorRepository();

  Future<PlannedMeetingJourneyResult> planJourneyForMeeting({
    required MeetingDestination destination,
    required double originLat,
    required double originLon,
    DateTime? referenceTime,
    int arrivalBufferMinutes = 15,
  }) async {
    final schedule = MeetingScheduleResolver.resolveNextOccurrence(
      destination,
      referenceTime: referenceTime,
    );

    // Guard 1: Synthetic meetings cannot receive authentic routing
    if (destination.isSynthetic) {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: null,
        isRouteAvailableInApp: false,
        statusMessage: 'Routing unavailable: this is a synthetic fixture record.',
      );
    }

    // Guard 2: Online-only meetings or invalid coordinates
    if (!destination.isEligibleForPhysicalRouting) {
      final reason = destination.isOnlineOnly
          ? 'Meeting is held online via video conference.'
          : 'Invalid or missing physical location coordinates.';
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: null,
        isRouteAvailableInApp: false,
        statusMessage: 'Routing unavailable: $reason',
      );
    }

    // Generate fallback external maps directions URL (with user consent disclosure)
    final encodedDest = Uri.encodeComponent(
      destination.address.isNotEmpty
          ? destination.address
          : '${destination.latitude},${destination.longitude}',
    );
    final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$encodedDest';

    // Calculate arrival target based on scheduled meeting time
    final now = referenceTime ?? DateTime.now();
    final departUtcMs = now.toUtc().millisecondsSinceEpoch;
    int? arriveBeforeUtcMs;

    if (schedule.nextOccurrence != null) {
      final targetArrival = schedule.nextOccurrence!.subtract(
        Duration(minutes: arrivalBufferMinutes),
      );
      arriveBeforeUtcMs = targetArrival.toUtc().millisecondsSinceEpoch;
    }

    final requestId = 'req-${DateTime.now().millisecondsSinceEpoch}-${destination.sourceMeetingId}';

    try {
      final preview = await _repository.planMeetingJourney(
        requestId: requestId,
        meetingId: destination.compositeId,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destination.latitude,
        destinationLon: destination.longitude,
        departAtUtcMs: departUtcMs,
        arriveBeforeUtcMs: arriveBeforeUtcMs,
      );

      if (preview != null && preview.options.isNotEmpty) {
        return PlannedMeetingJourneyResult(
          destination: destination,
          schedule: schedule,
          inAppPreview: preview,
          fallbackExternalDirectionsUrl: fallbackUrl,
          isRouteAvailableInApp: true,
          statusMessage: 'In-app transit route planned successfully.',
        );
      }
    } on AtlasException catch (e) {
      debugPrint('MeetingJourneyPlanner: Atlas routing unavailable: $e');
    } catch (e) {
      debugPrint('MeetingJourneyPlanner: Unexpected routing failure: $e');
    }

    // Fallback mode: native routing unavailable or unlinked
    return PlannedMeetingJourneyResult(
      destination: destination,
      schedule: schedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: fallbackUrl,
      isRouteAvailableInApp: false,
      statusMessage: 'In-app transit network unlinked. External navigation available.',
    );
  }
}
