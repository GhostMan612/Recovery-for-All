// test/navigator/meeting_map_screen_walking_correction_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_journey_planner.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_schedule_resolver.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_bridge.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_dtos.dart';
import 'package:recovery_for_all/features/navigator/data/navigator_repository.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';
import 'package:recovery_for_all/features/navigator/ui/widgets/journey_sheet.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/screens/meeting_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SlowCancelableAtlasBridge extends AtlasBridge {
  final List<String> plannedRequestIds = [];
  final List<String> canceledRequestIds = [];
  final Map<String, Completer<JourneyPreview>> _pending = {};

  @override
  Future<AtlasCapabilities> getCapabilities({int apiVersion = AtlasBridge.currentApiVersion}) async =>
      const AtlasCapabilities(
        version: 1,
        staticTransit: true,
        localRouting: true,
        realtime: false,
        weather: false,
        offlineSnapshot: true,
        providerIds: ['atlas_static_planner'],
      );

  @override
  Future<AtlasOfflineStatus> getOfflineStatus({
    String feedId = 'default',
    int apiVersion = AtlasBridge.currentApiVersion,
  }) async =>
      const AtlasOfflineStatus(
        staticNetwork: 'ready',
        basemap: 'cached_tiles',
        routing: 'ready',
        notes: 'ready',
      );

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
    int? timeoutMs,
    int apiVersion = AtlasBridge.currentApiVersion,
  }) {
    plannedRequestIds.add(requestId);
    final completer = Completer<JourneyPreview>();
    _pending[requestId] = completer;
    return completer.future;
  }

  @override
  Future<bool> cancelRequest({
    required String requestId,
    int apiVersion = AtlasBridge.currentApiVersion,
  }) async {
    canceledRequestIds.add(requestId);
    final pending = _pending.remove(requestId);
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        AtlasException(
          code: AtlasErrorCode.canceled,
          message: 'Journey request was canceled',
          details: {'requestId': requestId},
        ),
      );
      return true;
    }
    return false;
  }
}

void main() {
  final sampleMeeting = RecoveryMeeting(
    id: 'tsml_aa_minnesota:mtg-f2-corr',
    name: 'Summit Hill Step Group',
    fellowship: 'AA',
    address: '1000 Summit Ave, Saint Paul, MN',
    type: 'Step Study',
    time: '7:30 PM',
    day: 2, // Tuesday
    minutes: 19 * 60 + 30,
    latitude: 44.9400,
    longitude: -93.1400,
  );

  final sampleDirectWalkOption = JourneyOption(
    journeyId: 'direct-walk',
    departUtcMs: 1791750000000,
    arriveUtcMs: 1791751200000,
    walkMeters: 1200,
    transferCount: 0,
    transferConfidence: 'direct_walk',
    legs: [
      JourneyLeg(
        mode: 'walk',
        fromLabel: 'Starting Point',
        toLabel: 'Summit Hill Step Group',
        startUtcMs: 1791750000000,
        endUtcMs: 1791751200000,
        routeLabel: 'Estimated Distance (No street routing)',
        distanceMeters: 1200,
        fromLat: 44.9450,
        fromLon: -93.1500,
        toLat: 44.9400,
        toLon: -93.1400,
      ),
    ],
  );

  group('MeetingMapScreen Walking Correction Tests (F2)', () {
    testWidgets('JourneySheet displays estimated distance badge and mode selection buttons', (tester) async {
      const destination = MeetingDestination(
        sourceId: 'tsml_aa_minnesota',
        sourceMeetingId: 'mtg-f2-corr',
        name: 'Summit Hill Step Group',
        fellowship: 'AA',
        meetingType: 'Step Study',
        latitude: 44.9400,
        longitude: -93.1400,
        address: '1000 Summit Ave, Saint Paul, MN',
        fetchedAtUtcMs: 1791750000000,
      );

      final planResult = PlannedMeetingJourneyResult(
        destination: destination,
        schedule: const ScheduleResolutionResult(
          status: MeetingScheduleStatus.scheduled,
          minutesUntil: 45,
          statusDescription: 'Tuesday at 7:30 PM',
        ),
        inAppPreview: JourneyPreview(
          version: 1,
          requestId: 'req-walk-corr-01',
          meetingId: destination.compositeId,
          providerId: 'atlas_pedestrian_planner',
          dataSource: 'direct_walk_estimate',
          isSynthetic: false,
          fetchedAtUtcMs: 1791750000000,
          freshness: 'fresh',
          options: [sampleDirectWalkOption],
        ),
        fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=44.94,-93.14',
        isRouteAvailableInApp: true,
        statusMessage: 'In-app route planned successfully.',
      );

      String? launchedMode;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: JourneySheet(
              planResult: planResult,
              onLaunchModeDirections: (mode) => launchedMode = mode,
              onLaunchExternalDirections: () => launchedMode = 'default',
            ),
          ),
        ),
      );

      // Verify estimated distance badge without fake route claims
      expect(find.text('Estimated Distance'), findsOneWidget);
      expect(find.textContaining('1.2 km (straight-line estimate)'), findsOneWidget);
      expect(find.textContaining('No walking polyline drawn'), findsOneWidget);

      // Verify explicit travel mode buttons
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Transit'), findsOneWidget);
      expect(find.text('Driving'), findsOneWidget);
      expect(find.text('Open External Directions (Google Maps)'), findsOneWidget);

      // Tap Driving
      await tester.tap(find.text('Driving'));
      await tester.pump();
      expect(launchedMode, 'driving');

      // Tap Transit
      await tester.tap(find.text('Transit'));
      await tester.pump();
      expect(launchedMode, 'transit');

      // Tap Walking
      await tester.tap(find.text('Walking'));
      await tester.pump();
      expect(launchedMode, 'walking');
    });

    testWidgets('MeetingMapScreen never draws walking polyline and renders origin/destination markers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MeetingMapScreen(
              initialMeetings: [sampleMeeting],
            ),
          ),
        ),
      );

      // Advance initial loading frames without indefinite settling
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to map view if list is shown
      final toggleViewButton = find.byTooltip('Show map');
      if (toggleViewButton.evaluate().isNotEmpty) {
        await tester.tap(toggleViewButton);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Verify that PolylineLayer does not contain any fabricated walking polyline
      final polylineLayers = tester.widgetList<PolylineLayer>(find.byType(PolylineLayer));
      for (final layer in polylineLayers) {
        expect(layer.polylines.isEmpty, isTrue);
      }
    });

    testWidgets('MeetingMapScreen cancels active request idempotently across Close, swipe, Back, and dispose', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final bridge = _SlowCancelableAtlasBridge();
      final planner = MeetingJourneyPlanner(
        repository: NavigatorRepository(bridge: bridge),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MeetingMapScreen(
              initialMeetings: [sampleMeeting],
              initialUserPosition: const (44.9450, -93.1500),
              journeyPlanner: planner,
            ),
          ),
        ),
      );
      await tester.pump();

      Future<void> openInFlightSheet() async {
        await tester.tap(find.text('Summit Hill Step Group'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get Directions'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Planning transit route…'), findsOneWidget);
      }

      // 1. Dismiss via Close (X) button.
      await openInFlightSheet();
      expect(bridge.plannedRequestIds, hasLength(1));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(bridge.canceledRequestIds, [bridge.plannedRequestIds[0]]);
      expect(find.text('Planning transit route…'), findsNothing);

      // 2. Dismiss via swipe down.
      await openInFlightSheet();
      expect(bridge.plannedRequestIds, hasLength(2));
      await tester.fling(find.byTooltip('Close'), const Offset(0, 400), 800.0);
      await tester.pumpAndSettle();
      expect(find.text('Planning transit route…'), findsNothing);
      expect(bridge.canceledRequestIds, [
        bridge.plannedRequestIds[0],
        bridge.plannedRequestIds[1],
      ]);

      // 3. Dismiss via system Back pop.
      await openInFlightSheet();
      expect(bridge.plannedRequestIds, hasLength(3));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Planning transit route…'), findsNothing);
      expect(bridge.canceledRequestIds, [
        bridge.plannedRequestIds[0],
        bridge.plannedRequestIds[1],
        bridge.plannedRequestIds[2],
      ]);

      // 4. Parent widget dispose while request is active.
      await openInFlightSheet();
      expect(bridge.plannedRequestIds, hasLength(4));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.canceledRequestIds, [
        bridge.plannedRequestIds[0],
        bridge.plannedRequestIds[1],
        bridge.plannedRequestIds[2],
        bridge.plannedRequestIds[3],
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}
