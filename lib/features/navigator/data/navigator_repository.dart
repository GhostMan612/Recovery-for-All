// lib/features/navigator/data/navigator_repository.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'atlas_bridge.dart';
import 'atlas_dtos.dart';

class NavigatorRepository {
  final AtlasBridge _bridge;

  NavigatorRepository({AtlasBridge? bridge}) : _bridge = bridge ?? AtlasBridge();

  Future<AtlasCapabilities> checkCapabilities() async {
    try {
      return await _bridge.getCapabilities();
    } catch (_) {
      // Graceful fallback when channel or native plugin not available
      return const AtlasCapabilities(
        version: 1,
        staticTransit: false,
        localRouting: false,
        realtime: false,
        weather: false,
        offlineSnapshot: false,
        providerIds: [],
      );
    }
  }

  Future<AtlasOfflineStatus> getOfflineStatus({String feedId = 'default'}) async {
    try {
      return await _bridge.getOfflineStatus(feedId: feedId);
    } catch (_) {
      return const AtlasOfflineStatus(
        staticNetwork: 'unavailable',
        basemap: 'cached_tiles',
        routing: 'unavailable',
        notes: 'Fallback mode active',
      );
    }
  }

  Future<JourneyPreview?> planMeetingJourney({
    required String requestId,
    required String meetingId,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required int departAtUtcMs,
    int? arriveBeforeUtcMs,
    int maxWalkMeters = 1500,
  }) async {
    try {
      return await _bridge.planJourney(
        requestId: requestId,
        meetingId: meetingId,
        originLat: originLat,
        originLon: originLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        departAtUtcMs: departAtUtcMs,
        arriveBeforeUtcMs: arriveBeforeUtcMs,
        maxWalkMeters: maxWalkMeters,
        allowRemote: false,
      );
    } on AtlasException {
      rethrow;
    } catch (e) {
      throw AtlasException(
        code: AtlasErrorCode.nativeFailure,
        message: 'Failed to plan meeting journey: $e',
      );
    }
  }
}
