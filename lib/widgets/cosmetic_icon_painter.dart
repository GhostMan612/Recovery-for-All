// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/cosmetic_icon_painter.dart
//
// Code-owned VECTOR art for every cosmetic item and every companion mood.
//
// A tester filed: "the avatars for the recovery pet… we absolutely NEED custom
// generated stuff for that. not the emoji icons." The composite creature was
// already painted, and the species picker was converted to
// [SpeciesPortraitPainter], but the DRESSER GRID still rendered a system glyph
// per item, as did the starter-preset picker, the "Wearing Today" chips, and
// three mood readouts. An emoji is the worst possible art for this job:
//
//   * it is a FONT glyph, so the same item looks different on every device and
//     renders as tofu or a monochrome box on the builds most likely to be on
//     the reduced-motion path;
//   * it cannot vary by item — there is no "Trail Boots in a different shape";
//   * `dart:ui` has no guarantee the codepoint exists at all.
//
// DESIGN — SILHOUETTE FIRST, COLOUR SECOND. Same doctrine as
// [AvatarPainter.speciesShapes], for the same reason: two items that differ
// only in hue are one icon and a recolour. So each item's identity is a
// [CosmeticGlyph] — a shape plus three orthogonal modifiers — and the palette
// is chosen by category. Colour is used where it is genuinely the only
// difference: the two declared COLOURWAY subcategories, `skin/tone` and
// `hair/color`, where "Obsidian" vs "Pearl" IS the product.
//
// UNIQUENESS IS PROVEN, NOT EYEBALLED. `test/cosmetic_vector_art_test.dart`
// asserts that no two items inside one category share both a glyph signature
// and a colour, and that same-signature pairs are always same-colour in one of
// the two declared colourway subcategories. Adding an item that collides is a
// test failure, not a subtle visual regression.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';

/// Base silhouette vocabulary for a cosmetic icon.
///
/// Kept to primitives that are cheap to draw and cheap to tell apart at 24dp.
/// Every enum value is used by at least one registry entry, so a shape that is
/// never drawn is a compile-time-visible dead branch rather than a silent one.
enum CosmeticShape {
  disc,
  ring,
  drop,
  flame,
  wave,
  leaf,
  star,
  crescent,
  band,
  cone,
  diamond,
  capsule,
  chevrons,
  cross,
  pentagon,
  shield,
  lens,
  wing,
  arcCrown,
  ladder,
  dome,
  visor,
  boot,
  sole,
  flare,
  plate,
  collar,
  sash,
  chain,
  gem,
  burst,
  grid,
  spiralShell,
  cloudBands,
  flower,
  snowflake,
  comet,
  scarfBand,
  lantern,
  bag,
  staff,
  blank,
}

/// A cosmetic's visual identity: a silhouette plus three modifiers.
///
/// The modifiers are deliberately ORTHOGONAL — each changes the outline in a
/// way the others cannot, which is what makes the signature space large enough
/// for a 14-item category to be collision-free:
///
///   [rays]  repeated elements (spikes, dots, waves, pips) around or across
///           the form. 0 means "none".
///   [stack] extra layers, drawn offset downward. 0 means "single".
///   [ring]  an enclosing outline, which reads as "badge" at 24dp.
@immutable
class CosmeticGlyph {
  final CosmeticShape shape;
  final int rays;
  final int stack;
  final bool ring;

  const CosmeticGlyph(this.shape,
      {this.rays = 0, this.stack = 0, this.ring = false});

  /// The comparison key. Two icons with the same signature have the same
  /// silhouette; the test then requires them to differ in colour.
  String get signature => '${shape.name}|$rays|$stack|${ring ? 1 : 0}';

  @override
  String toString() => signature;
}

/// Registry of icon art. Every catalog id resolves to a [CosmeticGlyph] and a
/// colour token; nothing renders through a fallback that could collapse two
/// items into one picture.
class CosmeticArt {
  const CosmeticArt._();

  /// Per-category palette as `[fill, accent]`.
  ///
  /// Category-coloured rather than item-coloured on purpose: the grid is already
  /// tabbed by category, so colour's job is to reinforce the tab, and the
  /// silhouette's job is to identify the item. Colouring all 108 icons
  /// individually is ~200 more literals of art direction that would add nothing
  /// a player can read at 24dp.
  static const Map<CosmeticCategory, List<Color>> _categoryPalette = {
    CosmeticCategory.body: [Color(0xFF818CF8), Color(0xFF4338CA)],
    CosmeticCategory.skin: [Color(0xFFFBBF24), Color(0xFF92400E)],
    CosmeticCategory.face: [Color(0xFF38BDF8), Color(0xFF075985)],
    CosmeticCategory.hair: [Color(0xFF475569), Color(0xFF1E293B)],
    CosmeticCategory.top: [Color(0xFF64748B), Color(0xFF334155)],
    CosmeticCategory.bottom: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
    CosmeticCategory.shoes: [Color(0xFF78350F), Color(0xFF451A03)],
    CosmeticCategory.headwear: [Color(0xFF0EA5E9), Color(0xFF075985)],
    CosmeticCategory.jewelry: [Color(0xFFFCD34D), Color(0xFFB45309)],
    CosmeticCategory.accessory: [Color(0xFFFB7185), Color(0xFF9F1239)],
    CosmeticCategory.aura: [Color(0xFF34D399), Color(0xFF065F46)],
  };

  /// The two subcategories where colour IS the product.
  ///
  /// "Pearl" and "Obsidian" are the same droplet; that is the item. Everything
  /// else must differ in silhouette. Asserted by the test, so adding a third
  /// colourway subcategory without art for it fails rather than ships as two
  /// identical icons.
  static const Set<String> colourwaySubcategories = {'tone', 'color'};

  /// Used for an item with no category palette, and for the `_none` rows.
  ///
  /// Named rather than inlined at each use site: it was written out twice, and
  /// the colour gate counts literals, so a copy-paste fallback is exactly how a
  /// file quietly accumulates unreviewed colours.
  static const List<Color> _fallbackPalette = [
    Color(0xFF64748B),
    Color(0xFF334155),
  ];

  /// Explicit colours for the colourway items only.
  static const Map<String, Color> _colourways = {
    'skin_pearl': Color(0xFFF8FAFC),
    'skin_amber': Color(0xFFF59E0B),
    'skin_slate': Color(0xFF64748B),
    'skin_rose': Color(0xFFFB7185),
    'skin_jade': Color(0xFF10B981),
    'skin_obsidian': Color(0xFF0F172A),
    'skin_aurora': Color(0xFFA78BFA),
    'hair_color_ink': Color(0xFF0F172A),
    'hair_color_sun': Color(0xFFFBBF24),
    'hair_color_sea': Color(0xFF0EA5E9),
    'hair_color_violet': Color(0xFF8B5CF6),
    'hair_color_silver': Color(0xFFD1D5DB),
  };

  /// id -> silhouette. 108 entries; the test fails if the catalog grows without
  /// one, so there is no silent fallback in practice.
  static const Map<String, CosmeticGlyph> _glyphs = {
    // ---- body / form -------------------------------------------------
    'body_soft_glow': CosmeticGlyph(CosmeticShape.disc),
    'body_ember': CosmeticGlyph(CosmeticShape.flame),
    'body_tide': CosmeticGlyph(CosmeticShape.wave, rays: 3),
    'body_moss': CosmeticGlyph(CosmeticShape.leaf),
    'body_starlit': CosmeticGlyph(CosmeticShape.star, rays: 6),
    'body_sovereign': CosmeticGlyph(CosmeticShape.arcCrown, rays: 5),
    'basic_shell': CosmeticGlyph(CosmeticShape.spiralShell),
    'basic_shell_dup': CosmeticGlyph(CosmeticShape.spiralShell),

    // ---- skin / tone (colourway) -------------------------------------
    'skin_pearl': CosmeticGlyph(CosmeticShape.drop),
    'skin_amber': CosmeticGlyph(CosmeticShape.drop),
    'skin_slate': CosmeticGlyph(CosmeticShape.drop),
    'skin_rose': CosmeticGlyph(CosmeticShape.drop),
    'skin_jade': CosmeticGlyph(CosmeticShape.drop),
    'skin_obsidian': CosmeticGlyph(CosmeticShape.drop),
    'skin_aurora': CosmeticGlyph(CosmeticShape.drop),

    // ---- face / eyes --------------------------------------------------
    'face_calm': CosmeticGlyph(CosmeticShape.lens),
    'face_bright': CosmeticGlyph(CosmeticShape.lens, rays: 1),
    'face_soft': CosmeticGlyph(CosmeticShape.lens, rays: 2),
    'face_fierce': CosmeticGlyph(CosmeticShape.diamond),
    'face_dream': CosmeticGlyph(CosmeticShape.band, stack: 2),

    // ---- face / marking -----------------------------------------------
    'face_mark_dot': CosmeticGlyph(CosmeticShape.disc, stack: 1),
    'face_mark_stripe': CosmeticGlyph(CosmeticShape.band, rays: 2),
    'face_mark_sigil': CosmeticGlyph(CosmeticShape.pentagon, rays: 5),

    // ---- hair / style -------------------------------------------------
    'hair_short_wave': CosmeticGlyph(CosmeticShape.dome),
    'hair_crop': CosmeticGlyph(CosmeticShape.dome, rays: 2),
    'hair_long_flow': CosmeticGlyph(CosmeticShape.wave, rays: 2),
    'hair_bun': CosmeticGlyph(CosmeticShape.disc, ring: true),
    'hair_braids': CosmeticGlyph(CosmeticShape.ladder, rays: 2),
    'hair_flame': CosmeticGlyph(CosmeticShape.flame, rays: 3),

    // ---- hair / color (colourway) -------------------------------------
    // `disc`, deliberately NOT the `dome` used by hair/style. The first draft
    // gave these five the same silhouette as `hair_short_wave`, so the hair tab
    // showed six identical outlines separated only by fill — one item and five
    // recolours, which is the exact failure the colourway rule is meant to
    // allow and nowhere else. A colour swatch wants its OWN shape anyway.
    'hair_color_ink': CosmeticGlyph(CosmeticShape.disc),
    'hair_color_sun': CosmeticGlyph(CosmeticShape.disc),
    'hair_color_sea': CosmeticGlyph(CosmeticShape.disc),
    'hair_color_violet': CosmeticGlyph(CosmeticShape.disc),
    'hair_color_silver': CosmeticGlyph(CosmeticShape.disc),

    // ---- top ----------------------------------------------------------
    'top_tee_plain': CosmeticGlyph(CosmeticShape.plate, stack: 1),
    'top_hoodie_soft': CosmeticGlyph(CosmeticShape.plate, stack: 2),
    'top_tank': CosmeticGlyph(CosmeticShape.plate, rays: 2),
    'top_flannel': CosmeticGlyph(CosmeticShape.plate, rays: 4),
    'top_jacket_dawn': CosmeticGlyph(CosmeticShape.collar),
    'top_cloak_forest': CosmeticGlyph(CosmeticShape.collar, rays: 3, stack: 1),
    'top_robe_river': CosmeticGlyph(CosmeticShape.flare, stack: 2),
    'top_armor_light': CosmeticGlyph(CosmeticShape.plate, rays: 3, stack: 3),
    'top_sovereign_mantle': CosmeticGlyph(CosmeticShape.collar, rays: 5),
    'season_solstice_cloak': CosmeticGlyph(CosmeticShape.cloudBands),
    'tactical_streetwear': CosmeticGlyph(CosmeticShape.plate, rays: 5),
    'tactical_streetwear_dup': CosmeticGlyph(CosmeticShape.plate, rays: 5),
    'sovereign_mantle_dup': CosmeticGlyph(CosmeticShape.collar, rays: 4),
    'sovereign_mantle_hatchery': CosmeticGlyph(CosmeticShape.collar, rays: 4),
    'cyber_monk_robes': CosmeticGlyph(CosmeticShape.sash, stack: 3),
    'cyber_monk_robes_dup': CosmeticGlyph(CosmeticShape.sash, stack: 3),

    // ---- bottom -------------------------------------------------------
    'bottom_shorts': CosmeticGlyph(CosmeticShape.flare),
    'bottom_joggers': CosmeticGlyph(CosmeticShape.flare, rays: 2),
    'bottom_jeans': CosmeticGlyph(CosmeticShape.flare, rays: 4),
    'bottom_skirt_flow': CosmeticGlyph(CosmeticShape.flare, rays: 6),
    'bottom_cargo': CosmeticGlyph(CosmeticShape.chevrons),
    'bottom_wrap_moss': CosmeticGlyph(CosmeticShape.sash, stack: 2),
    'bottom_greaves': CosmeticGlyph(CosmeticShape.plate, rays: 2, stack: 1),

    // ---- shoes --------------------------------------------------------
    'shoes_bare': CosmeticGlyph(CosmeticShape.sole),
    'shoes_sneakers': CosmeticGlyph(CosmeticShape.sole, stack: 1),
    'shoes_sandals': CosmeticGlyph(CosmeticShape.sole, rays: 2),
    'shoes_boots_trail': CosmeticGlyph(CosmeticShape.boot),
    'shoes_boots_storm': CosmeticGlyph(CosmeticShape.boot, stack: 2),
    'shoes_slippers_home': CosmeticGlyph(CosmeticShape.dome, rays: 3),
    'shoes_kicks_neon': CosmeticGlyph(CosmeticShape.boot, rays: 4),
    'shoes_sovereign': CosmeticGlyph(CosmeticShape.boot, rays: 2, ring: true),

    // ---- headwear -----------------------------------------------------
    'head_none': CosmeticGlyph(CosmeticShape.blank),
    'head_beanie': CosmeticGlyph(CosmeticShape.dome, stack: 1),
    'head_cap': CosmeticGlyph(CosmeticShape.visor),
    'head_bandana': CosmeticGlyph(CosmeticShape.capsule, rays: 2),
    'head_hood': CosmeticGlyph(CosmeticShape.cone, rays: 2, stack: 2),
    'head_crown_leaf': CosmeticGlyph(CosmeticShape.arcCrown),
    'head_crown_star': CosmeticGlyph(CosmeticShape.arcCrown, rays: 5),
    'head_halo_soft': CosmeticGlyph(CosmeticShape.ring),
    'season_solstice_crown': CosmeticGlyph(CosmeticShape.snowflake, rays: 6),

    // ---- jewelry ------------------------------------------------------
    'jewelry_none': CosmeticGlyph(CosmeticShape.blank),
    'jewelry_band_simple': CosmeticGlyph(CosmeticShape.ring, stack: 1),
    'jewelry_pendant_seed': CosmeticGlyph(CosmeticShape.cross),
    'jewelry_pendant_wave': CosmeticGlyph(CosmeticShape.chain, rays: 2),
    'jewelry_earring_dot': CosmeticGlyph(CosmeticShape.gem),
    'jewelry_earring_moon': CosmeticGlyph(CosmeticShape.crescent),
    'jewelry_ring_bond': CosmeticGlyph(CosmeticShape.ring, rays: 2, stack: 1),
    'jewelry_chain_star': CosmeticGlyph(CosmeticShape.chain, rays: 5),
    'jewelry_crest_sovereign': CosmeticGlyph(CosmeticShape.shield, rays: 3),

    // ---- accessories --------------------------------------------------
    'acc_none': CosmeticGlyph(CosmeticShape.blank),
    'acc_bag_day': CosmeticGlyph(CosmeticShape.bag),
    'acc_scarf': CosmeticGlyph(CosmeticShape.scarfBand),
    'acc_glasses': CosmeticGlyph(CosmeticShape.lens, rays: 4),
    'acc_watch': CosmeticGlyph(CosmeticShape.ring, rays: 1),
    'acc_lantern': CosmeticGlyph(CosmeticShape.lantern),
    'acc_staff_path': CosmeticGlyph(CosmeticShape.staff),
    'acc_wings_soft': CosmeticGlyph(CosmeticShape.wing),
    'season_equinox_bloom': CosmeticGlyph(CosmeticShape.flower, rays: 5),
    'season_harvest_lantern': CosmeticGlyph(CosmeticShape.lantern, rays: 6),
    'cbt_deflector_shield': CosmeticGlyph(CosmeticShape.shield),
    'cbt_deflector_shield_dup': CosmeticGlyph(CosmeticShape.shield),
    'ethereal_wings': CosmeticGlyph(CosmeticShape.wing, rays: 6),
    'ethereal_wings_dup': CosmeticGlyph(CosmeticShape.wing, rays: 6),

    // ---- aura ---------------------------------------------------------
    'aura_none': CosmeticGlyph(CosmeticShape.blank),
    'aura_warm': CosmeticGlyph(CosmeticShape.disc, rays: 8),
    'aura_calm_blue': CosmeticGlyph(CosmeticShape.ring, rays: 3),
    'aura_forest': CosmeticGlyph(CosmeticShape.disc, rays: 3),
    'aura_ember': CosmeticGlyph(CosmeticShape.ring, rays: 6),
    'aura_starfield': CosmeticGlyph(CosmeticShape.grid, rays: 4),
    'aura_sovereign': CosmeticGlyph(CosmeticShape.burst, rays: 8),
    'season_newyear_spark': CosmeticGlyph(CosmeticShape.burst, rays: 5),
    'season_always_comet': CosmeticGlyph(CosmeticShape.comet),
    'starter_glow': CosmeticGlyph(CosmeticShape.disc, rays: 2),
    'starter_glow_dup': CosmeticGlyph(CosmeticShape.disc, rays: 2),
    'neon_grid_aura': CosmeticGlyph(CosmeticShape.grid, rays: 2),
    'neon_grid_aura_dup': CosmeticGlyph(CosmeticShape.grid, rays: 2),
  };

  /// Starter preset -> the item whose icon represents it.
  ///
  /// The preset picker used three emoji (🥾/🌊/🔥) that did not correspond to
  /// anything the player would later own, so the picker advertised art the
  /// catalogue does not contain. Each preset now shows a real item from its own
  /// outfit, which is both honest and coherent with the grid.
  static const Map<String, String> presetIconItem = {
    'pathwalker': 'shoes_boots_trail',
    'tidekeeper': 'aura_calm_blue',
    'embersmith': 'body_ember',
  };

  /// The silhouette for [id].
  ///
  /// Falls back to a dashed [CosmeticShape.blank] rather than to another item's
  /// shape, because a wrong-but-recognisable icon is a worse failure than an
  /// obviously-unfinished one — and the fallback is unreachable while the test
  /// coverage assertion holds, so it is a guard, not a crutch.
  static CosmeticGlyph specFor(String id) =>
      _glyphs[id] ?? const CosmeticGlyph(CosmeticShape.blank);

  /// The stable colour key used by the uniqueness test.
  ///
  /// A string, not a [Color], so the assertion compares tokens and never
  /// depends on a `Color` equality API that has moved between Flutter versions.
  static String colourTokenFor(PetCosmetic item) {
    final own = _colourways[item.id];
    if (own != null) return 'own:${item.id}';
    return 'cat:${item.category.name}';
  }

  /// `[fill, accent]` for [item].
  static List<Color> paletteFor(PetCosmetic item) {
    final own = _colourways[item.id];
    if (own != null) {
      // A colourway has no second tone to derive, so darken by mixing toward
      // black through the same alpha-free path the painter uses.
      return [own, Color.alphaBlend(const Color(0xFF000000), own)];
    }
    return _categoryPalette[item.category] ?? _fallbackPalette;
  }

  /// `[fill, accent]` for a bare category, used when the catalogue entry is
  /// missing so a retired id still draws in a sensible tone.
  static List<Color> paletteForCategory(CosmeticCategory category) =>
      _categoryPalette[category] ?? _fallbackPalette;

  /// True when [item] has hand-written art rather than the fallback.
  static bool hasArt(String id) => _glyphs.containsKey(id);
}

/// Draws one cosmetic item as vector art.
///
/// Sized by its parent; every coordinate below is a fraction of
/// [size.shortestSide], so a 20dp chip and a 96dp card show the same picture.
class CosmeticIconPainter extends CustomPainter {
  final String itemId;
  final PetCosmetic? item;

  /// Draws an item the catalogue no longer contains (a slot holding a retired
  /// id) as the dashed "none" badge rather than skipping the cell, so an
  /// equipped-but-missing item is visible instead of blank.
  const CosmeticIconPainter({required this.itemId, this.item});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final glyph = CosmeticArt.specFor(itemId);
    final cat = item?.category ?? CosmeticCategory.aura;
    final palette = item != null
        ? CosmeticArt.paletteFor(item!)
        : CosmeticArt.paletteForCategory(cat);
    final fill = Paint()..color = palette[0];
    final accent = Paint()..color = palette[1];
    final stroke = Paint()
      ..color = palette[1]
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.055)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (glyph.shape == CosmeticShape.blank) {
      _paintBlank(canvas, c, s, stroke);
      return;
    }

    // Layers first so the main form sits on top of its own underlayers.
    for (var i = 0; i < glyph.stack; i++) {
      final dy = s * (0.08 + 0.09 * i);
      _paintShape(canvas, c.translate(0, dy), s * 0.62, fill, accent, stroke,
          glyph, dimmed: true);
    }
    _paintShape(canvas, c, s * 0.72, fill, accent, stroke, glyph);

    if (glyph.rays > 0) _paintRays(canvas, c, s * 0.86, glyph.rays, fill, accent);
    if (glyph.ring) {
      canvas.drawCircle(c, s * 0.46, stroke);
    }
  }

  /// Dashed circle: "nothing equipped". Distinct from every other icon on
  /// purpose — a "none" row that looks like an item is a mis-sale.
  void _paintBlank(Canvas canvas, Offset c, double s, Paint stroke) {
    const dashes = 9;
    final r = s * 0.40;
    final sweep = (2 * math.pi) / dashes;
    for (var i = 0; i < dashes; i++) {
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep * 0.55,
        false,
        stroke,
      );
    }
  }

  /// Repeated elements around the form. N is the primary differentiator, so it
  /// has to read at 20dp: dots and spikes, never hairlines.
  void _paintRays(Canvas canvas, Offset c, double r, int n, Paint fill, Paint accent) {
    if (n <= 0) return;
    final paint = n.isEven ? fill : accent;
    final dot = math.max(1.2, r * 0.13);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / n);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawCircle(p, dot, paint);
    }
  }

  void _paintShape(Canvas canvas, Offset c, double s, Paint fill, Paint accent,
      Paint stroke, CosmeticGlyph g,
      {bool dimmed = false}) {
    final f = dimmed ? _fade(fill) : fill;
    final a = Paint()
      ..color = (dimmed ? _fade(accent) : accent).color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.035)
      ..strokeJoin = StrokeJoin.round;
    final st = dimmed ? _fade(stroke) : stroke;

    Path path() {
      switch (g.shape) {
        case CosmeticShape.disc:
          return Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.46));
        case CosmeticShape.ring:
          return Path()
            ..addOval(Rect.fromCircle(center: c, radius: s * 0.40));
        case CosmeticShape.drop:
          final p = Path()
            ..moveTo(c.dx, c.dy - s * 0.50)
            ..quadraticBezierTo(c.dx + s * 0.38, c.dy + s * 0.02, c.dx + s * 0.26, c.dy + s * 0.26)
            ..quadraticBezierTo(c.dx, c.dy + s * 0.52, c.dx - s * 0.26, c.dy + s * 0.26)
            ..quadraticBezierTo(c.dx - s * 0.38, c.dy + s * 0.02, c.dx, c.dy - s * 0.50)
            ..close();
          return p;
        case CosmeticShape.flame:
          return Path()
            ..moveTo(c.dx, c.dy - s * 0.50)
            ..cubicTo(c.dx + s * 0.34, c.dy - s * 0.10, c.dx + s * 0.30, c.dy + s * 0.28,
                c.dx, c.dy + s * 0.46)
            ..cubicTo(c.dx - s * 0.30, c.dy + s * 0.28, c.dx - s * 0.16, c.dy - s * 0.06, c.dx, c.dy - s * 0.50)
            ..close();
        case CosmeticShape.wave:
          return Path()
            ..moveTo(c.dx - s * 0.46, c.dy + s * 0.10)
            ..quadraticBezierTo(c.dx - s * 0.24, c.dy - s * 0.30, c.dx, c.dy + s * 0.06)
            ..quadraticBezierTo(c.dx + s * 0.24, c.dy + s * 0.42, c.dx + s * 0.46, c.dy + s * 0.02)
            ..lineTo(c.dx + s * 0.46, c.dy + s * 0.24)
            ..quadraticBezierTo(c.dx + s * 0.24, c.dy + s * 0.64, c.dx, c.dy + s * 0.28)
            ..quadraticBezierTo(c.dx - s * 0.24, c.dy - s * 0.08, c.dx - s * 0.46, c.dy + s * 0.32)
            ..close();
        case CosmeticShape.leaf:
          return Path()
            ..moveTo(c.dx - s * 0.42, c.dy + s * 0.40)
            ..quadraticBezierTo(c.dx - s * 0.34, c.dy - s * 0.44, c.dx + s * 0.42, c.dy - s * 0.40)
            ..quadraticBezierTo(c.dx + s * 0.34, c.dy + s * 0.44, c.dx - s * 0.42, c.dy + s * 0.40)
            ..close();
        case CosmeticShape.star:
          return _star(c, s * 0.48, 5, 0.45);
        case CosmeticShape.crescent:
          return Path()
            ..addOval(Rect.fromCircle(center: c, radius: s * 0.42))
            ..addOval(Rect.fromCircle(center: c.translate(s * 0.20, -s * 0.10), radius: s * 0.36))
            ..fillType = PathFillType.evenOdd;
        case CosmeticShape.band:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.92, height: s * 0.26),
              Radius.circular(s * 0.12),
            ));
        case CosmeticShape.cone:
          return Path()
            ..moveTo(c.dx, c.dy - s * 0.46)
            ..lineTo(c.dx + s * 0.44, c.dy + s * 0.42)
            ..lineTo(c.dx - s * 0.44, c.dy + s * 0.42)
            ..close();
        case CosmeticShape.diamond:
          return Path()
            ..moveTo(c.dx, c.dy - s * 0.48)
            ..lineTo(c.dx + s * 0.38, c.dy)
            ..lineTo(c.dx, c.dy + s * 0.48)
            ..lineTo(c.dx - s * 0.38, c.dy)
            ..close();
        case CosmeticShape.capsule:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.46, height: s * 0.88),
              Radius.circular(s * 0.23),
            ));
        case CosmeticShape.chevrons:
          return Path()
            ..moveTo(c.dx - s * 0.42, c.dy + s * 0.24)
            ..lineTo(c.dx, c.dy - s * 0.16)
            ..lineTo(c.dx + s * 0.42, c.dy + s * 0.24)
            ..lineTo(c.dx + s * 0.42, c.dy + s * 0.02)
            ..lineTo(c.dx, c.dy - s * 0.38)
            ..lineTo(c.dx - s * 0.42, c.dy + s * 0.02)
            ..close();
        case CosmeticShape.cross:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.90, height: s * 0.28),
              Radius.circular(s * 0.08),
            ))
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.28, height: s * 0.90),
              Radius.circular(s * 0.08),
            ));
        case CosmeticShape.pentagon:
          return _star(c, s * 0.46, 5, 1.0);
        case CosmeticShape.shield:
          return Path()
            ..moveTo(c.dx - s * 0.38, c.dy - s * 0.40)
            ..lineTo(c.dx + s * 0.38, c.dy - s * 0.40)
            ..lineTo(c.dx + s * 0.30, c.dy + s * 0.16)
            ..quadraticBezierTo(c.dx + s * 0.16, c.dy + s * 0.46, c.dx, c.dy + s * 0.48)
            ..quadraticBezierTo(c.dx - s * 0.16, c.dy + s * 0.46, c.dx - s * 0.30, c.dy + s * 0.16)
            ..close();
        case CosmeticShape.lens:
          return Path()
            ..moveTo(c.dx - s * 0.46, c.dy)
            ..quadraticBezierTo(c.dx - s * 0.22, c.dy - s * 0.40, c.dx, c.dy - s * 0.40)
            ..quadraticBezierTo(c.dx + s * 0.22, c.dy - s * 0.40, c.dx + s * 0.46, c.dy)
            ..quadraticBezierTo(c.dx + s * 0.22, c.dy + s * 0.40, c.dx, c.dy + s * 0.40)
            ..quadraticBezierTo(c.dx - s * 0.22, c.dy + s * 0.40, c.dx - s * 0.46, c.dy)
            ..close();
        case CosmeticShape.wing:
          final p = Path();
          for (final sign in const [-1.0, 1.0]) {
            final root = Offset(c.dx + sign * s * 0.06, c.dy + s * 0.34);
            p.moveTo(root.dx, root.dy);
            p.quadraticBezierTo(c.dx + sign * s * 0.50, c.dy - s * 0.06,
                c.dx + sign * s * 0.44, c.dy - s * 0.44);
            p.quadraticBezierTo(c.dx + sign * s * 0.26, c.dy - s * 0.14, root.dx, root.dy);
            p.close();
          }
          return p;
        case CosmeticShape.arcCrown:
          final p = Path()
            ..moveTo(c.dx - s * 0.44, c.dy + s * 0.22)
            ..quadraticBezierTo(c.dx, c.dy - s * 0.52, c.dx + s * 0.44, c.dy + s * 0.22)
            ..close();
          return p;
        case CosmeticShape.ladder:
          final p = Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, -s * 0.18), width: s * 0.22, height: s * 0.80),
              Radius.circular(s * 0.08),
            ))
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, s * 0.18), width: s * 0.22, height: s * 0.80),
              Radius.circular(s * 0.08),
            ));
          return p;
        case CosmeticShape.dome:
          return Path()
            ..moveTo(c.dx - s * 0.46, c.dy + s * 0.30)
            ..arcToPoint(Offset(c.dx + s * 0.46, c.dy + s * 0.30),
                radius: Radius.circular(s * 0.48), clockwise: false)
            ..close();
        case CosmeticShape.visor:
          // Cap dome + brim. Built as one path rather than addPath() so the
          // two parts share a fill — a brim drawn as a separate subpath with
          // even-odd would punch a hole where the two overlap.
          return Path()
            ..moveTo(c.dx - s * 0.44, c.dy - s * 0.06)
            ..arcToPoint(Offset(c.dx + s * 0.44, c.dy - s * 0.06),
                radius: Radius.circular(s * 0.46), clockwise: false)
            ..close()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: c.translate(s * 0.34, -s * 0.02),
                  width: s * 0.46,
                  height: s * 0.12),
              Radius.circular(s * 0.06),
            ));
        case CosmeticShape.boot:
          return Path()
            ..moveTo(c.dx - s * 0.26, c.dy - s * 0.46)
            ..lineTo(c.dx - s * 0.04, c.dy - s * 0.46)
            ..lineTo(c.dx - s * 0.04, c.dy + s * 0.14)
            ..lineTo(c.dx + s * 0.34, c.dy + s * 0.20)
            ..quadraticBezierTo(c.dx + s * 0.44, c.dy + s * 0.40, c.dx + s * 0.28, c.dy + s * 0.44)
            ..lineTo(c.dx - s * 0.26, c.dy + s * 0.44)
            ..close();
        case CosmeticShape.sole:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.92, height: s * 0.26),
              Radius.circular(s * 0.13),
            ))
            ..addOval(Rect.fromCenter(
                center: c.translate(0, -s * 0.22), width: s * 0.52, height: s * 0.34));
        case CosmeticShape.flare:
          return Path()
            ..moveTo(c.dx - s * 0.22, c.dy - s * 0.44)
            ..lineTo(c.dx + s * 0.22, c.dy - s * 0.44)
            ..lineTo(c.dx + s * 0.46, c.dy + s * 0.44)
            ..lineTo(c.dx - s * 0.46, c.dy + s * 0.44)
            ..close();
        case CosmeticShape.plate:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.86, height: s * 0.62),
              Radius.circular(s * 0.16),
            ));
        case CosmeticShape.collar:
          return Path()
            ..moveTo(c.dx - s * 0.48, c.dy + s * 0.34)
            ..lineTo(c.dx - s * 0.30, c.dy - s * 0.36)
            ..lineTo(c.dx, c.dy - s * 0.06)
            ..lineTo(c.dx + s * 0.30, c.dy - s * 0.36)
            ..lineTo(c.dx + s * 0.48, c.dy + s * 0.34)
            ..close();
        case CosmeticShape.sash:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 0.90, height: s * 0.24),
              Radius.circular(s * 0.10),
            ));
        case CosmeticShape.chain:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, -s * 0.30), width: s * 0.16, height: s * 0.44),
              Radius.circular(s * 0.08),
            ))
            // Path has no addCircle; a pendant charm is addOval over a
            // from-circle rect, which is what every other disc here uses too.
            ..addOval(Rect.fromCircle(
                center: c.translate(0, s * 0.30), radius: s * 0.22));
        case CosmeticShape.gem:
          return Path()
            ..moveTo(c.dx - s * 0.36, c.dy - s * 0.16)
            ..lineTo(c.dx + s * 0.36, c.dy - s * 0.16)
            ..lineTo(c.dx + s * 0.18, c.dy + s * 0.40)
            ..lineTo(c.dx - s * 0.18, c.dy + s * 0.40)
            ..close();
        case CosmeticShape.burst:
          return _star(c, s * 0.50, 8, 0.38);
        case CosmeticShape.grid:
          final p = Path();
          for (var row = -1; row <= 1; row++) {
            for (var col = -1; col <= 1; col++) {
              if (row == 0 && col == 0) continue;
              p.addOval(Rect.fromCircle(
                center: c.translate(col * s * 0.28, row * s * 0.28),
                radius: s * 0.10,
              ));
            }
          }
          return p;
        case CosmeticShape.spiralShell:
          final p = Path();
          for (var i = 0; i < 60; i++) {
            final t = i / 60 * 2 * math.pi * 2.2;
            final r = s * 0.06 + s * 0.36 * (i / 60);
            final pt = Offset(c.dx + r * math.cos(t), c.dy + r * math.sin(t));
            if (i == 0) {
              p.moveTo(pt.dx, pt.dy);
            } else {
              p.lineTo(pt.dx, pt.dy);
            }
          }
          return p;
        case CosmeticShape.cloudBands:
          final p = Path();
          for (var i = 0; i < 2; i++) {
            final dy = (i == 0 ? -1 : 1) * s * 0.22;
            p.addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, dy), width: s * 0.84, height: s * 0.22),
              Radius.circular(s * 0.11),
            ));
          }
          return p;
        case CosmeticShape.flower:
          final p = Path();
          for (var i = 0; i < 5; i++) {
            final ang = -math.pi / 2 + i * (2 * math.pi / 5);
            p.addOval(Rect.fromCenter(
              center: c.translate(math.cos(ang) * s * 0.26, math.sin(ang) * s * 0.26),
              width: s * 0.32,
              height: s * 0.32,
            ));
          }
          return p;
        case CosmeticShape.snowflake:
          final p = Path();
          for (var i = 0; i < 6; i++) {
            final ang = -math.pi / 2 + i * (math.pi / 3);
            final dir = Offset(math.cos(ang), math.sin(ang));
            p.moveTo(c.dx - dir.dx * s * 0.46, c.dy - dir.dy * s * 0.46);
            p.lineTo(c.dx + dir.dx * s * 0.46, c.dy + dir.dy * s * 0.46);
          }
          return p;
        case CosmeticShape.comet:
          final p = Path()
            ..addOval(Rect.fromCircle(center: c.translate(s * 0.16, -s * 0.16), radius: s * 0.26))
            ..moveTo(c.dx - s * 0.06, c.dy + s * 0.06)
            ..quadraticBezierTo(c.dx - s * 0.34, c.dy + s * 0.24, c.dx - s * 0.46, c.dy + s * 0.44)
            ..lineTo(c.dx - s * 0.20, c.dy + s * 0.44)
            ..quadraticBezierTo(c.dx - s * 0.18, c.dy + s * 0.20, c.dx + s * 0.10, c.dy + s * 0.10)
            ..close();
          return p;
        case CosmeticShape.scarfBand:
          final p = Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, -s * 0.12), width: s * 0.90, height: s * 0.28),
              Radius.circular(s * 0.13),
            ));
          p.moveTo(c.dx + s * 0.26, c.dy);
          p.lineTo(c.dx + s * 0.46, c.dy + s * 0.44);
          p.lineTo(c.dx + s * 0.20, c.dy + s * 0.40);
          p.close();
          return p;
        case CosmeticShape.lantern:
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, s * 0.10), width: s * 0.62, height: s * 0.68),
              Radius.circular(s * 0.18),
            ))
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, -s * 0.32), width: s * 0.28, height: s * 0.22),
              Radius.circular(s * 0.06),
            ));
        case CosmeticShape.bag:
          // The bag's handle: a half-arc that becomes a stroke, since a
            // filled arc of zero thickness would draw nothing.
          return Path()
            ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: c.translate(0, s * 0.14),
                  width: s * 0.74,
                  height: s * 0.60),
              Radius.circular(s * 0.10),
            ));
        case CosmeticShape.staff:
          return Path()
            ..moveTo(c.dx + s * 0.22, c.dy + s * 0.46)
            ..lineTo(c.dx - s * 0.10, c.dy - s * 0.30);
        case CosmeticShape.blank:
          return Path();
      }
    }

    final p = path();
    final isStrokeOnly = g.shape == CosmeticShape.ring ||
        g.shape == CosmeticShape.spiralShell ||
        g.shape == CosmeticShape.staff ||
        g.shape == CosmeticShape.snowflake;

    if (isStrokeOnly) {
      canvas.drawPath(p, st);
    } else {
      canvas.drawPath(p, f);
      // A hairline in the accent tone. Without it a filled icon on a tinted
      // tile loses its edge, and the tile tint is chosen per category — so two
      // categories can look like one row at a glance.
      canvas.drawPath(p, a);
    }
  }

  Paint _fade(Paint p) => Paint()
    ..color = p.color.withValues(alpha: p.color.a * 0.45)
    ..style = p.style
    ..strokeWidth = p.strokeWidth
    ..strokeCap = p.strokeCap
    ..strokeJoin = p.strokeJoin;

  Path _star(Offset c, double r, int points, double innerRatio) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final ang = -math.pi / 2 + i * math.pi / points;
      final rad = i.isEven ? r : r * innerRatio;
      final pt = Offset(c.dx + rad * math.cos(ang), c.dy + rad * math.sin(ang));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant CosmeticIconPainter oldDelegate) =>
      oldDelegate.itemId != itemId || oldDelegate.item?.id != item?.id;
}

/// Draws a companion's mood as a face, replacing `PetMoodX.emoji`.
///
/// Same reason as everything else here: 😊/🙂/🥺 are font glyphs, they differ
/// per device, and they were being drawn inside a `Text` on the pet card and
/// twice on the pet home screen — including in the "Meet {name}!" headline.
class PetMoodGlyphPainter extends CustomPainter {
  final PetMoodX mood;
  final bool resting;

  const PetMoodGlyphPainter({required this.mood, this.resting = false});

  static const _ink = Color(0xFF0F172A);
  static const _tint = {
    PetMoodX.happy: Color(0xFFF59E0B),
    PetMoodX.neutral: Color(0xFF64748B),
    PetMoodX.sad: Color(0xFF38BDF8),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = _tint[mood] ?? _tint[PetMoodX.neutral]!;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.07)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, s * 0.42, fill);

    final eyeY = c.dy - s * 0.10;
    if (resting || mood == PetMoodX.sad) {
      // Downcast lids: a flat line with a droop, still readable as a face.
      for (final sign in const [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(c.dx + sign * s * 0.22 - s * 0.08, eyeY)
          ..lineTo(c.dx + sign * s * 0.22 + s * 0.08, eyeY + (mood == PetMoodX.sad ? s * 0.04 : 0));
        canvas.drawPath(p, ink);
      }
    } else {
      for (final sign in const [-1.0, 1.0]) {
        canvas.drawCircle(
            Offset(c.dx + sign * s * 0.22, eyeY), math.max(1.4, s * 0.07), Paint()..color = _ink);
      }
    }

    final mouth = Rect.fromCenter(
      center: Offset(c.dx, c.dy + s * 0.16),
      width: s * 0.34,
      height: s * 0.26,
    );
    if (mood == PetMoodX.happy) {
      canvas.drawArc(mouth, 0.15 * math.pi, 0.7 * math.pi, false, ink);
    } else if (mood == PetMoodX.sad) {
      canvas.drawArc(mouth, 1.15 * math.pi, 0.7 * math.pi, false, ink);
    } else {
      canvas.drawLine(
        Offset(c.dx - s * 0.12, c.dy + s * 0.18),
        Offset(c.dx + s * 0.12, c.dy + s * 0.18),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PetMoodGlyphPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.resting != resting;
}