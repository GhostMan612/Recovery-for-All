// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/trial_monster_painter.dart
//
// Procedural shadow-monster painters for Trials of the Path (R9).
// Each monster is an abstract shape — no gore (gate G2) — breathing
// via a single shared ticker param [t] in 0..1.

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TrialMonsterKind { wraith, hound, fog, reaper }

class TrialMonsterPainter extends CustomPainter {
  final TrialMonsterKind kind;
  final Color baseColor;
  final double t; // 0..1 breathing phase
  final double hitFlash; // 0..1 white flash on hit

  TrialMonsterPainter({
    required this.kind,
    required this.baseColor,
    required this.t,
    this.hitFlash = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 8;
    final breathe = math.sin(t * 2 * math.pi) * 0.06 + 1.0;
    final flashColor = Color.lerp(baseColor, Colors.white, hitFlash)!;

    // Soft shadow under monster
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + size.height * 0.32),
          width: size.width * 0.55, height: 18),
      shadowPaint,
    );

    switch (kind) {
      case TrialMonsterKind.wraith:
        _paintWraith(canvas, size, cx, cy, breathe, flashColor);
      case TrialMonsterKind.hound:
        _paintHound(canvas, size, cx, cy, breathe, flashColor);
      case TrialMonsterKind.fog:
        _paintFog(canvas, size, cx, cy, breathe, flashColor);
      case TrialMonsterKind.reaper:
        _paintReaper(canvas, size, cx, cy, breathe, flashColor);
    }
  }

  void _paintWraith(Canvas c, Size s, double cx, double cy,
      double breathe, Color col) {
    final h = s.height * 0.58 * breathe;
    final w = s.width * 0.32;
    final path = Path()
      ..moveTo(cx - w * 0.4, cy + h * 0.35)
      ..cubicTo(cx - w * 0.6, cy, cx - w * 0.5, cy - h * 0.3,
          cx - w * 0.15, cy - h * 0.45)
      ..cubicTo(cx, cy - h * 0.5, cx + w * 0.15, cy - h * 0.45,
          cx + w * 0.5, cy - h * 0.3)
      ..cubicTo(cx + w * 0.6, cy, cx + w * 0.4, cy + h * 0.35,
          cx, cy + h * 0.42)
      ..close();
    // Waver
    final waver = math.sin(t * 2 * math.pi * 1.3) * 4;
    c.save();
    c.translate(waver, 0);
    c.drawPath(path, Paint()..color = col.withValues(alpha: 0.95));
    // Inner glow
    c.drawPath(path, Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    c.restore();
    // Eyes
    _eyes(c, cx, cy - h * 0.18, col);
  }

  void _paintHound(Canvas c, Size s, double cx, double cy,
      double breathe, Color col) {
    final lunge = math.sin(t * 2 * math.pi) * 6;
    c.save();
    c.translate(lunge, 0);
    final body = Path()
      ..moveTo(cx - s.width * 0.28, cy + s.height * 0.18)
      ..cubicTo(cx - s.width * 0.32, cy - s.height * 0.08,
          cx - s.width * 0.12, cy - s.height * 0.22,
          cx, cy - s.height * 0.18)
      ..cubicTo(cx + s.width * 0.12, cy - s.height * 0.22,
          cx + s.width * 0.32, cy - s.height * 0.08,
          cx + s.width * 0.28, cy + s.height * 0.18)
      ..cubicTo(cx + s.width * 0.18, cy + s.height * 0.24,
          cx - s.width * 0.18, cy + s.height * 0.24,
          cx - s.width * 0.28, cy + s.height * 0.18)
      ..close();
    c.drawPath(body, Paint()..color = col);
    // Ears
    final ear = Path()
      ..moveTo(cx - s.width * 0.18, cy - s.height * 0.18)
      ..lineTo(cx - s.width * 0.22, cy - s.height * 0.32)
      ..lineTo(cx - s.width * 0.08, cy - s.height * 0.22)
      ..close();
    c.drawPath(ear, Paint()..color = col.withValues(alpha: 0.85));
    final ear2 = Path()
      ..moveTo(cx + s.width * 0.18, cy - s.height * 0.18)
      ..lineTo(cx + s.width * 0.22, cy - s.height * 0.32)
      ..lineTo(cx + s.width * 0.08, cy - s.height * 0.22)
      ..close();
    c.drawPath(ear2, Paint()..color = col.withValues(alpha: 0.85));
    c.restore();
    _eyes(c, cx, cy - s.height * 0.08, col, spacing: s.width * 0.14);
  }

  void _paintFog(Canvas c, Size s, double cx, double cy,
      double breathe, Color col) {
    final drift = math.sin(t * 2 * math.pi * 0.7) * 8;
    final blobs = [
      (dx: -s.width * 0.18 + drift * 0.5, dy: -4.0, r: s.width * 0.18),
      (dx: s.width * 0.14 - drift * 0.3, dy: 6.0, r: s.width * 0.22),
      (dx: drift * 0.2, dy: -10.0, r: s.width * 0.16),
      (dx: -s.width * 0.05, dy: 12.0, r: s.width * 0.14),
    ];
    for (final b in blobs) {
      final pulse = 1 + math.sin(t * 2 * math.pi + b.dx) * 0.04;
      c.drawCircle(
        Offset(cx + b.dx, cy + b.dy),
        b.r * pulse * breathe,
        Paint()..color = col.withValues(alpha: 0.42),
      );
    }
    // Central darker core
    c.drawCircle(Offset(cx, cy), s.width * 0.13 * breathe,
        Paint()..color = col.withValues(alpha: 0.55));
    _eyes(c, cx, cy - 2, col, spacing: s.width * 0.10, alpha: 0.7);
  }

  void _paintReaper(Canvas c, Size s, double cx, double cy,
      double breathe, Color col) {
    final h = s.height * 0.68 * breathe;
    final cloak = Path()
      ..moveTo(cx, cy - h * 0.48)
      ..cubicTo(cx - s.width * 0.22, cy - h * 0.3,
          cx - s.width * 0.26, cy + h * 0.25,
          cx - s.width * 0.18, cy + h * 0.38)
      ..lineTo(cx + s.width * 0.18, cy + h * 0.38)
      ..cubicTo(cx + s.width * 0.26, cy + h * 0.25,
          cx + s.width * 0.22, cy - h * 0.3,
          cx, cy - h * 0.48)
      ..close();
    c.drawPath(cloak, Paint()..color = col);
    // Hood inner void
    final hood = Path()
      ..moveTo(cx - s.width * 0.09, cy - h * 0.32)
      ..cubicTo(cx - s.width * 0.06, cy - h * 0.42,
          cx + s.width * 0.06, cy - h * 0.42,
          cx + s.width * 0.09, cy - h * 0.32)
      ..cubicTo(cx + s.width * 0.05, cy - h * 0.22,
          cx - s.width * 0.05, cy - h * 0.22,
          cx - s.width * 0.09, cy - h * 0.32)
      ..close();
    c.drawPath(hood, Paint()..color = Colors.black.withValues(alpha: 0.55));
    // Edge highlight
    c.drawPath(cloak, Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    _eyes(c, cx, cy - h * 0.28, col, spacing: s.width * 0.07);
  }

  void _eyes(Canvas c, double cx, double cy, Color col,
      {double spacing = 18, double alpha = 0.9}) {
    final eyePaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha);
    c.drawCircle(Offset(cx - spacing / 2, cy), 3.2, eyePaint);
    c.drawCircle(Offset(cx + spacing / 2, cy), 3.2, eyePaint);
    // Pupil glint
    final pupil = Paint()..color = col.withValues(alpha: 0.9);
    c.drawCircle(Offset(cx - spacing / 2 + 0.8, cy - 0.6), 1.2, pupil);
    c.drawCircle(Offset(cx + spacing / 2 + 0.8, cy - 0.6), 1.2, pupil);
  }

  @override
  bool shouldRepaint(covariant TrialMonsterPainter old) =>
      old.t != t || old.hitFlash != hitFlash || old.kind != kind;
}

/// Soft drifting particles behind the monster stage.
class TrialAmbiencePainter extends CustomPainter {
  final double t;
  final Color tint;
  TrialAmbiencePainter({required this.t, required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = tint.withValues(alpha: 0.06);
    for (var i = 0; i < 14; i++) {
      final seed = i * 1.37;
      final x = (seed * 73 % 1.0) * size.width;
      final y = ((seed * 91 % 1.0) * size.height +
              math.sin(t * 2 * math.pi + seed) * 12) %
          size.height;
      final r = 1.2 + (seed % 0.7) * 2.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TrialAmbiencePainter old) => old.t != t;
}
