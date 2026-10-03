// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/avatar_painter.dart
//
// Code-owned vector avatar: the companion is PAINTED, not composited from
// emoji. Species drives silhouette + palette; every equipped cosmetic slot
// renders as a real shape layer (cap brims, jacket bands, sneaker paws...).
// Mood drives the eyes/mouth. No text glyphs anywhere in the output.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';

/// Tail silhouette vocabulary. Each is a different curve, not a different
/// colour, because a tail is a large fraction of a small animal's outline.
enum TailStyle { bushy, flat, plume, whip, puff, short, none }

/// Per-species silhouette parameters. Fractions of the canvas, not pixels, so a
/// portrait and a full avatar at any size agree.
///
/// PUBLIC because [AvatarPainter.speciesShapes] is public — a private type in a
/// public API is a real leak: any caller inspecting a shape has to reach for
/// `dynamic` or guess. The alternative (making the map private) would hide the
/// shape contract that `test/species_vector_art_test.dart` exists to pin.
class SpeciesShape {
  final double bodyWidth;
  final double bodyHeight;
  final double earHeight;
  final double earWidth;

  /// Ear splay in radians. Negative leans the ears inward (canine), positive
  /// outward (squirrel).
  final double earTilt;
  final TailStyle tail;

  const SpeciesShape({
    required this.bodyWidth,
    required this.bodyHeight,
    required this.earHeight,
    required this.earWidth,
    required this.earTilt,
    required this.tail,
  });
}

/// Catalog portrait of a companion species, drawn as vector art.
///
/// Replaces the emoji the species picker used to show. The tester was explicit:
/// *"the avatars for the recovery pet… we absolutely NEED custom generated
/// stuff for that, not the emoji icons."* The composite avatar was already
/// painted, but the picker showed `species.emoji` — a glyph from the system
/// font, so it looked different on every device, carried no species silhouette,
/// and rendered as tofu or a monochrome box on the builds most likely to need
/// the reduced-motion path.
///
/// This is deliberately a SEPARATE painter from [AvatarPainter] rather than a
/// flag on it. A catalog portrait has no `RecoveryPet`: no equipped cosmetics,
/// no bond, no mood. Threading a synthetic pet through the full painter to draw
/// a silhouette would couple two things that have no business being coupled.
class SpeciesPortraitPainter extends CustomPainter {
  final String speciesId;
  final Color? accent;

  const SpeciesPortraitPainter({required this.speciesId, this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final shape = AvatarPainter.shapeFor(speciesId);
    final palette =
        AvatarPainter.speciesColors[speciesId] ?? AvatarPainter.speciesColors['ember_kit']!;
    final base = palette[0];
    final shade = palette[1];
    final highlight = palette[2];

    // Tail first, so the body overlaps its root and the join is invisible.
    _paintTail(canvas, centre, s, shape, base, shade);

    // Ears behind the head so the head's edge reads as continuous.
    _paintEars(canvas, centre, s, shape, base, shade);

    // Body: a rounded superellipse, wide for otter/wolf, tall for hare.
    final bodyRect = Rect.fromCenter(
      center: Offset(centre.dx, centre.dy + s * 0.06),
      width: s * shape.bodyWidth,
      height: s * shape.bodyHeight,
    );
    canvas.drawPath(
      _roundedBlob(bodyRect),
      Paint()..color = base,
    );
    // Belly highlight — gives the flat blob volume without an outline.
    canvas.drawPath(
      _roundedBlob(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy + s * 0.16),
          width: s * shape.bodyWidth * 0.56,
          height: s * shape.bodyHeight * 0.46,
        ),
      ),
      Paint()..color = highlight.withValues(alpha: 0.55),
    );

    // Face. Two eyes and a muzzle, all vector — the thing that makes it read as
    // a creature rather than an egg.
    final eyeY = centre.dy - s * 0.02;
    final eyeDx = s * shape.bodyWidth * 0.17;
    final eyeR = s * 0.045;
    for (final sign in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(centre.dx + eyeDx * sign, eyeY),
        eyeR,
        Paint()..color = shade,
      );
      // Catchlight — one pixel, and the face comes alive.
      canvas.drawCircle(
        Offset(centre.dx + eyeDx * sign - eyeR * 0.3, eyeY - eyeR * 0.35),
        eyeR * 0.34,
        Paint()..color = highlight,
      );
    }

    // Muzzle, species-tinted rather than neutral.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx, centre.dy + s * 0.11),
        width: s * shape.bodyWidth * 0.26,
        height: s * 0.07,
      ),
      Paint()..color = highlight.withValues(alpha: 0.8),
    );

    if (accent != null) {
      canvas.drawCircle(
        Offset(centre.dx, centre.dy + s * 0.10),
        s * 0.022,
        Paint()..color = accent!,
      );
    }
  }

  void _paintEars(Canvas canvas, Offset centre, double s,
      SpeciesShape shape, Color base, Color shade) {
    if (shape.earHeight <= 0.01) return; // loon: no ears by design
    final earW = s * shape.earWidth;
    final earH = s * shape.earHeight;
    final headTop = centre.dy - s * shape.bodyHeight * 0.5;
    final dx = s * shape.bodyWidth * 0.26;

    for (final sign in const [-1.0, 1.0]) {
      final pivot = Offset(centre.dx + dx * sign, headTop + earH * 0.18);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(shape.earTilt * sign);
      final path = Path()
        ..moveTo(-earW * 0.5, 0)
        ..quadraticBezierTo(0, -earH * 0.9, earW * 0.5, 0)
        ..close();
      canvas.drawPath(path, Paint()..color = base);
      // Inner ear in the shade tone keeps the ear legible on a light palette.
      final inner = Path()
        ..moveTo(-earW * 0.22, 0)
        ..quadraticBezierTo(0, -earH * 0.6, earW * 0.22, 0)
        ..close();
      canvas.drawPath(inner, Paint()..color = shade.withValues(alpha: 0.5));
      canvas.restore();
    }
  }

  void _paintTail(Canvas canvas, Offset centre, double s,
      SpeciesShape shape, Color base, Color shade) {
    if (shape.tail == TailStyle.none) return;
    final root = Offset(centre.dx + s * shape.bodyWidth * 0.42,
        centre.dy + s * 0.16);
    final len = s * (shape.tail == TailStyle.whip ? 0.46 : 0.34);
    final w = s * (shape.tail == TailStyle.whip
        ? 0.05
        : shape.tail == TailStyle.short
            ? 0.10
            : 0.20);

    final path = Path()..moveTo(root.dx, root.dy);
    switch (shape.tail) {
      case TailStyle.bushy:
      case TailStyle.plume:
        path.cubicTo(root.dx + len * 0.5, root.dy - w,
            root.dx + len, root.dy - w * 0.4,
            root.dx + len * 0.92, root.dy + w * 0.25);
      case TailStyle.flat:
      case TailStyle.short:
        path.cubicTo(root.dx + len * 0.5, root.dy + w * 0.2,
            root.dx + len * 0.8, root.dy + w * 0.1,
            root.dx + len, root.dy + w * 0.35);
      case TailStyle.whip:
        path.cubicTo(root.dx + len * 0.6, root.dy - w,
            root.dx + len * 0.9, root.dy - w * 1.6,
            root.dx + len, root.dy - w * 2.6);
      case TailStyle.puff:
        path.cubicTo(root.dx + len * 0.6, root.dy - w * 0.8,
            root.dx + len, root.dy - w * 0.6,
            root.dx + len * 0.85, root.dy + w * 0.1);
      case TailStyle.none:
        break;
    }

    path.cubicTo(root.dx + len * 0.8, root.dy + w * 0.9,
        root.dx + len * 0.2, root.dy + w * 0.7, root.dx, root.dy);
    path.close();
    canvas.drawPath(path, Paint()..color = shade);
  }

  /// A rounded superellipse — the body shape shared by every species.
  static Path _roundedBlob(Rect rect) {
    final r = Radius.circular(rect.shortestSide * 0.46);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, r));
  }

  @override
  bool shouldRepaint(covariant SpeciesPortraitPainter oldDelegate) =>
      oldDelegate.speciesId != speciesId || oldDelegate.accent != accent;
}

class AvatarPainter extends CustomPainter {
  final RecoveryPet pet;

  AvatarPainter(this.pet);

  // ---- palettes ----

  /// Species palette as `[base, shade, highlight]`.
  ///
  /// PUBLIC, not private: [SpeciesPortraitPainter] reuses exactly this map so a
  /// companion's catalog thumbnail cannot drift from the colour of the same
  /// creature once it is adopted. Two copies of a palette is two chances to
  /// ship an Ember Kit that is orange in the picker and red once hatched.
  static const Map<String, List<Color>> speciesColors = {
    'ember_kit': [Color(0xFFF59E0B), Color(0xFFC2410C), Color(0xFFFDE68A)],
    'tide_kin': [Color(0xFF38BDF8), Color(0xFF0369A1), Color(0xFFBAE6FD)],
    'moss_sprite': [Color(0xFF34D399), Color(0xFF047857), Color(0xFFD1FAE5)],
    'star_whelp': [Color(0xFF818CF8), Color(0xFF4338CA), Color(0xFFE0E7FF)],
    'sovereign_linx': [Color(0xFF475569), Color(0xFF1E293B), Color(0xFFFCD34D)],
    'riverglass_otter': [Color(0xFF2DD4BF), Color(0xFF0F766E), Color(0xFFCCFBF1)],
    'prairie_ember_hare': [Color(0xFFFB923C), Color(0xFF9A3412), Color(0xFFFED7AA)],
    'north_star_loon': [Color(0xFF38BDF8), Color(0xFF1E3A8A), Color(0xFFBAE6FD)],
  };

  /// Backwards-compatible private alias, so the existing body of this painter
  /// keeps working unchanged.
  static const Map<String, List<Color>> _speciesColors = speciesColors;

  /// Shape parameters per species: body width, height and ear geometry.
  ///
  /// This is what makes the species *look* different rather than merely being
  /// tinted differently — a tester reading the species picker saw eight emoji
  /// glyphs standing in for eight creatures that all painted as the same
  /// rounded blob. Silhouette is the strongest recognition cue a 2D avatar has,
  /// so it varies first and colour second.
  static const Map<String, SpeciesShape> speciesShapes = {
    // Fox/canine: wide cheeks, tall pointed ears.
    'ember_kit': SpeciesShape(
      bodyWidth: 0.78,
      bodyHeight: 0.80,
      earHeight: 0.30,
      earWidth: 0.20,
      earTilt: -0.30,
      tail: TailStyle.bushy,
    ),
    // Otter: low and long, small round ears.
    'tide_kin': SpeciesShape(
      bodyWidth: 0.88,
      bodyHeight: 0.70,
      earHeight: 0.09,
      earWidth: 0.13,
      earTilt: 0.0,
      tail: TailStyle.flat,
    ),
    // Squirrel/sprite: compact, tall ears, plume tail.
    'moss_sprite': SpeciesShape(
      bodyWidth: 0.70,
      bodyHeight: 0.76,
      earHeight: 0.22,
      earWidth: 0.12,
      earTilt: 0.15,
      tail: TailStyle.plume,
    ),
    // Wolf: broad chest, tall ears, long tail.
    'star_whelp': SpeciesShape(
      bodyWidth: 0.86,
      bodyHeight: 0.88,
      earHeight: 0.34,
      earWidth: 0.18,
      earTilt: -0.14,
      tail: TailStyle.bushy,
    ),
    // Cat: narrow, very tall ears, long whip tail.
    'sovereign_linx': SpeciesShape(
      bodyWidth: 0.72,
      bodyHeight: 0.82,
      earHeight: 0.36,
      earWidth: 0.16,
      earTilt: -0.05,
      tail: TailStyle.whip,
    ),
    'riverglass_otter': SpeciesShape(
      bodyWidth: 0.86,
      bodyHeight: 0.68,
      earHeight: 0.08,
      earWidth: 0.12,
      earTilt: 0.0,
      tail: TailStyle.flat,
    ),
    'prairie_ember_hare': SpeciesShape(
      bodyWidth: 0.68,
      bodyHeight: 0.74,
      // Hare ears are the species' whole silhouette.
      earHeight: 0.62,
      earWidth: 0.10,
      earTilt: 0.06,
      tail: TailStyle.puff,
    ),
    'north_star_loon': SpeciesShape(
      bodyWidth: 0.80,
      bodyHeight: 0.84,
      earHeight: 0.05,
      earWidth: 0.10,
      earTilt: 0.0,
      tail: TailStyle.short,
    ),
  };

  static SpeciesShape shapeFor(String speciesId) =>
      speciesShapes[speciesId] ?? speciesShapes['ember_kit']!;

  static const Map<String, Color> _auraColors = {
    'aura_warm': Color(0xFFF59E0B),
    'aura_calm_blue': Color(0xFF38BDF8),
    'aura_forest': Color(0xFF34D399),
    'aura_ember': Color(0xFFF97316),
    'aura_starfield': Color(0xFF818CF8),
    'aura_sovereign': Color(0xFFFCD34D),
  };

  static const Map<String, Color> _topColors = {
    'top_tee_plain': Color(0xFFE2E8F0),
    'top_hoodie_soft': Color(0xFF64748B),
    'top_tank': Color(0xFFF87171),
    'top_flannel': Color(0xFFB45309),
    'top_jacket_dawn': Color(0xFFF59E0B),
    'top_cloak_forest': Color(0xFF166534),
    'top_robe_river': Color(0xFF0E7490),
    'top_armor_light': Color(0xFF94A3B8),
    'top_sovereign_mantle': Color(0xFFFCD34D),
  };

  static const Map<String, Color> _bottomColors = {
    'bottom_shorts': Color(0xFF64748B),
    'bottom_joggers': Color(0xFF334155),
    'bottom_jeans': Color(0xFF1D4ED8),
    'bottom_skirt_flow': Color(0xFFC084FC),
    'bottom_cargo': Color(0xFF4D7C0F),
    'bottom_wrap_moss': Color(0xFF166534),
    'bottom_greaves': Color(0xFF94A3B8),
  };

  static const Map<String, Color> _shoeColors = {
    'shoes_sneakers': Color(0xFFE2E8F0),
    'shoes_sandals': Color(0xFFD97706),
    'shoes_boots_trail': Color(0xFF78350F),
    'shoes_boots_storm': Color(0xFF1E293B),
    'shoes_slippers_home': Color(0xFFF472B6),
    'shoes_kicks_neon': Color(0xFF22D3EE),
    'shoes_sovereign': Color(0xFFFCD34D),
  };

  static const Map<String, Color> _hairColors = {
    'hair_short_wave': Color(0xFF334155),
    'hair_crop': Color(0xFF1E293B),
    'hair_long_flow': Color(0xFF475569),
    'hair_bun': Color(0xFF334155),
    'hair_braids': Color(0xFF475569),
    'hair_flame': Color(0xFFF97316),
    'hair_color_ink': Color(0xFF0F172A),
    'hair_color_sun': Color(0xFFFBBF24),
    'hair_color_sea': Color(0xFF0EA5E9),
    'hair_color_violet': Color(0xFF8B5CF6),
    'hair_color_silver': Color(0xFFD1D5DB),
  };

  /// Aura glow color for an equipped aura id (used by fallback painters).
  static Color auraColorFor(String? auraId) =>
      _auraColors[auraId] ?? const Color(0x00000000);

  Color get _body {
    final c = _speciesColors[pet.speciesId] ?? _speciesColors['ember_kit']!;
    return c[0];
  }

  Color get _bodyDark =>
      (_speciesColors[pet.speciesId] ?? _speciesColors['ember_kit']!)[1];

  Color get _belly =>
      (_speciesColors[pet.speciesId] ?? _speciesColors['ember_kit']!)[2];

  String? _slot(CosmeticCategory cat) => pet.slot(cat);

  bool _worn(String? id) => id != null && !id.endsWith('_none');

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);

    _paintAura(canvas, c, s);
    _paintTail(canvas, c, s);
    _paintEars(canvas, c, s);
    _paintBody(canvas, c, s);
    _paintSkinTint(canvas, c, s);
    _paintBottom(canvas, c, s);
    _paintTop(canvas, c, s);
    _paintShoes(canvas, c, s);
    _paintFace(canvas, c, s);
    _paintHair(canvas, c, s);
    _paintHeadwear(canvas, c, s);
    _paintJewelry(canvas, c, s);
    _paintAccessory(canvas, c, s);
  }

  void _paintAura(Canvas canvas, Offset c, double s) {
    final auraId = _slot(CosmeticCategory.aura);
    if (!_worn(auraId)) return;
    final color = _auraColors[auraId] ?? const Color(0xFFF59E0B);
    final rect = Rect.fromCenter(center: c, width: s * 0.98, height: s * 0.98);
    canvas.drawCircle(
      c,
      s * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(rect),
    );
  }

  void _paintTail(Canvas canvas, Offset c, double s) {
    if (pet.speciesId == 'sovereign_linx') return; // bobbed
    final path = Path()
      ..moveTo(c.dx + s * 0.20, c.dy + s * 0.16)
      ..quadraticBezierTo(
          c.dx + s * 0.46, c.dy + s * 0.10, c.dx + s * 0.38, c.dy - s * 0.16)
      ..quadraticBezierTo(
          c.dx + s * 0.34, c.dy + s * 0.02, c.dx + s * 0.16, c.dy + s * 0.06)
      ..close();
    canvas.drawPath(path, Paint()..color = _bodyDark);
  }

  void _paintEars(Canvas canvas, Offset c, double s) {
    final earPaint = Paint()..color = _body;
    final innerPaint = Paint()..color = _bodyDark.withValues(alpha: 0.7);
    final big = pet.speciesId == 'ember_kit' || pet.speciesId == 'star_whelp';
    final earW = s * (big ? 0.13 : 0.10);
    final earH = s * (big ? 0.20 : 0.13);
    for (final side in [-1.0, 1.0]) {
      final base = Offset(c.dx + side * s * 0.17, c.dy - s * 0.20);
      final tip = Offset(base.dx + side * s * 0.03, base.dy - earH);
      final ear = Path()
        ..moveTo(base.dx - earW / 2, base.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx + earW / 2, base.dy)
        ..close();
      canvas.drawPath(ear, earPaint);
      final inner = Path()
        ..moveTo(base.dx - earW * 0.28, base.dy - s * 0.02)
        ..lineTo(tip.dx, tip.dy + earH * 0.22)
        ..lineTo(base.dx + earW * 0.28, base.dy - s * 0.02)
        ..close();
      canvas.drawPath(inner, innerPaint);
    }
  }

  void _paintBody(Canvas canvas, Offset c, double s) {
    final bodyRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + s * 0.05),
      width: s * 0.62,
      height: s * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(s * 0.22)),
      Paint()..color = _body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + s * 0.16),
        width: s * 0.34,
        height: s * 0.30,
      ),
      Paint()..color = _belly.withValues(alpha: 0.85),
    );
  }

  void _paintSkinTint(Canvas canvas, Offset c, double s) {
    final skin = _slot(CosmeticCategory.skin);
    if (!_worn(skin) || skin == 'skin_pearl') return;
    const tints = {
      'skin_amber': Color(0xFFF59E0B),
      'skin_slate': Color(0xFF64748B),
      'skin_rose': Color(0xFFFB7185),
      'skin_jade': Color(0xFF10B981),
      'skin_obsidian': Color(0xFF0F172A),
      'skin_aurora': Color(0xFFA78BFA),
    };
    final tint = tints[skin];
    if (tint == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + s * 0.05),
          width: s * 0.62,
          height: s * 0.56,
        ),
        Radius.circular(s * 0.22),
      ),
      Paint()..color = tint.withValues(alpha: 0.22),
    );
  }

  void _paintTop(Canvas canvas, Offset c, double s) {
    final top = _slot(CosmeticCategory.top);
    if (!_worn(top)) return;
    final color = _topColors[top] ?? const Color(0xFFE2E8F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + s * 0.14),
          width: s * 0.56,
          height: s * 0.24,
        ),
        Radius.circular(s * 0.08),
      ),
      Paint()..color = color,
    );
  }

  void _paintBottom(Canvas canvas, Offset c, double s) {
    final bottom = _slot(CosmeticCategory.bottom);
    if (!_worn(bottom)) return;
    final color = _bottomColors[bottom] ?? const Color(0xFF334155);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + s * 0.28),
          width: s * 0.50,
          height: s * 0.12,
        ),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = color,
    );
  }

  void _paintShoes(Canvas canvas, Offset c, double s) {
    final shoes = _slot(CosmeticCategory.shoes);
    if (!_worn(shoes)) return;
    final color = _shoeColors[shoes] ?? const Color(0xFFE2E8F0);
    final paint = Paint()..color = color;
    final y = c.dy + s * 0.34;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx - s * 0.13, y), width: s * 0.14, height: s * 0.07),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + s * 0.13, y), width: s * 0.14, height: s * 0.07),
        paint);
  }

  void _paintFace(Canvas canvas, Offset c, double s) {
    final eyeY = c.dy - s * 0.02;
    final dx = s * 0.09;
    final eyePaint = Paint()..color = const Color(0xFF0F172A);
    final face = _slot(CosmeticCategory.face);
    final resting = pet.isResting;

    if (resting || face == 'face_dream') {
      // closed, peaceful
      final arc = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(c.dx + side * dx, eyeY),
              width: s * 0.09,
              height: s * 0.07),
          math.pi * 1.1,
          math.pi * 0.8,
          false,
          arc,
        );
      }
    } else {
      final fierce = face == 'face_fierce';
      final eyeR = s * (fierce ? 0.022 : 0.026);
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(c.dx + side * dx, eyeY), eyeR, eyePaint);
        if (fierce) {
          canvas.drawLine(
            Offset(c.dx + side * (dx - s * 0.045), eyeY - s * 0.05),
            Offset(c.dx + side * (dx + s * 0.035), eyeY - s * 0.028),
            arcStroke(const Color(0xFF0F172A), s * 0.012),
          );
        }
      }
    }

    // nose + mouth
    final nose = Path()
      ..moveTo(c.dx - s * 0.018, c.dy + s * 0.035)
      ..lineTo(c.dx + s * 0.018, c.dy + s * 0.035)
      ..lineTo(c.dx, c.dy + s * 0.055)
      ..close();
    canvas.drawPath(nose, Paint()..color = _bodyDark);

    final mouth = arcStroke(const Color(0xFF0F172A), s * 0.011);
    if (!resting) {
      if (pet.mood == PetMoodX.happy || face == 'face_bright') {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy + s * 0.055),
              width: s * 0.10,
              height: s * 0.08),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          mouth,
        );
      } else if (pet.mood == PetMoodX.sad) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy + s * 0.095),
              width: s * 0.10,
              height: s * 0.08),
          1.15 * math.pi,
          0.7 * math.pi,
          false,
          mouth,
        );
      } else {
        canvas.drawLine(
          Offset(c.dx - s * 0.025, c.dy + s * 0.07),
          Offset(c.dx + s * 0.025, c.dy + s * 0.07),
          mouth,
        );
      }
    }
  }

  void _paintHair(Canvas canvas, Offset c, double s) {
    final hair = _slot(CosmeticCategory.hair);
    if (!_worn(hair)) return;
    final color = _hairColors[hair] ?? const Color(0xFF334155);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy - s * 0.06),
          width: s * 0.44,
          height: s * 0.30),
      math.pi,
      math.pi,
      false,
      Paint()..color = color,
    );
  }

  void _paintHeadwear(Canvas canvas, Offset c, double s) {
    final head = _slot(CosmeticCategory.headwear);
    if (!_worn(head)) return;
    switch (head) {
      case 'head_crown_leaf':
        final leaf = Paint()..color = const Color(0xFF22C55E);
        for (final side in [-1.0, 0.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(c.dx + side * s * 0.07, c.dy - s * 0.30),
              width: s * 0.06,
              height: s * 0.12,
            ),
            leaf,
          );
        }
      case 'head_crown_star':
        _drawStar(canvas, Offset(c.dx, c.dy - s * 0.30), s * 0.06,
            const Color(0xFFFCD34D));
      case 'head_halo_soft':
        canvas.drawCircle(
          Offset(c.dx, c.dy - s * 0.32),
          s * 0.10,
          arcStroke(const Color(0xFFFDE68A), s * 0.02),
        );
      case 'head_bandana':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy - s * 0.17),
                width: s * 0.42,
                height: s * 0.06),
            Radius.circular(s * 0.03),
          ),
          Paint()..color = const Color(0xFFDC2626),
        );
      default: // beanie / cap / hood — one solid cap with brim
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy - s * 0.14),
              width: s * 0.40,
              height: s * 0.30),
          math.pi,
          math.pi,
          false,
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy - s * 0.145),
                width: s * 0.44,
                height: s * 0.045),
            Radius.circular(s * 0.02),
          ),
          Paint()..color = const Color(0xFF38BDF8),
        );
    }
  }

  void _paintJewelry(Canvas canvas, Offset c, double s) {
    final j = _slot(CosmeticCategory.jewelry);
    if (!_worn(j)) return;
    final chest = Offset(c.dx, c.dy + s * 0.10);
    const map = {
      'jewelry_pendant_seed': Color(0xFF22C55E),
      'jewelry_pendant_wave': Color(0xFF38BDF8),
      'jewelry_earring_dot': Color(0xFFE2E8F0),
      'jewelry_earring_moon': Color(0xFFE2E8F0),
      'jewelry_ring_bond': Color(0xFFF59E0B),
      'jewelry_chain_star': Color(0xFFFCD34D),
      'jewelry_crest_sovereign': Color(0xFFFCD34D),
    };
    final color = map[j] ?? const Color(0xFFE2E8F0);
    final big = j == 'jewelry_crest_sovereign';
    canvas.drawCircle(chest, s * (big ? 0.045 : 0.03), Paint()..color = color);
  }

  void _paintAccessory(Canvas canvas, Offset c, double s) {
    final acc = _slot(CosmeticCategory.accessory);
    if (!_worn(acc)) return;
    switch (acc) {
      case 'acc_scarf':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy - s * 0.10),
                width: s * 0.40,
                height: s * 0.06),
            Radius.circular(s * 0.03),
          ),
          Paint()..color = const Color(0xFFDC2626),
        );
      case 'acc_lantern':
        final glow = Paint()
          ..color = const Color(0xFFFDE68A).withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03);
        canvas.drawCircle(Offset(c.dx + s * 0.28, c.dy + s * 0.10), s * 0.05, glow);
        canvas.drawCircle(Offset(c.dx + s * 0.28, c.dy + s * 0.10), s * 0.028,
            Paint()..color = const Color(0xFFFDE68A));
      case 'acc_wings_soft':
        final wing = Paint()..color = Colors.white.withValues(alpha: 0.75);
        for (final side in [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(c.dx + side * s * 0.30, c.dy - s * 0.05),
              width: s * 0.22,
              height: s * 0.34,
            ),
            wing,
          );
        }
      case 'acc_staff_path':
        canvas.drawLine(
          Offset(c.dx + s * 0.26, c.dy + s * 0.30),
          Offset(c.dx + s * 0.32, c.dy - s * 0.28),
          arcStroke(const Color(0xFF92400E), s * 0.018),
        );
      case 'acc_glasses':
        final frame = arcStroke(const Color(0xFF0F172A), s * 0.011);
        for (final side in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(c.dx + side * s * 0.09, c.dy - s * 0.02),
              s * 0.045, frame);
        }
      case 'acc_watch':
        canvas.drawCircle(Offset(c.dx - s * 0.24, c.dy + s * 0.16), s * 0.022,
            Paint()..color = const Color(0xFF38BDF8));
      case 'acc_bag_day':
        canvas.drawLine(
          Offset(c.dx - s * 0.20, c.dy - s * 0.10),
          Offset(c.dx + s * 0.10, c.dy + s * 0.18),
          arcStroke(const Color(0xFF92400E), s * 0.014),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx - s * 0.24, c.dy + s * 0.16),
                width: s * 0.14,
                height: s * 0.12),
            Radius.circular(s * 0.03),
          ),
          Paint()..color = const Color(0xFF92400E),
        );
    }
  }

  // ---- helpers ----

  static Paint arcStroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + radius * math.cos(angle),
          c.dy + radius * math.sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) =>
      oldDelegate.pet != pet ||
      oldDelegate.pet.equippedSlots.toString() != pet.equippedSlots.toString() ||
      oldDelegate.pet.mood != pet.mood;
}
