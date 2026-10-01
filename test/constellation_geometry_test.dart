import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/constellation_geometry.dart';

/// The bug these lock down was invisible to every test in the suite.
///
/// `ConstellationScreen`'s painter scaled star *positions* about the canvas
/// centre by `zoom`, never scaled star *size*, and had no pan gesture at all.
/// So a star a little off-centre left the screen at about 2.5x and there was
/// no gesture that could bring it back — found on a real B160V, see
/// `SESSION_HANDOFF.md` §7a and L27.
///
/// The property worth protecting is therefore not "zoom looks right" but
/// **every star stays reachable at every zoom level**, which is exactly what
/// `clampSkyPan` is for and what these tests assert.
void main() {
  // The B160V's canvas, so the numbers are the ones that actually broke.
  const phone = Size(720, 1290);
  const desktop = Size(1440, 900);
  const tiny = Size(320, 568);

  // `ConstellationNode3D.calculate` clamps radius to 0.1..0.45, and the
  // components are radius * sin * cos, so |x|,|y| <= 0.45. These are the
  // extremes the generator can actually emit.
  const extremes = <Offset>[
    Offset(0.45, 0.0),
    Offset(-0.45, 0.0),
    Offset(0.0, 0.45),
    Offset(0.0, -0.45),
    Offset(0.32, 0.32),
    Offset(-0.32, -0.32),
    Offset(0.1, -0.1),
  ];

  List<Offset> grid(int n) => [
        for (var i = 0; i < n; i++)
          Offset(
            -0.45 + 0.9 * (i / (n - 1)),
            0.45 - 0.9 * ((i * 7 % n) / (n - 1)),
          ),
      ];

  group('skyStarScale', () {
    test('is 1.0 at minimum zoom and grows monotonically', () {
      expect(skyStarScale(1.0), 1.0);
      var previous = 0.0;
      for (var z = 1.0; z <= 10.0; z += 0.25) {
        final s = skyStarScale(z);
        expect(s, greaterThan(previous), reason: 'must grow at zoom $z');
        previous = s;
      }
    });

    test('stays sane at the top of the range', () {
      // A linear mapping would put this at 10x and make a star wider than the
      // phone. The sub-linear curve is the point.
      expect(skyStarScale(10.0), lessThan(2.0));
      expect(skyStarScale(10.0), greaterThan(1.5));
    });
  });

  group('clampSkyPan — the reachability invariant', () {
    for (final size in [phone, desktop, tiny]) {
      for (final nodes in [extremes, grid(25), grid(60)]) {
        for (var zoom = 1.0; zoom <= 10.0; zoom += 0.5) {
          test('every star reachable at zoom $zoom on ${size.width.toInt()}x${size.height.toInt()}, ${nodes.length} nodes', () {
            // Get the full legal pan range by asking for impossible pans and
            // letting the clamp pin them to the ends.
            final loPan = clampSkyPan(
                normalised: nodes, size: size, zoom: zoom, desired: const Offset(-1e9, -1e9));
            final hiPan = clampSkyPan(
                normalised: nodes, size: size, zoom: zoom, desired: const Offset(1e9, 1e9));

            // Sanity: the clamp is monotonic, so lo must not exceed hi.
            expect(loPan.dx, lessThanOrEqualTo(hiPan.dx));
            expect(loPan.dy, lessThanOrEqualTo(hiPan.dy));

            final raw = skyPositions(
                normalised: nodes, size: size, zoom: zoom, pan: Offset.zero);

            for (var i = 0; i < raw.length; i++) {
              final p = raw[i];
              // A node is reachable if SOME dx in [loPan.dx, hiPan.dx] lands its
              // x inside the canvas, and likewise for y. Checking that any
              // *node* happens to be on screen would be wrong: once the
              // constellation is much larger than the canvas the bounding box
              // spans the canvas while every individual node sits outside it,
              // which is fine and expected.
              final xReachable =
                  p.dx + loPan.dx <= size.width && p.dx + hiPan.dx >= 0;
              final yReachable =
                  p.dy + loPan.dy <= size.height && p.dy + hiPan.dy >= 0;
              expect(xReachable && yReachable, isTrue,
                  reason: 'node $i at $p is unreachable at zoom $zoom on '
                      '${size.width}x$size; legal pan x '
                      '[${loPan.dx.toStringAsFixed(1)}, ${hiPan.dx.toStringAsFixed(1)}] '
                      'y [${loPan.dy.toStringAsFixed(1)}, ${hiPan.dy.toStringAsFixed(1)}]');
            }
          });
        }
      }
    }

    test('centres the sky and ignores pan when everything fits', () {
      for (var zoom = 1.0; zoom <= 2.0; zoom += 0.25) {
        final wanted = Offset(9999, -9999);
        final clamped = clampSkyPan(
          normalised: extremes,
          size: phone,
          zoom: zoom,
          desired: wanted,
        );
        expect(clamped.dx, lessThan(1.0), reason: 'x must be centred, not $clamped');
        expect(clamped.dy, lessThan(1.0), reason: 'y must be centred, not $clamped');
      }
    });

    test('is idempotent — clamping twice changes nothing', () {
      for (var zoom = 1.0; zoom <= 10.0; zoom += 0.5) {
        for (final desired in [
          Offset.zero,
          const Offset(500, -500),
          const Offset(-100000, 100000),
        ]) {
          final once = clampSkyPan(
              normalised: grid(40), size: phone, zoom: zoom, desired: desired);
          final twice = clampSkyPan(
              normalised: grid(40), size: phone, zoom: zoom, desired: once);
          expect(twice, once, reason: 'not idempotent at zoom $zoom');
        }
      }
    });

    test('degenerate inputs do not throw', () {
      expect(
        clampSkyPan(normalised: const [], size: phone, zoom: 3, desired: const Offset(1, 1)),
        Offset.zero,
      );
      expect(
        clampSkyPan(normalised: extremes, size: Size.zero, zoom: 3, desired: const Offset(1, 1)),
        Offset.zero,
      );
    });
  });

  group('a single off-centre star — the exact reported symptom', () {
    test('stays reachable across the whole zoom range and can be panned back', () {
      const one = [Offset(0.30, 0.08)];
      for (var zoom = 1.0; zoom <= 10.0; zoom += 0.5) {
        // Whatever pan the gesture left behind, the star must be inside.
        for (final desired in [
          Offset.zero,
          const Offset(2000, 0),
          const Offset(-2000, 0),
          const Offset(0, 2000),
          const Offset(0, -2000),
        ]) {
          final pan = clampSkyPan(
              normalised: one, size: phone, zoom: zoom, desired: desired);
          final p = skyPositions(
              normalised: one, size: phone, zoom: zoom, pan: pan);
          final inside = p.first.dx >= 0 &&
              p.first.dx <= phone.width &&
              p.first.dy >= 0 &&
              p.first.dy <= phone.height;
          expect(inside, isTrue,
              reason: 'single star stranded at zoom $zoom with pan $pan');
        }
      }
    });
  });

  group('gesturePan', () {
    test('a pure one-finger drag pans by exactly the finger delta', () {
      final size = phone;
      final pan = gesturePan(
        basePan: Offset.zero,
        baseZoom: 1.0,
        newZoom: 1.0,
        focalDelta: const Offset(40, -25),
        startFocal: const Offset(100, 100),
        size: size,
      );
      expect(pan.dx, closeTo(40, 0.001));
      expect(pan.dy, closeTo(-25, 0.001));
    });

    test('pinching about the centre pans by nothing extra', () {
      final size = phone;
      final pan = gesturePan(
        basePan: Offset.zero,
        baseZoom: 1.0,
        newZoom: 4.0,
        focalDelta: Offset.zero,
        startFocal: Offset(size.width / 2, size.height / 2),
        size: size,
      );
      expect(pan.dx, closeTo(0, 0.001));
      expect(pan.dy, closeTo(0, 0.001));
    });

    test('the grabbed point stays under the fingertip while pinching', () {
      // The property that makes a pinch feel right, and the reason
      // gesturePan carries that last term. This tests the algebra directly —
      // the clamp is exercised separately, and mixing the two in one test
      // hides which of them is broken.
      const size = phone;
      const baseZoom = 1.0;
      const newZoom = 5.0;
      const basePan = Offset(30, -20);
      const startFocal = Offset(520, 400);
      const movedFocal = Offset(580, 440);

      // Solve for the node that sits exactly under the finger when the gesture
      // starts. Without this the test "grabs" empty sky and asserts nothing.
      final centre = Offset(size.width / 2, size.height / 2);
      final grabbed = Offset(
        (startFocal.dx - centre.dx - basePan.dx) /
            (size.width * kSkySpread * baseZoom),
        (startFocal.dy - centre.dy - basePan.dy) /
            (size.height * kSkySpread * baseZoom),
      );
      // Sanity: the solved node is inside the range the generator can emit.
      expect(grabbed.dx.abs(), lessThanOrEqualTo(0.45));
      expect(grabbed.dy.abs(), lessThanOrEqualTo(0.45));

      final before = skyPositionOf(grabbed, size, baseZoom, basePan);
      expect(before.dx, closeTo(startFocal.dx, 0.01));
      expect(before.dy, closeTo(startFocal.dy, 0.01));

      final pan = gesturePan(
        basePan: basePan,
        baseZoom: baseZoom,
        newZoom: newZoom,
        focalDelta: movedFocal - startFocal,
        startFocal: startFocal,
        size: size,
      );
      final after = skyPositionOf(grabbed, size, newZoom, pan);
      expect(after.dx, closeTo(movedFocal.dx, 0.01),
          reason: 'grabbed point drifted horizontally during pinch');
      expect(after.dy, closeTo(movedFocal.dy, 0.01),
          reason: 'grabbed point drifted vertically during pinch');
    });
  });
}
