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

  const RecoveryConstellation3DWidget({
    super.key,
    required this.nodes,
  });

  @override
  State<RecoveryConstellation3DWidget> createState() => // <-- Warning resolved here
      _RecoveryConstellation3DWidgetState();
}

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

  Constellation3DPainter({
    required this.nodes,
    required this.yaw,
    required this.pitch,
    this.zoom = 1.0,
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

    final centerPaint = Paint()
      ..color = centerColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), 8.0, centerPaint);

    final corePaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), 4.0, corePaint);

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
      double px = cx + x2 * scale;
      double py = cy + y3 * scale;

      projectedPoints.add(Offset(px, py));
      depths.add(z3);
    }

    final linePaint = Paint()
      ..color = linkColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < projectedPoints.length; i++) {
      canvas.drawLine(
        Offset(cx, cy),
        projectedPoints[i],
        linePaint,
      );
      if (i > 0) {
        canvas.drawLine(projectedPoints[i - 1], projectedPoints[i], linePaint);
      }
    }

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

      canvas.drawCircle(projectedPoints[i], 10.0 * depthAlpha, starGlowPaint);
      canvas.drawCircle(projectedPoints[i], 4.0 * depthAlpha, starPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: nodes[i].title,
          style: TextStyle(
            color: labelColor.withValues(alpha: depthAlpha),
            fontSize: 9.0 * depthAlpha,
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
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.nodes != nodes ||
        oldDelegate.zoom != zoom;
  }
}