// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

class _ResourceLink {
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  const _ResourceLink(this.title, this.subtitle, this.url,
      {this.icon = Icons.link_outlined});
}

/// Curated community support directory: Recovery Community Organizations,
/// all-pathway meetings, and daily reflection feeds from trusted sources.
class CommunityResourcesScreen extends StatelessWidget {
  const CommunityResourcesScreen({super.key});

  static const List<_ResourceLink> _minnesota = [
    _ResourceLink(
      'All Recovery Meetings',
      'Pathway-neutral gatherings run by MN Recovery Connection',
      'https://www.minnesotarecovery.org/all-recovery-meetings/',
      icon: Icons.groups_2,
    ),
    _ResourceLink(
      'Peer Recovery Support (Free)',
      'Request a peer recovery coach · MRC',
      'https://www.minnesotarecovery.org/request-services/',
      icon: Icons.support_agent,
    ),
    _ResourceLink(
      'Telephone Recovery Support',
      'Regular supportive calls from peers · MRC',
      'https://www.minnesotarecovery.org/telephone-recovery-support/',
      icon: Icons.phone_in_talk_outlined,
    ),
    _ResourceLink(
      'Minnesota Resource Directory',
      'Searchable state-wide recovery resource search',
      'https://www.minnesotarecovery.org/resources-search/',
      icon: Icons.travel_explore,
    ),
    _ResourceLink(
      'Recovery Community Organizations in MN',
      'Every RCO across the state, listed by region',
      'https://www.minnesotarecovery.org/rcos-in-minnesota/',
      icon: Icons.map_outlined,
    ),
  ];

  static const List<_ResourceLink> _dailyPractice = [
    _ResourceLink(
      "Elder's Meditation of the Day",
      'Daily Native teaching from the Wellbriety Movement (Coyhis Publishing)',
      'https://wellbrietymovement.com/meditations/',
      icon: Icons.wb_twilight_outlined,
    ),
    _ResourceLink(
      'Wellbriety Circles & Flyers',
      'White Bison meeting directory, virtual and in person',
      'https://whitebison.org/wellbriety-meeting-flyers/',
      icon: Icons.circle_outlined,
    ),
    _ResourceLink(
      'InTheRooms — 24/7 Online Rooms',
      'Live fellowship rooms around the clock',
      'https://www.intherooms.com/home/',
      icon: Icons.videocam_outlined,
    ),
  ];

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _section(String header, List<_ResourceLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final link in links)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Icon(link.icon, color: AppColors.accent),
                title: Text(link.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(link.subtitle,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.open_in_new,
                    size: 18, color: Colors.white38),
                onTap: () => _open(link.url),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Community Support',
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
              'Trusted organizations outside this app. Links open in your '
              'browser so content is always current.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13,
                  height: 1.45),
            ),
          ),
          const SizedBox(height: 20),
          _section('Minnesota', _minnesota),
          const SizedBox(height: 12),
          _section('Daily Practice & Online Rooms', _dailyPractice),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
