// lib/features/navigator/application/street_route_provider.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../domain/street_route.dart';

/// Provider-independent street-routing interface.
abstract class StreetRouteProvider {
  String get providerId;
  String get displayName;
  bool get isConfigured;
  bool get isRemote => false;

  Future<StreetRouteResult> calculateRoute({
    required StreetRouteMode mode,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
  });
}

/// Standalone pure Dart decoder for Valhalla / Google Encoded Polylines (Precision 1e6).
class PolylineDecoder {
  static List<(double, double)> decode(String encoded, {int precision = 6}) {
    final factor = precision == 6 ? 1e6 : 1e5;
    final points = <(double, double)>[];
    var index = 0;
    final len = encoded.length;
    var lat = 0;
    var lng = 0;

    while (index < len) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add((lat / factor, lng / factor));
    }
    return points;
  }
}

/// Valhalla street routing adapter (self-hosted or local sovereign instance).
class ValhallaRouteAdapter implements StreetRouteProvider {
  final String baseUrl;
  final http.Client _client;

  ValhallaRouteAdapter({
    this.baseUrl = 'http://127.0.0.1:8002',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'valhalla';

  @override
  String get displayName => 'Valhalla Routing Engine';

  @override
  bool get isConfigured => baseUrl.isNotEmpty;

  @override
  bool get isRemote => false;

  @override
  Future<StreetRouteResult> calculateRoute({
    required StreetRouteMode mode,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
  }) async {
    final url = Uri.parse('$baseUrl/route');
    final payload = {
      'locations': [
        {'lat': originLat, 'lon': originLon},
        {'lat': destinationLat, 'lon': destinationLon},
      ],
      'costing': mode.valhallaCosting,
      'directions_options': {
        'units': 'kilometers',
        'language': 'en-US',
      },
    };

    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        return StreetRouteResult.failure(
          errorMessage: 'Valhalla HTTP ${res.statusCode}: ${res.body}',
          providerId: providerId,
        );
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final trip = json['trip'] as Map<String, dynamic>?;
      if (trip == null) {
        return StreetRouteResult.failure(
          errorMessage: 'Malformed Valhalla response: missing trip object',
          providerId: providerId,
        );
      }

      final legs = trip['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) {
        return StreetRouteResult.failure(
          errorMessage: 'No route legs found in Valhalla response',
          providerId: providerId,
        );
      }

      final leg = legs.first as Map<String, dynamic>;
      final encodedShape = leg['shape'] as String? ?? '';
      final points = PolylineDecoder.decode(encodedShape, precision: 6);

      final summary = trip['summary'] as Map<String, dynamic>? ?? {};
      final lengthKm = (summary['length'] as num?)?.toDouble() ?? 0.0;
      final timeSeconds = (summary['time'] as num?)?.toInt() ?? 0;

      final maneuversJson = leg['maneuvers'] as List<dynamic>? ?? [];
      final maneuvers = <StreetManeuver>[];
      for (final m in maneuversJson) {
        final map = m as Map<String, dynamic>;
        maneuvers.add(StreetManeuver(
          instruction: map['instruction'] as String? ?? '',
          streetName: (map['street_names'] as List<dynamic>?)?.firstOrNull?.toString(),
          distanceMeters: (((map['length'] as num?)?.toDouble() ?? 0.0) * 1000).round(),
          durationSeconds: (map['time'] as num?)?.toInt() ?? 0,
          latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
          longitude: (map['lon'] as num?)?.toDouble() ?? 0.0,
          type: StreetManeuverType.fromValhallaType(map['type'] as int?),
        ));
      }

      final route = StreetRoute(
        mode: mode,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        geometry: points,
        totalDistanceMeters: (lengthKm * 1000).round(),
        estimatedDurationSeconds: timeSeconds,
        maneuvers: maneuvers,
        providerId: providerId,
        dataSource: 'valhalla_engine',
        isVerifiedGeometry: points.length >= 2,
        fetchedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      return StreetRouteResult.success(route: route, providerId: providerId);
    } catch (e) {
      return StreetRouteResult.failure(
        errorMessage: 'Connection to Valhalla routing engine failed: $e',
        providerId: providerId,
      );
    }
  }
}

/// OpenRouteService hosted or private instance adapter.
/// Uses the updated HeiGIT endpoint: https://api.heigit.org/openrouteservice/v2/directions
class OpenRouteServiceAdapter implements StreetRouteProvider {
  final String baseUrl;
  final String? apiKey;
  final http.Client _client;

  OpenRouteServiceAdapter({
    this.baseUrl = 'https://api.heigit.org/openrouteservice/v2/directions',
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'openrouteservice';

  @override
  String get displayName => 'OpenRouteService API';

  @override
  bool get isConfigured => apiKey != null && apiKey!.trim().isNotEmpty;

  @override
  bool get isRemote => true;

  @override
  Future<StreetRouteResult> calculateRoute({
    required StreetRouteMode mode,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
  }) async {
    if (!isConfigured) {
      return StreetRouteResult.unavailable(
        reason: 'OpenRouteService API key is not configured. Request blocked.',
        providerId: providerId,
      );
    }

    // Input coordinate sanity check
    if (originLat < -90 || originLat > 90 || destinationLat < -90 || destinationLat > 90 ||
        originLon < -180 || originLon > 180 || destinationLon < -180 || destinationLon > 180) {
      return StreetRouteResult.failure(
        errorMessage: 'Invalid coordinates provided for route calculation.',
        providerId: providerId,
      );
    }

    // If already at destination
    if ((originLat - destinationLat).abs() < 0.00005 && (originLon - destinationLon).abs() < 0.00005) {
      return StreetRouteResult.success(
        route: StreetRoute(
          mode: mode,
          originLat: originLat,
          originLon: originLon,
          destinationLat: destinationLat,
          destinationLon: destinationLon,
          geometry: [(originLat, originLon)],
          totalDistanceMeters: 0,
          estimatedDurationSeconds: 0,
          maneuvers: [
            StreetManeuver(
              instruction: 'You have arrived at your destination.',
              distanceMeters: 0,
              durationSeconds: 0,
              latitude: destinationLat,
              longitude: destinationLon,
              type: StreetManeuverType.arrive,
            ),
          ],
          providerId: providerId,
          dataSource: 'openrouteservice_hosted',
          isVerifiedGeometry: true,
          fetchedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
        providerId: providerId,
      );
    }

    final profile = mode == StreetRouteMode.walking ? 'foot-walking' : 'driving-car';
    final url = Uri.parse('$baseUrl/$profile/geojson');

    final payload = {
      'coordinates': [
        [originLon, originLat],
        [destinationLon, destinationLat],
      ],
      'instructions': true,
      'units': 'm',
    };

    try {
      final res = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': apiKey!.trim(),
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        if (res.statusCode == 429) {
          return StreetRouteResult.failure(
            errorMessage: 'OpenRouteService rate limit reached (HTTP 429). Please wait before retrying.',
            providerId: providerId,
          );
        }
        if (res.statusCode == 401 || res.statusCode == 403) {
          return StreetRouteResult.failure(
            errorMessage: 'OpenRouteService authorization failed (HTTP ${res.statusCode}). Check API credentials.',
            providerId: providerId,
          );
        }

        String? detailMsg;
        try {
          final errJson = jsonDecode(res.body) as Map<String, dynamic>?;
          detailMsg = errJson?['error']?['message']?.toString();
        } catch (_) {}

        return StreetRouteResult.failure(
          errorMessage: detailMsg != null
              ? 'OpenRouteService error: $detailMsg'
              : 'OpenRouteService HTTP ${res.statusCode}',
          providerId: providerId,
        );
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        return StreetRouteResult.failure(
          errorMessage: 'No route features in OpenRouteService GeoJSON response',
          providerId: providerId,
        );
      }

      final feature = features.first as Map<String, dynamic>;
      final geom = feature['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'] as List<dynamic>? ?? [];
      final points = coords.map((c) {
        final pair = c as List<dynamic>;
        return ((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final summary = props['summary'] as Map<String, dynamic>? ?? {};
      final totalDist = (summary['distance'] as num?)?.round() ?? 0;
      final totalDur = (summary['duration'] as num?)?.round() ?? 0;

      final segments = props['segments'] as List<dynamic>? ?? [];
      final maneuvers = <StreetManeuver>[];
      if (segments.isNotEmpty) {
        final steps = (segments.first as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          final stepType = step['type'] as int? ?? 0;
          final stepName = step['name'] as String? ?? '';
          final stepDist = (step['distance'] as num?)?.round() ?? 0;
          final stepDur = (step['duration'] as num?)?.round() ?? 0;
          final stepInst = step['instruction'] as String? ?? '';
          final waypoints = step['way_points'] as List<dynamic>? ?? [];
          final wpIdx = waypoints.isNotEmpty ? (waypoints.first as num).toInt() : 0;
          final coord = wpIdx < points.length ? points[wpIdx] : (originLat, originLon);

          maneuvers.add(StreetManeuver(
            instruction: stepInst,
            streetName: stepName.isEmpty ? null : stepName,
            distanceMeters: stepDist,
            durationSeconds: stepDur,
            latitude: coord.$1,
            longitude: coord.$2,
            type: _mapOrsManeuverType(stepType),
          ));
        }
      }

      final route = StreetRoute(
        mode: mode,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        geometry: points,
        totalDistanceMeters: totalDist,
        estimatedDurationSeconds: totalDur,
        maneuvers: maneuvers,
        providerId: providerId,
        dataSource: 'openrouteservice_hosted',
        isVerifiedGeometry: points.length >= 2,
        fetchedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      return StreetRouteResult.success(route: route, providerId: providerId);
    } on TimeoutException {
      return StreetRouteResult.failure(
        errorMessage: 'OpenRouteService request timed out after 15 seconds.',
        providerId: providerId,
      );
    } on SocketException catch (e) {
      return StreetRouteResult.failure(
        errorMessage: 'Network connection failed: ${e.message}',
        providerId: providerId,
      );
    } on FormatException catch (e) {
      return StreetRouteResult.failure(
        errorMessage: 'Malformed routing response: ${e.message}',
        providerId: providerId,
      );
    } catch (e) {
      return StreetRouteResult.failure(
        errorMessage: 'OpenRouteService request failed: $e',
        providerId: providerId,
      );
    }
  }

  static StreetManeuverType _mapOrsManeuverType(int type) {
    switch (type) {
      case 0:
        return StreetManeuverType.turnLeft;
      case 1:
        return StreetManeuverType.turnRight;
      case 2:
        return StreetManeuverType.turnSharpLeft;
      case 3:
        return StreetManeuverType.turnSharpRight;
      case 4:
        return StreetManeuverType.turnSlightLeft;
      case 5:
        return StreetManeuverType.turnSlightRight;
      case 6:
        return StreetManeuverType.continueStraight;
      case 10:
        return StreetManeuverType.arrive;
      case 11:
        return StreetManeuverType.depart;
      default:
        return StreetManeuverType.continueStraight;
    }
  }
}

/// Fallback offline street route provider when no live street graph server is authorized.
/// This is the secure fail-closed default for production releases.
class OfflineStreetRouteProvider implements StreetRouteProvider {
  const OfflineStreetRouteProvider();

  @override
  String get providerId => 'offline_unconfigured';

  @override
  String get displayName => 'Offline (No Routing Engine)';

  @override
  bool get isConfigured => false;

  @override
  bool get isRemote => false;

  @override
  Future<StreetRouteResult> calculateRoute({
    required StreetRouteMode mode,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
  }) async {
    return const StreetRouteResult.unavailable(
      reason: 'Offline routing is unavailable: Street routing engine is not configured.',
      providerId: 'offline_unconfigured',
    );
  }
}

/// Synthetic street route provider delivering street-network geometry
/// exclusively for automated testing and isolated development fixtures.
/// MUST NOT be used as the default production runtime provider.
class SyntheticStreetRouteProvider implements StreetRouteProvider {
  @override
  String get providerId => 'synthetic_fixtures';

  @override
  String get displayName => 'Verified Street Fixture Provider (Test Only)';

  @override
  bool get isConfigured => true;

  @override
  bool get isRemote => false;

  @override
  Future<StreetRouteResult> calculateRoute({
    required StreetRouteMode mode,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
  }) async {
    // Scenario A: Boyd Park to Hope on the Horizon (Blair House, 165 Western Ave N, Saint Paul)
    // Real Saint Paul street alignment: Boyd Park -> Selby Ave -> Western Ave N -> Blair House
    if ((originLat - 44.9472).abs() < 0.01 && (originLon - (-93.1235)).abs() < 0.01) {
      return _buildBoydParkToBlairHouseRoute(mode, originLat, originLon, destinationLat, destinationLon);
    }

    // Coordinates outside verified fixture scenarios fail closed safely
    return StreetRouteResult.failure(
      errorMessage: 'No verified street network route available for these coordinates in offline fixture mode.',
      providerId: providerId,
    );
  }

  static StreetRouteResult _buildBoydParkToBlairHouseRoute(
    StreetRouteMode mode,
    double originLat,
    double originLon,
    double destinationLat,
    double destinationLon,
  ) {
    // Authentic street points along Selby Ave and Western Ave N in Saint Paul:
    final streetGeometry = <(double, double)>[
      (44.9472, -93.1235), // Boyd Park / Farrington St
      (44.9472, -93.1215), // Selby Ave & Nina St
      (44.9472, -93.1192), // Selby Ave & Western Ave N (Turn intersection)
      (44.9495, -93.1192), // Western Ave N & Holly Ave
      (44.9520, -93.1192), // Western Ave N & Marshall Ave
      (44.9544, -93.1192), // 165 Western Ave N (Blair House)
    ];

    final isWalking = mode == StreetRouteMode.walking;
    final totalDistance = 880; // meters (~0.55 mi)
    final durationSeconds = isWalking ? 660 : 180; // 11 min walk vs 3 min drive

    final maneuvers = [
      const StreetManeuver(
        instruction: 'Head east on Selby Ave toward Nina St',
        streetName: 'Selby Ave',
        distanceMeters: 350,
        durationSeconds: 260,
        latitude: 44.9472,
        longitude: -93.1235,
        type: StreetManeuverType.depart,
      ),
      const StreetManeuver(
        instruction: 'Turn left onto Western Ave N',
        streetName: 'Western Ave N',
        distanceMeters: 530,
        durationSeconds: 400,
        latitude: 44.9472,
        longitude: -93.1192,
        type: StreetManeuverType.turnLeft,
      ),
      const StreetManeuver(
        instruction: 'Arrive at Hope on the Horizon (Blair House, 165 Western Ave N) on right',
        streetName: 'Western Ave N',
        distanceMeters: 0,
        durationSeconds: 0,
        latitude: 44.9544,
        longitude: -93.1192,
        type: StreetManeuverType.arrive,
      ),
    ];

    return StreetRouteResult.success(
      route: StreetRoute(
        mode: mode,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        geometry: streetGeometry,
        totalDistanceMeters: totalDistance,
        estimatedDurationSeconds: durationSeconds,
        maneuvers: maneuvers,
        providerId: 'synthetic_fixtures',
        dataSource: 'saint_paul_osm_graph_fixture',
        isVerifiedGeometry: true,
        fetchedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      providerId: 'synthetic_fixtures',
    );
  }
}

/// Secure development configuration resolver for live routing providers.
/// Enforces production fail-closed boundaries: in release builds, always returns
/// [OfflineStreetRouteProvider] unless an enterprise sovereign backend is configured.
class DevRoutingConfig {
  DevRoutingConfig._();

  static const String _envKey = String.fromEnvironment('ORS_API_KEY', defaultValue: '');
  static const String _storageKey = 'ors_api_key_dev';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Resolves the street route provider for the current environment.
  /// Strictly fails closed: in release builds or if no key is configured,
  /// returns [OfflineStreetRouteProvider].
  static Future<StreetRouteProvider> resolveProvider({http.Client? client}) async {
    if (kReleaseMode) {
      return const OfflineStreetRouteProvider();
    }

    // 1. Check on-device secure storage (developer key)
    try {
      final storedKey = await _storage.read(key: _storageKey);
      if (storedKey != null && storedKey.trim().isNotEmpty) {
        return OpenRouteServiceAdapter(apiKey: storedKey.trim(), client: client);
      }
    } catch (_) {}

    // 2. Check compile-time environment define in debug mode
    if (_envKey.trim().isNotEmpty) {
      try {
        await _storage.write(key: _storageKey, value: _envKey.trim());
      } catch (_) {}
      return OpenRouteServiceAdapter(apiKey: _envKey.trim(), client: client);
    }

    return const OfflineStreetRouteProvider();
  }

  /// Stores developer key on-device in secure storage (debug only).
  static Future<void> setDevKey(String key) async {
    if (kReleaseMode) return;
    if (key.trim().isEmpty) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: key.trim());
    }
  }
}
