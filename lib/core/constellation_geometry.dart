/// Layout maths for the 2D constellation sky.
///
/// This lives apart from `constellation_screen.dart` for two reasons.
///
/// First, so there is **one** answer to "where is star *i* right now". The
/// painter and the tap hit-test used to compute this independently, which is
/// exactly how the zoom slider came to move its thumb in one coordinate space
/// and the stars in another.
///
/// Second, so the invariant that actually matters is testable without a device:
/// **every star must stay reachable at every zoom level**. Zooming used to scale
/// positions about the canvas centre with no pan and no clamp, so a star a
/// little off-centre left the screen entirely at around 2.5x and there was no
/// gesture that could bring it back.
///
/// The functions take *normalised* positions (roughly -0.45..0.45, which is
/// what `ConstellationNode3D.calculate` produces) rather than the node type
/// itself, so this module has no dependency on the screen layer.
library;

import 'dart:ui' show Offset, Size;

/// How much of the canvas half-extent a node at `|x| == 1` sits out from the
/// centre. Below 1.0 leaves a margin so stars never touch the bezel.
const double kSkySpread = 0.45;

/// Star radius grows with zoom, but sub-linearly.
///
/// A linear scale is wrong here: the zoom range is 1x-10x, so a linear mapping
/// would make a star wider than the phone at the top of the range. This gives
/// 1.0x at minimum zoom and 1.9x at maximum — a visible, believable growth that
/// still reads as "the same star, closer".
double skyStarScale(double zoom) => 1.0 + (zoom - 1.0) * 0.10;

/// Screen position of one normalised node.
Offset skyPositionOf(
  Offset normalised,
  Size size,
  double zoom,
  Offset pan,
) {
  final x = size.width / 2 + normalised.dx * size.width * kSkySpread * zoom + pan.dx;
  final y = size.height / 2 + normalised.dy * size.height * kSkySpread * zoom + pan.dy;
  return Offset(x, y);
}

/// Screen positions of every normalised node, in order.
List<Offset> skyPositions({
  required List<Offset> normalised,
  required Size size,
  required double zoom,
  required Offset pan,
}) =>
    [
      for (final n in normalised) skyPositionOf(n, size, zoom, pan),
    ];

/// Restrict [desired] to the range that keeps every star reachable.
///
/// Two regimes, and the difference matters:
///
/// * When the zoomed constellation **fits** the canvas, the pan is ignored
///   entirely and the sky is centred. Letting it drift would only ever show the
///   user empty space, which is the bug this module exists to prevent.
/// * When it is **too big to fit**, the pan is clamped to exactly the range
///   that can bring either edge of the constellation to the opposite edge of
///   the canvas. Every star is then reachable by construction — you may not be
///   able to see them all at once, but none of them can be lost.
///
/// `lo <= hi` holds because the fit test guarantees `span > extent`.
Offset clampSkyPan({
  required List<Offset> normalised,
  required Size size,
  required double zoom,
  required Offset desired,
}) {
  if (normalised.isEmpty || size.isEmpty) return Offset.zero;

  final raw = skyPositions(
    normalised: normalised,
    size: size,
    zoom: zoom,
    pan: Offset.zero,
  );
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in raw) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }

  double axis(double min, double max, double extent, double wanted) {
    final span = max - min;
    if (span <= extent) {
      // Fits: centre it and discard the requested pan.
      return (extent - span) / 2 - min;
    }
    final lo = extent - max; // content's right edge at the canvas' left edge
    final hi = -min; // content's left edge at the canvas' right edge
    return wanted.clamp(lo, hi);
  }

  return Offset(
    axis(minX, maxX, size.width, desired.dx),
    axis(minY, maxY, size.height, desired.dy),
  );
}

/// Pan for a gesture that has both panned and pinched.
///
/// [basePan] is the pan when the gesture began, [baseZoom] the zoom then, and
/// [focalDelta] how far the fingers have travelled. The last two terms are what
/// make a pinch zoom *about the fingers* rather than about the canvas centre:
/// the point the user grabbed stays under their fingertip.
///
/// Derivation, so the algebra is not "tidied up" into a bug later. A content
/// point sits at `P = C + O*z + pan`, where `C` is the canvas centre and `O`
/// the node's normalised offset. The point under the fingers at gesture start
/// is `P0 = C + O*s0 + basePan = startFocal`. Requiring
/// `P1 = startFocal + focalDelta` and solving for the pan at zoom `s1`:
///
/// ```text
/// pan = basePan*k + focalDelta + (startFocal - C) * (1 - k)   where k = s1/s0
/// ```
///
/// The `basePan*k` is easy to drop and looks harmless; it is not. Omitting it
/// double-counts any pan that was already in effect when the pinch began, and
/// the grabbed star visibly slides out from under the finger. The regression
/// test in `test/constellation_geometry_test.dart` pins the exact position.
Offset gesturePan({
  required Offset basePan,
  required double baseZoom,
  required double newZoom,
  required Offset focalDelta,
  required Offset startFocal,
  required Size size,
}) {
  final centre = Offset(size.width / 2, size.height / 2);
  final k = newZoom / baseZoom;
  return basePan * k + focalDelta + (startFocal - centre) * (1 - k);
}
