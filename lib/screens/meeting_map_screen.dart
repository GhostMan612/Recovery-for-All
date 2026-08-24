// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/meeting_finder_service.dart';
import '../services/recovery_pet_service.dart';

/// Meeting finder — keyless OSM raster map (flutter_map, CARTO dark tiles)
/// with custom live pins for meetings + the user's location, plus an
/// offline-friendly list view. Time-aware: shows live + upcoming meetings.
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

class _MeetingMapScreenState extends State<MeetingMapScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showMapView = false;
  late List<RecoveryMeeting> _meetings;

  @override
  void initState() {
    super.initState();
    _meetings = widget.initialMeetings;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Location unavailable — list still works; map centers on first pin.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  ll.LatLng get _mapCenter {
    if (_currentPosition != null) {
      return ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    for (final m in _meetings) {
      if (m.hasLocation) return ll.LatLng(m.latitude, m.longitude);
    }
    return const ll.LatLng(44.9778, -93.2650); // Twin Cities
  }

  Future<void> _openDirections(RecoveryMeeting meeting) async {
    if (!meeting.hasLocation) {
      final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(meeting.address)}');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${meeting.latitude},${meeting.longitude}');
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
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
                  color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
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
                  foregroundColor: Colors.white,
                ),
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
            '[Meeting] ${meeting.name}: ${reflection.isEmpty ? '(attended, no notes)' : reflection}',
        isSyncedToCloud: false,
      ));
    }
    final before = (await RecoveryPetService.ensureHatched()).sparks;
    await RecoveryPetService.logMeeting();
    final delta =
        (await RecoveryPetService.ensureHatched()).sparks - before;
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              Text(
                '${live ? 'LIVE NOW · ' : ''}${meeting.time}',
                style: TextStyle(
                    color: live ? AppColors.success : AppColors.accent,
                    fontSize: 13,
                    fontWeight: live ? FontWeight.bold : FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(meeting.address,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              if (widget.database != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
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
                    foregroundColor: Colors.white,
                  ),
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

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.35),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: const Icon(Icons.person_pin_circle,
                size: 14, color: Colors.white),
          ),
        ),
      );
    }
    for (var i = 0; i < _meetings.length && i < 200; i++) {
      final m = _meetings[i];
      if (!m.hasLocation) continue;
      final live = MeetingFinderService.isInProgress(m, DateTime.now());
      markers.add(
        Marker(
          point: ll.LatLng(m.latitude, m.longitude),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _showMeetingDetails(m),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? AppColors.success : AppColors.accent,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: (live ? AppColors.success : AppColors.accent)
                        .withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                m.type.contains('Online')
                    ? Icons.videocam
                    : Icons.groups_2,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
            onPressed: () => setState(() => _showMapView = !_showMapView),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _showMapView
              ? FlutterMap(
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _currentPosition != null ? 12.0 : 8.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.recoveryforall',
                    ),
                    MarkerLayer(markers: _buildMarkers()),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors · © CARTO'),
                      ],
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _meetings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final meeting = _meetings[index];
                    final live = MeetingFinderService.isInProgress(meeting, now);
                    final label =
                        MeetingFinderService.upcomingLabel(meeting, now);
                    return Material(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading: Icon(
                          live
                              ? Icons.circle
                              : meeting.type.contains('Online')
                                  ? Icons.videocam_outlined
                                  : Icons.groups_2,
                          color: live ? AppColors.success : AppColors.accent,
                          size: live ? 14 : 24,
                        ),
                        title: Text(meeting.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${live ? 'LIVE NOW' : label} · ${meeting.type}\n${meeting.address}',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12,
                              height: 1.35),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white38),
                        onTap: () => _showMeetingDetails(meeting),
                      ),
                    );
                  },
                ),
    );
  }
}
