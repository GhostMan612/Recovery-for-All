// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

class _Circle {
  final String name;
  final String location;
  final String flyerUrl;
  const _Circle(this.name, this.location, this.flyerUrl);
}

/// Curated directory of White Bison Wellbriety circles.
///
/// Schedules and Zoom credentials live inside each official flyer image, so
/// tiles deep-link to the live flyer instead of copying details that would go
/// stale. Data courtesy of White Bison (whitebison.org).
class WellbrietyCirclesScreen extends StatelessWidget {
  const WellbrietyCirclesScreen({super.key});

  static const List<_Circle> _circles = [
    _Circle('White Bison Sunday Night Meeting', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2025/02/Sunday-Night-Meeting-Flyer.png'),
    _Circle('Red Road Journey to R Shuka', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2026/08/08-2026-Red-Road-Journey-to-R-Shuka.jpg'),
    _Circle('Mashkiwizii Manido Sharing Circle & Book Study', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2026/08/08-2026-Nat-Su-Online-Meeting.jpg'),
    _Circle('Arizona Wellbriety Recovery Meetings', 'Arizona & Virtual',
        'https://whitebison.org/wp-content/uploads/2026/04/04-2026-AZ-WELLBRIETY-RECOVERY-MEETING-SCHEDULE-pdf.jpg'),
    _Circle('Puyallup Tribe Re-Entry Meetings', 'Tacoma, WA & Virtual',
        'https://whitebison.org/wp-content/uploads/2026/04/04-2026-Puyallup-Tribe-Reentry-Meetings.png'),
    _Circle('ITCC Mending Basket Red Road', 'Willits, CA & Virtual',
        'https://whitebison.org/wp-content/uploads/2026/03/03-2026-ITCC-Mending-Basket-Red-Road-2026-pdf.jpg'),
    _Circle('Wellbriety.Online Women\'s Circle', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2024/03/02-2024-Wellbriety.Online-New-womens-Wellbriety-Sat-flyer-2.jpg'),
    _Circle('Wellbriety.Online Men\'s Sacred Circle', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2024/03/02-2024-New-Mens-Wellbriety-Thurs.jpg'),
    _Circle('Two Spirit Nation', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2024/04/04-2024-Two-Spirit-Nation.jpeg'),
    _Circle('Youth Red Road to Wellbriety', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2022/03/Youth-RR-Meeiting-_Glory-Lewis-464x600.jpg'),
    _Circle('Morning Star Wellbriety', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2024/01/Untitled-408-x-528-px.png'),
    _Circle('Wellbriety Ireland', 'Virtual',
        'https://whitebison.org/wp-content/uploads/2025/01/01-2025-Wellbriety-Ireland-Zoom-Meeting.jpg'),
  ];

  static const String _allFlyersUrl =
      'https://whitebison.org/wellbriety-meeting-flyers/';
  static const String _inTheRoomsUrl = 'https://www.intherooms.com/home/';
  static const String _circleMeetingsUrl =
      'https://whitebison.org/circle-meetings/';
  static const String _meditationUrl =
      'https://wellbrietymovement.com/meditations/';

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Wellbriety Circles',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'Recurring Wellbriety gatherings curated by White Bison. '
              'Tap any circle to open its official flyer with the current '
              'schedule and meeting link.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13,
                  height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          for (final circle in _circles)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Icon(
                    circle.location == 'Virtual'
                        ? Icons.videocam_outlined
                        : Icons.location_on_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text(circle.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(circle.location,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: Colors.white38),
                  onTap: () => _open(circle.flyerUrl),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.bgCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.explore_outlined, color: AppColors.accent),
                  title: const Text('All Meeting Flyers — whitebison.org',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _open(_allFlyersUrl),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.groups_3, color: AppColors.accent),
                  title: const Text('24/7 Online Rooms — InTheRooms.com',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text(
                      'Includes Wellbriety and other fellowship rooms',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _open(_inTheRoomsUrl),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.self_improvement, color: AppColors.accent),
                  title: const Text('About Wellbriety Circles',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _open(_circleMeetingsUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.wb_twilight_outlined,
                      color: AppColors.accent),
                  title: const Text("Elder's Meditation of the Day",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Daily teaching · Coyhis Publishing',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _open(_meditationUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
