// lib/features/navigator/data/atlas_bridge.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/services.dart';
import 'atlas_dtos.dart';

class AtlasBridge {
  static const String channelName = 'recoveryforall/atlas_v1';
  static const int currentApiVersion = 1;

  final MethodChannel _channel;

  AtlasBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  Future<AtlasCapabilities> getCapabilities({int apiVersion = currentApiVersion}) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCapabilities',
        {'apiVersion': apiVersion},
      );
      if (res == null) {
        throw const AtlasException(
          code: AtlasErrorCode.nativeFailure,
          message: 'Received null response from native getCapabilities',
        );
      }
      return AtlasCapabilities.fromMap(Map<String, dynamic>.from(res));
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  Future<AtlasStaticNetworkStatus> loadStaticNetwork({
    required String requestId,
    required String feedId,
    bool fromCacheOnly = true,
    int apiVersion = currentApiVersion,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'loadStaticNetwork',
        {
          'apiVersion': apiVersion,
          'requestId': requestId,
          'feedId': feedId,
          'fromCacheOnly': fromCacheOnly,
        },
      );
      if (res == null) {
        throw const AtlasException(
          code: AtlasErrorCode.nativeFailure,
          message: 'Received null response from native loadStaticNetwork',
        );
      }
      return AtlasStaticNetworkStatus.fromMap(Map<String, dynamic>.from(res));
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

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
    int apiVersion = currentApiVersion,
  }) async {
    // Coordinate validation per BRIDGE_API_CONTRACT.md
    _validateCoordinate(originLat, originLon, 'origin');
    _validateCoordinate(destinationLat, destinationLon, 'destination');

    if (requestId.trim().isEmpty) {
      throw const AtlasException(
        code: AtlasErrorCode.badInput,
        message: 'requestId must not be empty',
      );
    }

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'planJourney',
        {
          'apiVersion': apiVersion,
          'requestId': requestId,
          'meetingId': meetingId,
          'origin': {'lat': originLat, 'lon': originLon},
          'destination': {'lat': destinationLat, 'lon': destinationLon},
          'departAtUtcMs': departAtUtcMs,
          'arriveBeforeUtcMs': arriveBeforeUtcMs,
          'maxWalkMeters': maxWalkMeters,
          'allowRemote': allowRemote,
          'transitModes': transitModes,
        },
      );

      if (res == null) {
        throw const AtlasException(
          code: AtlasErrorCode.nativeFailure,
          message: 'Received null response from native planJourney',
        );
      }
      return JourneyPreview.fromMap(Map<String, dynamic>.from(res));
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  Future<bool> cancelRequest({
    required String requestId,
    int apiVersion = currentApiVersion,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'cancelRequest',
        {'apiVersion': apiVersion, 'requestId': requestId},
      );
      return res?['cancelRequested'] == true;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  Future<AtlasOfflineStatus> getOfflineStatus({
    String feedId = 'default',
    int apiVersion = currentApiVersion,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getOfflineStatus',
        {'apiVersion': apiVersion, 'feedId': feedId},
      );
      if (res == null) {
        throw const AtlasException(
          code: AtlasErrorCode.nativeFailure,
          message: 'Received null response from native getOfflineStatus',
        );
      }
      return AtlasOfflineStatus.fromMap(Map<String, dynamic>.from(res));
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  void _validateCoordinate(double lat, double lon, String label) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) {
      throw AtlasException(
        code: AtlasErrorCode.badInput,
        message: '$label coordinates cannot be NaN or Infinite: ($lat, $lon)',
      );
    }
    if (lat < -90.0 || lat > 90.0) {
      throw AtlasException(
        code: AtlasErrorCode.badInput,
        message: '$label latitude out of range [-90, 90]: $lat',
      );
    }
    if (lon < -180.0 || lon > 180.0) {
      throw AtlasException(
        code: AtlasErrorCode.badInput,
        message: '$label longitude out of range [-180, 180]: $lon',
      );
    }
  }

  AtlasException _mapPlatformException(PlatformException e) {
    final code = AtlasErrorCode.fromCode(e.code);
    Map<String, dynamic>? details;
    if (e.details is Map) {
      details = Map<String, dynamic>.from(e.details as Map);
    }
    return AtlasException(
      code: code,
      message: e.message ?? 'Platform channel failure (${e.code})',
      details: details,
    );
  }
}
