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

  // ---- The tester bug: "shows statewide meetings instead of local 2-mile" ----
  //
  // Two independent defects produced it, and the label being null hid both:
  //
  //   1. The dashboard gated the radius filter on `isCacheFresh(cachedAtMs)`,
  //      a 24-hour window. A fix older than a day meant no filtering at all.
  //   2. When the filter was skipped, `tierLabel` stayed null — so the card
  //      showed the entire state with nothing on screen to explain it.
  //
  // A home does not move 300 miles in a day, so a day-old fix is still the right
  // basis for "within 2 mi". These pin the window and the label together,
  // because fixing only one leaves the bug reproducible through the other.

  group('radius staleness window', () {
    final now = DateTime.now().millisecondsSinceEpoch;

    test('null is never usable', () {
      expect(isLocationUsableForRadius(null), isFalse);
    });

    test('a fix from 2 days ago IS usable for a radius', () {
      // This is the exact case the 24h window rejected. It is the difference
      // between a tester seeing their own neighbourhood and seeing the state.
      expect(isLocationUsableForRadius(now - const Duration(days: 2).inMilliseconds),
          isTrue);
    });

    test('a fix from 3 weeks ago is still usable', () {
      expect(isLocationUsableForRadius(now - const Duration(days: 21).inMilliseconds),
          isTrue);
    });

    test('a fix older than 30 days is rejected', () {
      expect(isLocationUsableForRadius(now - const Duration(days: 31).inMilliseconds),
          isFalse);
    });

    test('the radius window is deliberately LONGER than isCacheFresh', () {
      // If these ever converge again, the two questions have been conflated and
      // the daily false negative returns.
      final twoDays = now - const Duration(days: 2).inMilliseconds;
      expect(isCacheFresh(twoDays), isFalse);
      expect(isLocationUsableForRadius(twoDays), isTrue);
    });
  });

  test('applyRadiusTiers null location returns all statewide, and SAYS WHY', () {
    final ms = [_m(id: 'a', lat: 44.9778, lng: -93.2650), _m(id: 'b', lat: 46.0, lng: -93.0)];
    final r = applyRadiusTiers(ms, null);
    expect(r.meetings, hasLength(2));
    // The bare word "Statewide" was the whole user-facing explanation, and a
    // tester reading the card had no way to tell that a *setting* was
    // responsible for meetings they could not walk to.
    expect(r.tierLabel, contains('Statewide'));
    expect(r.tierLabel, contains('no location'));
  });

  test('applyRadiusTiers distinguishes "filter off" from "no location"', () {
    final ms = [_m(id: 'a', lat: 45.0778, lng: -93.2650)];
    final off = applyRadiusTiers(ms, _ref, enforceRadius: false);
    expect(off.tierLabel, contains('radius filter off'));
    final unknown = applyRadiusTiers(ms, null);
    expect(unknown.tierLabel, contains('no location'));
    // A filter that is ON but has no fix must not claim the filter is off —
    // that would send the user to toggle a setting that is already correct.
    expect(unknown.tierLabel, isNot(contains('filter off')));
    // And a null location must never read as "we know where you are".
    expect(unknown.tierLabel, isNot(contains('filter off')));
  });

  test('applyRadiusTiers enforceRadius false returns all statewide', () {
    final ms = [_m(id: 'a', lat: 45.0778, lng: -93.2650)];
    final r = applyRadiusTiers(ms, _ref, enforceRadius: false);
    expect(r.meetings, hasLength(1));
    expect(r.tierLabel, contains('Statewide'));
  });

  // The two tests below used to assert the tier cascade (Nearby -> Regional ->
  // Wider Area -> Statewide) and, on the empty case, that the FULL input list
  // came back with a "Statewide — No local meetings" label. That fallback was
  // the bug: during a 2-mile search the dashboard's "In progress now" card
  // advertised meetings from across the state. The contract now is a hard
  // radius filter that returns EMPTY rather than widening itself.
  test('applyRadiusTiers keeps only meetings inside the requested radius', () {
    final near = _m(id: 'near', lat: 45.0778, lng: -93.2650);
    final regional = _m(id: 'regional', lat: 45.3778, lng: -93.2650);
    final wider = _m(id: 'wider', lat: 45.7778, lng: -93.2650);
    final far = _m(id: 'far', lat: 46.4778, lng: -93.2650);

    // 2 mi (the default) admits only the ~7 mi `near` outlier is excluded too,
    // so use explicit radii to prove the boundary is honoured.
    final r = applyRadiusTiers([near, regional, wider, far], _ref,
        radiusMiles: 30);
    expect(r.meetings.map((m) => m.id), ['near', 'regional']);
    expect(r.tierLabel, contains('Within 30.0 mi'));
  });

  test('applyRadiusTiers returns EMPTY, not statewide, when nothing is in range',
      () {
    final far = _m(id: 'far', lat: 46.4778, lng: -93.2650);
    final r = applyRadiusTiers([far], _ref, radiusMiles: 2);
    expect(r.meetings, isEmpty,
        reason: 'a 2-mile search must never fall back to showing the whole state');
    expect(r.tierLabel, contains('Nothing within'));
  });

  test('applyRadiusTiers default radius is 2 miles, not a wide tier', () {
    // ~7 mi away: inside the old 25 km "Nearby" tier, far outside 2 mi.
    final sevenMiles = _m(id: 'seven', lat: 45.0778, lng: -93.2650);
    final r = applyRadiusTiers([sevenMiles], _ref);
    expect(r.meetings, isEmpty);
    expect(r.tierLabel, contains('Nothing within 2.0 mi'));
    // The empty-state label must name the control, because the radius is a
    // long-press on this very card and there is otherwise no way to find it.
    expect(r.tierLabel, contains('hold this card'));
  });

  test('applyRadiusTiers has NO label when there is nothing to filter', () {
    // An empty input is a distinct state from "nothing in range"; a label on an
    // empty card is noise, and "No meetings within 2 mi" would be a lie when the
    // filter never ran.
    final r = applyRadiusTiers(const [], _ref);
    expect(r.meetings, isEmpty);
    expect(r.tierLabel, isNull);
  });

  test('applyRadiusTiers drops no-coord meetings instead of surfacing them', () {
    final noCoord = _m(id: 'ghost', lat: 0, lng: 0);
    final near = _m(id: 'near', lat: 45.0010, lng: -93.2650);
    final r = applyRadiusTiers([noCoord, near], _ref, radiusMiles: 2);
    expect(r.meetings.map((m) => m.id), ['near'],
        reason: 'a meeting with no location cannot be inside any radius');
  });

  test('sanitizeRadiusMiles clamps to the supported range', () {
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(null),
        MeetingRadiusPrefs.defaultRadiusMiles);
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(0), 1.0);
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(500), 50.0);
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(double.nan),
        MeetingRadiusPrefs.defaultRadiusMiles);
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(double.infinity),
        MeetingRadiusPrefs.defaultRadiusMiles);
    expect(MeetingRadiusPrefs.sanitizeRadiusMiles(7), 7.0);
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
