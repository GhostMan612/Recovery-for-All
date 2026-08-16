// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/meeting_finder_service.dart';
class MeetingMapScreen extends StatefulWidget {
  final List<RecoveryMeeting> initialMeetings;
  const MeetingMapScreen({
    super.key,
    required this.initialMeetings,
  });
  @override
  State<MeetingMapScreen> createState() => _MeetingMapScreenState();
}
class _MeetingMapScreenState extends State<MeetingMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;
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
      _buildMarkers(widget.initialMeetings);
    } catch (e) {
      _buildMarkers(widget.initialMeetings);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          onTap: () {
            // TODO: Handle meeting selection and show details
          },
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Meeting Map'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : GoogleMap(
              initialCameraPosition: _currentPosition != null
                  ? CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
              style: '''[
                {
                  "elementType": "geometry",
                  "stylers": [
                    {
                      "color": "#1e293b"
                    }
                  ]
                },
                {
                  "elementType": "labels.text.fill",
                  "stylers": [
                    {
                      "color": "#94a3b8"
                    }
                  ]
                },
                {
                  "elementType": "labels.text.stroke",
                  "stylers": [
                    {
                      "color": "#0f172a"
                    }
                  ]
                },
                {
                  "featureType": "administrative",
                  "elementType": "geometry.stroke",
                  "stylers": [
                    {
                      "color": "#334155"
                    }
                  ]
                },
                {
                  "featureType": "administrative.land_parcel",
                  "elementType": "labels.text.fill",
                  "stylers": [
                    {
                      "color": "#64748b"
                    }
                  ]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry",
                  "stylers": [
                    {
                      "color": "#1e293b"
                    }
                  ]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry.stroke",
                  "stylers": [
                    {
                      "color": "#334155"
                    }
                  ]
                },
                {
                  "featureType": "road",
                  "elementType": "labels.text.fill",
                  "stylers": [
                    {
                      "color": "#94a3b8"
                    }
                  ]
                },
                {
                  "featureType": "road.highway",
                  "elementType": "geometry",
                  "stylers": [
                    {
                      "color": "#1e293b"
                    }
                  ]
                },
                {
                  "featureType": "water",
                  "elementType": "geometry.fill",
                  "stylers": [
                    {
                      "color": "#0f172a"
                    }
                  ]
                }
              ]''',
            ),
    );
  }
}