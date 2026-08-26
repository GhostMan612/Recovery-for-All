// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/meeting_finder_service.dart';
import '../services/map_tile_cache.dart';
import '../services/recovery_pet_service.dart';

/// Meeting finder — keyless OSM map (flutter_map) with Sovereign-grade
/// controls: layer switcher (dark/light/satellite/topo), radius slider,
/// city filter, live/upcoming color tiers, compass + re-center, and a
/// live weather chip (Open-Meteo, keyless).
class MeetingMapScreen extends StatefulWidget {
  final List<RecoveryMeeting> initialMeetings;
  final RecoveryDatabase? database;

  const MeetingMapScreen({
    super.key,
    required this.initialMeetings,
    this.database,
  });

  @override
  State<MeetingMapScreen> createState() => _MeetingMapScreenState();
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

class _MeetingMapScreenState extends State<MeetingMapScreen> {
  final MapController _mapController = MapController();

  Position? _currentPosition;
  bool _isLoading = true;
  bool _showMapView = false;

  // Filters
  double _radiusMi = 25;
  String _cityFilter = 'All';
  bool _showAllTime = false;
  List<RecoveryMeeting> _base = [];
  String? _loadError;

  // Layers — Sovereign Mantle pattern: independent toggles, stackable.
  // First active layer = base; subsequent = overlays rendered on top.
  final Set<String> _activeLayers = {'dark'};

  static const List<_MapLayer> _availableLayers = [
    _MapLayer('dark', 'Dark', 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: ['a', 'b', 'c', 'd']),
    _MapLayer('light', 'Light', 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
        subdomains: ['a', 'b', 'c', 'd']),
    _MapLayer('sat', 'Satellite',
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
    _MapLayer('topo', 'Topo', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
        subdomains: ['a', 'b', 'c']),
    _MapLayer('osm', 'OSM', 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: ['a', 'b', 'c']),
  ];

  String? _weatherChip;
  String _locationDebug = '';
  bool _downloading = false;
  List<Marker> _cachedMarkers = [];
  List<Marker> _userMarkers = [];
  List<Marker> _meetingMarkers = [];

  static const double _maxRadiusMi = 50.0;
  static const double _miToKm = 1.60934;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ------------------------------------------------------------------
  // Init + location
  // ------------------------------------------------------------------

  Future<void> _initialize() async {
    final (lat, lng) = await _resolveLocation();
    await _load(lat, lng);
  }

  Future<(double, double)> _resolveLocation() async {
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
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().millisecondsSinceEpoch -
                  last.timestamp.millisecondsSinceEpoch <
              5 * 60 * 1000) {
        if (mounted) {
          setState(() => _locationDebug =
              'Last known: ${last.latitude.toStringAsFixed(4)}, ${last.longitude.toStringAsFixed(4)}');
        }
        return (last.latitude, last.longitude);
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
      return (pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        setState(() => _locationDebug = 'GPS FAILED: $e');
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
      radiusKm: _maxRadiusMi * _miToKm,
      upcomingOnly: !_showAllTime,
    );
  }

  // ------------------------------------------------------------------
  // Derived data
  // ------------------------------------------------------------------

  (double, double)? get _me => _currentPosition == null
      ? null
      : (_currentPosition!.latitude, _currentPosition!.longitude);

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

  void _recenter() {
    final me = _me;
    if (me != null) {
      _mapController.move(ll.LatLng(me.$1, me.$2), 13);
    } else {
      _mapController.move(_firstPinOrTwinCities(), 11);
    }
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

  Future<void> _logAttended(RecoveryMeeting meeting) async {
    final controller = TextEditingController();
    final reflection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You attended "${meeting.name}"',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
                'One question before it counts — what did you take away '
                'from the room today? (A sentence is plenty.)',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'It helped when…',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: AppColors.bgCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    Navigator.pop(sheetContext, controller.text.trim()),
                child: const Text('Save Reflection',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    if (reflection == null) return;
    final db = widget.database;
    if (db != null) {
      await db.addJournalEntry(JournalEntry(
        id: 'meeting_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 4,
        contentEncrypted:
            '[Meeting] ${meeting.name}: ${reflection.isEmpty ? "(attended, no notes)" : reflection}',
        isSyncedToCloud: false,
      ));
    }
    final before = (await RecoveryPetService.ensureHatched()).sparks;
    await RecoveryPetService.logMeeting();
    final delta = (await RecoveryPetService.ensureHatched()).sparks - before;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(delta > 0
            ? 'Reflection saved · +$delta Sparks'
            : 'Reflection saved · daily Sparks cap reached, and that is fine'),
      ),
    );
  }

  void _showMeetingDetails(RecoveryMeeting meeting) {
    final now = DateTime.now();
    final live = MeetingFinderService.isInProgress(meeting, now);
    final label = MeetingFinderService.upcomingLabel(meeting, now);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${live ? 'LIVE NOW · ' : ''}$label · ${meeting.type}',
                  style: TextStyle(
                      color: live ? AppColors.success : AppColors.accent,
                      fontSize: 13,
                      fontWeight: live ? FontWeight.bold : FontWeight.w500)),
              const SizedBox(height: 8),
              Text(meeting.address,
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              if (widget.database != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
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
      backgroundColor: const Color(0xFF1E293B),
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
                const Text('Map Layers',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'Toggle multiple layers — they stack on top of each other.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                                    : AppColors.textMuted)),
                        selected: _activeLayers.contains(layer.id),
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.bgCard,
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
      backgroundColor: const Color(0xFF1E293B),
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
                const Text('Filter Meetings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text('Radius · ${_radiusMi.round()} mi',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Slider(
                  value: _radiusMi,
                  min: 1,
                  max: _maxRadiusMi,
                  divisions: 49,
                  activeColor: AppColors.accent,
                  label: '${_radiusMi.round()} mi',
                  onChanged: (v) => setSheet(() => _radiusMi = v),
                  onChangeEnd: (v) => setState(() => _radiusMi = v),
                ),
                const SizedBox(height: 8),
                const Text('City / Area',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
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
                                    : AppColors.textMuted)),
                        selected: _cityFilter == city,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.bgCard,
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
                  title: const Text('Show every meeting (all week)',
                      style:
                          TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Off = live now + next 7 days only',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  value: _showAllTime,
                  activeThumbColor: AppColors.accent,
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Downloading offline pack',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Securing map tiles for ${_radiusMi.round()} mi around you.',
                  style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                backgroundColor: const Color(0xFF334155),
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 8),
              Text('$done / $total tiles',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF94A3B8))),
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
        backgroundColor: const Color(0xFF1E293B),
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
    if (MeetingFinderService.isInProgress(m, now)) return AppColors.success;
    if (m.type.contains('Online')) return const Color(0xFFA78BFA);
    final next = MeetingFinderService.nextOccurrence(m, now);
    if (next != null) {
      if (next.difference(now).inHours < 24) return const Color(0xFFFBBF24);
    }
    return AppColors.accent;
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
            color: AppColors.accent.withValues(alpha: 0.3),
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: const Icon(Icons.person_pin_circle,
              size: 14, color: Colors.white),
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
                  color: live ? Colors.white : Colors.white70,
                  width: live ? 2.2 : 1.4),
            ),
            child: Icon(
                m.type.contains('Online') ? Icons.videocam : Icons.groups_2,
                size: 15,
                color: Colors.white),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Meeting Finder'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _showMapView ? 'Show list' : 'Show map',
            icon: Icon(
                _showMapView ? Icons.view_list_outlined : Icons.map_outlined,
                color: Colors.white70),
            onPressed: () {
              setState(() => _showMapView = !_showMapView);
              if (_showMapView) _loadWeather();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _showMapView
              ? _buildMap(liveCount, visible)
              : _buildList(now, visible),
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
                      color: AppColors.accent,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text('${clusterMarkers.length}',
                          style: const TextStyle(
                              color: Colors.white,
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
            color: liveCount > 0 ? AppColors.success : null,
          ),
        ),
        if (_locationDebug.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: _MapChip(label: _locationDebug),
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
                  tooltip: 'Offline pack',
                  onTap:
                      _downloading ? () {} : () => _startPrefetch()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(DateTime now, List<RecoveryMeeting> visible) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.textDim),
            const SizedBox(height: 14),
            Text(
              _showAllTime
                  ? 'No meetings match these filters.'
                  : 'No meetings in the next 7 days.\nOpen filters to show every meeting.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text('Tap the tune icon above to adjust filters',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
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
                color: AppColors.bgCard,
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
                        const Text('LIVE',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  title: Text(meeting.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '$label · ${meeting.type}\n${meeting.address}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.35)),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.white38),
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

class _MapChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _MapChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color ?? AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}
