// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
class RecoveryMeeting {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String time;
  final String address;
  const RecoveryMeeting({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.time,
    required this.address,
  });
}
class MeetingFinderService {
  Future<List<RecoveryMeeting>> findLocalMeetings(double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [];
  }
}