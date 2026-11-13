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
  final List<JourneyOption>? customOptions;
  int? lastDepartAtUtcMs;
  int? lastArriveBeforeUtcMs;

  _FakeAtlasBridge({this.simulateSdkInstalled = true, this.customOptions});

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
    lastDepartAtUtcMs = departAtUtcMs;
    lastArriveBeforeUtcMs = arriveBeforeUtcMs;

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
      options: customOptions ?? [
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
        includeDirectWalk: false,
      );

      expect(result.isRouteAvailableInApp, isTrue);
      expect(result.inAppPreview, isNotNull);
      expect(result.inAppPreview!.options.length, 1);
      expect(result.inAppPreview!.options.first.journeyId, 'j-01');
      expect(result.statusMessage, contains('successfully'));
    });

    test('ranks returned options prioritizing on-time arrivals, fewer transfers, and lower walk distance', () async {
      // Meeting at 7:00 PM (19:00) on Monday (2026-10-12 19:00:00)
      final meetingStartMs = DateTime(2026, 10, 12, 19, 0).toUtc().millisecondsSinceEpoch;

      final lateOption = JourneyOption(
        journeyId: 'j-late',
        departUtcMs: meetingStartMs - 600000,
        arriveUtcMs: meetingStartMs + 300000, // 5 min late
        walkMeters: 100,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [],
      );

      final multiTransferOption = JourneyOption(
        journeyId: 'j-multi-transfer',
        departUtcMs: meetingStartMs - 3600000,
        arriveUtcMs: meetingStartMs - 600000, // on time
        walkMeters: 200,
        transferCount: 2,
        transferConfidence: 'high',
        legs: [],
      );

      final directOptionLongWalk = JourneyOption(
        journeyId: 'j-direct-long-walk',
        departUtcMs: meetingStartMs - 2400000,
        arriveUtcMs: meetingStartMs - 900000, // on time
        walkMeters: 800,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [],
      );

      final directOptionShortWalk = JourneyOption(
        journeyId: 'j-direct-short-walk',
        departUtcMs: meetingStartMs - 2400000,
        arriveUtcMs: meetingStartMs - 900000, // on time
        walkMeters: 300,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [],
      );

      final fakeBridge = _FakeAtlasBridge(
        customOptions: [lateOption, multiTransferOption, directOptionLongWalk, directOptionShortWalk],
      );
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
        dayOfWeek: 1, // Monday
        minuteOfDay: 19 * 60,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9700,
        originLon: -93.2600,
        referenceTime: DateTime(2026, 10, 12, 17, 0),
        includeDirectWalk: false,
      );

      expect(result.isRouteAvailableInApp, isTrue);
      final ranked = result.inAppPreview!.options;
      // Best: direct short walk -> direct long walk -> multi-transfer -> late option
      expect(ranked[0].journeyId, 'j-direct-short-walk');
      expect(ranked[1].journeyId, 'j-direct-long-walk');
      expect(ranked[2].journeyId, 'j-multi-transfer');
      expect(ranked[3].journeyId, 'j-late');
    });

    test('Saint Paul physical defect scenario: direct walk dominates multi-leg Green Line detour with 2.2 km walking', () async {
      // Meeting in Cathedral Hill area of Saint Paul (Tuesday 8:30 PM)
      // Reference time: Tuesday 7:30 PM (1 hour before meeting)
      final refTime = DateTime(2026, 10, 13, 19, 30);
      final meetingStartMs = DateTime(2026, 10, 13, 20, 30).toUtc().millisecondsSinceEpoch;

      // Unnecessary Green Line detour: 2.2 km walking, 1 transfer, 38 min duration
      final greenLineDetour = JourneyOption(
        journeyId: 'green-line-detour',
        departUtcMs: meetingStartMs - 2280000, // departs 38 min before meeting
        arriveUtcMs: meetingStartMs - 600000,  // arrives 10 min before meeting
        walkMeters: 2200,                     // 2.2 km walking
        transferCount: 1,
        transferConfidence: 'high',
        legs: [
          JourneyLeg(
            mode: 'walk',
            fromLabel: 'Starting Point',
            toLabel: 'Western Ave Station',
            startUtcMs: meetingStartMs - 2280000,
            endUtcMs: meetingStartMs - 1680000,
            distanceMeters: 1000,
          ),
          JourneyLeg(
            mode: 'rail',
            fromLabel: 'Western Ave Station',
            toLabel: '10th St Station',
            startUtcMs: meetingStartMs - 1680000,
            endUtcMs: meetingStartMs - 1380000,
            routeLabel: 'METRO Green Line',
          ),
          JourneyLeg(
            mode: 'walk',
            fromLabel: '10th St Station',
            toLabel: 'Robert St Station',
            startUtcMs: meetingStartMs - 1380000,
            endUtcMs: meetingStartMs - 1200000,
            distanceMeters: 400,
          ),
          JourneyLeg(
            mode: 'rail',
            fromLabel: 'Robert St Station',
            toLabel: 'Union Depot',
            startUtcMs: meetingStartMs - 1200000,
            endUtcMs: meetingStartMs - 1000000,
            routeLabel: 'METRO Green Line',
          ),
          JourneyLeg(
            mode: 'walk',
            fromLabel: 'Union Depot',
            toLabel: 'Cathedral Hill Recovery',
            startUtcMs: meetingStartMs - 1000000,
            endUtcMs: meetingStartMs - 600000,
            distanceMeters: 800,
          ),
        ],
      );

      final fakeBridge = _FakeAtlasBridge(customOptions: [greenLineDetour]);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'sp-cathedral-01',
        name: 'Cathedral Hill Recovery',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9560,
        longitude: -93.1150,
        address: '500 Dayton Ave, Saint Paul, MN 55102',
        dayOfWeek: 2, // Tuesday
        minuteOfDay: 20 * 60 + 30, // 8:30 PM
        fetchedAtUtcMs: 1791750000000,
      );

      // Nearby origin near Boyd Park / Dayton Ave (~950m straight line, ~1.2 km walk)
      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9510,
        originLon: -93.1250,
        referenceTime: refTime,
        includeDirectWalk: true,
      );

      expect(result.isRouteAvailableInApp, isTrue);
      final ranked = result.inAppPreview!.options;
      expect(ranked.length, 2);

      // Acceptance: Direct walk option is generated and ranked #1 over the 2.2 km Green Line detour
      expect(ranked[0].journeyId, 'direct-walk');
      expect(ranked[0].isDirectWalk, isTrue);
      expect(ranked[0].walkMeters, lessThan(1500));
      expect(ranked[0].transferCount, 0);

      // Green Line detour is demoted to option 2
      expect(ranked[1].journeyId, 'green-line-detour');
      expect(ranked[1].isDirectWalk, isFalse);
    });

    test('Saint Paul scenario: transit with low walk burden (300m) and 0 transfers is preferred over 1.2 km walk', () async {
      final refTime = DateTime(2026, 10, 13, 19, 30);
      final meetingStartMs = DateTime(2026, 10, 13, 20, 30).toUtc().millisecondsSinceEpoch;

      // Convenient direct bus option with minimal walking (300m walk, 0 transfers)
      final directBusOption = JourneyOption(
        journeyId: 'direct-bus-route',
        departUtcMs: meetingStartMs - 1800000,
        arriveUtcMs: meetingStartMs - 600000,
        walkMeters: 300,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [
          JourneyLeg(
            mode: 'walk',
            fromLabel: 'Starting Point',
            toLabel: 'Selby & Mackubin',
            startUtcMs: meetingStartMs - 1800000,
            endUtcMs: meetingStartMs - 1650000,
            distanceMeters: 150,
          ),
          JourneyLeg(
            mode: 'bus',
            fromLabel: 'Selby & Mackubin',
            toLabel: 'Selby & Western',
            startUtcMs: meetingStartMs - 1650000,
            endUtcMs: meetingStartMs - 750000,
            routeLabel: 'Route 21',
          ),
          JourneyLeg(
            mode: 'walk',
            fromLabel: 'Selby & Western',
            toLabel: 'Cathedral Hill Recovery',
            startUtcMs: meetingStartMs - 750000,
            endUtcMs: meetingStartMs - 600000,
            distanceMeters: 150,
          ),
        ],
      );

      final fakeBridge = _FakeAtlasBridge(customOptions: [directBusOption]);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'sp-cathedral-01',
        name: 'Cathedral Hill Recovery',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9560,
        longitude: -93.1150,
        address: '500 Dayton Ave, Saint Paul, MN 55102',
        dayOfWeek: 2,
        minuteOfDay: 20 * 60 + 30,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9510,
        originLon: -93.1250,
        referenceTime: refTime,
        includeDirectWalk: true,
      );

      expect(result.isRouteAvailableInApp, isTrue);
      final ranked = result.inAppPreview!.options;
      expect(ranked.length, 2);

      // Transit option with 300m walk is ranked #1 (preserving accessibility)
      expect(ranked[0].journeyId, 'direct-bus-route');
      expect(ranked[1].journeyId, 'direct-walk');
    });

    test('meeting departure planning targets arrival window on scheduled meeting day, not days early', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      // Meeting is on Tuesday at 8:30 PM
      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'sp-cathedral-01',
        name: 'Cathedral Hill Recovery',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9560,
        longitude: -93.1150,
        address: '500 Dayton Ave, Saint Paul, MN 55102',
        dayOfWeek: 2, // Tuesday
        minuteOfDay: 20 * 60 + 30, // 8:30 PM (20:30)
        fetchedAtUtcMs: 1791750000000,
      );

      // Reference time is Wednesday morning 8:29 AM (nearly a week before next Tuesday)
      final wednesdayMorning = DateTime(2026, 10, 14, 8, 29);

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9510,
        originLon: -93.1250,
        referenceTime: wednesdayMorning,
        planningMode: JourneyPlanningMode.arriveBeforeMeeting,
      );

      expect(result.isRouteAvailableInApp, isTrue);
      expect(fakeBridge.lastArriveBeforeUtcMs, isNotNull);

      final arriveTarget = DateTime.fromMillisecondsSinceEpoch(fakeBridge.lastArriveBeforeUtcMs!);
      // Expected arrival target is next Tuesday at 8:15 PM (15 min buffer before 8:30 PM)
      expect(arriveTarget.weekday, DateTime.tuesday);
      expect(arriveTarget.hour, 20);
      expect(arriveTarget.minute, 15);

      final departWindow = DateTime.fromMillisecondsSinceEpoch(fakeBridge.lastDepartAtUtcMs!);
      // Transit search window is on Tuesday evening, within 90 min of target arrival
      expect(departWindow.weekday, DateTime.tuesday);
      expect(arriveTarget.difference(departWindow).inMinutes, 90);
    });

    test('repairs itinerary continuity: fixes identical origin/destination labels on walking legs', () async {
      final buggyWalkOption = JourneyOption(
        journeyId: 'j-buggy-labels',
        departUtcMs: 1791750000000,
        arriveUtcMs: 1791751800000,
        walkMeters: 1000,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [
          JourneyLeg(
            mode: 'walk',
            fromLabel: 'Western Ave Station',
            toLabel: 'Western Ave Station', // Buggy identical label
            startUtcMs: 1791750000000,
            endUtcMs: 1791751800000,
            distanceMeters: 1000,
          ),
        ],
      );

      final fakeBridge = _FakeAtlasBridge(customOptions: [buggyWalkOption]);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'sp-cathedral-01',
        name: 'Cathedral Hill Recovery',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9560,
        longitude: -93.1150,
        address: '500 Dayton Ave, Saint Paul, MN 55102',
        dayOfWeek: 2,
        minuteOfDay: 20 * 60 + 30,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9510,
        originLon: -93.1250,
        includeDirectWalk: false,
      );

      final repairedOpt = result.inAppPreview!.options.first;
      // Repaired destination label should point to the meeting destination, not identical stop
      expect(repairedOpt.legs.first.toLabel, 'Cathedral Hill Recovery');
    });

    test('deduplicates equivalent transit itineraries', () async {
      final opt1 = JourneyOption(
        journeyId: 'j-dup-1',
        departUtcMs: 1791750000000,
        arriveUtcMs: 1791751800000,
        walkMeters: 400,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [
          JourneyLeg(
            mode: 'bus',
            fromLabel: 'Stop A',
            toLabel: 'Stop B',
            startUtcMs: 1791750000000,
            endUtcMs: 1791751800000,
            routeLabel: 'Route 21',
          ),
        ],
      );

      final opt2 = JourneyOption(
        journeyId: 'j-dup-2',
        departUtcMs: 1791750000000,
        arriveUtcMs: 1791751800000,
        walkMeters: 400,
        transferCount: 0,
        transferConfidence: 'high',
        legs: [
          JourneyLeg(
            mode: 'bus',
            fromLabel: 'Stop A',
            toLabel: 'Stop B',
            startUtcMs: 1791750000000,
            endUtcMs: 1791751800000,
            routeLabel: 'Route 21',
          ),
        ],
      );

      final fakeBridge = _FakeAtlasBridge(customOptions: [opt1, opt2]);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'sp-cathedral-01',
        name: 'Cathedral Hill Recovery',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9560,
        longitude: -93.1150,
        address: '500 Dayton Ave, Saint Paul, MN 55102',
        dayOfWeek: 2,
        minuteOfDay: 20 * 60 + 30,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: 44.9510,
        originLon: -93.1250,
        includeDirectWalk: false,
      );

      expect(result.inAppPreview!.options.length, 1);
    });

    test('synthetic meeting record is rejected from physical routing', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const syntheticMeeting = MeetingDestination(
        sourceId: 'mock_test_directory',
        sourceMeetingId: 'synth_1',
        name: 'Synthetic Recovery Meeting',
        fellowship: 'AA',
        meetingType: 'Discussion',
        latitude: 44.9778,
        longitude: -93.2650,
        address: '123 Fake St, Minneapolis',
        isSynthetic: true,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: syntheticMeeting,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNull);
      expect(result.statusMessage, contains('synthetic'));
    });

    test('online only meeting is rejected with video conference explanation', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const onlineMeeting = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'zoom_01',
        name: 'Online Sobriety Group',
        fellowship: 'AA',
        meetingType: 'Online',
        latitude: 0.0,
        longitude: 0.0,
        address: '',
        conferenceUrl: 'https://zoom.us/j/123456789',
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: onlineMeeting,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNull);
      expect(result.statusMessage, contains('online via video conference'));
    });

    test('missing origin coordinates returns graceful explanation without assuming Minneapolis', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: '101',
        name: 'Downtown AA Group',
        fellowship: 'AA',
        meetingType: 'Open',
        latitude: 44.9778,
        longitude: -93.2650,
        address: '100 S 5th St, Minneapolis',
        dayOfWeek: 2,
        minuteOfDay: 12 * 60,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: destination,
        originLat: null,
        originLon: null,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNotNull);
      expect(result.statusMessage, contains('Starting location not set'));
    });

    test('destination outside Metro Transit coverage is detected and reports coverage boundary', () async {
      final fakeBridge = _FakeAtlasBridge(simulateSdkInstalled: true);
      final repo = NavigatorRepository(bridge: fakeBridge);
      final planner = MeetingJourneyPlanner(repository: repo);

      const duluthMeeting = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'duluth-01',
        name: 'Duluth Lakeside Fellowship',
        fellowship: 'AA',
        meetingType: 'Discussion',
        latitude: 46.7867, // Duluth is outside Metro Transit service bounds
        longitude: -92.1005,
        address: 'Duluth, MN',
        dayOfWeek: 2,
        minuteOfDay: 18 * 60,
        fetchedAtUtcMs: 1791750000000,
      );

      final result = await planner.planJourneyForMeeting(
        destination: duluthMeeting,
        originLat: 44.9700,
        originLon: -93.2600,
      );

      expect(result.isRouteAvailableInApp, isFalse);
      expect(result.inAppPreview, isNull);
      expect(result.fallbackExternalDirectionsUrl, isNotNull);
      expect(result.statusMessage, contains('outside the Metro Transit regional service area'));
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
