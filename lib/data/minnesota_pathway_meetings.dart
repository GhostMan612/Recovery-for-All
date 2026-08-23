// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/data/minnesota_pathway_meetings.dart
//
// Curated Minnesota meetings for pathways without public JSON feeds
// (Recovery Dharma today; Wellbriety/others as they're verified).
//
// Sources: Recovery Dharma Minnesota (recoverydharmamn.org) schedule as
// listed in the public SobaSearch directory, August 2026. Addresses are
// real venues; coordinates are pending geocoding (map phase).

import '../services/meeting_finder_service.dart';

class MinnesotaPathwayMeetings {
  MinnesotaPathwayMeetings._();

  static final List<RecoveryMeeting> recoveryDharma = [
    _rd('RD @ Minnesota Zen Meditation Ctr', 'Sun · 6:00 PM',
        'Minnesota Zen Meditation Ctr, 3343 E Bde Maka Ska Pkwy, Minneapolis, MN 55408'),
    _rd('Taking the Practice Off the Pillow', 'Mon · 7:00 PM', 'Online (Minneapolis sangha)'),
    _rd('RD Meeting @ Unity Church Unitarian', 'Mon · 7:00 PM',
        'Unity Church Unitarian, 732 Holly Ave, St Paul, MN 55104'),
    _rd('Taking the Practice Off the Pillow', 'Mon · 8:30 PM', 'Online (Minneapolis sangha)'),
    _rd('RD Meeting @ Unity Church Unitarian', 'Tue · 1:00 PM',
        'Unity Church Unitarian, 732 Holly Ave, St Paul, MN 55104'),
    _rd('RD Northfield', 'Tue · 6:30 PM',
        'Northfield Buddhist Meditation Center, 313 1/2 Division St S #201, Northfield, MN 55057'),
    _rd('RD Flowering Lotus Meditation', 'Tue · 6:30 PM', 'Online (Minneapolis sangha)'),
    _rd('Taking the Practice Off the Pillow', 'Tue · 9:00 PM', 'Online (Minneapolis sangha)'),
    _rd('RD Wisdom on Wednesday', 'Wed · 5:45 PM',
        'St. Paul Yoga Center, 1162 Selby Ave, St Paul, MN 55104'),
    _rd('Recovery Dharma on St. Germain', 'Wed · 6:00 PM',
        'Lahr Block basement movement room, 601 W St Germain St, St Cloud, MN 56301'),
    _rd('RD in Fridley', 'Wed · 6:00 PM',
        "Mercy Hospital Unity Campus, 520 Osborne Rd NE #103, Fridley, MN 55432"),
    _rd('Taking the Practice Off the Pillow', 'Wed · 8:00 PM', 'Online (Minneapolis sangha)'),
    _rd('Rainbow RD @ All God\'s Children MCC', 'Wed · 8:00 PM',
        'All God\'s Children Metropolitan Community Church, 3100 Park Ave, Minneapolis, MN 55407'),
    _rd('RD Meeting @ Unity Church Unitarian', 'Thu · 1:00 PM',
        'Unity Church Unitarian, 732 Holly Ave, St Paul, MN 55104'),
    _rd('RD Northfield', 'Thu · 6:30 PM',
        'Northfield Buddhist Meditation Center, 313 1/2 Division St S #201, Northfield, MN 55057'),
    _rd('RD @ Shambhala Meditation Center', 'Thu · 7:30 PM',
        'Shambhala Meditation Center of Minneapolis, 2931 Grand St NE, Minneapolis, MN 55418'),
    _rd('Taking the Practice Off the Pillow', 'Thu · 9:00 PM', 'Online (Minneapolis sangha)'),
    _rd('RD Core Recovery Concepts', 'Fri · 7:00 PM',
        'St. Paul Yoga Center, 1162 Selby Ave, St Paul, MN 55104'),
    _rd('RD Minneapolis — Alano', 'Sat · 11:00 AM',
        'Minneapolis Alano Society, 2218 1st Ave S, Minneapolis, MN 55404'),
    _rd('RD @ Grace United Methodist Church', 'Sat · 11:00 AM',
        'Grace United Methodist Church, 1120 17th St S, Moorhead, MN 56560'),
    _rd('RD @ Yoga Sanctuary', 'Sat · 12:30 PM',
        'Yoga Sanctuary, 100 W 46th St, Minneapolis, MN 55419'),
  ];

  static RecoveryMeeting _rd(String name, String time, String address) {
    final online = address.startsWith('Online');
    return RecoveryMeeting(
      id: 'mn_rd_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').hashCode.abs()}'
          '_${time.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase()}',
      name: name,
      latitude: 0,
      longitude: 0,
      type: online ? 'Recovery Dharma · Online' : 'Recovery Dharma · Open',
      time: time,
      address: address,
    );
  }

  /// Everything curated, ready to merge into finder results.
  static List<RecoveryMeeting> get all => [...recoveryDharma];
}
