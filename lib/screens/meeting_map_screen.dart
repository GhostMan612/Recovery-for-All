// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/meeting_radius_logic.dart';
import '../core/dashboard_providers.dart' show meetingRadiusProvider;
import '../database/recovery_database.dart';
import '../services/meeting_finder_service.dart';
import '../services/map_tile_cache.dart';
import '../services/recovery_pet_service.dart';
import '../services/constellation_service.dart';
import '../widgets/app_primitives.dart';

/// Meeting finder — keyless OSM map (flutter_map) with Sovereign-grade
/// controls: layer switcher (dark/light/satellite/topo), radius slider,
/// city filter, live/upcoming color tiers, compass + re-center, and a
/// live weather chip (Open-Meteon, keyless).
///
/// ConsumerStatefulWidget so the radius slider can publish to
/// [meetingRadiusProvider]; the dashboard's "In progress now" card reads the
/// same value. While this was a local field, the two surfaces could not agree
/// and the card quietly showed statewide meetings during a 2-mile search.
class MeetingMapScreen extends ConsumerStatefulWidget {
  final List<RecoveryMeeting> initialMeetings;
  final RecoveryDatabase? database;

  const MeetingMapScreen({
    super.key,
    required this.initialMeetings,
    this.database,
  });

  @override
  ConsumerState<MeetingMapScreen> createState() => _MeetingMapScreenState();
}

// ---- layer definitions (Sovereign Mantle pattern: independent toggles) ----

class _MapLayer {
  final String id;
  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  const _MapLayer(this.id, this.label, this.urlTemplate,
      {this.subdomains = const []});
}

class _MeetingMapScreenState extends ConsumerState<MeetingMapScreen> {
  final MapController _mapController = MapController();

  /// Resolved device position as (lat, lng); null until a fix lands.
  /// (Plain record — Position's many required fields aren't needed.)
  (double, double)? _currentPosition;
  bool _isLoading = true;
  String _loadStage = 'Finding you…';
  bool _showMapView = false;

  // Filters. Seeded from the shared provider in initState so the map opens
  // showing the radius the dashboard is already using.
  late double _radiusMi = MeetingRadiusPrefs.defaultRadiusMiles;
  String _cityFilter = 'All';
  bool _showAllTime = false;
  List<RecoveryMeeting> _base = [];
  String? _loadError;

  // Layers — Sovereign Mantle pattern: independent toggles, stackable.
  // First active layer = base; subsequent = overlays rendered on top.
  final Set<String> _activeLayers = {'osm'}; // Default to OSM instead of dark

  static const List<_MapLayer> _availableLayers = [
    // Esri Canvas (keyless, no API key required) - replaces Carto
    _MapLayer('dark', 'Dark',
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'),
    _MapLayer('light', 'Light',
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}'),
    _MapLayer('sat', 'Satellite',
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
    _MapLayer('topo', 'Topo', 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
        subdomains: ['a', 'b', 'c']),
    _MapLayer('osm', 'OSM', 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: ['a', 'b', 'c']),
  ];

  String? _weatherChip;
  String _locationDebug = '';
  bool _downloading = false;
  List<Marker> _cachedMarkers = [];
  List<Marker> _userMarkers = [];
  List<Marker> _meetingMarkers = [];

  static const double _maxRadiusMi = MeetingRadiusPrefs.maxRadiusMiles;
  static const double _miToKm = 1.60934;

  @override
  void initState() {
    super.initState();
    // Adopt the persisted radius. Safe in initState: Riverpod's ref is
    // available there, and setRadiusMiles only guards against a no-op write.
    _radiusMi = ref.read(meetingRadiusProvider).radiusMiles;
    _initialize();
  }

  // ------------------------------------------------------------------
  // Init + location
  // ------------------------------------------------------------------

  Future<void> _initialize() async {
    // Staged loading: the screen must always *feel* alive — each stage
    // shows for at least 400 ms so it never flashes by unreadably.
    await _stage('Finding you…');
    final (lat, lng) = await _resolveLocation();
    // Store the fix so _me (user pin, distances, recenter) comes alive.
    _currentPosition = (lat, lng);
    if (mounted) setState(() {});
    await _stage('Fetching meetings…');
    await _load(lat, lng);
    await _stage('Rendering map');
  }

  /// Shows [label] as the load stage, holding it on screen >= 400 ms.
  Future<void> _stage(String label) async {
    final sw = Stopwatch()..start();
    if (mounted) setState(() => _loadStage = label);
    final floor = const Duration(milliseconds: 400) - sw.elapsed;
    if (floor > Duration.zero) await Future<void>.delayed(floor);
  }

  Future<(double, double)> _resolveLocation({bool forceFresh = false}) async {
    try {
      // Location SERVICES off (GPS toggle) is not a permission problem —
      // surface it distinctly instead of a generic failure.
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          setState(() =>
              _locationDebug = 'Location services OFF — enable GPS and retry');
        }
        return const (44.9778, -93.2650);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        // Only the OS app-settings page can undo this one.
        await Geolocator.openAppSettings();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationDebug = 'Permission: $permission');
        }
        return const (44.9778, -93.2650);
      }

      // Fast path: last-known position (instant if GPS was used recently).
      // Skipped on explicit recenter — the user asked for a FRESH fix.
      if (!forceFresh) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().millisecondsSinceEpoch -
                    last.timestamp.millisecondsSinceEpoch <
                5 * 60 * 1000) {
          if (mounted) {
            setState(() => _locationDebug =
                'Last known: ${last.latitude.toStringAsFixed(4)}, ${last.longitude.toStringAsFixed(4)}');
          }
          unawaited(cacheLocation(last.latitude, last.longitude));
          return (last.latitude, last.longitude);
        }
      }

      // Cold GPS fix — generous timeout for first lock.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() => _locationDebug =
            'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
      }
      unawaited(cacheLocation(pos.latitude, pos.longitude));
      return (pos.latitude, pos.longitude);
    } catch (e) {
      // Fresh fix failed (cold GPS, timeout, etc). A STALE fix still
      // beats dropping the user in Minneapolis — cascade before giving up.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final ageMin =
              DateTime.now().difference(last.timestamp).inMinutes;
          if (mounted) {
            setState(() => _locationDebug =
                'Stale fix (${ageMin}m old): ${last.latitude.toStringAsFixed(4)}, ${last.longitude.toStringAsFixed(4)} — tap for details');
          }
          unawaited(cacheLocation(last.latitude, last.longitude));
          return (last.latitude, last.longitude);
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _locationDebug = 'GPS FAILED: $e — tap for details');
      }
      return const (44.9778, -93.2650);
    }
  }

  Future<void> _load(double lat, double lng) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      _base = await _fetch(lat, lng);
    } catch (e) {
      _loadError = 'Could not load directory — cached/sample data shown.';
    }
    if (mounted) setState(() => _isLoading = false);
    _rebuildMarkers();
    if (_showMapView) _loadWeather();
  }

  Future<List<RecoveryMeeting>> _fetch(double lat, double lng) async {
    return MeetingFinderService().findNearbyMeetings(
      lat,
      lng,
      radiusKm: _radiusMi * _miToKm, // Use current radius filter
      upcomingOnly: !_showAllTime,
    );
  }

  // ------------------------------------------------------------------
  // Derived data
  // ------------------------------------------------------------------

  (double, double)? get _me => _currentPosition;

  double _distanceMi(RecoveryMeeting m, (double, double) me) {
    if (!m.hasLocation) return double.infinity;
    return MeetingFinderService()
            .distanceKm(me.$1, me.$2, m.latitude, m.longitude) /
        _miToKm;
  }

  String? _cityOf(RecoveryMeeting m) {
    if (m.address.startsWith('Online')) return 'Online';
    final parts = m.address.split(',').map((e) => e.trim()).toList();
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
    return null;
  }

  List<String> get _cityOptions {
    final counts = <String, int>{};
    for (final m in _base) {
      final city = _cityOf(m);
      if (city != null && city.isNotEmpty) counts[city] = (counts[city] ?? 0) + 1;
    }
    final cities = counts.keys.toList()..sort();
    return ['All', ...cities];
  }

  List<RecoveryMeeting> get _visible {
    final me = _me;
    return _base.where((m) {
      final city = _cityOf(m) ?? 'Unknown';
      if (_cityFilter != 'All' && city != _cityFilter) return false;
      if (m.hasLocation && me != null) return _distanceMi(m, me) <= _radiusMi;
      return true;
    }).toList();
  }

  // ------------------------------------------------------------------
  // Weather
  // ------------------------------------------------------------------

  Future<void> _loadWeather() async {
    try {
      final me = _me;
      final lat = me?.$1 ?? 44.9778;
      final lng = me?.$2 ?? -93.2650;
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code&temperature_unit=fahrenheit');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).round();
      final code = current['weather_code'] as int? ?? 0;
      if (!mounted) return;
      setState(() => _weatherChip = '${_weatherEmoji(code)} $temp°F');
    } catch (_) {}
  }

  String _weatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    return '⛈️';
  }

  // ------------------------------------------------------------------
  // Map controls
  // ------------------------------------------------------------------

  Future<void> _recenter() async {
    // Explicit recenter = fresh GPS fix, never the stale cache.
    final (lat, lng) = await _resolveLocation(forceFresh: true);
    setState(() => _currentPosition = (lat, lng));
    _rebuildMarkers(); // user pin + distances recompute
    _mapController.move(ll.LatLng(lat, lng), 14);
  }

  void _resetNorth() {
    try {
      _mapController.rotate(0);
    } catch (_) {}
  }

  ll.LatLng get _mapCenter => _me != null
      ? ll.LatLng(_me!.$1, _me!.$2)
      : _firstPinOrTwinCities();

  ll.LatLng _firstPinOrTwinCities() {
    for (final m in _visible) {
      if (m.hasLocation) return ll.LatLng(m.latitude, m.longitude);
    }
    return const ll.LatLng(44.9778, -93.2650);
  }

  // ------------------------------------------------------------------
  // Directions + attendance
  // ------------------------------------------------------------------

  Future<void> _openDirections(RecoveryMeeting meeting) async {
    final Uri uri;
    if (meeting.hasLocation) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${meeting.latitude},${meeting.longitude}');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(meeting.address)}');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _joinZoomMeeting(String url) async {
    try {
      final uri = Uri.parse(url);
      // Zoom deep-link: externalApplication routes to OS Intent Resolver
      // which auto-opens Zoom app and passes conference ID directly.
      if (url.contains('zoom.us/j/')) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _logAttended(RecoveryMeeting meeting) async {
    final now = DateTime.now();

    // Time-window validation: must be within ±30 minutes of scheduled start time
    if (meeting.isDated) {
      final nextOcc = MeetingFinderService.nextOccurrence(meeting, now);
      if (nextOcc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: const Text(
              'Unable to determine meeting schedule. Please try again later.',
            ),
          ),
        );
        return;
      }
      final diff = now.difference(nextOcc).abs();
      if (diff > const Duration(minutes: 30)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: const Text(
              'You can only check in within 30 minutes of the meeting\'s scheduled time.',
            ),
          ),
        );
        return;
      }
    }

    // Geo-verification: must be within 150m of meeting location + mock detection
    if (meeting.hasLocation) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 15));

        // Mock location detection (geolocator 14+)
        if (pos.isMocked) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              content: const Text(
                'Mock location detected. Please disable location spoofing.',
              ),
            ),
          );
          return;
        }

        const double maxDistanceMeters = 150.0;
        final distanceM = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          meeting.latitude,
          meeting.longitude,
        );
        if (distanceM > maxDistanceMeters) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              content: const Text(
                'You\'re a bit too far from this meeting to check in (within 150m required).',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: const Text(
              'Unable to verify location. Please enable GPS and try again.',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // Rule R3 Reflection Sheet — quick-tag chips + optional text
    final reflectionData = await _showReflectionSheet(meeting);
    if (reflectionData == null) return;

    final db = widget.database;
    if (db != null) {
      await db.addJournalEntry(JournalEntry(
        id: 'meeting_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 4,
        contentEncrypted:
            '[Meeting] ${meeting.name}: ${reflectionData.tag}${reflectionData.text.isNotEmpty ? ' — ${reflectionData.text}' : ''}',
        isSyncedToCloud: false,
      ));
    }
    final before = (await RecoveryPetService.ensureHatched()).sparks;
    await RecoveryPetService.logMeeting();
    if (db != null) {
      await ConstellationService.addMeetingStar(db, meetingName: meeting.name);
    }
    final delta = (await RecoveryPetService.ensureHatched()).sparks - before;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(delta > 0
            ? 'Reflection saved · +$delta Sparks'
            : 'Reflection saved · daily Sparks cap reached, and that is fine'),
      ),
    );
  }

  /// Rule R3: Quick-tag reflection sheet for meeting attendance
  Future<_ReflectionData?> _showReflectionSheet(RecoveryMeeting meeting) async {
    const tags = [
      'Listened & Supported',
      'Shared my truth',
      'Connected with a peer/sponsor',
      'Needed a safe space',
    ];
    String? selectedTag;
    final textController = TextEditingController();

    return showModalBottomSheet<_ReflectionData>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meeting Reflection',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                  'How did "${meeting.name}" feel today? Pick one, then add a note if you want.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag,
                          style: TextStyle(
                              fontSize: 13,
                              color: selectedTag == tag
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurfaceVariant)),
                      selected: selectedTag == tag,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      checkmarkColor: Colors.white,
                      onSelected: (on) {
                        setSheet(() => selectedTag = on ? tag : null);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 2,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'One takeaway from today… (optional)',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      disabledBackgroundColor: Theme.of(context).colorScheme.outlineVariant,
                      disabledForegroundColor: Theme.of(context).colorScheme.outline),
                  onPressed: selectedTag == null
                      ? null
                      : () => Navigator.pop(
                          sheetContext,
                          _ReflectionData(
                              tag: selectedTag!, text: textController.text.trim())),
                  child: const Text('Confirm Attendance (+8✦)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMeetingDetails(RecoveryMeeting meeting) {
    final now = DateTime.now();
    final live = MeetingFinderService.isInProgress(meeting, now);
    final label = MeetingFinderService.upcomingLabel(meeting, now);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meeting.name,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${live ? 'LIVE NOW · ' : ''}$label · ${meeting.type}',
                  style: TextStyle(
                      color: live ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: live ? FontWeight.bold : FontWeight.w500)),
              const SizedBox(height: 8),
              Text(meeting.address,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 16),
              if (widget.database != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.how_to_reg_outlined),
                    label: const Text('I attended — reflect'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _logAttended(meeting);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (meeting.conferenceUrl != null &&
                  meeting.conferenceUrl!.contains('zoom.us/j/')) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandZoom,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Join on Zoom'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _joinZoomMeeting(meeting.conferenceUrl!);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (meeting.seventhTraditionUrl != null &&
                  meeting.seventhTraditionUrl!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.pink,
                      side: BorderSide(
                          color: AppColors.pink.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Pass the Basket (7th Tradition)'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _launchExternal(
                          context, meeting.seventhTraditionUrl!, '7th Tradition');
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Get Directions'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openDirections(meeting);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // LAYERS sheet — base maps + overlays ONLY. No filters here.
  // ------------------------------------------------------------------

  void _openLayers() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Map Layers',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'Toggle multiple layers — they stack on top of each other.',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final layer in _availableLayers)
                      FilterChip(
                        label: Text(layer.label,
                            style: TextStyle(
                                fontSize: 13,
                                color: _activeLayers.contains(layer.id)
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurfaceVariant)),
                        selected: _activeLayers.contains(layer.id),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        checkmarkColor: Colors.white,
                        onSelected: (on) {
                          setSheet(() {
                            if (on) {
                              _activeLayers.add(layer.id);
                            } else if (_activeLayers.length > 1) {
                              _activeLayers.remove(layer.id);
                            }
                          });
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // FILTERS sheet — radius + city + time. NO layers here.
  // ------------------------------------------------------------------

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter Meetings',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text('Radius · ${_radiusMi.round()} mi',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                Slider(
                  value: _radiusMi,
                  min: MeetingRadiusPrefs.minRadiusMiles,
                  max: _maxRadiusMi,
                  divisions: 49,
                  activeColor: Theme.of(context).colorScheme.primary,
                  label: '${_radiusMi.round()} mi',
                  onChanged: (v) => setSheet(() => _radiusMi = v),
                  // Commit on release: writing SharedPreferences on every
                  // drag frame is wasted I/O, and the dashboard only needs the
                  // settled value.
                  onChangeEnd: (v) {
                    setState(() => _radiusMi = v);
                    unawaited(ref.read(meetingRadiusProvider.notifier).setRadiusMiles(v));
                  },
                ),
                const SizedBox(height: 8),
                Text('City / Area',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final city in _cityOptions)
                      ChoiceChip(
                        label: Text(city,
                            style: TextStyle(
                                fontSize: 12,
                                color: _cityFilter == city
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurfaceVariant)),
                        selected: _cityFilter == city,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        checkmarkColor: Colors.white,
                        onSelected: (_) {
                          setSheet(() => _cityFilter = city);
                          setState(() => _cityFilter = city);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show every meeting (all week)',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                  subtitle: Text('Off = live now + next 7 days only',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  value: _showAllTime,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (v) async {
                    setSheet(() => _showAllTime = v);
                    setState(() => _showAllTime = v);
                    final (lat, lng) = await _resolveLocation();
                    await _load(lat, lng);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Offline pack (P3)
  // ------------------------------------------------------------------

  Future<void> _startPrefetch() async {
    if (_downloading) return;
    final me = _me;
    final lat = me?.$1 ?? 44.9778;
    final lng = me?.$2 ?? -93.2650;
    setState(() => _downloading = true);
    var cancelled = false;
    var total = 0;
    var done = 0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: Text('Downloading offline pack',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Securing map tiles for ${_radiusMi.round()} mi around you.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                backgroundColor: Theme.of(context).colorScheme.track,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text('$done / $total tiles',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );

    final layerId = _activeLayers.first;
    final secured = await TilePrefetch.prefetchPack(
      layer: layerId,
      lat: lat,
      lng: lng,
      radiusKm: _radiusMi * 1.60934,
      zooms: const [11, 12, 13, 14, 15],
      onProgress: (d, t) {
        done = d;
        total = t;
      },
      isCancelled: () => cancelled || !mounted,
    );

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    setState(() => _downloading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(cancelled
            ? 'Pack paused · $secured tiles secured'
            : 'Pack complete · $secured tiles offline'),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Urgency color tiers
  // ------------------------------------------------------------------

  Color _pinColor(RecoveryMeeting m) {
    final now = DateTime.now();
    if (MeetingFinderService.isInProgress(m, now)) return Theme.of(context).colorScheme.tertiary;
    if (m.type.contains('Online')) return AppColors.pinOnline;
    final next = MeetingFinderService.nextOccurrence(m, now);
    if (next != null) {
      if (next.difference(now).inHours < 24) return AppColors.pinSoon;
    }
    return Theme.of(context).colorScheme.primary;
  }

  // ------------------------------------------------------------------
  // Markers
  // ------------------------------------------------------------------

  void _rebuildMarkers() {
    _cachedMarkers.clear();
    _userMarkers.clear();
    _meetingMarkers.clear();
    final markers = <Marker>[];
    final me = _me;
    if (me != null) {
      markers.add(Marker(
        key: const ValueKey('user_pin'),
        point: ll.LatLng(me.$1, me.$2),
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
          child: Icon(Icons.person_pin_circle,
              size: 14, color: Theme.of(context).colorScheme.onPrimary),
        ),
      ));
    }
    final now = DateTime.now();
    for (final m in _visible) {
      if (!m.hasLocation) continue;
      final color = _pinColor(m);
      final live = MeetingFinderService.isInProgress(m, now);
      markers.add(Marker(
        point: ll.LatLng(m.latitude, m.longitude),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showMeetingDetails(m),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                  color: live ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  width: live ? 2.2 : 1.4),
            ),
            child: Icon(
                m.type.contains('Online') ? Icons.videocam : Icons.groups_2,
                size: 15,
                color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ));
    }
    _cachedMarkers = markers;
    // Split into user pin + meeting pins for cluster layer.
    _userMarkers = markers
        .where((m) => m.key == const ValueKey('user_pin'))
        .toList();
    _meetingMarkers = markers
        .where((m) => m.key != const ValueKey('user_pin'))
        .toList();
  }

  // ------------------------------------------------------------------
  // Build — stacked tile layers from active set
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = _visible;
    final liveCount =
        visible.where((m) => MeetingFinderService.isInProgress(m, now)).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: const Text('Meeting Finder'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _showMapView ? 'Show list' : 'Show map',
            icon: Icon(
                _showMapView ? Icons.view_list_outlined : Icons.map_outlined,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: () {
              setState(() => _showMapView = !_showMapView);
              if (_showMapView) _loadWeather();
            },
          ),
        ],
      ),
        body: _isLoading
            ? _buildLoading()
            : _showMapView
                ? _buildMap(liveCount, visible)
              : _buildList(now, visible),
    );
  }

  /// Staged loading view: stage label + thin progress bar + skeleton rows.
  /// The point is *perceived* responsiveness — the user should never
  /// wonder whether the tap registered.
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_outlined,
              color: Theme.of(context).colorScheme.primary, size: 44),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _loadStage,
              key: ValueKey(_loadStage),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < 3; i++)
            Opacity(
              opacity: 0.55 - i * 0.15,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                width: 260,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(int liveCount, List<RecoveryMeeting> visible) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _me != null ? 12.0 : 9.0,
              // flutter_map's default is `InteractiveFlag.all`, which
              // INCLUDES a two-finger twist gesture. On a phone that gesture
              // competes with pinch-zoom, so a zoom that drifts even slightly
              // sideways snaps the map into a rotation nobody asked for — the
              // exact complaint from the closed-test testers. Strip rotate,
              // plus the desktop ctrl+drag path, which is a separate flag.
              // Panning and zooming are untouched: one-finger drag and
              // two-finger pinch both still work as users expect.
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                cursorKeyboardRotationOptions:
                    CursorKeyboardRotationOptions.disabled(),
              ),
            ),
            children: [
              for (final (index, layer) in _availableLayers.indexed)
                if (_activeLayers.contains(layer.id))
                  TileLayer(
                    urlTemplate: layer.urlTemplate,
                    subdomains: layer.subdomains.isEmpty
                        ? const ['a']
                        : layer.subdomains,
                    userAgentPackageName: 'com.recoveryforall',
                    keepBuffer: index == 0 ? 2 : 1,
                  ),
              MarkerLayer(
                markers: _userMarkers,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  maxZoom: 15,
                  markers: _meetingMarkers,
                  builder: (context, clusterMarkers) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2),
                    ),
                    child: Center(
                      child: Text('${clusterMarkers.length}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  onClusterTap: (cluster) => _mapController.move(
                      cluster.bounds.center,
                      _mapController.camera.zoom + 2),
                ),
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (_weatherChip != null)
          Positioned(left: 12, top: 12, child: _MapChip(label: _weatherChip!)),
        Positioned(
          left: 12,
          top: _weatherChip != null ? 52 : 12,
          child: _MapChip(
            label: '$liveCount live · ${visible.length} shown',
            color: liveCount > 0 ? Theme.of(context).colorScheme.tertiary : null,
          ),
        ),
        if (_locationDebug.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: _MapChip(
              label: _locationDebug,
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  title: Text('Location diagnostics',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                  content: SingleChildScrollView(
                    child: Text(_locationDebug,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text('Close',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapButton(
                  icon: Icons.explore_outlined,
                  tooltip: 'Reset north',
                  onTap: _resetNorth),
              const SizedBox(height: 8),
              _MapButton(
                  icon: Icons.my_location,
                  tooltip: 'Center on me',
                  onTap: _recenter),
              const SizedBox(height: 8),
              _MapButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Layers',
                  onTap: _openLayers),
              const SizedBox(height: 8),
              _MapButton(
                  icon: Icons.filter_list_outlined,
                  tooltip: 'Filter meetings',
                  onTap: _openFilters),
              const SizedBox(height: 8),
              _MapButton(
                  icon: _downloading
                      ? Icons.downloading
                      : Icons.download_outlined,
                  tooltip: _downloading
                      ? 'Offline pack, downloading'
                      : 'Offline pack',
                  // Was `() {}` while downloading, so the control announced
                  // as available and silently did nothing. null disables it.
                  onTap: _downloading ? null : () => _startPrefetch()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(DateTime now, List<RecoveryMeeting> visible) {
    if (_loadError != null) {
      return AppErrorState(
        icon: Icons.cloud_off,
        title: 'Could not load the meeting directory',
        message: _loadError,
        onRetry: _me != null ? () => _load(_me!.$1, _me!.$2) : null,
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text(
              _showAllTime
                  ? 'No meetings match these filters.'
                  : 'No meetings in the next 7 days.\nOpen filters to show every meeting.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text('Tap the tune icon above to adjust filters',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _MapChip(
                  label:
                      '${visible.length} meetings · ${_radiusMi.round()} mi${_cityFilter != 'All' ? ' · $_cityFilter' : ''}'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final meeting = visible[index];
              final live = MeetingFinderService.isInProgress(meeting, now);
              final label = MeetingFinderService.upcomingLabel(meeting, now);
              final color = _pinColor(meeting);
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        live
                            ? Icons.circle
                            : meeting.type.contains('Online')
                                ? Icons.videocam_outlined
                                : Icons.groups_2,
                        color: color,
                        size: live ? 14 : 24,
                      ),
                      if (live)
                        Text('LIVE',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  title: Text(meeting.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '$label · ${meeting.type}\n${meeting.address}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35)),
                  isThreeLine: true,
                  trailing: Icon(Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                  onTap: () => _showMeetingDetails(meeting),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Launches a URL in an external browser.
Future<void> _launchExternal(BuildContext context, String url, String label) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text('Could not open $label'),
      ),
    );
  }
}

/// Data returned from the Rule R3 reflection sheet.
class _ReflectionData {
  final String tag;
  final String text;
  const _ReflectionData({required this.tag, required this.text});
}

class _MapChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _MapChip({required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 120),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color ?? Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(label,
          maxLines: onTap != null ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11)),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _MapButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip,
            // 10px padding around a 20px icon is a 40x40 target; five of these
            // stack on the map edge, so they need the 48dp minimum.
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}
