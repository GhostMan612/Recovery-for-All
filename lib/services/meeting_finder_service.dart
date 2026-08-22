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

/// Offline-first meeting directory.
///
/// Returns a synthetic sample fellowship until a real directory backend is
/// configured. All names/addresses are fictional SAMPLE data.
class MeetingFinderService {
  static const List<Map<String, String>> _templates = [
    {'name': 'SAMPLE Sunrise Serenity', 'type': 'AA · Open Discussion', 'time': 'Daily · 7:00 AM'},
    {'name': 'SAMPLE New Beginnings', 'type': 'NA · Step Study', 'time': 'Mon & Thu · 6:30 PM'},
    {'name': 'SAMPLE Midday Reset', 'type': 'SMART Recovery · CBT Tools', 'time': 'Tue & Fri · 12:15 PM'},
    {'name': 'SAMPLE Still Water Sangha', 'type': 'Recovery Dharma · Meditation', 'time': 'Wed · 6:00 PM'},
    {'name': 'SAMPLE Four Directions Circle', 'type': 'Wellbriety · Medicine Wheel', 'time': 'Sun · 4:00 PM'},
    {'name': 'SAMPLE Open Hearts Group', 'type': 'AA · Speaker Meeting', 'time': 'Sat · 8:00 PM'},
    {'name': 'SAMPLE Evening Anchors', 'type': 'NA · Open Discussion', 'time': 'Nightly · 9:00 PM'},
    {'name': 'SAMPLE Secular Path', 'type': 'Secular · LifeRing Check-in', 'time': 'Thu · 7:30 PM'},
  ];

  Future<List<RecoveryMeeting>> findNearbyMeetings(double lat, double lng) async {
    final meetings = <RecoveryMeeting>[];
    for (var i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      meetings.add(
        RecoveryMeeting(
          id: 'sample_meeting_$i',
          name: t['name']!,
          latitude: lat + 0.014 * ((i % 5) - 2) + i * 0.0011,
          longitude: lng + 0.011 * ((i % 3) - 1) - i * 0.0009,
          type: t['type']!,
          time: t['time']!,
          address: '${120 + i * 8} Fellowship Way, Suite ${i + 1}',
        ),
      );
    }
    return meetings;
  }
}
