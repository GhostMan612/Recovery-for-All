// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

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
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _yaw += details.delta.dx * 0.01;
          _pitch += details.delta.dy * 0.01;
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0F172A),
        child: CustomPaint(
          painter: Constellation3DPainter(
            nodes: widget.nodes,
            yaw: _yaw,
            pitch: _pitch,
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

  Constellation3DPainter({
    required this.nodes,
    required this.yaw,
    required this.pitch,
    this.zoom = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double perspective = 300.0;

    final centerPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), 8.0, centerPaint);

    final corePaint = Paint()
      ..color = const Color(0xFF38BDF8)
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
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.3)
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
        ..color = Colors.white.withValues(alpha: depthAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(projectedPoints[i], 10.0 * depthAlpha, starGlowPaint);
      canvas.drawCircle(projectedPoints[i], 4.0 * depthAlpha, starPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: nodes[i].title,
          style: TextStyle(
            color: const Color(0xFF94A3B8).withValues(alpha: depthAlpha),
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
      case 'step_work': return const Color(0xFF34D399);
      case 'community': return const Color(0xFF38BDF8);
      case 'service': return const Color(0xFFF97316);
      case 'mindfulness': return const Color(0xFFA78BFA);
      case 'spiritual': return const Color(0xFF34D399);
      default: return const Color(0xFFFBBF24); // milestone = gold
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