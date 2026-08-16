// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

class ConstellationNode {
  final String id;
  final String title;
  final String category;
  final DateTime timestamp;
  final double positionX;
  final double positionY;

  ConstellationNode({
    required this.id,
    required this.title,
    required this.category,
    required this.timestamp,
    required this.positionX,
    required this.positionY,
  });

  factory ConstellationNode.calculate({
    required String id,
    required String title,
    required String category,
    required DateTime timestamp,
    required int index,
  }) {
    double baseAngle;
    switch (category.toLowerCase()) {
      case 'spiritual':
        baseAngle = pi / 4;
        break;
      case 'community':
        baseAngle = 3 * pi / 4;
        break;
      case 'service':
        baseAngle = 5 * pi / 4;
        break;
      case 'mindfulness':
        baseAngle = 7 * pi / 4;
        break;
      default:
        baseAngle = 0.0;
    }

    final int titleHash = title.hashCode;
    final Random random = Random(titleHash);
    
    final double angleJitter = (random.nextDouble() - 0.5) * (pi / 6);
    final double angle = baseAngle + angleJitter;

    final double baseRadius = 0.15 + (index * 0.08);
    final double radiusJitter = (random.nextDouble() - 0.5) * 0.05;
    final double radius = (baseRadius + radiusJitter).clamp(0.1, 0.45);

    final double x = 0.5 + radius * cos(angle);
    final double y = 0.5 + radius * sin(angle);

    return ConstellationNode(
      id: id,
      title: title,
      category: category,
      timestamp: timestamp,
      positionX: x,
      positionY: y,
    );
  }
}

class RecoveryConstellationWidget extends StatelessWidget {
  final List<ConstellationNode> nodes;

  const RecoveryConstellationWidget({
    super.key,
    required this.nodes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F172A),
      child: CustomPaint(
        painter: ConstellationPainter(nodes: nodes),
      ),
    );
  }
}

class ConstellationPainter extends CustomPainter {
  final List<ConstellationNode> nodes;

  ConstellationPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final centerPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      8.0,
      centerPaint,
    );

    final corePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      4.0,
      corePaint,
    );

    if (nodes.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final List<Offset> points = nodes.map((node) {
      return Offset(node.positionX * size.width, node.positionY * size.height);
    }).toList();

    for (int i = 0; i < points.length; i++) {
      canvas.drawLine(
        Offset(size.width / 2, size.height / 2),
        points[i],
        linePaint,
      );
      if (i > 0) {
        canvas.drawLine(points[i - 1], points[i], linePaint);
      }
    }

    final starGlowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..style = PaintingStyle.fill;

    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 10.0, starGlowPaint);
      canvas.drawCircle(points[i], 4.0, starPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: nodes[i].title,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx + 8.0, points[i].dy - 6.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) {
    return oldDelegate.nodes != nodes;
  }
}