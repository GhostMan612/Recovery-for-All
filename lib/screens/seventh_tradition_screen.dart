// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/seventh_tradition_screen.dart
//
// 7th Tradition & Support screen — external routing for fellowship
// donations, official literature portals, and community app upkeep.
// All links open in external browser per Google Play guidelines.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../services/meeting_finder_service.dart';

class SeventhTraditionScreen extends StatelessWidget {
  const SeventhTraditionScreen({super.key});

  static const List<_SupportLink> _fellowshipLinks = [
    _SupportLink(
      fellowship: RecoveryFellowship.aa,
      label: 'AA General Service Office (GSO)',
      url: 'https://www.aa.org/contributions',
      description: 'Support AA World Services, GSO, and your local intergroup.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.na,
      label: 'NA World Services (NAWS)',
      url: 'https://www.na.org/contribute',
      description: 'Contribute to NA World Services and literature fund.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.cma,
      label: 'CMA World Services',
      url: 'https://crystalmeth.org/donate',
      description: 'Support Crystal Meth Anonymous World Services.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.ca,
      label: 'CA World Services',
      url: 'https://ca.org/donate',
      description: 'Support Cocaine Anonymous World Services.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.oa,
      label: 'OA World Service Office',
      url: 'https://oa.org/contribute',
      description: 'Contribute to Overeaters Anonymous World Service Office.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.alanon,
      label: 'Al-Anon Family Groups (WSO)',
      url: 'https://al-anon.org/donate',
      description: 'Support Al-Anon/Alateen World Service Office.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.smart,
      label: 'SMART Recovery USA',
      url: 'https://www.smartrecovery.org/donate',
      description: 'Support SMART Recovery programs and research.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.dharma,
      label: 'Recovery Dharma',
      url: 'https://recoverydharma.org/donate',
      description: 'Support Buddhist-inspired recovery community.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.lifering,
      label: 'LifeRing Secular Recovery',
      url: 'https://lifering.org/donate',
      description: 'Support LifeRing secular recovery meetings.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.wfs,
      label: 'Women for Sobriety',
      url: 'https://womenforsobriety.org/donate',
      description: 'Support Women for Sobriety programs.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.cr,
      label: 'Celebrate Recovery',
      url: 'https://celebraterecovery.com/give',
      description: 'Support Celebrate Recovery ministry.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.allRecovery,
      label: 'All Recovery',
      url: 'https://allrecovery.org/support',
      description: 'Support secular, non-12-step recovery community.',
    ),
  ];

  static const List<_SupportLink> _literatureLinks = [
    _SupportLink(
      fellowship: RecoveryFellowship.aa,
      label: 'AA Grapevine / AAWS Store',
      url: 'https://www.aa.org/store',
      description: 'Official AA literature: Big Book, 12&12, Daily Reflections, Grapevine.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.na,
      label: 'NAWS Literature Catalog',
      url: 'https://www.na.org/literature',
      description: 'Official NA literature: Basic Text, It Works, JFT, SPAD, IPs.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.cma,
      label: 'CMA Literature',
      url: 'https://crystalmeth.org/literature',
      description: 'CMA books, pamphlets, and keytags.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.ca,
      label: 'CA Literature',
      url: 'https://ca.org/literature',
      description: 'CA books, booklets, and recovery tools.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.oa,
      label: 'OA Bookstore',
      url: 'https://bookstore.oa.org',
      description: 'OA literature: Voices of Recovery, For Today, Steps & Traditions.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.smart,
      label: 'SMART Recovery Bookstore',
      url: 'https://www.smartrecovery.org/shop',
      description: 'SMART Handbook, meeting guides, and tools.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.dharma,
      label: 'Recovery Dharma Bookstore',
      url: 'https://recoverydharma.org/bookstore',
      description: 'Recovery Dharma book, meeting format, and meditation guides.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.alanon,
      label: 'Al-Anon Literature (WSO)',
      url: 'https://al-anon.org/literature',
      description: 'Al-Anon/Alateen books: Courage to Change, How Al-Anon Works.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.lifering,
      label: 'LifeRing Bookstore',
      url: 'https://lifering.org/bookstore',
      description: 'LifeRing convenor handbook, recovery by choice book.',
    ),
    _SupportLink(
      fellowship: RecoveryFellowship.wfs,
      label: 'WFS Literature',
      url: 'https://womenforsobriety.org/shop',
      description: 'WFS New Life Program, daily reflections, and pamphlets.',
    ),
  ];

  static final _SupportLink _appSupportLink = _SupportLink(
    fellowship: null,
    label: 'Support Recovery for All Development',
    url: 'https://github.com/sponsors/GhostMan612',
    description: 'Recovery for All is free, open-source, and offline-first. '
        'Your support covers hosting, device testing, and continued development. '
        'No ads, no tracking, no data collection — ever.',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('7th Tradition & Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro card
          _SectionCard(
            title: 'What Is the 7th Tradition?',
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.accent,
            child: const Text(
              'Every fellowship is self-supporting through its own contributions. '
              'The 7th Tradition ensures no outside affiliations, no dues or fees, '
              'and that the message reaches those who still suffer — free of charge.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          // Card 1: Fellowship 7th Tradition
          _SectionCard(
            title: 'Fellowship 7th Tradition',
            subtitle: 'Direct links to official contribution portals',
            icon: Icons.volunteer_activism_outlined,
            iconColor: AppColors.success,
            child: Column(
              children: [
                for (final link in _fellowshipLinks)
                  _SupportListTile(
                    link: link,
                    onTap: () => _launchExternal(context, link.url, link.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: Literature Stores
          _SectionCard(
            title: 'Official Literature Stores',
            subtitle: 'Buy conference-approved books, pamphlets, and keytags',
            icon: Icons.menu_book_outlined,
            iconColor: const Color(0xFFA78BFA),
            child: Column(
              children: [
                for (final link in _literatureLinks)
                  _SupportListTile(
                    link: link,
                    onTap: () => _launchExternal(context, link.url, link.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 3: Community App Upkeep
          _SectionCard(
            title: 'Community App Upkeep',
            subtitle: 'Keep Recovery for All free, private, and offline-first',
            icon: Icons.favorite_outline_rounded,
            iconColor: const Color(0xFFF472B6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recovery for All is built by people in recovery, for people in recovery. '
                  'No ads. No tracking. No accounts required. Fully offline-capable.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your support helps cover:',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...[
                  '📱 Device testing (Blu View 5, Moto G 2025, Dell 5400)',
                  '☁️ GitHub Actions CI / Firestore hosting costs',
                  '🦙 GGUF model hosting (Hugging Face bandwidth)',
                  '🛠️ Ongoing development & security updates',
                ].map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      e,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF472B6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new_outlined, size: 20),
                    label: const Text('Support Development',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () => _launchExternal(
                      context,
                      _appSupportLink.url,
                      _appSupportLink.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Disclaimer
          Center(
            child: Text(
              'All links open in your browser. Recovery for All does not process payments '
              'or collect financial information.',
              style: TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _launchExternal(BuildContext context, String url, String label) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: Text('Could not open $label'),
        ),
      );
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1, indent: 16, endIndent: 16),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _SupportListTile extends StatelessWidget {
  final _SupportLink link;
  final VoidCallback onTap;

  const _SupportListTile({
    required this.link,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (link.fellowship != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    link.fellowship!.code.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const SizedBox(width: 36),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (link.description.isNotEmpty)
                    Text(
                      link.description,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Color(0xFF64748B), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SupportLink {
  final RecoveryFellowship? fellowship;
  final String label;
  final String url;
  final String description;

  const _SupportLink({
    this.fellowship,
    required this.label,
    required this.url,
    required this.description,
  });
}