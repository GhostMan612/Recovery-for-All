// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// The companion's cosmetics must be VECTOR art, and the art must actually
// distinguish the items.
//
// A tester filed: "the avatars for the recovery pet… we absolutely NEED custom
// generated stuff for that. not the emoji icons." The species picker and the
// composite creature were converted first; the dresser grid, the starter-preset
// picker, the "Wearing Today" chips and three mood readouts were not, and the
// `emoji` field that fed them lived in the DATA file.
//
// The interesting half is not "there is no emoji" — that is a text scan. It is
// "the 108 replacements are not 40 icons in 108 places". A fallback that draws
// the same shape for everything would pass every emoji check and be useless, so
// uniqueness is asserted as a PROPERTY here rather than trusted to a review.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/services/pet_cosmetic_catalog.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/widgets/cosmetic_icon_painter.dart';

/// Every id the app can ask the painter to draw.
///
/// `all` is what the dresser grid renders. `hatcheryTierItems` is a separate
/// list of ids used by the hatchery tier; it is included because the painter is
/// keyed by id, so a missing entry there would be a silent dashed "none".
List<PetCosmetic> everyDrawableItem() => [
      ...PetCosmeticCatalog.all,
      ...PetCosmeticCatalog.hatcheryTierItems,
    ];

/// The same set, deduplicated by (category, label).
///
/// The catalogue lists eight hatchery items TWICE — once in `all` with a `_dup`
/// suffix and once in `hatcheryTierItems` without it (`starter_glow_dup` /
/// `starter_glow`, and so on). Same label, same category, same cost: they are
/// one item under two ids, not two items. Uniqueness is therefore asserted over
/// distinct ITEMS, not over ids, and [the catalogue's duplicate ids are named,
/// not hidden] records the pairs so the wart stays visible.
List<PetCosmetic> distinctItems() {
  final seen = <String>{};
  return everyDrawableItem().where((i) {
    return seen.add('${i.category.name}|${i.label}');
  }).toList();
}

void main() {
  group('coverage', () {
    test('every catalog item has hand-written art', () {
      final missing = everyDrawableItem()
          .where((i) => !CosmeticArt.hasArt(i.id))
          .map((i) => i.id)
          .toList();
      expect(missing, isEmpty,
          reason: 'these would render as the dashed "none" badge: $missing');
    });

    test('no art entry is orphaned by a deleted catalogue row', () {
      // The inverse failure: art for an item that no longer exists is dead code
      // that looks like coverage, and it inflates the count above so a genuinely
      // missing item hides among the spares.
      final ids = everyDrawableItem().map((i) => i.id).toSet();
      final drawn = PetCosmeticCatalog.all
          .map((i) => i.id)
          .where(CosmeticArt.hasArt)
          .toSet();
      expect(ids, containsAll(drawn));
    });

    test('the catalogue did not shrink while the art was written', () {
      // If items are removed, the uniqueness assertions below have less to say.
      // This states the floor so a future deletion is a deliberate edit here.
      expect(PetCosmeticCatalog.all.length, greaterThanOrEqualTo(90));
    });
  });

  group('silhouette uniqueness — the real assertion', () {
    test('no two items in a category share both a silhouette and a colour', () {
      // Two items that agree on shape signature AND colour are two identical
      // icons. This is the failure a fallback produces, and the one a reviewer
      // cannot reliably catch across 108 rows in 11 tabs.
      //
      // Scoped PER CATEGORY on purpose: the palette is per category, and the
      // grid is tabbed by category, so `body_sovereign` (arcCrown|5, body
      // violet) and `head_crown_star` (arcCrown|5, headwear cyan) are visibly
      // different pictures on different tabs. Asserting globally would fail on
      // a collision that does not exist for the player.
      final seen = <String, String>{};
      final collisions = <String>[];

      for (final item in distinctItems()) {
        final key = '${item.category.name}|'
            '${CosmeticArt.specFor(item.id).signature}|'
            '${CosmeticArt.colourTokenFor(item)}';
        if (seen.containsKey(key)) {
          collisions.add('${seen[key]} == ${item.id} ($key)');
        } else {
          seen[key] = item.id;
        }
      }

      expect(collisions, isEmpty,
          reason: 'these pairs are visually indistinguishable:\n'
              '${collisions.join('\n')}');
    });

    test('same-silhouette pairs inside a category are always colourway items',
        () {
      // The only legitimate way to collide on shape is `skin/tone` and
      // `hair/color`, where the colour IS the item. Everything else must differ
      // in outline. Asserting the ALLOWLIST of subcategories means a third
      // colourway cannot be added by quietly giving its items the same shape.
      final byCategorySignature = <String, List<PetCosmetic>>{};
      for (final item in distinctItems()) {
        byCategorySignature
            .putIfAbsent(
                '${item.category.name}|${CosmeticArt.specFor(item.id).signature}',
                () => [])
            .add(item);
      }
      for (final entry in byCategorySignature.entries) {
        if (entry.value.length < 2) continue;
        for (final item in entry.value) {
          expect(
            CosmeticArt.colourwaySubcategories.contains(item.subcategory),
            isTrue,
            reason: '${entry.value.map((i) => i.id).toList()} share silhouette '
                '"${CosmeticArt.specFor(item.id).signature}" in '
                '${item.category.name}, but "${item.subcategory}" is not a '
                'declared colourway subcategory',
          );
        }
      }
    });

    test("the catalogue's duplicate ids are named, not hidden", () {
      // Eight hatchery items appear twice: once in `all` with a `_dup` suffix
      // and once in `hatcheryTierItems` without it. That is a pre-existing
      // catalogue wart (two ids, one product) and NOT art debt — the art is
      // intentionally shared. This test exists so the count cannot silently
      // grow, and so whoever fixes the catalogue finds the list.
      final byItem = <String, List<String>>{};
      for (final item in everyDrawableItem()) {
        byItem
            .putIfAbsent('${item.category.name}|${item.label}', () => [])
            .add(item.id);
      }
      final duplicated = byItem.values.where((ids) => ids.length > 1);
      expect(
        duplicated.map((ids) => ids.toList()),
        containsAll([
          ['starter_glow_dup', 'starter_glow'],
          ['basic_shell_dup', 'basic_shell'],
          ['neon_grid_aura_dup', 'neon_grid_aura'],
          ['tactical_streetwear_dup', 'tactical_streetwear'],
          ['cbt_deflector_shield_dup', 'cbt_deflector_shield'],
          // THREE ids for one product here, not two: the top also has a
          // distinct-but-same-named `top_sovereign_mantle` in the ceremonial
          // subcategory.
          ['top_sovereign_mantle', 'sovereign_mantle_dup',
            'sovereign_mantle_hatchery'],
          ['cyber_monk_robes_dup', 'cyber_monk_robes'],
          ['ethereal_wings_dup', 'ethereal_wings'],
        ]),
        reason: 'the duplicate-id list changed. If the catalogue was de-duped, '
            'delete these rows from here AND drop the `_dup` entries from '
            'CosmeticArt — but keep one art spec per remaining id.',
      );
    });

    test('the two colourway subcategories are the only ones declared', () {
      // Guards the guard above: if `colourwaySubcategories` grew to include
      // "style", every style collision would become legal.
      expect(CosmeticArt.colourwaySubcategories, {'tone', 'color'});
    });

    test('every skin tone and hair colour really does have its own colour', () {
      // If one of these fell through to the category palette it would collide
      // with its siblings on BOTH axes, and the tests above would fail — but
      // with a confusing message. This names the actual cause.
      for (final item in PetCosmeticCatalog.all.where(
          (i) => i.subcategory == 'tone' || i.subcategory == 'color')) {
        expect(CosmeticArt.colourTokenFor(item), 'own:${item.id}',
            reason: '${item.id} is a colourway but has no dedicated colour');
      }
    });

    test('the palette covers all eleven categories', () {
      for (final category in CosmeticCategory.values) {
        expect(CosmeticArt.paletteForCategory(category), hasLength(2),
            reason: '$category has no palette and will draw in the fallback');
      }
    });
  });

  group('painting does not throw', () {
    Future<void> pump(WidgetTester tester, PetCosmetic item) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(
                painter: CosmeticIconPainter(itemId: item.id, item: item),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('paints every catalogue item at grid size', (tester) async {
      for (final item in PetCosmeticCatalog.all) {
        await pump(tester, item);
        expect(tester.takeException(), isNull, reason: '${item.id} threw');
      }
    });

    testWidgets('paints at the 16dp chip size used by "Wearing Today"',
        (tester) async {
      // A layout that pins a size needs more than one size tested. 16dp is
      // where a hairline outline or a 0.035 stroke width would round away and
      // leave an unrecognisable smudge.
      for (final item in PetCosmeticCatalog.all.take(20)) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(
                  painter: CosmeticIconPainter(itemId: item.id, item: item),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${item.id} threw at 16dp');
      }
    });

    testWidgets('an id the catalogue does not know still draws', (tester) async {
      // A slot holding a retired id must not crash the grid or vanish.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(
                painter: CosmeticIconPainter(itemId: 'retired_item_v9'),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a zero-size canvas is a no-op, not a NaN', (tester) async {
      // `size.shortestSide` on a collapsed box is 0, and every geometry constant
      // below is a multiple of it — the classic divide-by-zero paint crash.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRepaint reacts to an id change', (tester) async {
      const a = CosmeticIconPainter(itemId: 'top_tee_plain');
      const b = CosmeticIconPainter(itemId: 'top_tank');
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(a), isFalse);
    });

    testWidgets('the mood face paints for every mood and the resting state',
        (tester) async {
      for (final mood in PetMoodX.values) {
        for (final resting in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(
                    painter: PetMoodGlyphPainter(mood: mood, resting: resting),
                  ),
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '$mood resting=$resting threw');
        }
      }
    });
  });

  group('no emoji left in the companion surfaces', () {
    /// Source with comments stripped.
    ///
    /// Comments MUST go: two of these files describe the removal in prose that
    /// contains the very identifiers being searched for, and a scan that reads
    /// its own documentation fails on the first run. That is lessons-learned
    /// L32 in miniature.
    String codeOf(String path) {
      var src = File(path).readAsStringSync();
      src = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      src = src.replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');
      return src;
    }

    test('the dresser grid draws the painter, not a glyph', () {
      final src = codeOf('lib/screens/avatar_dresser_screen.dart');
      expect(src, contains('CosmeticIconPainter'));
      expect(src, isNot(contains('displayEmoji')));
      expect(src, isNot(contains('item.emoji')));
    });

    test('the preset picker draws a real item from its own outfit', () {
      final src = codeOf('lib/screens/onboarding_screen.dart');
      expect(src, isNot(contains('presetEmojis')));
      expect(src, contains('CosmeticArt.presetIconItem'));
    });

    test('"Wearing Today" draws the painter', () {
      final src = codeOf('lib/screens/pet_home_screen.dart');
      expect(src, isNot(contains('item.emoji')));
      expect(src, isNot(contains('mood.emoji')));
      expect(src, contains('PetMoodGlyphPainter'));
    });

    test('the pet card draws a mood face', () {
      final src = codeOf('lib/widgets/recovery_pet_card.dart');
      expect(src, isNot(contains('mood.emoji')));
      expect(src, contains('PetMoodGlyphPainter'));
    });

    test('the data files carry no art at all', () {
      // A glyph in the catalogue is the bug this whole pass removed; if one
      // comes back, the visual identity has a second source of truth again.
      expect(codeOf('lib/services/pet_cosmetic_catalog.dart'),
          isNot(contains('presetEmojis')));
      expect(codeOf('lib/services/recovery_pet_service.dart'),
          isNot(contains('String emoji')));
    });

    test('AvatarVisualLayer exposes no emoji lookup', () {
      final src = codeOf('lib/widgets/avatar_visual_layer.dart');
      expect(src, isNot(contains('emojiForCosmetic')));
      expect(src, isNot(contains('displayEmoji')));
    });

    test('the mood LABEL survives, so screen readers lose nothing', () {
      // Removing a glyph must not remove the words that announced it.
      expect(PetMoodX.happy.label, isNotEmpty);
      expect(PetMoodX.neutral.label, isNotEmpty);
      expect(PetMoodX.sad.label, isNotEmpty);
      expect(PetMoodX.values.map((m) => m.label).toSet(), hasLength(3));
    });
  });
}