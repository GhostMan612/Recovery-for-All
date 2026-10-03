// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meeting_finder_service.dart';

class MeetingRadiusPrefs {
  MeetingRadiusPrefs._();
  // Aliases of the three key names above. `MeetingRadiusNotifier` referenced
  // MeetingRadiusKeys.lat/lng/time, which do not exist — the restore path could
  // not have compiled if it were reached, and silently never was. These point
  // at the single owner of each string so the two spellings cannot drift.
  static const String lat = latKey;
  static const String lng = lngKey;
  static const String time = timeKey;
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

/// Whether a cached fix is good enough to run a RADIUS filter with.
///
/// Deliberately a different, much longer window than [isCacheFresh]. The two
/// answer different questions:
///
///   * "is this fix precise *right now*" — 24 h is the right answer for anything
///     that claims to know where the user is at this instant.
///   * "is this fix near enough to answer *which meetings are walkable*" — a
///     person's home does not move 300 miles in a day, and a month-old fix is
///     still a far better basis for "within 2 mi" than falling back to
///     statewide results.
///
/// The dashboard's meeting card used [isCacheFresh] for the second question,
/// which meant a user who opened the app more than a day after their last
/// successful fix silently got every meeting in the state with NO label saying
/// so — the exact bug a tester filed as "the card shows statewide meetings
/// instead of local 2-mile meetings". Thirty days keeps a genuine error
/// (user who moved cities) working while removing the daily false negative.
bool isLocationUsableForRadius(int? epochMs, {int maxAgeDays = 30}) {
  if (epochMs == null) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  return (now - epochMs) < maxAgeDays * 24 * 60 * 60 * 1000;
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
({List<RecoveryMeeting> meetings, String? tierLabel}) applyRadiusTiers(
  List<RecoveryMeeting> meetings,
  ll.LatLng? userLoc, {
  bool enforceRadius = true,
  double? radiusMiles,
}) {
  if (meetings.isEmpty) {
    return (meetings: meetings, tierLabel: null);
  }
  // Order matters and is not arbitrary. `enforceRadius` is a SETTING the user
  // owns, so it is reported first — a user who deliberately turned the filter
  // off needs to know that is why the list is statewide. Only then does a null
  // location get reported, because a null location is a MISSING FIX rather than
  // a choice.
  //
  // An earlier version took `locationKnown` as a parameter, which was
  // contradictory: it could be passed as true alongside a null `userLoc`, and
  // the honest answer to "is the location known" when `userLoc` is null is no.
  if (!enforceRadius) {
    return (meetings: meetings, tierLabel: 'Statewide — radius filter off');
  }
  if (userLoc == null) {
    // Both branches used to say the same thing, so a user whose location had
    // never been acquired saw an unexplained statewide list with no reason to
    // suspect a setting.
    return (meetings: meetings, tierLabel: 'Statewide — no location yet');
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
      // Say what to do about it. The previous label told the user what happened
      // but not that there is a control they own — and the control (a long-press
      // on this very card) is undiscoverable, which is the other half of why
      // this went unnoticed.
      tierLabel: 'Nothing within $miles mi — hold this card to widen, or open the map',
    );
  }
  return (meetings: within, tierLabel: 'Within $miles mi · hold to widen');
}
