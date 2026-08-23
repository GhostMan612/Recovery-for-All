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

  static const List<_ResourceLink> _twelveStep = [
    _ResourceLink(
      'Alcoholics Anonymous — Find A.A.',
      'Official aa.org meeting finder',
      'https://www.aa.org/find-aa',
      icon: Icons.local_bar_outlined,
    ),
    _ResourceLink(
      'Online Intergroup of A.A. (OIAA)',
      'AA meetings online, every hour of every day',
      'https://aa-intergroup.org/',
      icon: Icons.language,
    ),
    _ResourceLink(
      'aahomegroup — 24/7 Live Zoom',
      'The original around-the-clock AA Zoom room',
      'https://aahomegroup.org/',
      icon: Icons.home_outlined,
    ),
    _ResourceLink(
      'Narcotics Anonymous — NA Works',
      'Official NA meeting search',
      'https://naworks.org/all_meetings/',
      icon: Icons.group_work_outlined,
    ),
    _ResourceLink(
      'Virtual NA Meetings',
      'Global online and phone NA gatherings',
      'https://virtual-na.org/',
      icon: Icons.videocam_outlined,
    ),
    _ResourceLink(
      'NA Minnesota Region',
      'Regional meeting search for Minnesota',
      'https://naminnesota.org/',
      icon: Icons.map_outlined,
    ),
    _ResourceLink(
      'Cocaine Anonymous',
      'Official C.A. meeting search',
      'https://ca.org/',
      icon: Icons.search,
    ),
    _ResourceLink(
      'Crystal Meth Anonymous Online',
      'C.M.A. online meeting listings',
      'https://online.crystalmeth.org/',
      icon: Icons.search,
    ),
    _ResourceLink(
      'Adult Children of Alcoholics (ACA)',
      'Fellowship for dysfunctional-family origins',
      'https://adultchildren.org/',
      icon: Icons.family_restroom,
    ),
  ];

  static const List<_ResourceLink> _secularMindfulness = [
    _ResourceLink(
      'SMART Recovery Meetings',
      'CBT-based tools, in person and online',
      'https://smartrecovery.org/meeting',
      icon: Icons.psychology_outlined,
    ),
    _ResourceLink(
      'Recovery Dharma Meetings',
      'Buddhist-inspired mindfulness sanghas',
      'https://recoverydharma.org/meetings/',
      icon: Icons.self_improvement,
    ),
    _ResourceLink(
      'Secular Organizations for Sobriety',
      'S.O.S. secular meeting locator',
      'https://www.sossobriety.org/',
      icon: Icons.light_mode_outlined,
    ),
    _ResourceLink(
      'Women for Sobriety',
      'Program built by and for women',
      'https://womenforsobriety.org/',
      icon: Icons.favorite_outline,
    ),
    _ResourceLink(
      'Celebrate Recovery',
      'Christ-centered recovery groups',
      'https://celebraterecovery.com/',
      icon: Icons.church_outlined,
    ),
  ];

  static const List<_ResourceLink> _familyFriends = [
    _ResourceLink(
      'Al-Anon Family Groups',
      'Support for families affected by alcoholism',
      'https://al-anon.org/',
      icon: Icons.family_restroom,
    ),
    _ResourceLink(
      'Alateen (Teens)',
      'Meeting finder for teenagers',
      'https://al-anon.org/newcomers/teen-corner-alateen/',
      icon: Icons.emoji_people_outlined,
    ),
    _ResourceLink(
      'Nar-Anon Find a Meeting',
      'Support for families affected by addiction',
      'https://www.nar-anon.org/find-a-meeting',
      icon: Icons.diversity_1_outlined,
    ),
  ];

  static const List<_ResourceLink> _treatmentLocators = [
    _ResourceLink(
      'FastTrackerMN',
      'Real-time SUD bed & service availability, MN + Tribal nations',
      'https://sud.fasttrackermn.org/search',
      icon: Icons.bed_outlined,
    ),
    _ResourceLink(
      'SAMHSA FindTreatment.gov',
      'National licensed treatment locator',
      'https://findtreatment.gov/',
      icon: Icons.medical_services_outlined,
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
          const SizedBox(height: 12),
          _section('Twelve-Step Fellowships', _twelveStep),
          const SizedBox(height: 12),
          _section('Secular, Mindfulness & Faith-Based', _secularMindfulness),
          const SizedBox(height: 12),
          _section('Family & Friends', _familyFriends),
          const SizedBox(height: 12),
          _section('Treatment & Beds', _treatmentLocators),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
