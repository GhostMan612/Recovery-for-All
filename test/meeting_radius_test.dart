// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:recovery_for_all/core/meeting_radius_logic.dart';
import 'package:recovery_for_all/services/meeting_finder_service.dart';

RecoveryMeeting _m({
  required String id,
  required double lat,
  required double lng,
  int? day,
  int? minutes,
}) =>
    RecoveryMeeting(
      id: id,
      name: 'M$id',
      latitude: lat,
      longitude: lng,
      type: 'AA',
      time: '00:00',
      address: 'x',
      day: day,
      minutes: minutes,
    );

final _ref = ll.LatLng(44.9778, -93.2650);
final _wedNoon = DateTime(2026, 9, 9, 12, 0);

void main() {
  test('isCacheFresh null is stale', () {
    expect(isCacheFresh(null), isFalse);
  });

  test('isCacheFresh 1h ago is fresh, 25h ago is stale, exactly 24h is stale', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    const hour = 60 * 60 * 1000;
    expect(isCacheFresh(now - hour), isTrue);
    expect(isCacheFresh(now - 25 * hour), isFalse);
    expect(isCacheFresh(now - 24 * hour), isFalse);
    expect(isCacheFresh(now - 24 * hour + 1000), isTrue);
  });

  test('calculateSortScore clamps negatives and applies formula', () {
    expect(calculateSortScore(0, 0), 0.0);
    expect(calculateSortScore(10, 60), 13.0);
    expect(calculateSortScore(5, 30), 6.5);
    expect(calculateSortScore(5, -30), 5.0);
    expect(calculateSortScore(-4, 0), -4.0);
  });

  test('applyRadiusTiers null location returns all statewide', () {
    final ms = [_m(id: 'a', lat: 44.9778, lng: -93.2650), _m(id: 'b', lat: 46.0, lng: -93.0)];
    final r = applyRadiusTiers(ms, null);
    expect(r.meetings, hasLength(2));
    expect(r.tierLabel, 'Statewide');
  });

  test('applyRadiusTiers enforceRadius false returns all statewide', () {
    final ms = [_m(id: 'a', lat: 45.0778, lng: -93.2650)];
    final r = applyRadiusTiers(ms, _ref, enforceRadius: false);
    expect(r.meetings, hasLength(1));
    expect(r.tierLabel, 'Statewide');
  });

  test('applyRadiusTiers cascades Nearby Regional Wider Area Statewide', () {
    final near = _m(id: 'near', lat: 45.0778, lng: -93.2650);
    final regional = _m(id: 'regional', lat: 45.3778, lng: -93.2650);
    final wider = _m(id: 'wider', lat: 45.7778, lng: -93.2650);
    final far = _m(id: 'far', lat: 46.4778, lng: -93.2650);
    var r = applyRadiusTiers([far, wider, regional, near], _ref);
    expect(r.tierLabel, 'Nearby');
    expect(r.meetings.map((m) => m.id), ['near']);
    r = applyRadiusTiers([far, wider, regional], _ref);
    expect(r.tierLabel, 'Regional');
    expect(r.meetings.map((m) => m.id), ['regional']);
    r = applyRadiusTiers([far, wider], _ref);
    expect(r.tierLabel, 'Wider Area');
    expect(r.meetings.map((m) => m.id), ['wider']);
    r = applyRadiusTiers([far], _ref);
    expect(r.tierLabel, 'Statewide — No local meetings found in the next 6 hours');
    expect(r.meetings.map((m) => m.id), ['far']);
  });

  test('applyRadiusTiers excludes no-coord meetings from tiers but keeps fallback', () {
    final noCoord = _m(id: 'ghost', lat: 0, lng: 0);
    final near = _m(id: 'near', lat: 45.0778, lng: -93.2650);
    var r = applyRadiusTiers([noCoord, near], _ref);
    expect(r.tierLabel, 'Nearby');
    expect(r.meetings.map((m) => m.id), ['near']);
    r = applyRadiusTiers([noCoord], _ref);
    expect(r.tierLabel, 'Statewide — No local meetings found in the next 6 hours');
    expect(r.meetings.map((m) => m.id), ['ghost']);
  });

  test('sortMeetings orders live before soon before later at equal distance', () {
    const lat = 45.0778;
    const lng = -93.2650;
    final live = _m(id: 'live', lat: lat, lng: lng, day: 3, minutes: 690);
    final soon = _m(id: 'soon', lat: lat, lng: lng, day: 3, minutes: 780);
    final later = _m(id: 'later', lat: lat, lng: lng, day: 3, minutes: 900);
    final out = sortMeetings([later, soon, live], _ref, _wedNoon);
    expect(out.map((m) => m.id).toList(), ['live', 'soon', 'later']);
  });

  test('sortMeetings sends no-coord meetings last and keeps every entry', () {
    final ghost = _m(id: 'ghost', lat: 0, lng: 0);
    final live = _m(id: 'live', lat: 45.0778, lng: -93.2650, day: 3, minutes: 690);
    final out = sortMeetings([ghost, live], _ref, _wedNoon);
    expect(out.map((m) => m.id).toList(), ['live', 'ghost']);
  });

  test('sortMeetings scores are non-decreasing across a mixed list', () {
    const d = ll.Distance();
    final ms = [
      _m(id: 'a', lat: 45.7778, lng: -93.2650, day: 3, minutes: 690),
      _m(id: 'b', lat: 45.0778, lng: -93.2650, day: 3, minutes: 900),
      _m(id: 'c', lat: 45.3778, lng: -93.2650),
      _m(id: 'd', lat: 0, lng: 0),
    ];
    final out = sortMeetings(ms, _ref, _wedNoon);
    expect(out, hasLength(4));
    final scores = [
      for (final m in out)
        if (!m.hasLocation)
          double.infinity
        else if (MeetingFinderService.isInProgress(m, _wedNoon))
          d.as(ll.LengthUnit.Kilometer, _ref, ll.LatLng(m.latitude, m.longitude))
        else
          calculateSortScore(
            d.as(ll.LengthUnit.Kilometer, _ref, ll.LatLng(m.latitude, m.longitude)),
            MeetingFinderService.nextOccurrence(m, _wedNoon) == null
                ? 1 << 30
                : MeetingFinderService.nextOccurrence(m, _wedNoon)!.difference(_wedNoon).inMinutes,
          ),
    ];
    for (var i = 0; i + 1 < scores.length; i++) {
      expect(scores[i] <= scores[i + 1], isTrue);
    }
  });
}
