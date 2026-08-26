// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/data/recovery_literature.dart
//
// Single source of truth for the Literature Library. Screens render
// this data; nothing hardcodes links.
//
// LAWS (see blueprints/resource-system.md):
//  * Every URL must pass tools/verify_resources.py BEFORE commit.
//  * Subtitles are written to survive alone — if a link dies the reader
//    still knows what the resource was and can search for it.
//  * [pathways] ties a category to onboarding selections (exact
//    _pathwaysPool strings); EMPTY set = universal, always shown.
//  * MN-first ordering; national items follow.

import 'package:flutter/material.dart';

class LitCategory {
  final String name;
  final IconData icon;
  final Set<String> pathways;

  const LitCategory(this.name, this.icon, {this.pathways = const {}});
}

class LitLink {
  final String title;
  final String subtitle;
  final String url;

  const LitLink(this.title, this.subtitle, this.url);
}

class RecoveryLiterature {
  RecoveryLiterature._();

  /// Every link URL — used by the runtime link-health service.
  static List<String> get allUrls => [
        for (final (_, links) in sections)
          for (final l in links) l.url,
      ];

  static const List<(LitCategory, List<LitLink>)> sections = [
    (
      LitCategory('Alcoholics Anonymous', Icons.local_bar_outlined,
          pathways: {'12-Step (AA/NA)'}),
      [
        LitLink('The Big Book (4th ed.)', 'AA foundational text — free online',
            'https://www.aa.org/the-big-book'),
        LitLink('Twelve Steps & Twelve Traditions',
            'Steps in depth + tradition guidance',
            'https://www.aa.org/twelve-steps-twelve-traditions'),
        LitLink('The Twelve Steps', 'Step text and summaries',
            'https://www.aa.org/the-twelve-steps'),
        LitLink('Daily Reflections', 'A day at a time',
            'https://www.aa.org/daily-reflections'),
      ],
    ),
    (
      LitCategory('Narcotics Anonymous', Icons.group_work_outlined,
          pathways: {'12-Step (AA/NA)'}),
      [
        LitLink('NA Basic Text', 'The foundational NA text',
            'https://www.na.org/?id=46'),
        LitLink('NA Literature', 'Free recovery literature in many languages',
            'https://na.org/literature/'),
      ],
    ),
    (
      LitCategory('SMART Recovery', Icons.psychology_outlined,
          pathways: {'SMART Recovery'}),
      [
        LitLink('SMART Toolbox', 'CBT worksheets and tools',
            'https://smartrecovery.org/toolbox'),
        LitLink('SMART Handbooks', 'The 4th-edition participant handbook',
            'https://smartrecovery.org/handbooks'),
      ],
    ),
    (
      LitCategory('Recovery Dharma', Icons.self_improvement,
          pathways: {'Recovery Dharma'}),
      [
        LitLink('The Book — Recovery Dharma', 'Free PDF or read online',
            'https://recoverydharma.org/book'),
        LitLink('Inquiry Questions', 'Meditation and inquiry practices',
            'https://recoverydharma.org/inquiry'),
      ],
    ),
    (
      LitCategory('Wellbriety / White Bison', Icons.circle_outlined,
          pathways: {'Wellbriety'}),
      [
        LitLink('Medicine Wheel & 12 Steps', 'Program description',
            'https://whitebison.org/medicine-wheel-and-12-steps/'),
        LitLink('Wellbriety Meetings', 'Circles and flyers',
            'https://whitebison.org/wellbriety-meeting-flyers/'),
      ],
    ),
    (
      // Universal: state/national entry points help everyone.
      LitCategory('General / State', Icons.public),
      [
        LitLink('SAMHSA Find Help', 'National treatment locator',
            'https://findtreatment.gov/'),
        LitLink('MN Resource Directory', 'State-wide recovery resources',
            'https://www.minnesotarecovery.org/resources-search/'),
      ],
    ),
  ];
}
