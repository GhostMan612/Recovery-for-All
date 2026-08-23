// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/meeting_finder_service.dart';
import '../services/recovery_pet_service.dart';

/// Meeting finder with an offline-first list view plus an optional map view
/// (the map requires a Google Maps API key; the list never does).
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
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showMapView = false;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(46.2276, -94.3411),
    zoom: 7.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      // Location unavailable — fall back to the default camera position.
    }
    _buildMarkers(widget.initialMeetings);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildMarkers(List<RecoveryMeeting> meetings) {
    _markers.clear();
    for (var meeting in meetings) {
      _markers.add(
        Marker(
          markerId: MarkerId(meeting.id),
          position: LatLng(meeting.latitude, meeting.longitude),
          infoWindow: InfoWindow(
            title: meeting.name,
            snippet: '${meeting.time} - ${meeting.address}',
          ),
          onTap: () => _showMeetingDetails(meeting),
        ),
      );
    }
  }

  Future<void> _openDirections(RecoveryMeeting meeting) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${meeting.latitude},${meeting.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Honest attendance: one reflection question, then Sparks. No reflex
  /// check-boxes — the reflection is the point, the reward is the side effect.
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 13,
                  height: 1.4),
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
              Text('${meeting.type} · ${meeting.time}',
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
              const SizedBox(height: 8),
              Text(meeting.address,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              if (widget.database != null)
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

  String get _darkMapStyle => '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#94a3b8"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f172a"}]},
    {"featureType": "administrative", "elementType": "geometry.stroke",
     "stylers": [{"color": "#334155"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill",
     "stylers": [{"color": "#64748b"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#334155"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#94a3b8"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#334155"}]},
    {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#0f172a"}]}
  ]''';

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(_showMapView ? Icons.view_list_outlined : Icons.map_outlined,
                color: Colors.white70),
            onPressed: () => setState(() => _showMapView = !_showMapView),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _showMapView
              ? GoogleMap(
                  style: _darkMapStyle,
                  initialCameraPosition: _currentPosition != null
                      ? CameraPosition(
                          target: LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          zoom: 12.0,
                        )
                      : _defaultPosition,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.initialMeetings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final meeting = widget.initialMeetings[index];
                    return Material(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading:
                            const Icon(Icons.groups_2, color: Color(0xFF38BDF8)),
                        title: Text(meeting.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${meeting.type}\n${meeting.time} · ${meeting.address}',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () => _showMeetingDetails(meeting),
                      ),
                    );
                  },
                ),
    );
  }
}
