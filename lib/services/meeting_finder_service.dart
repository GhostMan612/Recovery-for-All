// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/meeting_finder_service.dart

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  bool get hasLocation => latitude != 0 || longitude != 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'time': time,
        'address': address,
      };

  factory RecoveryMeeting.fromJson(Map<String, dynamic> j) => RecoveryMeeting(
        id: j['id'] as String,
        name: j['name'] as String,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        type: j['type'] as String? ?? '',
        time: j['time'] as String? ?? '',
        address: j['address'] as String? ?? '',
      );
}

/// Real meeting directory backed by the two open standards the recovery
/// community already publishes:
///
///  * Meeting Guide / TSML JSON spec (Code for Recovery) — used by AA
///    intergroups and also emitted natively by BMLT root servers v4+.
///  * BMLT aggregator (`client_interface/tsml/?switcher=GetSearchResults`)
///    which federates ~85% of Narcotics Anonymous meetings worldwide.
///
/// Everything downloaded is cached locally so the finder keeps working
/// fully offline. A tiny synthetic sample remains as a last-resort fallback.
class MeetingFinderService {
  static const String _keySources = 'meeting_sources_v1';
  static const String _keyCache = 'meeting_cache_v1';
  static const String _keyCacheStamp = 'meeting_cache_stamp_v1';
  static const Duration cacheTtl = Duration(hours: 24);

  /// Verified live feeds speaking the Meeting Guide spec.
  static const List<String> defaultSources = [
    // Code for Recovery sample sheet feed (AA demo dataset).
    'https://sheets.code4recovery.org/storage/12Ga8uwMG4WJ8pZ_SEU7vNETp_aQZ-2yNVsYDFqIwHyE.json',
    // BMLT aggregator — NA meetings worldwide (geo-filtered per request).
    'https://aggregator.bmltenabled.org/main_server/client_interface/tsml/?switcher=GetSearchResults',
  ];

  static const String _bmltMarker = 'switcher=GetSearchResults';

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  Future<List<String>> getSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySources);
    if (raw == null) return List<String>.from(defaultSources);
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      return list.isEmpty ? List<String>.from(defaultSources) : list;
    } catch (_) {
      return List<String>.from(defaultSources);
    }
  }

  Future<void> setSources(List<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySources, jsonEncode(urls));
  }

  Future<DateTime?> lastRefreshed() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyCacheStamp);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Meetings sorted by distance to (lat, lng). Online / ungeocoded meetings
  /// are kept and listed after the located ones. Falls back to the built-in
  /// sample directory when nothing is cached and the network fails.
  Future<List<RecoveryMeeting>> findNearbyMeetings(double lat, double lng) async {
    var meetings = await _cachedMeetings();

    if (meetings.isEmpty) {
      try {
        meetings = await refresh(lat: lat, lng: lng);
      } catch (_) {
        meetings = const <RecoveryMeeting>[];
      }
    } else {
      final stamp = await lastRefreshed();
      if (stamp == null ||
          DateTime.now().difference(stamp) > cacheTtl) {
        // Refresh opportunistically for next time; never block the UI.
        () async {
          try {
            await refresh(lat: lat, lng: lng);
          } catch (_) {}
        }();
      }
    }

    if (meetings.isEmpty) {
      return sampleDirectory(lat, lng);
    }
    return sortByDistance(meetings, lat, lng);
  }

  /// Downloads every enabled source and rebuilds the local cache.
  Future<List<RecoveryMeeting>> refresh({double? lat, double? lng}) async {
    final sources = await getSources();
    final all = <String, RecoveryMeeting>{};

    for (final url in sources) {
      try {
        final uri = _buildUri(url, lat: lat, lng: lng);
        final response =
            await http.get(uri, headers: {'Accept': 'application/json'}).timeout(
          const Duration(seconds: 25),
        );
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! List) continue;
        for (final m in parseTsmlFeed(decoded)) {
          all[m.id] = m;
        }
      } catch (_) {
        // One bad source must not sink the others.
      }
    }

    final meetings = all.values.toList();
    if (meetings.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyCache,
        jsonEncode([for (final m in meetings) m.toJson()]),
      );
      await prefs.setInt(
        _keyCacheStamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    return meetings;
  }

  // ------------------------------------------------------------------
  // Parsing (Meeting Guide / TSML spec — shared by AA feeds and BMLT v4+)
  // ------------------------------------------------------------------

  static const List<String> _weekdays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  static const Map<String, String> _typeCodes = {
    'O': 'Open',
    'C': 'Closed',
    'B': 'Big Book',
    'M': 'Men',
    'W': 'Women',
    'Y': 'Young People',
    'LGBTQ': 'LGBTQ+',
    'D': 'Discussion',
    'S': 'Speaker',
    'ST': 'Step Study',
    'T': 'Tradition Study',
    'BI': 'Beginner',
    'LOC': 'In Person',
    'ONL': 'Online',
    'VAR': 'Video',
    'TC': 'Phone',
  };

  Uri _buildUri(String sourceUrl, {double? lat, double? lng}) {
    final isBmlt = sourceUrl.contains(_bmltMarker);
    if (isBmlt && lat != null && lng != null) {
      final sep = sourceUrl.contains('?') ? '&' : '?';
      return Uri.parse(
        '$sourceUrl${sep}lat_val=$lat&long_val=$lng&geo_width=100',
      );
    }
    return Uri.parse(sourceUrl);
  }

  List<RecoveryMeeting> parseTsmlFeed(List<dynamic> items) {
    final out = <RecoveryMeeting>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      // Coordinates: newer feeds nest them; others expose flat keys.
      double? lat;
      double? lng;
      final coords = raw['coordinates'];
      if (coords is Map) {
        lat = _asDouble(coords['latitude']);
        lng = _asDouble(coords['longitude']);
      }
      lat ??= _asDouble(raw['latitude']);
      lng ??= _asDouble(raw['longitude']);

      // Time label: "Mon · 6:30 PM".
      final dayIndex = _firstDay(raw['day']);
      final timeLabel = _formatTime(raw['time'] as String?);
      final parts = <String>[
        if (dayIndex != null) _weekdays[dayIndex],
        ?timeLabel,
      ];
      final time = parts.isNotEmpty ? parts.join(' · ') : 'By appointment';

      final conferenceUrl = raw['conference_url'] as String?;
      final types = (raw['types'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      final isOnline = (conferenceUrl != null && conferenceUrl.isNotEmpty) ||
          types.any((t) => t == 'ONL' || t == 'VAR' || t == 'TC');

      final typeLabels = <String>[
        if (isOnline) 'Online',
        for (final t in types)
          if (_typeCodes[t] != null &&
              !(isOnline && (t == 'ONL' || t == 'VAR' || t == 'TC')))
            _typeCodes[t]!,
      ];
      final region = (raw['region'] as String?) ??
          ((raw['regions'] as List?)?.isNotEmpty == true
              ? raw['regions'].first.toString()
              : null);
      final type = typeLabels.isNotEmpty
          ? typeLabels.take(3).join(' · ')
          : (region ?? 'Meeting');

      final addressParts = <String>[
        if ((raw['address'] as String?)?.isNotEmpty == true)
          raw['address'].toString(),
        if ((raw['city'] as String?)?.isNotEmpty == true)
          raw['city'].toString(),
        if ((raw['state'] as String?)?.isNotEmpty == true)
          raw['state'].toString(),
      ];
      final formattedAddress = raw['formatted_address'] as String?;
      final address = addressParts.isNotEmpty
          ? addressParts.join(', ')
          : (formattedAddress ?? region ?? '');

      out.add(RecoveryMeeting(
        id: (raw['slug'] as String?) ??
            (raw['id']?.toString()) ??
            'm_${name.hashCode}',
        name: name,
        latitude: lat ?? 0,
        longitude: lng ?? 0,
        type: type,
        time: time,
        address: address,
      ));
    }
    return out;
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _firstDay(dynamic day) {
    if (day is int && day >= 0 && day <= 6) return day;
    if (day is List && day.isNotEmpty) {
      final v = day.first;
      if (v is int && v >= 0 && v <= 6) return v;
      if (v is String) return int.tryParse(v);
    }
    if (day is String) return int.tryParse(day);
    return null;
  }

  static String? _formatTime(String? hhmm) {
    if (hhmm == null || hhmm.length < 4) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (h == null || h > 23) return null;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  // ------------------------------------------------------------------
  // Cache + helpers
  // ------------------------------------------------------------------

  Future<List<RecoveryMeeting>> _cachedMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCache);
    if (raw == null) return const <RecoveryMeeting>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => RecoveryMeeting.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <RecoveryMeeting>[];
    }
  }

  List<RecoveryMeeting> sortByDistance(
    List<RecoveryMeeting> meetings,
    double lat,
    double lng,
  ) {
    double dist(RecoveryMeeting m) =>
        distanceKm(lat, lng, m.latitude, m.longitude);
    final sorted = [...meetings];
    sorted.sort((a, b) {
      if (a.hasLocation && b.hasLocation) {
        return dist(a).compareTo(dist(b));
      }
      if (a.hasLocation) return -1;
      if (b.hasLocation) return 1;
      return a.time.compareTo(b.time);
    });
    return sorted;
  }

  double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180.0;

  /// Built-in synthetic fallback (SAMPLE data only) for cold offline start.
  static List<RecoveryMeeting> sampleDirectory(double lat, double lng) {
    const templates = [
      {'name': 'SAMPLE Sunrise Serenity', 'type': 'AA · Open Discussion', 'time': 'Daily · 7:00 AM'},
      {'name': 'SAMPLE New Beginnings', 'type': 'NA · Step Study', 'time': 'Mon & Thu · 6:30 PM'},
      {'name': 'SAMPLE Midday Reset', 'type': 'SMART · CBT Tools', 'time': 'Tue & Fri · 12:15 PM'},
      {'name': 'SAMPLE Still Water Sangha', 'type': 'Dharma · Meditation', 'time': 'Wed · 6:00 PM'},
      {'name': 'SAMPLE Four Directions Circle', 'type': 'Wellbriety · Medicine Wheel', 'time': 'Sun · 4:00 PM'},
      {'name': 'SAMPLE Open Hearts Group', 'type': 'AA · Speaker Meeting', 'time': 'Sat · 8:00 PM'},
      {'name': 'SAMPLE Evening Anchors', 'type': 'NA · Open Discussion', 'time': 'Nightly · 9:00 PM'},
      {'name': 'SAMPLE Secular Path', 'type': 'Secular · Check-in', 'time': 'Thu · 7:30 PM'},
    ];
    return [
      for (var i = 0; i < templates.length; i++)
        RecoveryMeeting(
          id: 'sample_meeting_$i',
          name: templates[i]['name']!,
          latitude: lat + 0.014 * ((i % 5) - 2) + i * 0.0011,
          longitude: lng + 0.011 * ((i % 3) - 1) - i * 0.0009,
          type: templates[i]['type']!,
          time: templates[i]['time']!,
          address: '${120 + i * 8} Fellowship Way, Suite ${i + 1}',
        ),
    ];
  }
}
