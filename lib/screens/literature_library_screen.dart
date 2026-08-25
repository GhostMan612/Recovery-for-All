// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

/// R2 — Literature library: public-domain and official free recovery
/// texts, organized by fellowship. All links verified working.
class LiteratureLibraryScreen extends StatelessWidget {
  const LiteratureLibraryScreen({super.key});

  static const List<(_LitCategory, List<_LitLink>)> _sections = [
    (
      _LitCategory('Alcoholics Anonymous', Icons.local_bar_outlined),
      [
        _LitLink('The Big Book (4th ed.)', 'AA foundational text — free online',
            'https://www.aa.org/the-big-book'),
        _LitLink('Twelve Steps & Twelve Traditions',
            'Steps in depth + tradition guidance',
            'https://www.aa.org/twelve-steps-twelve-traditions'),
        _LitLink('The Twelve Steps', 'Step text and summaries',
            'https://www.aa.org/the-twelve-steps'),
        _LitLink('Daily Reflections', 'A day at a time',
            'https://www.aa.org/daily-reflections'),
      ],
    ),
    (
      _LitCategory('Narcotics Anonymous', Icons.group_work_outlined),
      [
        _LitLink('NA Basic Text', 'The foundational NA text',
            'https://www.na.org/?id=46'),
        _LitLink('NA Literature', 'Full literature collection',
            'https://www.na.org/admin/include/spdf/index.html'),
      ],
    ),
    (
      _LitCategory('SMART Recovery', Icons.psychology_outlined),
      [
        _LitLink('SMART Toolbox', 'CBT worksheets and tools',
            'https://smartrecovery.org/toolbox'),
        _LitLink('SMART Handbook', 'The SMART Recovery guide',
            'https://smartrecovery.org/handbook'),
      ],
    ),
    (
      _LitCategory('Recovery Dharma', Icons.self_improvement),
      [
        _LitLink('The Book — Recovery Dharma', 'Free PDF or read online',
            'https://recoverydharma.org/book'),
        _LitLink('Inquiry Questions', 'Meditation and inquiry practices',
            'https://recoverydharma.org/inquiry'),
      ],
    ),
    (
      _LitCategory('Wellbriety / White Bison', Icons.circle_outlined),
      [
        _LitLink('Medicine Wheel & 12 Steps', 'Program description',
            'https://whitebison.org/medicine-wheel-and-12-steps/'),
        _LitLink('Wellbriety Meetings', 'Circles and flyers',
            'https://whitebison.org/wellbriety-meeting-flyers/'),
      ],
    ),
    (
      _LitCategory('General / State', Icons.public),
      [
        _LitLink('SAMHSA Find Help', 'National treatment locator',
            'https://findtreatment.gov/'),
        _LitLink('MN Resource Directory', 'State-wide recovery resources',
            'https://www.minnesotarecovery.org/resources-search/'),
      ],
    ),
  ];

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
        title: const Text('Literature Library',
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
              'Free, official recovery literature. Links open in your '
              'browser so you always get the latest edition.',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          for (final (category, links) in _sections) ...[
            Row(
              children: [
                Icon(category.icon, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(category.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            for (final link in links)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.menu_book_outlined,
                        color: AppColors.accent, size: 20),
                    title: Text(link.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(link.subtitle,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new,
                        size: 14, color: Colors.white38),
                    onTap: () => _open(link.url),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LitCategory {
  final String name;
  final IconData icon;
  const _LitCategory(this.name, this.icon);
}

class _LitLink {
  final String title;
  final String subtitle;
  final String url;
  const _LitLink(this.title, this.subtitle, this.url);
}
