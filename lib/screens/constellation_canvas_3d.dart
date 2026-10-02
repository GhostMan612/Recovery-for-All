// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ConstellationNode3D {
  final String id;
  final String title;
  final String category;
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;

  ConstellationNode3D({
    required this.id,
    required this.title,
    required this.category,
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
  });

  factory ConstellationNode3D.calculate({
    required String id,
    required String title,
    required String category,
    required DateTime timestamp,
    required int index,
  }) {
    double theta;
    switch (category.toLowerCase()) {
      case 'spiritual':
        theta = pi / 4;
        break;
      case 'community':
        theta = 3 * pi / 4;
        break;
      case 'service':
        theta = 5 * pi / 4;
        break;
      case 'mindfulness':
        theta = 7 * pi / 4;
        break;
      default:
        theta = 0.0;
    }

    final int titleHash = title.hashCode;
    final Random random = Random(titleHash);

    final double thetaJitter = (random.nextDouble() - 0.5) * (pi / 6);
    final double finalTheta = theta + thetaJitter;

    final double phi = (random.nextDouble() - 0.5) * (pi / 3) + (pi / 2);

    final double baseRadius = 0.15 + (index * 0.08);
    final double radiusJitter = (random.nextDouble() - 0.5) * 0.05;
    final double radius = (baseRadius + radiusJitter).clamp(0.1, 0.45);

    final double x = radius * sin(phi) * cos(finalTheta);
    final double y = radius * sin(phi) * sin(finalTheta);
    final double z = radius * cos(phi);

    return ConstellationNode3D(
      id: id,
      title: title,
      category: category,
      timestamp: timestamp,
      x: x,
      y: y,
      z: z,
    );
  }
}

class RecoveryConstellation3DWidget extends StatefulWidget {
  final List<ConstellationNode3D> nodes;

  /// 2D zoom, carried across from [_ConstellationCanvas] so the slider keeps
  /// meaning the same thing in both modes.
  ///
  /// This used to be absent, and that was a bug of its own. The zoom slider
  /// sits OUTSIDE the `_is3DView` conditional, so it is on screen in 3D mode;
  /// it was simply ignored by the 3D painter, which hard-defaulted `zoom` to
  /// 1.0. A slider that renders and does nothing is worse than a hidden one —
  /// the user drags it, nothing moves, and the app looks broken.
  ///
  /// It is deliberately NOT passed through raw. [_zoomFor3D] maps the 1.0-10.0
  /// 2D range onto a much smaller 3D range; at the raw value the projection's
  /// perspective term (300/(300+z+150)) is already near 0.5, so 10.0 would put
  /// every star hundreds of logical pixels off-screen.
  final double zoom;

  /// 2D pan, so a user who has framed part of their sky and then switches to
  /// 3D does not silently lose their framing.
  final Offset pan;

  const RecoveryConstellation3DWidget({
    super.key,
    required this.nodes,
    this.zoom = 1.0,
    this.pan = Offset.zero,
  });

  /// Maps the 2D zoom range onto a 3D range that keeps stars on screen.
  ///
  /// 1.0-10.0 becomes 0.85-2.6. Below 1.0 the sky shrinks toward the centre
  /// hub and the branch lines become unreadable; above ~2.6 the outermost
  /// stars leave the viewport entirely, which is the 2D `clampSkyPan`
  /// problem again in a projection that has no clamp.
  static double _zoomFor3D(double zoom2d) => zoomFor3D(zoom2d);

  @override
  State<RecoveryConstellation3DWidget> createState() => // <-- Warning resolved here
      _RecoveryConstellation3DWidgetState();
}

/// Maps the 2D canvas zoom (1.0-10.0) onto the 3D projection's usable range.
///
/// Top-level and visible-for-testing rather than a private static, because the
/// mapping is the part with arithmetic worth pinning: an off-by-one in the
/// divisor sends every star off-screen, and that is only observable by
/// rendering — the cheapest possible check is to assert the numbers.
///
/// 1.0-10.0 becomes 0.85-2.6, clamped at both ends. Above ~2.6 the outermost
/// stars leave the viewport, which is the `clampSkyPan` problem again in a
/// projection that has no clamp; below 1.0 the branch lines collapse into the
/// centre hub and stop being readable.
double zoomFor3D(double zoom2d) =>
    (0.85 + (zoom2d - 1.0) * (2.6 - 0.85) / 9.0).clamp(0.85, 2.6);

class _RecoveryConstellation3DWidgetState
    extends State<RecoveryConstellation3DWidget> {
  double _yaw = 0.0;
  double _pitch = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The 3D surface is drawn by TextPainter/canvas calls, which emit no
    // semantics of their own — without this a screen-reader user gets an
    // unlabelled region where the star list used to be (same class of bug as
    // the Wellness Check-In).
    return Semantics(
      label: '3D constellation view. ${widget.nodes.length} '
          '${widget.nodes.length == 1 ? 'star' : 'stars'}. Drag to rotate.',
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _yaw += details.delta.dx * 0.01;
            _pitch += details.delta.dy * 0.01;
          });
        },
        // `HitTestBehavior.opaque`, not the default `deferToChild`.
        //
        // This widget fills the Stack, so it is the last child in hit-test
        // order for every pixel it covers. With `deferToChild` the gesture
        // arena only claims a tap when one of its DESCENDANTS hits — and this
        // subtree ends in an `ExcludeSemantics` over a plain `Container` plus
        // canvas draws, none of which are hit-testable. Taps would therefore
        // fall straight through the 3D surface onto the 2D star canvas beneath
        // it, so a drag aimed at "leave 3D" would silently pan stars behind a
        // surface the user believes is solid.
        //
        // Opaque states the real intent: while 3D mode is on, this region
        // belongs to 3D mode. Combined with invariant 10 — which requires the
        // overlay to be declared BEFORE the controls — the split is correct.
        // Controls declared after it win the hit test; everything else belongs
        // to the 3D canvas and drags to rotate.
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: theme.colorScheme.surface,
            child: CustomPaint(
              painter: Constellation3DPainter(
                nodes: widget.nodes,
                yaw: _yaw,
                pitch: _pitch,
                zoom: RecoveryConstellation3DWidget._zoomFor3D(widget.zoom),
                pan: widget.pan,
                centerColor: theme.colorScheme.primary,
                linkColor: AppColors.accentSky,
                starColor: theme.colorScheme.onSurface,
                labelColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Constellation3DPainter extends CustomPainter {
  final List<ConstellationNode3D> nodes;
  final double yaw;
  final double pitch;
  final double zoom;
  final Color centerColor;
  final Color linkColor;
  final Color starColor;
  final Color labelColor;

  /// Screen-space offset applied after projection, carrying the 2D pan into 3D.
  ///
  /// Applied in *pixels*, not before the perspective divide, so it shifts the
  /// finished image rather than moving stars in 3D space. Multiplying it by
  /// [zoom] would be wrong: pan is a framing offset, not a position in the
  /// scene, and the user did not drag these stars sideways in 3D — they
  /// dragged the 2D sky.
  final Offset pan;

  Constellation3DPainter({
    required this.nodes,
    required this.yaw,
    required this.pitch,
    this.zoom = 1.0,
    this.pan = Offset.zero,
    required this.centerColor,
    required this.linkColor,
    required this.starColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double perspective = 300.0;

    // The hub circle is drawn before the `nodes.isEmpty` early return, so it
    // moves with the pan too — otherwise an empty-but-panned sky renders a
    // centre dot that contradicts every other framing cue.
    final hub = Offset(cx + pan.dx, cy + pan.dy);

    final centerPaint = Paint()
      ..color = centerColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(hub, 8.0, centerPaint);

    final corePaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(hub, 4.0, corePaint);

    if (nodes.isEmpty) return;

    final cosY = cos(yaw);
    final sinY = sin(yaw);
    final cosP = cos(pitch);
    final sinP = sin(pitch);

    final List<Offset> projectedPoints = [];
    final List<double> depths = [];

    for (var node in nodes) {
      double x1 = node.x * (size.width * 0.5);
      double y1 = node.y * (size.height * 0.5);
      double z1 = node.z * (size.width * 0.5);

      double x2 = x1 * cosY - z1 * sinY;
      double z2 = x1 * sinY + z1 * cosY;

      double y3 = y1 * cosP - z2 * sinP;
      double z3 = y1 * sinP + z2 * cosP;

      double scale = (perspective / (perspective + z3 + 150.0)) * zoom;
      double px = cx + x2 * scale + pan.dx;
      double py = cy + y3 * scale + pan.dy;

      projectedPoints.add(Offset(px, py));
      depths.add(z3);
    }

    final linePaint = Paint()
      ..color = linkColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // The hub the branch lines radiate from must move by the SAME pan as the
    // stars. Leaving it at the geometric centre while the stars are offset
    // detaches every line from its origin — the lines would still point at the
    // right star but start from the wrong place, which reads as a rendering
    // bug rather than as a panned view.
    for (int i = 0; i < projectedPoints.length; i++) {
      canvas.drawLine(
        hub,
        projectedPoints[i],
        linePaint,
      );
      if (i > 0) {
        canvas.drawLine(projectedPoints[i - 1], projectedPoints[i], linePaint);
      }
    }

    // Star and label size follow the zoom, not just the star spacing.
    //
    // Scaling only the positions is the exact flaw the 2D painter already
    // fixed once ("starScale is what makes zoom legible: without it a star
    // stayed 6px at every zoom level and zooming only moved it around"). The
    // same reasoning applies here: if the stars merely spread apart, the view
    // reads as panning rather than as approaching.
    //
    // `min(zoom, 1.8)` on the size factor: position zoom goes to 2.6 but a
    // 4px star at 2.6x is a 10px star with a 26px blur, and at depth the
    // glow swamps the label it is meant to sit behind.
    final double sizeScale = zoom.clamp(0.85, 1.8);

    for (int i = 0; i < projectedPoints.length; i++) {
      final zVal = depths[i];
      final double depthAlpha = ((150.0 - zVal) / 300.0).clamp(0.1, 1.0);

      final catColor = _categoryColor(nodes[i].category);
      final starGlowPaint = Paint()
        ..color = catColor.withValues(alpha: 0.4 * depthAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
        ..style = PaintingStyle.fill;

      final starPaint = Paint()
        ..color = starColor.withValues(alpha: depthAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
          projectedPoints[i], 10.0 * depthAlpha * sizeScale, starGlowPaint);
      canvas.drawCircle(
          projectedPoints[i], 4.0 * depthAlpha * sizeScale, starPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: nodes[i].title,
          style: TextStyle(
            color: labelColor.withValues(alpha: depthAlpha),
            fontSize: 9.0 * depthAlpha * sizeScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(projectedPoints[i].dx + 8.0, projectedPoints[i].dy - 6.0),
      );
    }
  }

  static Color _categoryColor(String category) {
    switch (category) {
      case 'step_work': return AppColors.starStepWork;
      case 'community': return AppColors.starCommunity;
      case 'service': return AppColors.starService;
      case 'mindfulness': return AppColors.starMindfulness;
      case 'spiritual': return AppColors.starSpiritual;
      default: return AppColors.starMilestone; // milestone = gold
    }
  }

  @override
  bool shouldRepaint(covariant Constellation3DPainter oldDelegate) {
    // `pan` was missing from this list, so panning the 2D sky and then
    // switching to 3D left the painter believing nothing had changed: no
    // repaint, stale positions, and the view appeared to ignore the pan
    // entirely. The same class of bug as an un-repainted AnimationController
    // that this repo has hit before.
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.nodes != nodes ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}