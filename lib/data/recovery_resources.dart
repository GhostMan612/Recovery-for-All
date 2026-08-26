// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/data/recovery_resources.dart
//
// Single source of truth for the Community Resources directory.
// LAWS (blueprints/resource-system.md): verify every URL before commit
// (tools/verify_resources.py); subtitles survive alone; [pathways] uses
// exact onboarding strings (empty = universal).

import 'package:flutter/material.dart';

class ResourceSection {
  final String name;
  final IconData icon;
  final Set<String> pathways;
  final List<ResourceLink> links;

  const ResourceSection(this.name,
      {required this.icon, this.pathways = const {}, required this.links});
}

class ResourceLink {
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;

  const ResourceLink(this.title, this.subtitle, this.url,
      {this.icon = Icons.open_in_new});
}

class RecoveryResources {
  RecoveryResources._();

  /// Every link URL — used by the runtime link-health service.
  static List<String> get allUrls => [
        for (final s in sections)
          for (final l in s.links) l.url,
      ];

  static const List<ResourceSection> sections = [
    ResourceSection('Minnesota First',
        icon: Icons.map_outlined,
        links: [
          ResourceLink('All Recovery Meetings',
              'Pathway-neutral gatherings run by MN Recovery Connection',
              'https://www.minnesotarecovery.org/all-recovery-meetings/',
              icon: Icons.groups_2),
          ResourceLink('Peer Recovery Support (Free)',
              'Request a peer recovery coach · MRC',
              'https://www.minnesotarecovery.org/request-services/',
              icon: Icons.support_agent),
          ResourceLink('Telephone Recovery Support',
              'Regular supportive calls from peers · MRC',
              'https://www.minnesotarecovery.org/telephone-recovery-support/',
              icon: Icons.phone_in_talk_outlined),
          ResourceLink('Minnesota Resource Directory',
              'Searchable state-wide recovery resource search',
              'https://www.minnesotarecovery.org/resources-search/',
              icon: Icons.travel_explore),
          ResourceLink('Recovery Community Organizations in MN',
              'Every RCO across the state, listed by region',
              'https://www.minnesotarecovery.org/rcos-in-minnesota/',
              icon: Icons.map_outlined),
          ResourceLink('Recovery Dharma Minnesota',
              'Buddhist-inspired sangha — meetings, events, retreats',
              'https://recoverydharmamn.org/',
              icon: Icons.self_improvement),
        ]),
    ResourceSection('Daily Practice & Online Rooms',
        icon: Icons.wb_twilight_outlined,
        links: [
          ResourceLink("Elder's Meditation of the Day",
              'Daily Native teaching from the Wellbriety Movement',
              'https://wellbrietymovement.com/meditations/',
              icon: Icons.wb_twilight_outlined),
          ResourceLink('Wellbriety Circles & Flyers',
              'White Bison meeting directory, virtual and in person',
              'https://whitebison.org/wellbriety-meeting-flyers/',
              icon: Icons.circle_outlined),
          ResourceLink('InTheRooms — 24/7 Online Rooms',
              'Live fellowship rooms around the clock',
              'https://www.intherooms.com/home/',
              icon: Icons.videocam_outlined),
        ]),
    ResourceSection('12-Step Meeting Finders',
        icon: Icons.local_bar_outlined,
        pathways: {'12-Step (AA/NA)'},
        links: [
          ResourceLink('Alcoholics Anonymous — Find A.A.',
              'Official aa.org meeting finder', 'https://www.aa.org/find-aa',
              icon: Icons.local_bar_outlined),
          ResourceLink('Online Intergroup of A.A. (OIAA)',
              'AA meetings online, every hour of every day',
              'https://aa-intergroup.org/',
              icon: Icons.language),
          ResourceLink('aahomegroup — 24/7 Live Zoom',
              'The original around-the-clock AA Zoom room',
              'https://aahomegroup.org/',
              icon: Icons.home_outlined),
          ResourceLink('Narcotics Anonymous — NA Works',
              'Official NA meeting search', 'https://naworks.org/all_meetings/',
              icon: Icons.group_work_outlined),
          ResourceLink('Virtual NA Meetings',
              'Global online and phone NA gatherings',
              'https://virtual-na.org/',
              icon: Icons.videocam_outlined),
          ResourceLink('NA Minnesota Region',
              'Regional meeting search for Minnesota',
              'https://naminnesota.org/',
              icon: Icons.map_outlined),
          ResourceLink('Cocaine Anonymous', 'Official C.A. meeting search',
              'https://ca.org/',
              icon: Icons.search),
          ResourceLink('Crystal Meth Anonymous Online',
              'C.M.A. online meeting listings', 'https://online.crystalmeth.org/',
              icon: Icons.search),
          ResourceLink('Adult Children of Alcoholics (ACA)',
              'Fellowship for dysfunctional-family origins',
              'https://adultchildren.org/',
              icon: Icons.family_restroom),
        ]),
    ResourceSection('Secular, Mindfulness & Faith-Based',
        icon: Icons.light_mode_outlined,
        pathways: {
          'SMART Recovery',
          'Recovery Dharma',
          'Secular/Agnostic',
          'Celebrate Recovery (Christian)'
        },
        links: [
          ResourceLink('SMART Recovery Meetings',
              'CBT-based tools, in person and online',
              'https://smartrecovery.org/meeting',
              icon: Icons.psychology_outlined),
          ResourceLink('Recovery Dharma Meetings',
              'Buddhist-inspired mindfulness sanghas',
              'https://recoverydharma.org/meetings/',
              icon: Icons.self_improvement),
          ResourceLink('LifeRing Secular Recovery — Online Meetings',
              'Secular, crosstalk-friendly meetings every week (S.O.S. '
              'founder\'s fellowship spirit lives on here)',
              'https://lifering.org/meeting-menu/online-meetings/',
              icon: Icons.light_mode_outlined),
          ResourceLink('Women for Sobriety', 'Program built by and for women',
              'https://womenforsobriety.org/',
              icon: Icons.favorite_outline),
          ResourceLink('Celebrate Recovery', 'Christ-centered recovery groups',
              'https://celebraterecovery.com/',
              icon: Icons.church_outlined),
        ]),
    ResourceSection('Family & Friends',
        icon: Icons.diversity_1_outlined,
        links: [
          ResourceLink('Al-Anon Family Groups',
              'Support for families affected by alcoholism',
              'https://al-anon.org/',
              icon: Icons.family_restroom),
          ResourceLink('Alateen (Teens)', 'Meeting finder for teenagers',
              'https://al-anon.org/newcomers/teen-corner-alateen/',
              icon: Icons.emoji_people_outlined),
          ResourceLink('Nar-Anon Find a Meeting',
              'Support for families affected by addiction',
              'https://www.nar-anon.org/find-a-meeting',
              icon: Icons.diversity_1_outlined),
        ]),
    ResourceSection('Treatment Locators',
        icon: Icons.medical_services_outlined,
        links: [
          ResourceLink('FastTrackerMN',
              'Real-time SUD bed & service availability, MN + Tribal nations',
              'https://www.fasttrackermn.org/',
              icon: Icons.bed_outlined),
          ResourceLink('SAMHSA FindTreatment.gov',
              'National licensed treatment locator',
              'https://findtreatment.gov/',
              icon: Icons.medical_services_outlined),
        ]),
    ResourceSection('Overdose Prevention & Harm Reduction',
        icon: Icons.health_and_safety_outlined,
        links: [
          ResourceLink('Steve Rummler HOPE Network (MN)',
              'Free naloxone training + free kits, fentanyl test strips by '
              'mail — statewide Minnesota',
              'https://steverummlerhopenetwork.org/',
              icon: Icons.health_and_safety_outlined),
          ResourceLink('Naloxone Training & NAP Locations',
              'Virtual trainings monthly + Naloxone Access Points map',
              'https://steverummlerhopenetwork.org/resources/'
              'i-want-naloxone-training/',
              icon: Icons.school_outlined),
          ResourceLink('MN Dept. of Health — Overdose Prevention',
              'Syringe service programs, safe disposal, state resources',
              'https://www.health.mn.gov/communities/overdose/'
              'response/resources.html',
              icon: Icons.local_hospital_outlined),
          ResourceLink('NEXT Distro',
              'Mail-based harm reduction supplies where services are sparse',
              'https://nextdistro.org/',
              icon: Icons.markunread_mailbox_outlined),
        ]),
    ResourceSection('Recovery Community Organizations',
        icon: Icons.volunteer_activism_outlined,
        links: [
          ResourceLink('Minnesota Recovery Connection',
              'The state\'s first RCO — free peer coaching, All Recovery '
              'meetings, advocacy',
              'https://www.minnesotarecovery.org/',
              icon: Icons.favorite_outline),
          ResourceLink('Recovery is Happening (MN)',
              'Peer recovery services rooted in Rochester, serving SE MN',
              'https://www.recoveryishappening.org/',
              icon: Icons.celebration_outlined),
        ]),
    ResourceSection('Sober Housing',
        icon: Icons.home_outlined,
        links: [
          ResourceLink('Oxford House Vacancies',
              'Real-time openings at democratically-run sober houses',
              'https://oxfordvacancies.com/',
              icon: Icons.home_outlined),
          ResourceLink('MASH — MN Association of Sober Homes',
              'The state\'s certified recovery residence directory (NARR '
              'standards)',
              'https://mnsoberhomes.org/',
              icon: Icons.verified_outlined),
        ]),
    ResourceSection('Veterans, Youth & LGBTQ+',
        icon: Icons.shield_outlined,
        links: [
          ResourceLink('Veterans Crisis Line', 'Dial 988 then press 1 · text 838255',
              'https://www.veteranscrisisline.net/',
              icon: Icons.military_tech_outlined),
          ResourceLink('MN Department of Veterans Affairs',
              'State veteran services, behavioral health and support links',
              'https://mn.gov/mdva/',
              icon: Icons.flag_outlined),
          ResourceLink('Alateen (Teen Corner)',
              'Recovery support for teens affected by someone\'s drinking',
              'https://al-anon.org/newcomers/teen-corner-alateen/',
              icon: Icons.emoji_people_outlined),
          ResourceLink('The Trevor Project',
              '24/7 crisis support for LGBTQ+ young people',
              'https://www.thetrevorproject.org/',
              icon: Icons.diversity_2_outlined),
        ]),
    ResourceSection('Indigenous Recovery (MN)',
        icon: Icons.spa_outlined,
        links: [
          ResourceLink('Indigenous Peoples Task Force',
              'Harm reduction + cultural healing, Minneapolis · 612-870-1723',
              'https://www.iptf.org/',
              icon: Icons.spa_outlined),
          ResourceLink('Native American Community Clinic',
              'Whole-family health including culturally grounded SUD care · '
              '(612) 872-8086',
              'https://nacc-healthcare.org/',
              icon: Icons.medical_services_outlined),
        ]),
  ];
}
