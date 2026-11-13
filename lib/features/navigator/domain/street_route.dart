// lib/features/navigator/domain/street_route.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

/// Travel mode for street routing.
enum StreetRouteMode {
  walking,
  driving;

  String get displayName {
    switch (this) {
      case StreetRouteMode.walking:
        return 'Walking';
      case StreetRouteMode.driving:
        return 'Driving';
    }
  }

  String get valhallaCosting {
    switch (this) {
      case StreetRouteMode.walking:
        return 'pedestrian';
      case StreetRouteMode.driving:
        return 'auto';
    }
  }
}

/// Maneuver type for directional turns and navigation steps.
enum StreetManeuverType {
  depart,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  continueStraight,
  uturn,
  arrive;

  static StreetManeuverType fromValhallaType(int? type) {
    switch (type) {
      case 1:
      case 2:
      case 3:
        return StreetManeuverType.depart;
      case 4:
      case 5:
        return StreetManeuverType.arrive;
      case 7:
      case 8:
        return StreetManeuverType.continueStraight;
      case 9:
        return StreetManeuverType.turnSlightRight;
      case 10:
        return StreetManeuverType.turnRight;
      case 11:
        return StreetManeuverType.turnSharpRight;
      case 12:
        return StreetManeuverType.uturn;
      case 13:
        return StreetManeuverType.turnSharpLeft;
      case 14:
        return StreetManeuverType.turnLeft;
      case 15:
        return StreetManeuverType.turnSlightLeft;
      default:
        return StreetManeuverType.continueStraight;
    }
  }
}

/// An individual maneuver / turn instruction along a street route.
@immutable
class StreetManeuver {
  final String instruction;
  final String? streetName;
  final int distanceMeters;
  final int durationSeconds;
  final double latitude;
  final double longitude;
  final StreetManeuverType type;

  const StreetManeuver({
    required this.instruction,
    this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  double get distanceMiles => distanceMeters * 0.000621371;

  String get formattedDistance {
    if (distanceMeters < 100) return '$distanceMeters m';
    return '${distanceMiles.toStringAsFixed(1)} mi';
  }

  Map<String, dynamic> toMap() => {
        'instruction': instruction,
        if (streetName != null) 'streetName': streetName,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'latitude': latitude,
        'longitude': longitude,
        'type': type.name,
      };

  factory StreetManeuver.fromMap(Map<String, dynamic> map) {
    return StreetManeuver(
      instruction: map['instruction'] as String? ?? '',
      streetName: map['streetName'] as String?,
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      type: StreetManeuverType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => StreetManeuverType.continueStraight,
      ),
    );
  }
}

/// Complete calculated street-network route with authentic geometry and maneuvers.
@immutable
class StreetRoute {
  final StreetRouteMode mode;
  final double originLat;
  final double originLon;
  final double destinationLat;
  final double destinationLon;

  /// Ordered street-network geometry coordinates: List of (latitude, longitude).
  /// Invariant: Must only represent authentic street graph geometry.
  final List<(double, double)> geometry;

  final int totalDistanceMeters;
  final int estimatedDurationSeconds;
  final List<StreetManeuver> maneuvers;
  final String providerId;
  final String dataSource; // 'valhalla_local', 'ors_hosted', 'synthetic_fixture'
  final bool isVerifiedGeometry;
  final String? statusMessage;
  final int fetchedAtUtcMs;

  const StreetRoute({
    required this.mode,
    required this.originLat,
    required this.originLon,
    required this.destinationLat,
    required this.destinationLon,
    required this.geometry,
    required this.totalDistanceMeters,
    required this.estimatedDurationSeconds,
    required this.maneuvers,
    required this.providerId,
    required this.dataSource,
    required this.isVerifiedGeometry,
    this.statusMessage,
    required this.fetchedAtUtcMs,
  });

  int get durationMinutes => (estimatedDurationSeconds / 60).round();
  double get distanceMiles => totalDistanceMeters * 0.000621371;
  double get distanceKm => totalDistanceMeters / 1000.0;

  String get formattedDistance => '${distanceMiles.toStringAsFixed(1)} mi';
  String get formattedDuration => '$durationMinutes min';

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'originLat': originLat,
        'originLon': originLon,
        'destinationLat': destinationLat,
        'destinationLon': destinationLon,
        'geometry': geometry.map((p) => [p.$1, p.$2]).toList(),
        'totalDistanceMeters': totalDistanceMeters,
        'estimatedDurationSeconds': estimatedDurationSeconds,
        'maneuvers': maneuvers.map((m) => m.toMap()).toList(),
        'providerId': providerId,
        'dataSource': dataSource,
        'isVerifiedGeometry': isVerifiedGeometry,
        if (statusMessage != null) 'statusMessage': statusMessage,
        'fetchedAtUtcMs': fetchedAtUtcMs,
      };
}

/// Result wrapper from a street routing query.
@immutable
class StreetRouteResult {
  final StreetRoute? route;
  final bool isSuccess;
  final String? errorMessage;
  final String providerId;

  const StreetRouteResult.success({
    required StreetRoute this.route,
    required this.providerId,
  })  : isSuccess = true,
        errorMessage = null;

  const StreetRouteResult.failure({
    required this.errorMessage,
    required this.providerId,
  })  : isSuccess = false,
        route = null;

  const StreetRouteResult.unavailable({
    required String reason,
    this.providerId = 'none',
  })  : isSuccess = false,
        errorMessage = reason,
        route = null;
}
