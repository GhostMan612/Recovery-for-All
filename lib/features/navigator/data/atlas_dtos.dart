// lib/features/navigator/data/atlas_dtos.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/foundation.dart';

enum AtlasErrorCode {
  unsupportedVersion,
  sdkNotInstalled,
  missingFeed,
  feedExpired,
  noItinerary,
  permissionRequired,
  remoteDisabled,
  networkFailure,
  timeout,
  badInput,
  nativeFailure,
  canceled;

  static AtlasErrorCode fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'UNSUPPORTED_VERSION':
        return AtlasErrorCode.unsupportedVersion;
      case 'SDK_NOT_INSTALLED':
        return AtlasErrorCode.sdkNotInstalled;
      case 'MISSING_FEED':
        return AtlasErrorCode.missingFeed;
      case 'FEED_EXPIRED':
        return AtlasErrorCode.feedExpired;
      case 'NO_ITINERARY':
        return AtlasErrorCode.noItinerary;
      case 'PERMISSION_REQUIRED':
        return AtlasErrorCode.permissionRequired;
      case 'REMOTE_DISABLED':
        return AtlasErrorCode.remoteDisabled;
      case 'NETWORK_FAILURE':
        return AtlasErrorCode.networkFailure;
      case 'TIMEOUT':
        return AtlasErrorCode.timeout;
      case 'BAD_INPUT':
        return AtlasErrorCode.badInput;
      case 'CANCELED':
        return AtlasErrorCode.canceled;
      default:
        return AtlasErrorCode.nativeFailure;
    }
  }
}

class AtlasException implements Exception {
  final AtlasErrorCode code;
  final String message;
  final Map<String, dynamic>? details;

  const AtlasException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'AtlasException($code, message: $message)';
}

@immutable
class AtlasCapabilities {
  final int version;
  final bool staticTransit;
  final bool localRouting;
  final bool realtime;
  final bool weather;
  final bool offlineSnapshot;
  final List<String> providerIds;

  const AtlasCapabilities({
    required this.version,
    required this.staticTransit,
    required this.localRouting,
    required this.realtime,
    required this.weather,
    required this.offlineSnapshot,
    required this.providerIds,
  });

  factory AtlasCapabilities.fromMap(Map<String, dynamic> map) {
    return AtlasCapabilities(
      version: (map['version'] as num?)?.toInt() ?? 1,
      staticTransit: map['staticTransit'] == true,
      localRouting: map['localRouting'] == true,
      realtime: map['realtime'] == true,
      weather: map['weather'] == true,
      offlineSnapshot: map['offlineSnapshot'] == true,
      providerIds: (map['providerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

@immutable
class AtlasStaticNetworkStatus {
  final String state;
  final String? feedHash;
  final int? fetchedAt;
  final int? expiresAt;
  final int stopCount;
  final String? source;

  const AtlasStaticNetworkStatus({
    required this.state,
    this.feedHash,
    this.fetchedAt,
    this.expiresAt,
    required this.stopCount,
    this.source,
  });

  factory AtlasStaticNetworkStatus.fromMap(Map<String, dynamic> map) {
    return AtlasStaticNetworkStatus(
      state: map['state'] as String? ?? 'unknown',
      feedHash: map['feedHash'] as String?,
      fetchedAt: (map['fetchedAt'] as num?)?.toInt(),
      expiresAt: (map['expiresAt'] as num?)?.toInt(),
      stopCount: (map['stopCount'] as num?)?.toInt() ?? 0,
      source: map['source'] as String?,
    );
  }
}

@immutable
class AtlasOfflineStatus {
  final String staticNetwork;
  final String basemap;
  final String routing;
  final int? dataAgeSeconds;
  final String? notes;

  const AtlasOfflineStatus({
    required this.staticNetwork,
    required this.basemap,
    required this.routing,
    this.dataAgeSeconds,
    this.notes,
  });

  factory AtlasOfflineStatus.fromMap(Map<String, dynamic> map) {
    return AtlasOfflineStatus(
      staticNetwork: map['staticNetwork'] as String? ?? 'unknown',
      basemap: map['basemap'] as String? ?? 'unknown',
      routing: map['routing'] as String? ?? 'unknown',
      dataAgeSeconds: (map['dataAgeSeconds'] as num?)?.toInt(),
      notes: map['notes'] as String?,
    );
  }
}

@immutable
class JourneyLeg {
  final String mode; // 'walk', 'bus', 'rail', 'other_transit'
  final String fromLabel;
  final String toLabel;
  final int startUtcMs;
  final int endUtcMs;
  final String? routeLabel;
  final int? distanceMeters;

  const JourneyLeg({
    required this.mode,
    required this.fromLabel,
    required this.toLabel,
    required this.startUtcMs,
    required this.endUtcMs,
    this.routeLabel,
    this.distanceMeters,
  });

  factory JourneyLeg.fromMap(Map<String, dynamic> map) {
    return JourneyLeg(
      mode: map['mode'] as String? ?? 'walk',
      fromLabel: map['fromLabel'] as String? ?? '',
      toLabel: map['toLabel'] as String? ?? '',
      startUtcMs: (map['startUtcMs'] as num?)?.toInt() ?? 0,
      endUtcMs: (map['endUtcMs'] as num?)?.toInt() ?? 0,
      routeLabel: map['routeLabel'] as String?,
      distanceMeters: (map['distanceMeters'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode,
        'fromLabel': fromLabel,
        'toLabel': toLabel,
        'startUtcMs': startUtcMs,
        'endUtcMs': endUtcMs,
        if (routeLabel != null) 'routeLabel': routeLabel,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
      };
}

@immutable
class JourneyOption {
  final String journeyId;
  final int departUtcMs;
  final int arriveUtcMs;
  final int walkMeters;
  final int transferCount;
  final String transferConfidence; // 'high', 'medium', 'low', 'scheduled_unknown'
  final List<JourneyLeg> legs;

  const JourneyOption({
    required this.journeyId,
    required this.departUtcMs,
    required this.arriveUtcMs,
    required this.walkMeters,
    required this.transferCount,
    required this.transferConfidence,
    required this.legs,
  });

  factory JourneyOption.fromMap(Map<String, dynamic> map) {
    return JourneyOption(
      journeyId: map['journeyId'] as String? ?? '',
      departUtcMs: (map['departUtcMs'] as num?)?.toInt() ?? 0,
      arriveUtcMs: (map['arriveUtcMs'] as num?)?.toInt() ?? 0,
      walkMeters: (map['walkMeters'] as num?)?.toInt() ?? 0,
      transferCount: (map['transferCount'] as num?)?.toInt() ?? 0,
      transferConfidence:
          map['transferConfidence'] as String? ?? 'scheduled_unknown',
      legs: (map['legs'] as List<dynamic>?)
              ?.map((e) => JourneyLeg.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'journeyId': journeyId,
        'departUtcMs': departUtcMs,
        'arriveUtcMs': arriveUtcMs,
        'walkMeters': walkMeters,
        'transferCount': transferCount,
        'transferConfidence': transferConfidence,
        'legs': legs.map((l) => l.toMap()).toList(),
      };
}

@immutable
class JourneyPreview {
  final int version;
  final String requestId;
  final String meetingId;
  final String providerId;
  final String dataSource; // 'static_gtfs', 'live_augmented', 'remote_opt_in', 'synthetic_fixture'
  final bool isSynthetic;
  final int fetchedAtUtcMs;
  final String freshness; // 'fresh', 'stale', 'expired', 'absent', 'unknown'
  final List<JourneyOption> options;

  const JourneyPreview({
    required this.version,
    required this.requestId,
    required this.meetingId,
    required this.providerId,
    required this.dataSource,
    required this.isSynthetic,
    required this.fetchedAtUtcMs,
    required this.freshness,
    required this.options,
  });

  factory JourneyPreview.fromMap(Map<String, dynamic> map) {
    return JourneyPreview(
      version: (map['version'] as num?)?.toInt() ?? 1,
      requestId: map['requestId'] as String? ?? '',
      meetingId: map['meetingId'] as String? ?? '',
      providerId: map['providerId'] as String? ?? '',
      dataSource: map['dataSource'] as String? ?? 'static_gtfs',
      isSynthetic: map['isSynthetic'] == true,
      fetchedAtUtcMs: (map['fetchedAtUtcMs'] as num?)?.toInt() ?? 0,
      freshness: map['freshness'] as String? ?? 'unknown',
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => JourneyOption.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'requestId': requestId,
        'meetingId': meetingId,
        'providerId': providerId,
        'dataSource': dataSource,
        'isSynthetic': isSynthetic,
        'fetchedAtUtcMs': fetchedAtUtcMs,
        'freshness': freshness,
        'options': options.map((o) => o.toMap()).toList(),
      };
}
