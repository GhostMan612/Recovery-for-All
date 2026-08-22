// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/meeting_finder_service.dart

class RecoveryMeeting {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String time;
  final String address;

  RecoveryMeeting({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.time,
    required this.address,
  });
}

class MeetingFinderService {
  Future<List<RecoveryMeeting>> findNearbyMeetings(double lat, double lng) async {
    return [];
  }
}
