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
        LitLink('Living Sober', 'Practical booklet: staying away from the '
            'first drink one day at a time',
            'https://www.aa.org/living-sober'),
        LitLink('AA Grapevine', 'The international journal of AA — member '
            'stories, sponsorship, sober humor',
            'https://www.aagrapevine.org/'),
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
        LitLink('Am I an Addict? (IP #7)', 'Free pamphlet — self-assessment reading',
            'https://www.na.org/?id=ips-EN-IP7'),
        LitLink('White Booklet', 'Short-form Basic Text excerpt — free online read',
            'https://www.na.org/?id=White%20Booklet'),
        LitLink('Just For Today — Daily Meditation', 'NA daily reading, free online',
            'https://www.jftna.org/jft/'),
        LitLink('NA Step Working Guide (Purchase Info)', 'Fellowship-approved workbook — print/eBook via NAWS catalog',
            'https://www.na.org/?id=Catalog'),
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
    (
      LitCategory('LifeRing — Secular', Icons.light_mode_outlined,
          pathways: {'LifeRing (Secular)', 'Secular/Agnostic'}),
      [
        LitLink('If This Is Day One',
            'LifeRing\'s welcoming start page for newcomers',
            'https://lifering.org/lifering-recovery-menu/if-this-is-day-one/'),
        LitLink('Online Meetings Calendar',
            'Crosstalk-friendly video meetings every day — "How was your week?"',
            'https://meetings.lifering.org/meetings/?scope=only'),
        LitLink('Recovery Toolbox', 'Practical tools and strategies',
            'https://lifering.org/recovery-toolbox/'),
      ],
    ),
    (
      LitCategory('Women for Sobriety', Icons.favorite_outline,
          pathways: {'Women for Sobriety'}),
      [
        LitLink('The New Life Program — 13 Acceptance Statements',
            'A new way of thinking built on self-worth and peer support',
            'https://www.womenforsobriety.org/acceptance-statements'),
        LitLink('Meetings Directory',
            'Online and in-person daily meetings — incl. Twin Cities & St. Paul',
            'https://meetings.womenforsobriety.org/meetings/'),
      ],
    ),
    (
      LitCategory('Celebrate Recovery', Icons.church_outlined,
          pathways: {'Celebrate Recovery'}),
      [
        LitLink('Find a Group / Online Meeting',
            'Official site — group locator plus a weekly online open-share '
            '(Wednesdays). Hurts, hang-ups, and habits of every kind.',
            'https://www.celebraterecovery.com/'),
      ],
    ),
    (
      // Universal: families and friends need their own recovery too.
      LitCategory('Family & Friends', Icons.diversity_1_outlined),
      [
        LitLink('Al-Anon Free Downloads',
            'Free pamphlets and magazines for families of alcoholics',
            'https://al-anon.org/for-members/members-resources/literature/'
            'downloadable-items/'),
        LitLink('Alateen (Teen Corner)',
            'Meetings and resources for teenagers',
            'https://al-anon.org/newcomers/teen-corner-alateen/'),
        LitLink('Nar-Anon Literature',
            'Free PDFs for families affected by addiction',
            'https://nar-anon.org/help-me-find-literature/'),
      ],
    ),
    (
      // Universal: crisis lines apply to every pathway, every person.
      LitCategory('Crisis & Help Lines', Icons.emergency_outlined),
      [
        LitLink('988 Suicide & Crisis Lifeline',
            'Call or text 988 — 24/7, free, confidential',
            'https://988lifeline.org/'),
        LitLink('Crisis Text Line', 'Text HOME to 741741 — 24/7 text support',
            'https://www.crisistextline.org/'),
        LitLink('SAMHSA National Helpline',
            '1-800-662-HELP — treatment referral, 24/7, free',
            'https://www.samhsa.gov/find-help/national-helpline'),
        LitLink('Veterans Crisis Line',
            'Dial 988 then press 1 — or text 838255',
            'https://www.veteranscrisisline.net/'),
        LitLink('The Trevor Project',
            'Crisis support for LGBTQ+ young people — 24/7',
            'https://www.thetrevorproject.org/'),
      ],
    ),
  ];
}
