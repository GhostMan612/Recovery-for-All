// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// Animated trail of footprints for the Meeting Finder loading state.
//
// The dashboard used to fetch the user's position and the whole meeting
// directory *before* navigating, so a tap on "Meeting Finder" sat dead for
// up to ~5 s and then the screen suddenly switched. The fix navigates
// instantly and lets MeetingMapScreen load behind its own staged loading
// view — but that view showed only a generic explore icon, so the user
// still had no sense of *going somewhere*. This trail is the going
// somewhere: footprints pulse in sequence, left-right-left, like walking
// to the meeting.
//
// Drawn in code (CustomPaint), no image assets, no new dependencies.
// Theme-aware: defaults to the scheme primary. When the platform asks for
// reduced motion, the prints render static at full opacity instead of
// animating.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class FootprintTrail extends StatefulWidget {
  const FootprintTrail({
    super.key,
    this.count = 5,
    this.color,
    this.cycle = const Duration(milliseconds: 1800),
  });

  /// Footprints in the trail.
  final int count;

  /// Print colour. Defaults to the theme primary.
  final Color? color;

  /// Time for one left-to-right pulse wave.
  final Duration cycle;

  @override
  State<FootprintTrail> createState() => _FootprintTrailState();
}

class _FootprintTrailState extends State<FootprintTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pulse for print [index]: a travelling sine wave, so the brightest
  /// print walks left to right and loops smoothly with no jump at the seam.
  double _opacityFor(int index, double progress) {
    final wave =
        0.5 + 0.5 * math.sin(2 * math.pi * (progress - index * 0.15));
    return 0.3 + 0.7 * wave;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // The stage label below this trail already announces the load state
    // ("Finding you…", "Fetching meetings…"), so the decoration itself
    // stays out of the semantics tree.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    key: ValueKey('footprint-opacity-$i'),
                    opacity:
                        reduceMotion ? 1.0 : _opacityFor(i, _controller.value),
                    child: Transform.translate(
                      // Alternating rise/fall: left foot, right foot.
                      offset: Offset(0, i.isEven ? -5 : 5),
                      child: Transform.rotate(
                        angle: i.isEven ? -0.18 : 0.18,
                        child: CustomPaint(
                          key: ValueKey('footprint-$i'),
                          size: const Size(26, 42),
                          painter: _FootprintPainter(color),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One footprint: forefoot ellipse, heel circle, four toe dots.
/// Drawn in a 26 x 42 box, toe-first (pointing up).
class _FootprintPainter extends CustomPainter {
  _FootprintPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // Toes: four dots arcing across the top, middle toes largest.
    const toes = [
      (6.0, 4.5, 2.4),
      (11.0, 2.5, 3.0),
      (16.5, 2.5, 2.9),
      (21.5, 4.5, 2.2),
    ];
    for (final (x, y, r) in toes) {
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    // Forefoot.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(13, 15), width: 16, height: 15),
      paint,
    );
    // Heel.
    canvas.drawCircle(const Offset(13, 33), 6, paint);
  }

  @override
  bool shouldRepaint(_FootprintPainter oldDelegate) =>
      oldDelegate.color != color;
}
