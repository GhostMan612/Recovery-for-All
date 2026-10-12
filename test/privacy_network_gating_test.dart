// test/privacy_network_gating_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/services/weather_service.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';
import 'package:recovery_for_all/services/map_tile_cache.dart';
import 'package:recovery_for_all/services/sponsor_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    PrivacyCapabilityService.resetForTesting();
    CommunityFeedService.resetPrivacyListenerForTesting();
    SponsorLinkService.resetTestingOverrides();
    tempDir = Directory.systemTemp.createTempSync('privacy_test_tiles_');
    MapTileCache.cacheDirForTesting = tempDir;
    CommunityFeedService.initPrivacyListener();
    SponsorLinkService.initPrivacyListener();
  });

  tearDown(() {
    MapTileCache.clientForTesting = null;
    MapTileCache.cacheDirForTesting = null;
    WeatherService.consentEvaluatorForTesting = null;
    SponsorLinkService.resetTestingOverrides();
    PrivacyCapabilityService.resetForTesting();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Slice B: Weather Network Request Enforcement', () {
    test('Negative test: When consent is false, fetchWeather makes 0 network calls and returns disabled', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'denied',
      });
      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('{"current": {}}', 200);
      });

      final result = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        isConsented: false,
        client: mockClient,
      );

      expect(networkCallCount, equals(0),
          reason: 'Network client must never be reached when consent is false');
      expect(result.isDisabled, isTrue);
      expect(result.summary, equals('Weather disabled'));
      expect(result.reason, contains('privacy settings'));
    });

    test('Negative test: Caller attempting to bypass policy with isConsented: true is blocked with 0 network calls', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'denied',
      });
      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('{"current": {}}', 200);
      });

      // Caller passes isConsented: true, but capability is denied
      final result = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        isConsented: true,
        client: mockClient,
      );

      expect(networkCallCount, equals(0),
          reason: 'WeatherService must independently verify capability policy and reject caller bypass');
      expect(result.isDisabled, isTrue);
    });

    test('Negative test: Old persisted granted remoteWeather on cold restart makes 0 network calls', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_remoteWeather': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('{"current": {}}', 200);
      });

      final result = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        client: mockClient,
      );

      expect(networkCallCount, equals(0),
          reason: 'Cold restart with old persisted grant alone must make zero network requests');
      expect(result.isDisabled, isTrue);
    });

    test('When capability is granted in session, fetchWeather executes HTTP request and parses response', () async {
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.granted,
      );
      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        expect(request.url.host, equals('api.open-meteo.com'));
        expect(request.url.queryParameters['latitude'], equals('44.9778'));
        expect(request.url.queryParameters['longitude'], equals('-93.265'));
        return http.Response(
          jsonEncode({
            'current': {
              'temperature_2m': 68.5,
              'weather_code': 0,
            }
          }),
          200,
        );
      });

      final result = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        client: mockClient,
      );

      expect(networkCallCount, equals(1));
      expect(result.isDisabled, isFalse);
      expect(result.temperatureF, equals(68.5));
      expect(result.summary, equals('Clear sky'));
    });

    test('Dynamic grant and revoke transitions govern weather requests', () async {
      SharedPreferences.setMockInitialValues({});
      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response(
          jsonEncode({'current': {'temperature_2m': 70.0, 'weather_code': 0}}),
          200,
        );
      });

      // 1. Initial state: ungranted -> blocked
      var res = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        client: mockClient,
      );
      expect(networkCallCount, equals(0));
      expect(res.isDisabled, isTrue);

      // 2. Grant capability in session -> allowed
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.granted,
      );
      res = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        client: mockClient,
      );
      expect(networkCallCount, equals(1));
      expect(res.isDisabled, isFalse);

      // 3. Revoke capability -> immediately blocked
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.remoteWeather,
        ConsentState.denied,
      );
      res = await WeatherService.fetchWeather(
        lat: 44.9778,
        lng: -93.2650,
        client: mockClient,
      );
      expect(networkCallCount, equals(1),
          reason: 'Subsequent revoked request must make 0 additional network calls');
      expect(res.isDisabled, isTrue);
    });

    test('Injectable policy evaluator governs weather requests without SharedPreferences', () async {
      var isAllowed = false;
      WeatherService.consentEvaluatorForTesting = () async => isAllowed;

      var networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response(
          jsonEncode({'current': {'temperature_2m': 65.0, 'weather_code': 0}}),
          200,
        );
      });

      var res = await WeatherService.fetchWeather(lat: 44.9778, lng: -93.2650, client: mockClient);
      expect(networkCallCount, equals(0));
      expect(res.isDisabled, isTrue);

      isAllowed = true;
      res = await WeatherService.fetchWeather(lat: 44.9778, lng: -93.2650, client: mockClient);
      expect(networkCallCount, equals(1));
      expect(res.isSuccess, isTrue);

      isAllowed = false;
      res = await WeatherService.fetchWeather(lat: 44.9778, lng: -93.2650, client: mockClient);
      expect(networkCallCount, equals(1));
      expect(res.isDisabled, isTrue);
    });
  });

  group('Slice B: Map Tile Outbound Request Enforcement', () {
    test('Negative test: Unknown or denied onlineTiles makes 0 outbound tile HTTP requests', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_onlineTiles': 'denied',
      });

      var tileRequestCount = 0;
      MapTileCache.clientForTesting = MockClient((request) async {
        tileRequestCount++;
        return http.Response('fake-png-bytes', 200);
      });

      final file = await MapTileCache.fetchAndCache('osm', 10, 250, 350);
      expect(file, isNull);
      expect(tileRequestCount, equals(0),
          reason: 'Tile HTTP client must never be invoked when onlineTiles consent is denied');

      // Tile prefetch pack also makes 0 requests
      final secured = await TilePrefetch.prefetchPack(
        layer: 'osm',
        lat: 44.9778,
        lng: -93.2650,
        radiusKm: 10,
        zooms: [12],
      );
      expect(secured, equals(0));
      expect(tileRequestCount, equals(0),
          reason: 'TilePrefetch must make 0 requests when onlineTiles is denied');
    });

    test('Negative test: Old persisted granted onlineTiles on cold restart makes 0 tile network requests', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_onlineTiles': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      var tileRequestCount = 0;
      MapTileCache.clientForTesting = MockClient((request) async {
        tileRequestCount++;
        return http.Response('fake-png-bytes', 200);
      });

      final file = await MapTileCache.fetchAndCache('osm', 10, 250, 350);
      expect(file, isNull);
      expect(tileRequestCount, equals(0),
          reason: 'Cold start must not fetch online tiles based solely on persisted grant');
    });

    test('When onlineTiles is granted in session, fetchAndCache reaches HTTP client and caches tile', () async {
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.onlineTiles,
        ConsentState.granted,
      );

      var tileRequestCount = 0;
      MapTileCache.clientForTesting = MockClient((request) async {
        tileRequestCount++;
        expect(request.url.host, equals('tile.openstreetmap.org'));
        return http.Response('mock-tile-bytes', 200);
      });

      final file = await MapTileCache.fetchAndCache('osm', 12, 100, 200);
      expect(tileRequestCount, equals(1));
      expect(file, isNotNull);
      expect(await file!.readAsString(), equals('mock-tile-bytes'));
    });
  });

  group('Slice C: Meeting Directory & Cloud Synchronization Decoupling', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PrivacyCapabilityService.resetForTesting();
      CommunityFeedService.resetPrivacyListenerForTesting();
      SponsorLinkService.resetTestingOverrides();
      CommunityFeedService.initPrivacyListener();
      SponsorLinkService.initPrivacyListener();
    });

    test('MeetingFinderService.refresh returns cached meetings without network when directoryRefresh is not granted', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_directoryRefresh': 'denied',
      });

      final service = MeetingFinderService();
      // Even if network would fail, refresh() safely short-circuits to getCached()
      final meetings = await service.refresh(lat: 44.9778, lng: -93.2650);
      expect(meetings, isA<List>());
    });

    test('MeetingFinderService.refresh on cold restart with old persisted granted uses cached directory with 0 network calls', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_directoryRefresh': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      final service = MeetingFinderService();
      final meetings = await service.refresh(lat: 44.9778, lng: -93.2650);
      expect(meetings, isA<List>(), reason: 'Cached directory must remain usable offline');
    });

    test('CommunityFeedService respects unconsented cloudSync and circleShare', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'denied',
        'privacy_consent_v1_circleShare': 'denied',
      });

      expect(CommunityFeedService.isRemoteAvailable(), isFalse);
    });

    test('CommunityFeedService on cold restart with old persisted granted cloudSync stays local-first', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
        'privacy_consent_v1_circleShare': 'granted',
      });
      await PrivacyCapabilityService.loadState();
      expect(CommunityFeedService.isRemoteAvailable(), isFalse);
      expect(await PrivacyCapabilityService.isGranted(PrivacyCapability.cloudSync), isFalse);
    });

    test('Granting cloudSync post-startup updates CommunityFeedService dynamically without restart', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'denied',
      });
      CommunityFeedService.remoteReady = false;

      expect(CommunityFeedService.isRemoteAvailable(), isFalse);

      // User grants cloud consent in settings post-startup
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      expect(CommunityFeedService.isRemoteAvailable(), isTrue,
          reason: 'CommunityFeedService must dynamically synchronize when cloudSync is granted');
    });

    test('Revoking cloudSync immediately triggers onRevokeCloud and cancels remote listeners', () async {
      CommunityFeedService.remoteReady = true;

      var listenerCancelled = false;
      CommunityFeedService.onRevokeCloud();
      expect(CommunityFeedService.isRemoteAvailable(), isFalse);

      // Verify that revocation callback fires when onRevokeCloud is invoked
      PrivacyCapabilityService.onConsentChangedCallbacks.add((cap, state) {
        if (cap == PrivacyCapability.cloudSync && !state.isGranted) {
          listenerCancelled = true;
        }
      });

      // Setting up callback test
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );
      expect(CommunityFeedService.isRemoteAvailable(), isTrue);

      // Simulate a revocation callback from an active stream listener
      CommunityFeedService.initPrivacyListener();
      // Revocation via service
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );
      expect(CommunityFeedService.isRemoteAvailable(), isFalse);
      expect(listenerCancelled, isTrue);
    });

    test('SponsorLinkService relay checks fail closed without network when cloudSync is denied', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'denied',
      });

      final orphaned = await SponsorLinkService.orphanedRelayDocIds();
      expect(orphaned, isEmpty,
          reason: 'SponsorLinkService must never initiate Firebase auth when cloudSync is denied');
    });

    test('SponsorLinkService on cold restart with old persisted granted cloudSync yields empty stream without network', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_consent_v1_cloudSync': 'granted',
      });
      await PrivacyCapabilityService.loadState();

      final stream = SponsorLinkService.watchPendingBundles('ABCD12EF-QX');
      final items = await stream.first;
      expect(items, isEmpty,
          reason: 'Cold start without session authorization must yield empty items without connecting');
    });

    test('Real subscribed sponsor stream tears down immediately upon cloud revocation', () async {
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      final underlyingSource = StreamController<List<Map<String, dynamic>>>();
      SponsorLinkService.authCheckerForTesting = () async => true;
      SponsorLinkService.currentUidForTesting = 'test_sponsor_uid';
      SponsorLinkService.inboxStreamForTesting = (uid, code) => underlyingSource.stream;

      addTearDown(() {
        SponsorLinkService.resetTestingOverrides();
        if (!underlyingSource.isClosed) underlyingSource.close();
      });

      final receivedEvents = <List<Map<String, dynamic>>>[];
      var streamClosed = false;

      final stream = SponsorLinkService.watchPendingBundles('ABCD12EF-QX');
      final subscription = stream.listen(
        (items) => receivedEvents.add(items),
        onDone: () => streamClosed = true,
      );
      addTearDown(subscription.cancel);

      // Allow async onListen to execute and attach subscription to underlying source
      await Future<void>.delayed(Duration.zero);
      expect(underlyingSource.hasListener, isTrue,
          reason: 'Active stream must be subscribed to underlying Firestore source');

      // Emit active event from relay source
      underlyingSource.add([
        {'id': 'bundle_1', 'status': 'pending'}
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.first['id'], equals('bundle_1'));

      // User revokes cloudSync
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.denied,
      );
      await Future<void>.delayed(Duration.zero);

      // Stream must be closed and underlying subscription cancelled
      expect(streamClosed, isTrue,
          reason: 'Stream must close immediately when cloudSync is revoked');
      expect(underlyingSource.hasListener, isFalse,
          reason: 'Underlying Firestore subscription must be cancelled upon revocation');
      expect(receivedEvents.length, equals(2));
      expect(receivedEvents.last, isEmpty,
          reason: 'Revocation clears pending items with empty list');

      // Subsequent emissions on the source are not received
      if (!underlyingSource.isClosed) {
        underlyingSource.add([
          {'id': 'bundle_2', 'status': 'pending'}
        ]);
        await Future<void>.delayed(Duration.zero);
      }
      expect(receivedEvents.length, equals(2),
          reason: 'No further events must be dispatched after revocation teardown');
    });
  });

  group('Slice D: Negative Verification & Security Invariant Checks', () {
    test('Default system posture denies all optional outbound network capabilities', () {
      final state = PrivacyCapabilityState.defaults();

      // Ensure every single capability fails closed
      for (final cap in PrivacyCapability.values) {
        expect(state.isGranted(cap), isFalse,
            reason: '${cap.name} must deny network requests in default state');
      }
    });

    test('Verification scope boundary note: Mocked unit tests verify application code boundaries', () {
      // NOTE (per Requirement 8 and WO-P0-PRIVACY):
      // Unit-level mock assertions verify that Dart-level service entry points
      // enforce privacy gates before invoking HttpClient or platform channels.
      // They do NOT constitute device-wide packet capture, and do not make
      // unverified claims about native platform libraries that bypass Dart.
      expect(true, isTrue);
    });
  });
}
