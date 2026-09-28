// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class WellnessWheelWidget extends StatefulWidget {
  final Map<String, double> initialScores;
  final ValueChanged<Map<String, double>>? onScoresChanged;

  const WellnessWheelWidget({
    super.key,
    required this.initialScores,
    this.onScoresChanged,
  });

  @override
  State<WellnessWheelWidget> createState() => _WellnessWheelWidgetState();
}

class _WellnessWheelWidgetState extends State<WellnessWheelWidget> {
  late Map<String, double> _scores;
  final List<String> _dimensions = [
    'Spiritual',
    'Intellectual',
    'Emotional',
    'Physical',
    'Social',
    'Occupational',
  ];

  @override
  void initState() {
    super.initState();
    _scores = Map<String, double>.from(widget.initialScores);
    for (final dim in _dimensions) {
      _scores.putIfAbsent(dim, () => 0.5);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    _updateScoreFromOffset(details.localPosition, size);
  }

  void _handleTapDown(TapDownDetails details, Size size) {
    _updateScoreFromOffset(details.localPosition, size);
  }

  void _updateScoreFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    final maxRadius = (size.width / 2) - 40.0;
    if (maxRadius <= 0) return;

    double angle = math.atan2(dy, dx);
    double adjustedAngle = angle + math.pi / 2;
    if (adjustedAngle < 0) {
      adjustedAngle += 2 * math.pi;
    }

    final sectionAngle = (2 * math.pi) / 6;
    final index = (((adjustedAngle + (sectionAngle / 2)) % (2 * math.pi)) / sectionAngle).floor() % 6;

    final double rawScore = (distance / maxRadius).clamp(0.0, 1.0);
    final double roundedScore = (rawScore * 10).round() / 10.0;

    setState(() {
      _scores[_dimensions[index]] = roundedScore;
    });

    if (widget.onScoresChanged != null) {
      widget.onScoresChanged!(Map<String, double>.from(_scores));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanUpdate: (details) => _handlePanUpdate(details, size),
            onTapDown: (details) => _handleTapDown(details, size),
            child: CustomPaint(
              size: size,
              painter: _WheelPainter(
                dimensions: _dimensions,
                scores: _scores,
                gridColor: Theme.of(context).colorScheme.outlineVariant,
                primaryColor: Theme.of(context).colorScheme.primary,
                nodeColor: Theme.of(context).colorScheme.surfaceContainer,
                labelColor: Theme.of(context).colorScheme.onSurface,
                accentGlow: AppColors.starMindfulness,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> dimensions;
  final Map<String, double> scores;
  final Color gridColor;
  final Color primaryColor;
  final Color nodeColor;
  final Color labelColor;
  final Color accentGlow;

  _WheelPainter({
    required this.dimensions,
    required this.scores,
    required this.gridColor,
    required this.primaryColor,
    required this.nodeColor,
    required this.labelColor,
    required this.accentGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) - 40.0;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, maxRadius * (i / 5), gridPaint);
    }

    final double angleStep = (2 * math.pi) / 6;

    for (int i = 0; i < 6; i++) {
      final double angle = (i * angleStep) - (math.pi / 2);
      final axisEnd = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      canvas.drawLine(center, axisEnd, gridPaint);

      final labelRadius = maxRadius + 18.0;
      final labelOffset = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      _drawText(
        canvas,
        dimensions[i],
        labelOffset,
        TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
    }

    final path = Path();
    final List<Offset> points = [];

    for (int i = 0; i < 6; i++) {
      final double angle = (i * angleStep) - (math.pi / 2);
      final double score = scores[dimensions[i]] ?? 0.5;
      final double radius = maxRadius * score;

      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      points.add(point);

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.12),
          accentGlow.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    final outlinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          accentGlow,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, outlinePaint);

    for (int i = 0; i < 6; i++) {
      final Offset point = points[i];

      final outerNodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 6.0, outerNodePaint);

      final innerNodePaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 4.0, innerNodePaint);

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(point, 8.0, glowPaint);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textOffset = Offset(
      offset.dx - (textPainter.width / 2),
      offset.dy - (textPainter.height / 2),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.dimensions != dimensions ||
        oldDelegate.scores != scores ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.accentGlow != accentGlow;
  }
}
