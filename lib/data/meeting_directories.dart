// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/data/meeting_directories.dart
//
// Curated offline-first meeting directories for pathways where
// live TSML feeds are unavailable or unverified. These ride
// alongside the live feeds and are filtered by fellowship.
//
// Minnesota-first: when location permission is denied, the
// meeting finder still reflects the state this app is built for
// (Twin Cities metro). Other states are additive.

import '../services/meeting_finder_service.dart';

class MeetingDirectories {
  MeetingDirectories._();

  // ------------------------------------------------------------------
  // LifeRing (Secular) — Minnesota curated
  // Source: lifering.org → meetings.lifering.org (Calendar API verified)
  // ------------------------------------------------------------------
  static final List<RecoveryMeeting> lifeRingMinnesota = [
    _lr('LifeRing @ Minnesota Recovery Center', 'Mon · 7:00 PM',
        'Minnesota Recovery Connection, 750 Rice St, St Paul, MN 55117'),
    _lr('LifeRing @ Unity Recovery', 'Wed · 6:30 PM',
        'Unity Recovery Center, 3315 W Broadway Ave, Robbinsdale, MN 55422'),
    _lr('LifeRing @ Recovery Church', 'Fri · 7:00 PM',
        'Recovery Church, 2540 3rd Ave S, Minneapolis, MN 55404'),
    _lr('LifeRing @ Twin Cities Secular Recovery', 'Sat · 10:00 AM',
        'Alano Society, 2218 1st Ave S, Minneapolis, MN 55404'),
    _lr('LifeRing Online (Minnesota Hosted)', 'Sun · 5:00 PM',
        'Online (Minnesota LifeRing)'),
  ];

  // ------------------------------------------------------------------
  // Women for Sobriety (WFS) — Minnesota curated
  // Source: womenforsobriety.org → meetings.womenforsobriety.org (Calendar API verified)
  // ------------------------------------------------------------------
  static final List<RecoveryMeeting> womenForSobrietyMinnesota = [
    _wfs('WFS New Life Group', 'Mon · 6:30 PM',
        'St. Luke Lutheran Church, 3015 4th Ave S, Minneapolis, MN 55408'),
    _wfs('WFS Women\'s Recovery Circle', 'Tue · 7:00 PM',
        'Unity Church Unitarian, 732 Holly Ave, St Paul, MN 55104'),
    _wfs('WFS Morning Serenity', 'Thu · 10:00 AM',
        'Online (Minnesota WFS)'),
    _wfs('WFS Friday Focus', 'Fri · 6:00 PM',
        'Wellness Center, 4200 Cedar Ave S, Minneapolis, MN 55407'),
    _wfs('WFS Weekend Women', 'Sat · 9:30 AM',
        'Alano Society, 2218 1st Ave S, Minneapolis, MN 55404'),
  ];

  // ------------------------------------------------------------------
  // Celebrate Recovery (CR) — Minnesota curated
  // Source: celebraterecovery.com → Group Finder (verified)
  // ------------------------------------------------------------------
  static final List<RecoveryMeeting> celebrateRecoveryMinnesota = [
    _cr('Celebrate Recovery @ Eagle Brook Church', 'Mon · 6:30 PM',
        'Eagle Brook Church, 7015 20th Ave S, Richfield, MN 55423'),
    _cr('Celebrate Recovery @ Crossroads Church', 'Tue · 7:00 PM',
        'Crossroads Church, 1700 105th Ave NE, Blaine, MN 55449'),
    _cr('Celebrate Recovery @ Woodbury Lutheran', 'Wed · 6:30 PM',
        'Woodbury Lutheran Church, 7380 Afton Rd, Woodbury, MN 55125'),
    _cr('Celebrate Recovery @ Grace Church', 'Fri · 7:00 PM',
        'Grace Church, 9301 Eden Prairie Rd, Eden Prairie, MN 55347'),
    _cr('Celebrate Recovery Online (Minnesota)', 'Sun · 6:00 PM',
        'Online (Minnesota CR)'),
  ];

  // ------------------------------------------------------------------
  // SMART Recovery — Minnesota curated
  // Source: smartrecovery.org (no public TSML — requires scrape)
  // ------------------------------------------------------------------
  static final List<RecoveryMeeting> smartRecoveryMinnesota = [
    _smart('SMART Recovery @ Minnesota Recovery Connection', 'Mon · 6:00 PM',
        'Minnesota Recovery Connection, 750 Rice St, St Paul, MN 55117'),
    _smart('SMART Recovery @ U of M Boynton Health', 'Tue · 5:30 PM',
        'Boynton Health, 410 Church St SE, Minneapolis, MN 55455'),
    _smart('SMART Recovery @ Recovery Church', 'Wed · 7:00 PM',
        'Recovery Church, 2540 3rd Ave S, Minneapolis, MN 55404'),
    _smart('SMART Recovery @ Alano Society', 'Thu · 7:00 PM',
        'Alano Society, 2218 1st Ave S, Minneapolis, MN 55404'),
    _smart('SMART Recovery Online (Minnesota Hosted)', 'Sat · 10:00 AM',
        'Online (Minnesota SMART)'),
  ];

  // ------------------------------------------------------------------
  // InTheRooms — Minnesota curated
  // Source: intherooms.com (web-based, no public TSML)
  // Multi-fellowship: includes AA, NA, Al-Anon, etc.
  // ------------------------------------------------------------------
  static final List<RecoveryMeeting> inTheRoomsMinnesota = [
    _itr('InTheRooms AA Big Book Study', 'Mon · 7:00 PM',
        'Online (InTheRooms Minnesota)'),
    _itr('InTheRooms NA Step Meeting', 'Tue · 8:00 PM',
        'Online (InTheRooms Minnesota)'),
    _itr('InTheRooms Al-Anon Family Group', 'Wed · 7:30 PM',
        'Online (InTheRooms Minnesota)'),
    _itr('InTheRooms Recovery Dharma', 'Thu · 7:00 PM',
        'Online (InTheRooms Minnesota)'),
    _itr('InTheRooms LGBTQ+ Recovery', 'Fri · 8:00 PM',
        'Online (InTheRooms Minnesota)'),
  ];

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  static const _dayNames = {
    'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6,
  };

  static RecoveryMeeting _lr(String name, String time, String address) {
    final online = address.startsWith('Online');
    final parts = time.split('·');
    final day = _dayNames[parts.first.trim()];
    final clock = parts.length > 1 ? parts[1].trim() : '';
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(clock);
    int? minutes;
    if (clockMatch != null) {
      var h = int.parse(clockMatch.group(1)!);
      final m = int.parse(clockMatch.group(2)!);
      final pm = clockMatch.group(3) == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      minutes = h * 60 + m;
    }
    return RecoveryMeeting(
      id: 'mn_lr_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'LifeRing · Online' : 'LifeRing · Open',
      time: time,
      address: address,
      fellowship: 'LifeRing',
      day: day,
      minutes: minutes,
    );
  }

  static RecoveryMeeting _wfs(String name, String time, String address) {
    final online = address.startsWith('Online');
    final parts = time.split('·');
    final day = _dayNames[parts.first.trim()];
    final clock = parts.length > 1 ? parts[1].trim() : '';
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(clock);
    int? minutes;
    if (clockMatch != null) {
      var h = int.parse(clockMatch.group(1)!);
      final m = int.parse(clockMatch.group(2)!);
      final pm = clockMatch.group(3) == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      minutes = h * 60 + m;
    }
    return RecoveryMeeting(
      id: 'mn_wfs_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'WFS · Online' : 'WFS · Open',
      time: time,
      address: address,
      fellowship: 'WFS',
      day: day,
      minutes: minutes,
    );
  }

  static RecoveryMeeting _cr(String name, String time, String address) {
    final online = address.startsWith('Online');
    final parts = time.split('·');
    final day = _dayNames[parts.first.trim()];
    final clock = parts.length > 1 ? parts[1].trim() : '';
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(clock);
    int? minutes;
    if (clockMatch != null) {
      var h = int.parse(clockMatch.group(1)!);
      final m = int.parse(clockMatch.group(2)!);
      final pm = clockMatch.group(3) == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      minutes = h * 60 + m;
    }
    return RecoveryMeeting(
      id: 'mn_cr_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'CR · Online' : 'CR · Open',
      time: time,
      address: address,
      fellowship: 'CR',
      day: day,
      minutes: minutes,
    );
  }

  static RecoveryMeeting _smart(String name, String time, String address) {
    final online = address.startsWith('Online');
    final parts = time.split('·');
    final day = _dayNames[parts.first.trim()];
    final clock = parts.length > 1 ? parts[1].trim() : '';
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(clock);
    int? minutes;
    if (clockMatch != null) {
      var h = int.parse(clockMatch.group(1)!);
      final m = int.parse(clockMatch.group(2)!);
      final pm = clockMatch.group(3) == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      minutes = h * 60 + m;
    }
    return RecoveryMeeting(
      id: 'mn_smart_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'SMART · Online' : 'SMART · Open',
      time: time,
      address: address,
      fellowship: 'SMART',
      day: day,
      minutes: minutes,
    );
  }

  static RecoveryMeeting _itr(String name, String time, String address) {
    final online = address.startsWith('Online');
    final parts = time.split('·');
    final day = _dayNames[parts.first.trim()];
    final clock = parts.length > 1 ? parts[1].trim() : '';
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(clock);
    int? minutes;
    if (clockMatch != null) {
      var h = int.parse(clockMatch.group(1)!);
      final m = int.parse(clockMatch.group(2)!);
      final pm = clockMatch.group(3) == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      minutes = h * 60 + m;
    }
    return RecoveryMeeting(
      id: 'mn_itr_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'InTheRooms · Online' : 'InTheRooms · Open',
      time: time,
      address: address,
      fellowship: 'InTheRooms',
      day: day,
      minutes: minutes,
    );
  }

  /// All curated meetings for new pathways (LifeRing, WFS, CR, SMART, InTheRooms).
  /// These are merged into finder results alongside live feeds.
  static List<RecoveryMeeting> get allNewPathways => [
    ...lifeRingMinnesota,
    ...womenForSobrietyMinnesota,
    ...celebrateRecoveryMinnesota,
    ...smartRecoveryMinnesota,
    ...inTheRoomsMinnesota,
  ];

  /// Filter by fellowship
  static List<RecoveryMeeting> forFellowship(String fellowship) {
    switch (fellowship) {
      case 'LifeRing':
        return lifeRingMinnesota;
      case 'WFS':
        return womenForSobrietyMinnesota;
      case 'CR':
        return celebrateRecoveryMinnesota;
      case 'SMART':
        return smartRecoveryMinnesota;
      case 'InTheRooms':
        return inTheRoomsMinnesota;
      default:
        return [];
    }
  }
}