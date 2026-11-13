// test/navigator/street_routing_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recovery_for_all/features/navigator/application/street_route_provider.dart';
import 'package:recovery_for_all/features/navigator/domain/street_route.dart';
import 'package:recovery_for_all/features/navigator/ui/widgets/street_route_preview_sheet.dart';

void main() {
  group('StreetRoute Domain Models', () {
    test('StreetRoute formats distance and duration correctly', () {
      final route = StreetRoute(
        mode: StreetRouteMode.walking,
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        geometry: const [(44.9490, -93.1186), (44.9515, -93.1255)],
        totalDistanceMeters: 805, // ~0.50 mi
        estimatedDurationSeconds: 600, // 10 min
        maneuvers: const [
          StreetManeuver(
            instruction: 'Walk north on Western Ave N',
            distanceMeters: 400,
            durationSeconds: 300,
            latitude: 44.9490,
            longitude: -93.1186,
            type: StreetManeuverType.depart,
            streetName: 'Western Ave N',
          ),
          StreetManeuver(
            instruction: 'Arrive at Hope on the Horizon',
            distanceMeters: 0,
            durationSeconds: 0,
            latitude: 44.9515,
            longitude: -93.1255,
            type: StreetManeuverType.arrive,
          ),
        ],
        providerId: 'test_provider',
        dataSource: 'synthetic_fixture',
        isVerifiedGeometry: true,
        fetchedAtUtcMs: 1728900000000,
      );

      expect(route.distanceMiles, closeTo(0.50, 0.01));
      expect(route.durationMinutes, 10);
      expect(route.formattedDistance, '0.5 mi');
      expect(route.formattedDuration, '10 min');
      expect(route.isVerifiedGeometry, isTrue);
      expect(route.maneuvers.length, 2);
      expect(route.maneuvers.first.formattedDistance, '0.2 mi');
    });

    test('StreetRoute unverified geometry flags correctly', () {
      const route = StreetRoute(
        mode: StreetRouteMode.driving,
        originLat: 44.0,
        originLon: -93.0,
        destinationLat: 44.1,
        destinationLon: -93.1,
        geometry: [],
        totalDistanceMeters: 0,
        estimatedDurationSeconds: 0,
        maneuvers: [],
        providerId: 'unverified',
        dataSource: 'offline',
        isVerifiedGeometry: false,
        fetchedAtUtcMs: 0,
      );

      expect(route.isVerifiedGeometry, isFalse);
      expect(route.geometry.isEmpty, isTrue);
    });
  });

  group('PolylineDecoder', () {
    test('Decodes precision 5 polyline correctly', () {
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = PolylineDecoder.decode(encoded, precision: 5);
      expect(points.length, 3);
      expect(points[0].$1, closeTo(38.5, 0.1));
      expect(points[0].$2, closeTo(-120.2, 0.1));
    });

    test('Handles empty and invalid polyline strings safely', () {
      expect(PolylineDecoder.decode(''), isEmpty);
      expect(() => PolylineDecoder.decode('???'), returnsNormally);
      expect(() => PolylineDecoder.decode('~'), returnsNormally);
    });
  });

  group('SyntheticStreetRouteProvider', () {
    final provider = SyntheticStreetRouteProvider();

    test('Returns genuine street-following pedestrian route for Boyd Park -> Blair House', () async {
      final result = await provider.calculateRoute(
        originLat: 44.9472,
        originLon: -93.1235,
        destinationLat: 44.9544,
        destinationLon: -93.1192,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isTrue);
      final route = result.route!;
      expect(route.isVerifiedGeometry, isTrue);
      expect(route.mode, StreetRouteMode.walking);
      expect(route.providerId, 'synthetic_fixtures');
      // Must have actual intermediate street vertices, not a 2-point straight line
      expect(route.geometry.length, greaterThan(5));
      expect(route.maneuvers.length, greaterThanOrEqualTo(3));
      expect(route.maneuvers.first.instruction, contains('Selby Ave'));
      expect(route.maneuvers.last.instruction, contains('Hope on the Horizon'));
      expect(route.distanceMiles, closeTo(0.55, 0.05));
    });

    test('Returns genuine road-network route for driving', () async {
      final result = await provider.calculateRoute(
        originLat: 44.9472,
        originLon: -93.1235,
        destinationLat: 44.9544,
        destinationLon: -93.1192,
        mode: StreetRouteMode.driving,
      );

      expect(result.isSuccess, isTrue);
      final route = result.route!;
      expect(route.isVerifiedGeometry, isTrue);
      expect(route.mode, StreetRouteMode.driving);
      expect(route.geometry.length, greaterThan(3));
      expect(route.durationMinutes, lessThan(10));
    });

    test('Fails closed safely for unverified distant location', () async {
      final result = await provider.calculateRoute(
        originLat: 45.1000,
        originLon: -93.5000,
        destinationLat: 45.2000,
        destinationLon: -93.6000,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('No verified street network route'));
    });
  });

  group('OfflineStreetRouteProvider', () {
    final provider = OfflineStreetRouteProvider();

    test('Returns fail-closed unverified route with clear offline status', () async {
      final result = await provider.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Offline routing is unavailable'));
      expect(result.route, isNull);
    });
  });

  group('ValhallaRouteAdapter', () {
    test('Parses Valhalla JSON response with maneuvers and geometry', () async {
      final mockResponse = jsonEncode({
        'trip': {
          'summary': {
            'length': 0.85, // km
            'time': 612, // seconds
          },
          'legs': [
            {
              'shape': 'k`weGbm_rPuAeEw@mB', // mock encoded polyline
              'maneuvers': [
                {
                  'type': 1,
                  'instruction': 'Walk northeast on Selby Ave.',
                  'length': 0.45,
                  'time': 324,
                  'street_names': ['Selby Avenue'],
                },
                {
                  'type': 4,
                  'instruction': 'You have arrived at your destination.',
                  'length': 0.0,
                  'time': 0,
                }
              ]
            }
          ]
        }
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200, headers: {'content-type': 'application/json'});
      });

      final adapter = ValhallaRouteAdapter(
        baseUrl: 'http://127.0.0.1:8002',
        client: mockClient,
      );

      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isTrue);
      final route = result.route!;
      expect(route.providerId, 'valhalla');
      expect(route.isVerifiedGeometry, isTrue);
      expect(route.totalDistanceMeters, closeTo(850, 1));
      expect(route.estimatedDurationSeconds, 612);
      expect(route.maneuvers.length, 2);
      expect(route.maneuvers.first.instruction, contains('Selby Ave'));
      expect(route.maneuvers.last.instruction, contains('arrived'));
    });

    test('Handles Valhalla server error response safely', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error_code': 171, 'error': 'No suitable path found'}), 400);
      });

      final adapter = ValhallaRouteAdapter(
        baseUrl: 'http://127.0.0.1:8002',
        client: mockClient,
      );

      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Valhalla HTTP 400'));
    });
  });

  group('OpenRouteServiceAdapter', () {
    final sampleGeoJson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-93.1186, 44.9490],
              [-93.1200, 44.9500],
              [-93.1255, 44.9515],
            ],
          },
          'properties': {
            'summary': {
              'distance': 780.0,
              'duration': 560.0,
            },
            'segments': [
              {
                'steps': [
                  {
                    'instruction': 'Head west on Selby Avenue',
                    'distance': 350.0,
                    'duration': 250.0,
                    'type': 11,
                    'name': 'Selby Avenue',
                  },
                  {
                    'instruction': 'Arrive at destination',
                    'distance': 0.0,
                    'duration': 0.0,
                    'type': 10,
                    'name': '',
                  },
                ],
              },
            ],
          },
        },
      ],
    };

    test('Parses ORS GeoJSON walking response correctly and verifies endpoint & coordinates', () async {
      String? requestedUrl;
      String? requestBody;
      String? authHeader;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        requestBody = request.body;
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode(sampleGeoJson), 200, headers: {'content-type': 'application/json'});
      });

      final adapter = OpenRouteServiceAdapter(
        apiKey: 'test_token',
        client: mockClient,
      );

      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isTrue);
      expect(requestedUrl, 'https://api.heigit.org/openrouteservice/v2/directions/foot-walking/geojson');
      expect(authHeader, 'test_token');

      // Verify coordinate order in request body: ORS requires [lon, lat]
      final decodedBody = jsonDecode(requestBody!) as Map<String, dynamic>;
      final coords = decodedBody['coordinates'] as List<dynamic>;
      expect(coords[0], [-93.1186, 44.9490]);
      expect(coords[1], [-93.1255, 44.9515]);

      final route = result.route!;
      expect(route.providerId, 'openrouteservice');
      expect(route.isVerifiedGeometry, isTrue);
      expect(route.geometry.length, 3);
      // Ensure coordinates converted from [lon, lat] to [lat, lon]
      expect(route.geometry.first.$1, 44.9490);
      expect(route.geometry.first.$2, -93.1186);
      expect(route.geometry.last.$1, 44.9515);
      expect(route.geometry.last.$2, -93.1255);
      expect(route.totalDistanceMeters, 780.0);
      expect(route.estimatedDurationSeconds, 560);
      expect(route.maneuvers.length, 2);
    });

    test('Parses ORS GeoJSON driving response correctly using driving-car endpoint', () async {
      String? requestedUrl;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        return http.Response(jsonEncode(sampleGeoJson), 200, headers: {'content-type': 'application/json'});
      });

      final adapter = OpenRouteServiceAdapter(
        apiKey: 'test_token',
        client: mockClient,
      );

      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.driving,
      );

      expect(result.isSuccess, isTrue);
      expect(requestedUrl, 'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson');
    });

    test('Fails closed when API key is missing or blank', () async {
      final unconfigured = OpenRouteServiceAdapter(apiKey: null);
      expect(unconfigured.isConfigured, isFalse);

      final result = await unconfigured.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('not configured'));
    });

    test('Handles HTTP 401/403 authorization failure safely', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': {'code': 401, 'message': 'Unauthorized'}}), 401);
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'invalid_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('authorization failed'));
      expect(result.errorMessage, isNot(contains('invalid_key')));
    });

    test('Handles HTTP 429 rate limit safely', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate limit exceeded', 429);
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('rate limit reached (HTTP 429)'));
    });

    test('Handles custom server error message parsing safely', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': {'message': 'Could not find point 0 within a radius of 350.0 meters.'}}), 404);
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Could not find point 0'));
    });

    test('Handles network timeout safely without crashing', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('timed out after 15 seconds'));
    });

    test('Handles socket connection error safely', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup');
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Network connection failed'));
    });

    test('Handles empty features array response safely', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'type': 'FeatureCollection', 'features': []}), 200);
      });

      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key', client: mockClient);
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('No route features'));
    });

    test('Rejects invalid input coordinates safely', () async {
      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key');
      final result = await adapter.calculateRoute(
        originLat: 195.0,
        originLon: -93.1186,
        destinationLat: 44.9515,
        destinationLon: -93.1255,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid coordinates'));
    });

    test('Returns instant arrival route for identical origin and destination', () async {
      final adapter = OpenRouteServiceAdapter(apiKey: 'test_key');
      final result = await adapter.calculateRoute(
        originLat: 44.9490,
        originLon: -93.1186,
        destinationLat: 44.9490,
        destinationLon: -93.1186,
        mode: StreetRouteMode.walking,
      );

      expect(result.isSuccess, isTrue);
      expect(result.route!.totalDistanceMeters, 0);
      expect(result.route!.maneuvers.first.type, StreetManeuverType.arrive);
    });
  });

  group('PrivacyCapability - Remote Routing', () {
    test('Remote routing capability has valid privacy disclosure and defaults to denied', () {
      final cap = PrivacyCapability.remoteRouting;
      expect(cap.name, 'remoteRouting');
      expect(cap.disclosure.recipient, contains('HeiGIT'));
      expect(cap.disclosure.transmittedData, contains('coordinates'));
      expect(cap.disclosure.fallback, contains('Google Maps'));
    });

    test('PrivacyCapabilityState handles remoteRouting authorization and revocation', () {
      var state = const PrivacyCapabilityState();
      expect(state.isGranted(PrivacyCapability.remoteRouting), isFalse);

      state = state.withSessionAuthorization(PrivacyCapability.remoteRouting, ConsentState.granted);
      expect(state.isGranted(PrivacyCapability.remoteRouting), isTrue);

      state = state.withSessionAuthorization(PrivacyCapability.remoteRouting, ConsentState.denied);
      expect(state.isGranted(PrivacyCapability.remoteRouting), isFalse);
    });
  });

  group('DevRoutingConfig', () {
    test('Resolves OfflineStreetRouteProvider when unconfigured', () async {
      final provider = await DevRoutingConfig.resolveProvider();
      expect(provider, isA<StreetRouteProvider>());
      expect(provider.isConfigured, isFalse);
    });
  });

  group('StreetRoutePreviewSheet Widget Test', () {
    testWidgets('Renders route header, maneuvers, and external fallback action', (tester) async {
      const route = StreetRoute(
        mode: StreetRouteMode.walking,
        originLat: 44.9472,
        originLon: -93.1235,
        destinationLat: 44.9544,
        destinationLon: -93.1192,
        geometry: [(44.9472, -93.1235), (44.9544, -93.1192)],
        totalDistanceMeters: 880,
        estimatedDurationSeconds: 660,
        maneuvers: [
          StreetManeuver(
            instruction: 'Head east on Selby Ave toward Nina St',
            distanceMeters: 350,
            durationSeconds: 260,
            latitude: 44.9472,
            longitude: -93.1235,
            type: StreetManeuverType.depart,
          ),
          StreetManeuver(
            instruction: 'Turn left onto Western Ave N',
            distanceMeters: 530,
            durationSeconds: 400,
            latitude: 44.9472,
            longitude: -93.1192,
            type: StreetManeuverType.turnLeft,
          ),
          StreetManeuver(
            instruction: 'Arrive at Hope on the Horizon',
            distanceMeters: 0,
            durationSeconds: 0,
            latitude: 44.9544,
            longitude: -93.1192,
            type: StreetManeuverType.arrive,
          ),
        ],
        providerId: 'synthetic_fixtures',
        dataSource: 'synthetic_fixture',
        isVerifiedGeometry: true,
        fetchedAtUtcMs: 1728900000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreetRoutePreviewSheet(
              route: route,
              onShowOnMap: () {},
              onOpenExternalNavigation: () {},
            ),
          ),
        ),
      );

      // Verify header and badge
      expect(find.text('Walking Route • 11 min'), findsOneWidget);
      expect(find.textContaining('0.5 mi (880 m)'), findsOneWidget);

      // Verify maneuvers
      expect(find.text('Head east on Selby Ave toward Nina St'), findsOneWidget);
      expect(find.text('Turn left onto Western Ave N'), findsOneWidget);
      expect(find.text('Arrive at Hope on the Horizon'), findsOneWidget);

      // Verify Google Maps fallback button and View on Map
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
    });
  });
}
