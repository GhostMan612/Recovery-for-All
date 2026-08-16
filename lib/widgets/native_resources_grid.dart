// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
class NativeResource {
  final String name;
  final String address;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final String type;
  final String description;
  final List<String> programs;
  const NativeResource({
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
    required this.programs,
  });
}
class NativeResourcesGrid extends StatefulWidget {
  final Position? userPosition;
  final VoidCallback? onResourceTap;
  const NativeResourcesGrid({
    super.key,
    this.userPosition,
    this.onResourceTap,
  });
  @override
  State<NativeResourcesGrid> createState() => _NativeResourcesGridState();
}
class _NativeResourcesGridState extends State<NativeResourcesGrid> {
  final List<NativeResource> _resources = const [
    NativeResource(
      name: 'Khunsi Onikan Outpatient Program',
      address: '579 Wells Street',
      city: 'St. Paul',
      phone: '651-300-4585',
      latitude: 44.9537,
      longitude: -93.0900,
      type: 'Outpatient',
      description: 'Culturally specific healing center focusing on holistic community-based recovery.',
      programs: ['Wellbriety', 'Counseling'],
    ),
  ];
  double _calculateDistance(double lat, double lon) {
    if (widget.userPosition == null) return -1.0;
    return Geolocator.distanceBetween(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          lat,
          lon,
        ) * 0.000621371;
  }
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final resource = _resources[index];
        final distance = _calculateDistance(resource.latitude, resource.longitude);
        return GestureDetector(
          onTap: widget.onResourceTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  resource.description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: resource.programs.map((program) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        program,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          resource.city,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (distance >= 0)
                      Text(
                        '${distance.toStringAsFixed(1)} mi away',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}