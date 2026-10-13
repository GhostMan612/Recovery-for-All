// test/navigator/meeting_journey_planner_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_journey_planner.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_bridge.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_dtos.dart';
import 'package:recovery_for_all/features/navigator/data/navigator_repository.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';

class _FakeAtlasBridge extends AtlasBridge {
  final bool simulateSdkInstalled;

  _FakeAtlasBridge({this.simulateSdkInstalled = true});

  @override
  Future<JourneyPreview> planJourney({
    required String requestId,
    required String meetingId,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required int departAtUtcMs,
    int? arriveBeforeUtcMs,
    int maxWalkMeters = 1500,
    bool allowRemote = false,
    List<String> transitModes = const ['bus', 'rail'],
    int apiVersion = AtlasBridge.currentApiVersion,
  }) async {
    if (!simulateSdkInstalled) {
      throw const AtlasException(
        code: AtlasErrorCode.sdkNotInstalled,
        message: 'Atlas SDK unlinked',
      );
    }

    return JourneyPreview(
      version: 1,
      requestId: requestId,
      meetingId: meetingId,
      providerId: 'metro_transit_mn',
      dataSource: 'static_gtfs',
      isSynthetic: false,
      fetchedAtUtcMs: 1791750000000,
      freshness: 'fresh',
      options: [
        JourneyOption(
          journeyId: 'j-01',
          departUtcMs: departAtUtcMs + 300000,
          arriveUtcMs: departAtUtcMs + 1800000,
          walkMeters: 450,
          transferCount: 0,
          transferConfidence: 'high',
          legs: [
            JourneyLeg(
              mode: 'bus',
              fromLabel: 'Origin Stop',
              toLabel: 'Alano Stop',
              startUtcMs: departAtUtcMs + 300000,
              endUtcMs: departAtUtcMs + 1800000,
              routeLabel: 'Route 6',
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  group('MeetingJourneyPlanner Tests', () {
    test('plans in-app route when native routing is operational', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: '101',
        name: 'Nicollet Avenue Group',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9778,
        longitude: -93.2650,
        address: '2214 S 10th Ave',
        dayOfWeek: 1,
        minuteOfDay: 19 * 60,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9700,
        originLon: -93.2600,
        referenceTime: DateTime(2026, 10, 12, 17, 0),
      );

      expect(result.isRouteAvailableInApp, isTrue);
      expect(result.inAppPreview, isNotNull);
      expect(result.inAppPreview!.options.length, 1);
      expect(result.fallbackExternalDirectionsUrl, isNotNull);
      expect(result.fallbackExternalDirectionsUrl, contains('google.com/maps/dir'));
    });

    test('synthetic meeting is blocked from routing with clear explanation', () async {
      final planner = MeetingJourneyPlanner();

      const syntheticDest = MeetingDestination(
        sourceId: 'sample',
        sourceMeetingId: 's-99',
        name: 'Sample Test Group',
        fellowship: 'NA',
        meetingType: 'Step',
        latitude: 44.9778,
        longitude: -93.2650,
        address: '123 Fake St',
        isSynthetic: true,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: syntheticDest,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNull);
      expect(result.statusMessage, contains('synthetic fixture record'));
    });

    test('online only meeting is blocked from physical routing', () async {
      final planner = MeetingJourneyPlanner();

      const onlineDest = MeetingDestination(
        sourceId: 'virtual',
        sourceMeetingId: 'v-01',
        name: 'Zoom Fellowship',
        fellowship: 'AA',
        meetingType: 'Discussion',
        latitude: 0.0,
        longitude: 0.0,
        address: 'Online',
        conferenceUrl: 'https://zoom.us/j/999',
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: onlineDest,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.statusMessage, contains('video conference'));
    });

    test('falls back gracefully to external directions when native SDK is unlinked', () async {
      final unlinkedBridge = _FakeAtlasBridge(simulateSdkInstalled: false);
      final repo = NavigatorRepository(bridge: unlinkedBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: '101',
        name: 'Cedar-Riverside Meeting',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9710,
        longitude: -93.2450,
        address: 'Cedar Ave, Minneapolis',
        dayOfWeek: 1,
        minuteOfDay: 19 * 60,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNotNull);
      expect(result.fallbackExternalDirectionsUrl, contains('google.com/maps/dir'));
      expect(result.statusMessage, contains('External navigation available'));
    });
  });
}
