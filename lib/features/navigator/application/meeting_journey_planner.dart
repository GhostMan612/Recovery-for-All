// lib/features/navigator/application/meeting_journey_planner.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../data/atlas_dtos.dart';
import '../data/navigator_repository.dart';
import '../domain/meeting_destination.dart';
import 'meeting_schedule_resolver.dart';

enum JourneyPlanningMode {
  arriveBeforeMeeting,
  leaveNow,
}

/// Idempotent cooperative cancellation token for meeting route requests.
class JourneyCancellationToken {
  bool _isCanceled = false;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  bool get isCanceled => _isCanceled;

  void addListener(VoidCallback listener) {
    if (_isCanceled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void cancel() {
    if (_isCanceled) return;
    _isCanceled = true;
    final snapshot = List<VoidCallback>.from(_listeners);
    _listeners.clear();
    for (final listener in snapshot) {
      listener();
    }
  }
}

@immutable
class PlannedMeetingJourneyResult {
  final MeetingDestination destination;
  final ScheduleResolutionResult schedule;
  final JourneyPreview? inAppPreview;
  final String? fallbackExternalDirectionsUrl;
  final bool isRouteAvailableInApp;
  final String statusMessage;
  final JourneyPlanningMode planningMode;
  final AtlasErrorCode? failureCode;
  final List<String> missingReasons;
  final bool canChooseManualOrigin;

  const PlannedMeetingJourneyResult({
    required this.destination,
    required this.schedule,
    this.inAppPreview,
    this.fallbackExternalDirectionsUrl,
    required this.isRouteAvailableInApp,
    required this.statusMessage,
    this.planningMode = JourneyPlanningMode.arriveBeforeMeeting,
    this.failureCode,
    this.missingReasons = const [],
    this.canChooseManualOrigin = false,
  });

  bool get hasTransitOptions =>
      inAppPreview?.options.any((opt) => !opt.isDirectWalk) ?? false;
}

class MeetingJourneyPlanner {
  final NavigatorRepository _repository;
  int _requestSequence = 0;

  MeetingJourneyPlanner({NavigatorRepository? repository})
      : _repository = repository ?? NavigatorRepository();

  String allocateRequestId(String sourceMeetingId) {
    _requestSequence++;
    return 'req-${DateTime.now().millisecondsSinceEpoch}-$_requestSequence-$sourceMeetingId';
  }

  Future<bool> cancelRequest(String requestId) {
    return _repository.cancelJourneyRequest(requestId);
  }

  static double calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<PlannedMeetingJourneyResult> planJourneyForMeeting({
    required MeetingDestination destination,
    double? originLat,
    double? originLon,
    DateTime? referenceTime,
    int arrivalBufferMinutes = 15,
    JourneyPlanningMode planningMode = JourneyPlanningMode.arriveBeforeMeeting,
    bool includeDirectWalk = true,
    Duration planTimeout = const Duration(seconds: 12),
    String? requestId,
    JourneyCancellationToken? cancellationToken,
  }) async {
    final budgetWatch = Stopwatch()..start();
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
        planningMode: planningMode,
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
        planningMode: planningMode,
      );
    }

    // Generate fallback external maps directions URL (with user consent disclosure)
    final encodedDest = Uri.encodeComponent(
      destination.address.isNotEmpty
          ? destination.address
          : '${destination.latitude},${destination.longitude}',
    );
    final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$encodedDest';

    // Guard 3: User origin coordinates must be provided (no assumed Minneapolis location)
    if (originLat == null || originLon == null) {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: 'Starting location not set. Enable GPS or choose a starting point to plan transit routes.',
        planningMode: planningMode,
        canChooseManualOrigin: true,
      );
    }

    // Guard 4: Geographic transit coverage bounds check
    if (!destination.isWithinTransitCoverage) {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: 'Local transit routing unavailable: destination is outside the Metro Transit regional service area. External navigation available.',
        planningMode: planningMode,
      );
    }

    if (originLat < MeetingDestination.metroMinLat ||
        originLat > MeetingDestination.metroMaxLat ||
        originLon < MeetingDestination.metroMinLon ||
        originLon > MeetingDestination.metroMaxLon) {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: 'Local transit routing unavailable: starting point is outside the Metro Transit regional service area. External navigation available.',
        planningMode: planningMode,
        canChooseManualOrigin: true,
      );
    }

    final now = referenceTime ?? DateTime.now();
    final nextOcc = schedule.nextOccurrence;

    // Distinguish between arrive-before-meeting and leave-now planning
    final int departUtcMs;
    final int? arriveBeforeUtcMs;

    if (planningMode == JourneyPlanningMode.arriveBeforeMeeting && nextOcc != null) {
      final targetArrival = nextOcc.subtract(Duration(minutes: arrivalBufferMinutes));
      arriveBeforeUtcMs = targetArrival.toUtc().millisecondsSinceEpoch;
      // Start transit search window up to 90 min before target arrival on the scheduled meeting day
      final windowStart = targetArrival.subtract(const Duration(minutes: 90));
      final effectiveStart = windowStart.isBefore(now) ? now : windowStart;
      departUtcMs = effectiveStart.toUtc().millisecondsSinceEpoch;
    } else {
      departUtcMs = now.toUtc().millisecondsSinceEpoch;
      arriveBeforeUtcMs = null;
    }

    // Synthesize Direct Walking Journey Option for nearby comparisons
    JourneyOption? directWalkOption;
    if (includeDirectWalk) {
      final crowMeters = calculateHaversineDistanceMeters(
        originLat,
        originLon,
        destination.latitude,
        destination.longitude,
      );
      // Generate pedestrian direct walk option for distances within reasonable range (<= 5 km)
      if (crowMeters <= 5000.0) {
        final directWalkMeters = (crowMeters * 1.25).round();
        final walkMinutes = math.max(1, (directWalkMeters / 75.0).ceil());

        final int walkDepartMs;
        final int walkArriveMs;

        if (planningMode == JourneyPlanningMode.arriveBeforeMeeting && nextOcc != null) {
          final targetArrival = nextOcc.subtract(Duration(minutes: arrivalBufferMinutes));
          walkArriveMs = targetArrival.toUtc().millisecondsSinceEpoch;
          walkDepartMs = targetArrival.subtract(Duration(minutes: walkMinutes)).toUtc().millisecondsSinceEpoch;
        } else {
          walkDepartMs = now.toUtc().millisecondsSinceEpoch;
          walkArriveMs = now.add(Duration(minutes: walkMinutes)).toUtc().millisecondsSinceEpoch;
        }

        directWalkOption = JourneyOption(
          journeyId: 'direct-walk',
          departUtcMs: walkDepartMs,
          arriveUtcMs: walkArriveMs,
          walkMeters: directWalkMeters,
          transferCount: 0,
          transferConfidence: 'direct_walk',
          legs: [
            JourneyLeg(
              mode: 'walk',
              fromLabel: 'Starting Point',
              toLabel: destination.name,
              startUtcMs: walkDepartMs,
              endUtcMs: walkArriveMs,
              routeLabel: 'Estimated Distance (No street routing)',
              distanceMeters: directWalkMeters,
              fromLat: originLat,
              fromLon: originLon,
              toLat: destination.latitude,
              toLon: destination.longitude,
            ),
          ],
        );
      }
    }

    final effectiveRequestId = (requestId != null && requestId.trim().isNotEmpty)
        ? requestId.trim()
        : allocateRequestId(destination.sourceMeetingId);

    PlannedMeetingJourneyResult buildCanceledResult() {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: 'Transit route planning was canceled. External navigation remains available.',
        planningMode: planningMode,
        failureCode: AtlasErrorCode.canceled,
      );
    }

    if (cancellationToken?.isCanceled == true) {
      unawaited(_repository.cancelJourneyRequest(effectiveRequestId));
      return buildCanceledResult();
    }

    final remainingMs = planTimeout.inMilliseconds - budgetWatch.elapsedMilliseconds;
    if (remainingMs <= 0) {
      unawaited(_repository.cancelJourneyRequest(effectiveRequestId));
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage:
            'Local transit routing unavailable: Transit route calculation timed out. External navigation available.',
        planningMode: planningMode,
        failureCode: AtlasErrorCode.timeout,
      );
    }

    final remainingTimeout = Duration(milliseconds: remainingMs);

    Future<JourneyPreview?> awaitPlanWithCancellation() async {
      final completer = Completer<JourneyPreview?>();
      var cancelSent = false;

      Future<void> dispatchNativeCancel() async {
        if (cancelSent) return;
        cancelSent = true;
        await _repository.cancelJourneyRequest(effectiveRequestId);
      }

      void onTokenCanceled() {
        unawaited(dispatchNativeCancel());
        if (!completer.isCompleted) {
          completer.completeError(
            const AtlasException(
              code: AtlasErrorCode.canceled,
              message: 'Journey request was canceled',
            ),
          );
        }
      }

      cancellationToken?.addListener(onTokenCanceled);

      final timer = Timer(remainingTimeout, () async {
        if (cancellationToken?.isCanceled == true) {
          onTokenCanceled();
          return;
        }
        await dispatchNativeCancel();
        if (!completer.isCompleted) {
          completer.completeError(
            const AtlasException(
              code: AtlasErrorCode.timeout,
              message: 'Transit schedule is still initializing or route calculation timed out',
            ),
          );
        }
      });

      final planFuture = _repository.planMeetingJourney(
        requestId: effectiveRequestId,
        meetingId: destination.compositeId,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destination.latitude,
        destinationLon: destination.longitude,
        departAtUtcMs: departUtcMs,
        arriveBeforeUtcMs: arriveBeforeUtcMs,
        timeoutMs: remainingMs,
      );

      planFuture.then(
        (value) {
          if (cancellationToken?.isCanceled == true) {
            onTokenCanceled();
          } else if (!completer.isCompleted) {
            completer.complete(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (cancellationToken?.isCanceled == true) {
            onTokenCanceled();
          } else if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      try {
        return await completer.future;
      } finally {
        timer.cancel();
        cancellationToken?.removeListener(onTokenCanceled);
      }
    }

    JourneyPreview? directWalkPreview(String freshness) {
      if (directWalkOption == null) return null;
      return JourneyPreview(
        version: 1,
        requestId: effectiveRequestId,
        meetingId: destination.compositeId,
        providerId: 'atlas_pedestrian_fallback',
        dataSource: 'direct_walk_estimate',
        isSynthetic: false,
        fetchedAtUtcMs: DateTime.now().millisecondsSinceEpoch,
        freshness: freshness,
        options: [directWalkOption],
      );
    }

    try {
      final preview = await awaitPlanWithCancellation();

      if (cancellationToken?.isCanceled == true) {
        return buildCanceledResult();
      }

      final returnedOptions = preview?.options ?? const <JourneyOption>[];
      final repairedAndDedupedTransit = _repairAndDeduplicateOptions(
        returnedOptions,
        destination,
      );

      final combinedOptions = <JourneyOption>[];
      if (directWalkOption != null) {
        combinedOptions.add(directWalkOption);
      }
      combinedOptions.addAll(repairedAndDedupedTransit);

      if (combinedOptions.isNotEmpty) {
        final sortedOptions = _rankJourneyOptions(
          options: combinedOptions,
          meetingStartMs: schedule.nextOccurrence?.toUtc().millisecondsSinceEpoch,
          planningMode: planningMode,
        );

        final rankedPreview = JourneyPreview(
          version: preview?.version ?? 1,
          requestId: preview?.requestId ?? effectiveRequestId,
          meetingId: preview?.meetingId ?? destination.compositeId,
          providerId: preview?.providerId ??
              (directWalkOption != null ? 'atlas_pedestrian_planner' : 'atlas_static_planner'),
          dataSource: preview?.dataSource ?? 'direct_walk_estimate',
          isSynthetic: preview?.isSynthetic ?? false,
          fetchedAtUtcMs: preview?.fetchedAtUtcMs ?? DateTime.now().millisecondsSinceEpoch,
          freshness: preview?.freshness ?? 'fresh',
          options: sortedOptions,
        );

        return PlannedMeetingJourneyResult(
          destination: destination,
          schedule: schedule,
          inAppPreview: rankedPreview,
          fallbackExternalDirectionsUrl: fallbackUrl,
          isRouteAvailableInApp: true,
          statusMessage: 'In-app route planned successfully.',
          planningMode: planningMode,
        );
      }
    } on AtlasException catch (e) {
      if (e.code == AtlasErrorCode.canceled) {
        return buildCanceledResult();
      }

      if (e.code == AtlasErrorCode.feedExpired) {
        final walkFallback = directWalkPreview('expired');
        if (walkFallback != null) {
          return PlannedMeetingJourneyResult(
            destination: destination,
            schedule: schedule,
            inAppPreview: walkFallback,
            fallbackExternalDirectionsUrl: fallbackUrl,
            isRouteAvailableInApp: true,
            statusMessage:
                'Metro Transit schedule expired — transit routing is disabled until refreshed in Settings. Showing estimated direct walk distance only.',
            planningMode: planningMode,
            failureCode: AtlasErrorCode.feedExpired,
          );
        }
        return PlannedMeetingJourneyResult(
          destination: destination,
          schedule: schedule,
          inAppPreview: null,
          fallbackExternalDirectionsUrl: fallbackUrl,
          isRouteAvailableInApp: false,
          statusMessage:
              'Local transit routing unavailable: ${e.message} External navigation available.',
          planningMode: planningMode,
          failureCode: AtlasErrorCode.feedExpired,
        );
      }

      if (e.code == AtlasErrorCode.noItinerary) {
        final missing = e.missingReasons;
        final missingOrigin = missing.contains('no-origin-stops-within-walk-limit');
        final missingDest = missing.contains('no-destination-stops-within-walk-limit');
        final genericStopLimit = missing.contains('stops-within-walk-limit');
        final canChooseOrigin =
            missingOrigin || (genericStopLimit && !missingDest);

        final String coverageMessage;
        if (missingOrigin && missingDest) {
          coverageMessage =
              'No covered Metro Transit stops found within 1.5 km of your starting point or this meeting.';
        } else if (missingDest) {
          coverageMessage =
              'No covered Metro Transit stop found within 1.5 km of this meeting.';
        } else if (missingOrigin || genericStopLimit) {
          coverageMessage =
              'No covered Metro Transit stop found within 1.5 km of your starting point.';
        } else {
          coverageMessage = 'No scheduled transit route found for this time.';
        }

        final walkFallback = directWalkPreview('fresh');
        if (walkFallback != null) {
          return PlannedMeetingJourneyResult(
            destination: destination,
            schedule: schedule,
            inAppPreview: walkFallback,
            fallbackExternalDirectionsUrl: fallbackUrl,
            isRouteAvailableInApp: true,
            statusMessage:
                '$coverageMessage Showing estimated direct walk distance only — this is not a transit itinerary. External navigation recommended for street directions.',
            planningMode: planningMode,
            failureCode: AtlasErrorCode.noItinerary,
            missingReasons: missing,
            canChooseManualOrigin: canChooseOrigin,
          );
        }

        return PlannedMeetingJourneyResult(
          destination: destination,
          schedule: schedule,
          inAppPreview: null,
          fallbackExternalDirectionsUrl: fallbackUrl,
          isRouteAvailableInApp: false,
          statusMessage: '$coverageMessage External navigation available.',
          planningMode: planningMode,
          failureCode: AtlasErrorCode.noItinerary,
          missingReasons: missing,
          canChooseManualOrigin: canChooseOrigin,
        );
      }

      debugPrint('MeetingJourneyPlanner: Atlas routing unavailable: $e');
      final String failureMessage;
      if (e.code == AtlasErrorCode.sdkNotInstalled) {
        failureMessage =
            'Local transit routing unavailable: Atlas engine not installed. External navigation available.';
      } else {
        failureMessage =
            'Local transit routing unavailable: ${e.message}. External navigation available.';
      }
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: failureMessage,
        planningMode: planningMode,
        failureCode: e.code,
        missingReasons: e.missingReasons,
      );
    } catch (e) {
      debugPrint('MeetingJourneyPlanner: Unexpected routing failure: $e');
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: null,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: false,
        statusMessage: 'Unexpected routing failure. External navigation available.',
        planningMode: planningMode,
        failureCode: AtlasErrorCode.nativeFailure,
      );
    }

    // Direct walk fallback if no transit options returned from operational provider
    final walkFallback = directWalkPreview('fresh');
    if (walkFallback != null) {
      return PlannedMeetingJourneyResult(
        destination: destination,
        schedule: schedule,
        inAppPreview: walkFallback,
        fallbackExternalDirectionsUrl: fallbackUrl,
        isRouteAvailableInApp: true,
        statusMessage:
            'Estimated direct distance available. No scheduled transit route found for this time. External navigation recommended for street directions.',
        planningMode: planningMode,
      );
    }

    return PlannedMeetingJourneyResult(
      destination: destination,
      schedule: schedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: fallbackUrl,
      isRouteAvailableInApp: false,
      statusMessage: 'No scheduled transit route found for this time. External navigation available.',
      planningMode: planningMode,
      failureCode: AtlasErrorCode.noItinerary,
    );
  }

  /// Validates itinerary continuity and eliminates duplicate route options
  List<JourneyOption> _repairAndDeduplicateOptions(
    List<JourneyOption> options,
    MeetingDestination destination,
  ) {
    final repairedOptions = <JourneyOption>[];

    for (final opt in options) {
      if (opt.legs.isEmpty) {
        repairedOptions.add(opt);
        continue;
      }
      final rawLegs = opt.legs;
      final fixedLegs = <JourneyLeg>[];

      for (var i = 0; i < rawLegs.length; i++) {
        final leg = rawLegs[i];
        var from = leg.fromLabel;
        var to = leg.toLabel;

        if (leg.isWalk) {
          if (i == 0 && (from.isEmpty || from == 'Origin')) {
            from = 'Starting Point';
          }
          if (i == rawLegs.length - 1 && (to.isEmpty || to == 'Destination')) {
            to = destination.name;
          }
          if (from == to) {
            if (i == rawLegs.length - 1) {
              to = destination.name;
            } else {
              to = '$to (Transfer)';
            }
          }
        }
        fixedLegs.add(JourneyLeg(
          mode: leg.mode,
          fromLabel: from,
          toLabel: to,
          startUtcMs: leg.startUtcMs,
          endUtcMs: leg.endUtcMs,
          routeLabel: leg.routeLabel,
          distanceMeters: leg.distanceMeters,
          fromLat: leg.fromLat,
          fromLon: leg.fromLon,
          toLat: leg.toLat,
          toLon: leg.toLon,
        ));
      }

      repairedOptions.add(JourneyOption(
        journeyId: opt.journeyId,
        departUtcMs: opt.departUtcMs,
        arriveUtcMs: opt.arriveUtcMs,
        walkMeters: opt.walkMeters,
        transferCount: opt.transferCount,
        transferConfidence: opt.transferConfidence,
        legs: fixedLegs,
      ));
    }

    // Deduplicate equivalent itineraries
    final seenSignatures = <String>{};
    final deduplicated = <JourneyOption>[];

    for (final opt in repairedOptions) {
      final transitSig = opt.legs
          .where((l) => l.isTransit)
          .map((l) => '${l.routeLabel}:${l.fromLabel}->${l.toLabel}')
          .join('|');
      final depMin = opt.departUtcMs ~/ 60000;
      final arrMin = opt.arriveUtcMs ~/ 60000;
      final sig = transitSig.isEmpty
          ? '${opt.journeyId}@$depMin-$arrMin'
          : '$transitSig@$depMin-$arrMin';

      if (seenSignatures.add(sig)) {
        deduplicated.add(opt);
      }
    }

    return deduplicated;
  }

  /// Compares a direct walk option against a transit option
  int _compareDirectWalkToTransit(JourneyOption walk, JourneyOption transit) {
    final walkDist = walk.walkMeters;
    final transitWalk = transit.walkMeters;
    final walkDuration = walk.durationMinutes;
    final transitDuration = transit.durationMinutes;

    // Condition 1: Transit walking burden is greater than or equal to direct walk.
    // (e.g. Saint Paul defect: transit required 2.2 km walk vs 1.2 km direct walk)
    if (transitWalk >= walkDist) {
      return -1; // Direct walk strongly dominates
    }

    // Condition 2: Transit has transfers and direct walk is short (<= 1.5 km) and faster or comparable
    if (transit.transferCount > 0 && walkDist <= 1500 && walkDuration <= (transitDuration + 5)) {
      return -1; // Walk dominates complicated multi-leg transit
    }

    // Condition 3: Transit is significantly slower (>= 15 min longer door-to-door) for a short walk
    if (walkDist <= 1500 && (transitDuration - walkDuration) >= 15) {
      return -1;
    }

    // Otherwise, if transit has substantially less walking and 0 transfers, transit is preferred
    if (transit.transferCount == 0 && transitWalk < walkDist) {
      if (walkDist <= 400) {
        return -1;
      }
      return 1; // Transit wins because it saves pedestrian exertion
    }

    // Default comparator by walking distance
    return walkDist.compareTo(transitWalk);
  }

  /// Ranks options comparing walking-first against transit itineraries
  List<JourneyOption> _rankJourneyOptions({
    required List<JourneyOption> options,
    int? meetingStartMs,
    required JourneyPlanningMode planningMode,
  }) {
    final sorted = List<JourneyOption>.from(options);

    sorted.sort((a, b) {
      // 1. If planning for meeting arrival, prioritize on-time arrivals
      if (meetingStartMs != null && planningMode == JourneyPlanningMode.arriveBeforeMeeting) {
        final aOnTime = a.arriveUtcMs <= meetingStartMs;
        final bOnTime = b.arriveUtcMs <= meetingStartMs;
        if (aOnTime && !bOnTime) return -1;
        if (!aOnTime && bOnTime) return 1;
      }

      // 2. Walking-first comparison against transit
      if (a.isDirectWalk && !b.isDirectWalk) {
        return _compareDirectWalkToTransit(a, b);
      } else if (!a.isDirectWalk && b.isDirectWalk) {
        return -_compareDirectWalkToTransit(b, a);
      }

      // 3. Fewer transfers
      if (a.transferCount != b.transferCount) {
        return a.transferCount.compareTo(b.transferCount);
      }

      // 4. Lower walking burden
      if (a.walkMeters != b.walkMeters) {
        return a.walkMeters.compareTo(b.walkMeters);
      }

      // 5. Total duration
      return a.durationMinutes.compareTo(b.durationMinutes);
    });

    return sorted;
  }
}
