// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meeting_finder_service.dart';

class MeetingRadiusPrefs {
  MeetingRadiusPrefs._();
  static const String latKey = 'last_known_location_lat_v1';
  static const String lngKey = 'last_known_location_lng_v1';
  static const String timeKey = 'last_known_location_time_v1';
  static const String enforceKey = 'dashboard_enforce_radius_v1';
  /// Search radius in MILES. Persisted so the dashboard's "In progress now"
  /// card and the meeting map agree. Before this existed the radius lived as a
  /// local field on MeetingMapScreen, so setting 2 mi there silently did
  /// nothing to the dashboard, which fell back to its own invented tiers.
  static const String radiusMilesKey = 'meeting_search_radius_miles_v1';

  static const double defaultRadiusMiles = 2.0;
  static const double minRadiusMiles = 1.0;
  static const double maxRadiusMiles = 50.0;

  static double sanitizeRadiusMiles(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return defaultRadiusMiles;
    return value.clamp(minRadiusMiles, maxRadiusMiles);
  }
}

bool isCacheFresh(int? epochMs, {int maxAgeHours = 24}) {
  if (epochMs == null) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  return (now - epochMs) < maxAgeHours * 60 * 60 * 1000;
}

double calculateSortScore(double distanceKm, int minutesUntilStart) {
  final m = minutesUntilStart < 0 ? 0 : minutesUntilStart;
  return distanceKm + (m / 60.0) * 3.0;
}

Future<void> cacheLocation(double lat, double lng) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(MeetingRadiusPrefs.latKey, lat);
  await prefs.setDouble(MeetingRadiusPrefs.lngKey, lng);
  await prefs.setInt(MeetingRadiusPrefs.timeKey, DateTime.now().millisecondsSinceEpoch);
}

int _minutesFor(RecoveryMeeting m, DateTime now) {
  if (MeetingFinderService.isInProgress(m, now)) return 0;
  final next = MeetingFinderService.nextOccurrence(m, now);
  if (next == null) return 1 << 30;
  final d = next.difference(now).inMinutes;
  return d < 0 ? 0 : d;
}

List<RecoveryMeeting> sortMeetings(
  List<RecoveryMeeting> meetings,
  ll.LatLng userLoc,
  DateTime now,
) {
  const distance = ll.Distance();
  final rows = <({RecoveryMeeting m, double score, int minutes, double km})>[];
  for (final m in meetings) {
    if (!m.hasLocation) {
      rows.add((m: m, score: double.infinity, minutes: 1 << 30, km: double.infinity));
      continue;
    }
    final km = distance.as(ll.LengthUnit.Kilometer, userLoc, ll.LatLng(m.latitude, m.longitude));
    final minutes = _minutesFor(m, now);
    rows.add((m: m, score: calculateSortScore(km, minutes), minutes: minutes, km: km));
  }
  rows.sort((a, b) {
    final c = a.score.compareTo(b.score);
    if (c != 0) return c;
    final d = a.minutes.compareTo(b.minutes);
    if (d != 0) return d;
    return a.km.compareTo(b.km);
  });
  return [for (final r in rows) r.m];
}

/// Filters [meetings] to those within [radiusMiles] of [userLoc].
///
/// The dashboard's "In progress now" card is a *local* tool for someone
/// deciding whether to walk to a meeting right now, so a meeting 30 miles out
/// is not a useful suggestion no matter how well it matches the time filter.
/// This previously returned whole hardcoded tiers (25/50/100 km) and, when
/// nothing was nearby, fell through to returning the ENTIRE input list — which
/// is how the card came to advertise statewide meetings during a 2-mile search.
({List<RecoveryMeeting> meetings, String tierLabel}) applyRadiusTiers(
  List<RecoveryMeeting> meetings,
  ll.LatLng? userLoc, {
  bool enforceRadius = true,
  double? radiusMiles,
}) {
  if (userLoc == null || !enforceRadius || meetings.isEmpty) {
    return (meetings: meetings, tierLabel: 'Statewide');
  }

  final miles = MeetingRadiusPrefs.sanitizeRadiusMiles(radiusMiles);
  final maxKm = miles * 1.60934;
  const distance = ll.Distance();
  double kmOf(RecoveryMeeting m) =>
      distance.as(ll.LengthUnit.Kilometer, userLoc, ll.LatLng(m.latitude, m.longitude));

  final within = meetings.where((m) => m.hasLocation && kmOf(m) <= maxKm).toList();
  if (within.isEmpty) {
    return (
      meetings: const [],
      tierLabel: 'No meetings within $miles mi — widen the radius to see more',
    );
  }
  return (meetings: within, tierLabel: 'Within $miles mi');
}
