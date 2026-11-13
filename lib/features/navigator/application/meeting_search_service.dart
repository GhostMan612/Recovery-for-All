// lib/features/navigator/application/meeting_search_service.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;
import '../../../../services/meeting_finder_service.dart';

/// Representation of a scored meeting search match.
class MeetingSearchResult {
  final RecoveryMeeting meeting;
  final int score;
  final double? distanceKm;

  const MeetingSearchResult({
    required this.meeting,
    required this.score,
    this.distanceKm,
  });
}

/// Offline-first, fast in-memory search service across cached recovery meetings.
///
/// Supports searching across meeting name, fellowship acronym/name, street address,
/// city, and day of week with multi-word cross-field matching and lightweight ranking.
class MeetingSearchService {
  static const Map<int, List<String>> _daySynonyms = {
    0: ['sunday', 'sun'],
    1: ['monday', 'mon'],
    2: ['tuesday', 'tue', 'tues'],
    3: ['wednesday', 'wed'],
    4: ['thursday', 'thu', 'thur', 'thurs'],
    5: ['friday', 'fri'],
    6: ['saturday', 'sat'],
  };

  static const Map<String, List<String>> _fellowshipSynonyms = {
    'aa': ['aa', 'alcoholics anonymous', '12 step', '12-step'],
    'na': ['na', 'narcotics anonymous'],
    'cma': ['cma', 'crystal meth anonymous'],
    'ca': ['ca', 'cocaine anonymous'],
    'oa': ['oa', 'overeaters anonymous'],
    'smart': ['smart', 'smart recovery'],
    'dharma': ['dharma', 'recovery dharma', 'buddhist'],
    'alanon': ['alanon', 'al-anon', 'al anon', 'alateen'],
    'allrecovery': ['all recovery', 'allrecovery', 'all-recovery', 'secular'],
    'lifering': ['lifering', 'life ring', 'life-ring'],
    'wfs': ['wfs', 'women for sobriety'],
    'cr': ['cr', 'celebrate recovery'],
    'intherooms': ['in the rooms', 'intherooms', 'itr'],
  };

  /// Calculates Haversine distance in kilometers between two coordinate pairs.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Day name string for a given day index (0 = Sunday ... 6 = Saturday).
  static String formatDayName(int? day) {
    switch (day) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Schedule varies';
    }
  }

  /// Extracts city name from meeting address.
  static String extractCity(RecoveryMeeting meeting) {
    if (meeting.address.startsWith('Online')) return 'Online';
    final parts = meeting.address.split(',').map((e) => e.trim()).toList();
    for (final part in parts) {
      if (part.endsWith(', MN') || part == 'MN') {
        final idx = parts.indexOf(part);
        if (idx > 0) return parts[idx - 1];
      }
    }
    final mn = parts.where((p) => p.contains('MN')).toList();
    if (mn.isNotEmpty) {
      final i = parts.indexOf(mn.first);
      if (i > 0) return parts[i - 1];
    }
    return '';
  }

  /// Searches [meetings] matching [query].
  ///
  /// For multi-word queries, every term must match across at least one field of the meeting
  /// (e.g. `"Tuesday AA"` matches meeting with day=Tuesday and fellowship=AA).
  static List<MeetingSearchResult> search({
    required String query,
    required List<RecoveryMeeting> meetings,
    double? userLat,
    double? userLon,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final terms = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return const [];

    final results = <MeetingSearchResult>[];

    for (final meeting in meetings) {
      final match = _evaluateMeeting(
        meeting: meeting,
        cleanQuery: cleanQuery,
        terms: terms,
        userLat: userLat,
        userLon: userLon,
      );
      if (match != null) {
        results.add(match);
      }
    }

    // Sort by descending score, then ascending distance
    results.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      if (a.distanceKm != null && b.distanceKm != null) {
        return a.distanceKm!.compareTo(b.distanceKm!);
      }
      return 0;
    });

    return results;
  }

  static MeetingSearchResult? _evaluateMeeting({
    required RecoveryMeeting meeting,
    required String cleanQuery,
    required List<String> terms,
    double? userLat,
    double? userLon,
  }) {
    final nameLower = meeting.name.toLowerCase();
    final addressLower = meeting.address.toLowerCase();
    final cityLower = extractCity(meeting).toLowerCase();
    final fellowshipCode = meeting.fellowship.toLowerCase();
    final fellowshipDisplay = meeting.fellowshipEnum.displayName.toLowerCase();
    final fellowshipWords = fellowshipDisplay.split(RegExp(r'[\s\-/]+'));
    final fellowshipSyns = _fellowshipSynonyms[meeting.fellowshipEnum.code.toLowerCase()] ?? [];
    final daySyns = meeting.day != null ? (_daySynonyms[meeting.day] ?? []) : <String>[];
    final timeLower = meeting.time.toLowerCase();

    // Verification: EVERY term must match at least one field
    for (final term in terms) {
      final matchesName = nameLower.contains(term);
      final matchesAddress = addressLower.contains(term) || cityLower.contains(term);
      final matchesFellowship = fellowshipCode == term ||
          fellowshipWords.any((w) => w == term || w.startsWith(term) || (term.length >= 4 && w.contains(term))) ||
          fellowshipSyns.any((s) => s == term || s.startsWith(term) || (term.length >= 3 && term.startsWith(s)));
      final matchesDay = daySyns.any((s) => s.startsWith(term) || term.startsWith(s));
      final matchesTime = timeLower.contains(term);

      if (!matchesName && !matchesAddress && !matchesFellowship && !matchesDay && !matchesTime) {
        return null; // Term missed all fields -> excluded
      }
    }

    // Ranking Score computation
    var score = 0;

    // 1. Exact meeting-name match
    if (nameLower == cleanQuery) {
      score += 1000;
    }
    // 2. Meeting-name prefix match
    else if (nameLower.startsWith(cleanQuery)) {
      score += 500;
    }
    // 3. Meeting-name substring match
    else if (nameLower.contains(cleanQuery)) {
      score += 300;
    }

    // Term-by-term scoring
    for (final term in terms) {
      if (nameLower.contains(term)) {
        score += 100;
      }
      if (addressLower.contains(term) || cityLower.contains(term)) {
        score += 60;
      }
      if (fellowshipCode == term ||
          fellowshipWords.any((w) => w == term || w.startsWith(term)) ||
          fellowshipSyns.any((s) => s == term || s.startsWith(term))) {
        score += 40;
      }
      if (daySyns.any((s) => s.startsWith(term) || term.startsWith(s))) {
        score += 30;
      }
      if (timeLower.contains(term)) {
        score += 15;
      }
    }

    // Distance calculation & subtle proximity boost (tiebreaker)
    double? distKm;
    if (userLat != null && userLon != null && meeting.hasLocation) {
      distKm = _haversineKm(userLat, userLon, meeting.latitude, meeting.longitude);
      // Small proximity bonus up to 10 points for closer meetings
      score += (10.0 / (1.0 + distKm * 0.1)).round();
    }

    return MeetingSearchResult(
      meeting: meeting,
      score: score,
      distanceKm: distKm,
    );
  }
}
