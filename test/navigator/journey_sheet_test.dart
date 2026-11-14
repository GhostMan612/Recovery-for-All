// test/navigator/journey_sheet_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_journey_planner.dart';
import 'package:recovery_for_all/features/navigator/application/meeting_schedule_resolver.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_dtos.dart';
import 'package:recovery_for_all/features/navigator/domain/meeting_destination.dart';
import 'package:recovery_for_all/features/navigator/ui/widgets/journey_sheet.dart';
import 'package:recovery_for_all/features/navigator/ui/widgets/journey_weather_card.dart';

void main() {
  const sampleDestination = MeetingDestination(
    sourceId: 'tsml_aa_minnesota',
    sourceMeetingId: 'alano_1',
    name: 'Minneapolis Alano Club',
    fellowship: 'AA',
    meetingType: 'Open',
    latitude: 44.9606,
    longitude: -93.2778,
    address: '2218 1st Ave S, Minneapolis, MN 55404',
    dayOfWeek: 6,
    minuteOfDay: 11 * 60,
    fetchedAtUtcMs: 1791750000000,
  );

  final sampleSchedule = ScheduleResolutionResult(
    status: MeetingScheduleStatus.scheduled,
    nextOccurrence: DateTime.fromMillisecondsSinceEpoch(1791753000000, isUtc: true),
    minutesUntil: 50,
    statusDescription: 'Saturday at 11:00 AM',
  );

  testWidgets('JourneySheet renders transit legs, walk distance, and route labels', (tester) async {
    final preview = JourneyPreview(
      version: 1,
      requestId: 'req-real-slice-01',
      meetingId: sampleDestination.compositeId,
      providerId: 'atlas_static_planner',
      dataSource: 'static_gtfs',
      isSynthetic: false,
      fetchedAtUtcMs: 1791750000000,
      freshness: 'fresh',
      options: [
        JourneyOption(
          journeyId: 'j-slice-01',
          departUtcMs: 1791750000000,
          arriveUtcMs: 1791751800000,
          walkMeters: 480,
          transferCount: 0,
          transferConfidence: 'high',
          legs: [
            JourneyLeg(
              mode: 'walk',
              fromLabel: 'Origin',
              toLabel: 'Nicollet Ave S & 5th St',
              startUtcMs: 1791750000000,
              endUtcMs: 1791750240000,
              distanceMeters: 220,
            ),
            JourneyLeg(
              mode: 'bus',
              fromLabel: 'Nicollet Ave S & 5th St',
              toLabel: 'Nicollet Ave S & 24th St E',
              startUtcMs: 1791750300000,
              endUtcMs: 1791751500000,
              routeLabel: 'Route 18',
            ),
            JourneyLeg(
              mode: 'walk',
              fromLabel: 'Nicollet Ave S & 24th St E',
              toLabel: 'Minneapolis Alano Club',
              startUtcMs: 1791751500000,
              endUtcMs: 1791751800000,
              distanceMeters: 260,
            ),
          ],
        ),
      ],
    );

    final planResult = PlannedMeetingJourneyResult(
      destination: sampleDestination,
      schedule: sampleSchedule,
      inAppPreview: preview,
      fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=2218%201st%20Ave%20S',
      isRouteAvailableInApp: true,
      statusMessage: 'In-app transit route planned successfully.',
    );

    JourneyOption? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: planResult,
            onSelectOption: (opt) => selected = opt,
          ),
        ),
      ),
    );

    expect(find.text('Minneapolis Alano Club'), findsOneWidget);
    expect(find.textContaining('Saturday at 11:00 AM'), findsOneWidget);
    expect(find.text('Available Transit Routes'), findsOneWidget);
    expect(find.text('Scheduled times \u2022 Not live GPS'), findsOneWidget);
    expect(find.textContaining('3 legs'), findsOneWidget);
    expect(find.textContaining('0.5 km walk'), findsOneWidget);
    expect(find.textContaining('Route 18'), findsOneWidget);
    expect(find.textContaining('Arrives 20 min before meeting (on time)'), findsOneWidget);
    expect(find.text('Open External Directions (Google Maps)'), findsOneWidget);

    // Tap preview on map
    await tester.tap(find.text('Preview on Map'));
    expect(selected, isNotNull);
    expect(selected!.journeyId, 'j-slice-01');
  });

  testWidgets('JourneySheet displays fallback message when routing is unavailable', (tester) async {
    final fallbackResult = PlannedMeetingJourneyResult(
      destination: sampleDestination,
      schedule: sampleSchedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=2218%201st%20Ave%20S',
      isRouteAvailableInApp: false,
      statusMessage: 'Local transit routing unavailable: location is outside the Metro Transit regional service area. External navigation available.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: fallbackResult,
          ),
        ),
      ),
    );

    expect(find.text('Minneapolis Alano Club'), findsOneWidget);
    expect(find.text('Local transit routing unavailable: location is outside the Metro Transit regional service area. External navigation available.'), findsOneWidget);
    expect(find.text('Open External Directions (Google Maps)'), findsOneWidget);
  });

  testWidgets('JourneySheet displays cached schedule badge and manual origin button when location not set', (tester) async {
    const staleDestination = MeetingDestination(
      sourceId: 'tsml_aa_minnesota',
      sourceMeetingId: 'alano_1',
      name: 'Minneapolis Alano Club',
      fellowship: 'AA',
      meetingType: 'Open',
      latitude: 44.9606,
      longitude: -93.2778,
      address: '2218 1st Ave S, Minneapolis, MN 55404',
      dayOfWeek: 6,
      minuteOfDay: 11 * 60,
      sourceFreshness: 'stale',
      fetchedAtUtcMs: 1791750000000,
    );

    const staleSchedule = ScheduleResolutionResult(
      status: MeetingScheduleStatus.scheduled,
      minutesUntil: 4320,
      statusDescription: 'Saturday at 11:00 AM (cached)',
      isStaleSchedule: true,
    );

    final staleResult = PlannedMeetingJourneyResult(
      destination: staleDestination,
      schedule: staleSchedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=2218%201st%20Ave%20S',
      isRouteAvailableInApp: false,
      statusMessage: 'Starting location not set. Enable GPS or choose a starting point to plan transit routes.',
    );

    var manualOriginTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: staleResult,
            onSelectManualOrigin: () => manualOriginTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Minneapolis Alano Club'), findsOneWidget);
    expect(find.textContaining('(cached)'), findsOneWidget);
    expect(find.text('Starting location not set. Enable GPS or choose a starting point to plan transit routes.'), findsOneWidget);
    expect(find.text('Choose Starting Point'), findsOneWidget);

    await tester.tap(find.text('Choose Starting Point'));
    expect(manualOriginTapped, isTrue);
  });

  testWidgets('JourneySheet renders weather card with temperature and source', (tester) async {
    final weatherData = JourneyWeatherData(
      temperatureFahrenheit: 68.4,
      conditionSummary: 'Partly Cloudy',
      source: 'Open-Meteo',
      fetchedAt: DateTime.now(),
    );

    final planResult = PlannedMeetingJourneyResult(
      destination: sampleDestination,
      schedule: sampleSchedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: null,
      isRouteAvailableInApp: false,
      statusMessage: 'No route available.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: planResult,
            weather: weatherData,
          ),
        ),
      ),
    );

    expect(find.textContaining('Partly Cloudy'), findsOneWidget);
    expect(find.textContaining('68°F'), findsOneWidget);
    expect(find.textContaining('Open-Meteo'), findsOneWidget);
  });

  testWidgets('JourneySheet surfaces Choose Starting Point on stop-coverage walk fallback and Settings button on FEED_EXPIRED', (tester) async {
    final walkOnlyOption = JourneyOption(
      journeyId: 'direct-walk',
      departUtcMs: 1791750000000,
      arriveUtcMs: 1791750900000,
      walkMeters: 900,
      transferCount: 0,
      transferConfidence: 'direct_walk',
      legs: const [
        JourneyLeg(
          mode: 'walk',
          fromLabel: 'Starting Point',
          toLabel: 'Minneapolis Alano Club',
          startUtcMs: 1791750000000,
          endUtcMs: 1791750900000,
          distanceMeters: 900,
        ),
      ],
    );

    final coverageWalkResult = PlannedMeetingJourneyResult(
      destination: sampleDestination,
      schedule: sampleSchedule,
      inAppPreview: JourneyPreview(
        version: 1,
        requestId: 'req-cov-1',
        meetingId: sampleDestination.compositeId,
        providerId: 'atlas_pedestrian_fallback',
        dataSource: 'direct_walk_estimate',
        isSynthetic: false,
        fetchedAtUtcMs: 1791750000000,
        freshness: 'fresh',
        options: [walkOnlyOption],
      ),
      fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=44.9606,-93.2778',
      isRouteAvailableInApp: true,
      statusMessage: 'No covered Metro Transit stop found within 1.5 km of your starting point. Showing estimated direct walk distance only — this is not a transit itinerary.',
      failureCode: AtlasErrorCode.noItinerary,
      canChooseManualOrigin: true,
    );

    var choseOrigin = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: coverageWalkResult,
            onSelectManualOrigin: () => choseOrigin = true,
          ),
        ),
      ),
    );

    expect(find.text('Available Routes (Walk Only)'), findsOneWidget);
    expect(find.textContaining('within 1.5 km'), findsOneWidget);
    expect(find.text('Choose Starting Point'), findsOneWidget);
    await tester.tap(find.text('Choose Starting Point'));
    expect(choseOrigin, isTrue);

    final expiredResult = PlannedMeetingJourneyResult(
      destination: sampleDestination,
      schedule: sampleSchedule,
      inAppPreview: null,
      fallbackExternalDirectionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=44.9606,-93.2778',
      isRouteAvailableInApp: false,
      statusMessage: 'The Metro Transit schedule expired on 2026-11-27. External navigation available.',
      failureCode: AtlasErrorCode.feedExpired,
    );

    var openedSettings = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JourneySheet(
            planResult: expiredResult,
            onOpenFeedSettings: () => openedSettings = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    expect(find.text('Refresh Schedule in Settings'), findsOneWidget);
    await tester.tap(find.text('Refresh Schedule in Settings'));
    expect(openedSettings, isTrue);
  });
}
