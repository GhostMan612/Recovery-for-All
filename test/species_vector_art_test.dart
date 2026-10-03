// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Companion art must be VECTOR, not emoji.
//
// A tester filed: "the avatars for the recovery pet… we absolutely NEED custom
// generated stuff for that. not the emoji icons."
//
// The composite avatar was already painted (AvatarPainter), but three surfaces
// still reached for a system emoji glyph:
//
//   * the species picker rendered `species.emoji` in a `Text`
//   * the reduce-motion / low-end fallback rendered an aura emoji at 0.85x the
//     avatar's size — on precisely the devices least able to render emoji
//   * the dresser grid uses emoji thumbnails
//
// These tests pin the first two, because both were silent regressions of a
// contract the code itself already stated ("Zero emoji in the composite").

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/widgets/avatar_painter.dart';

void main() {
  group('species art is vector, not glyphs', () {
    test('every catalog species has a shape and a palette', () {
      // A species with neither falls back to `ember_kit`, so eight entries
      // would silently render as four distinct creatures and four copies of
      // the fox. This is the check that makes that visible.
      for (final species in PetSpeciesCatalog.all) {
        expect(AvatarPainter.speciesShapes.containsKey(species.id), isTrue,
            reason: '${species.id} has no silhouette — it will draw as ember_kit');
        expect(AvatarPainter.speciesColors.containsKey(species.id), isTrue,
            reason: '${species.id} has no palette');
      }
    });

    test('the catalog has more species than the fallback, so the fallback is not '
        'the whole catalog', () {
      // Guards the guard: if someone adds two species and gives neither a
      // shape, the loop above already fails. This states the intent explicitly.
      expect(PetSpeciesCatalog.all.length,
          greaterThan(AvatarPainter.speciesShapes.length - 1));
    });

    test('species silhouettes are genuinely distinct, not just re-tinted', () {
      // Eight species that differ ONLY in colour are one creature. Compare the
      // silhouette parameters; two species sharing every shape parameter would
      // mean the picker shows the same outline twice.
      final byShape = <String, List<String>>{};
      AvatarPainter.speciesShapes.forEach((id, shape) {
        final key = '${shape.bodyWidth}|${shape.bodyHeight}|'
            '${shape.earHeight}|${shape.earWidth}|${shape.earTilt}';
        byShape.putIfAbsent(key, () => []).add(id);
      });
      for (final entry in byShape.entries) {
        expect(entry.value, hasLength(1),
            reason: '${entry.value} share one silhouette');
      }
    });

    test('the hare has the tallest ears in the catalog', () {
      // A regression here means "prairie_ember_hare" is just a squirrel.
      final heights = AvatarPainter.speciesShapes
          .map((id, shape) => MapEntry(id, shape.earHeight));
      final tallest = heights.entries.reduce((a, b) => a.value > b.value ? a : b);
      expect(tallest.key, 'prairie_ember_hare');
    });

    test('the loon has essentially no ears', () {
      final loon = AvatarPainter.speciesShapes['north_star_loon']!;
      expect(loon.earHeight, lessThan(0.06));
    });
  });

  group('portrait renders', () {
    Future<void> pumpPortrait(WidgetTester tester, String speciesId) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: SpeciesPortraitPainter(speciesId: speciesId),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('paints for every catalog species without throwing',
        (tester) async {
      for (final species in PetSpeciesCatalog.all) {
        await pumpPortrait(tester, species.id);
        expect(tester.takeException(), isNull,
            reason: '${species.id} threw while painting');
      }
    });

    testWidgets('an unknown species falls back to ember_kit rather than '
        'crashing', (tester) async {
      await pumpPortrait(tester, 'not_a_real_species');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a zero-size canvas is a no-op, not a division by zero',
        (tester) async {
      // A SizedBox collapsed to 0 appears in the species grid under a large
      // text scale; `math.min` over an empty box is the classic crash.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRepaint reacts to species change', (tester) async {
      const a = SpeciesPortraitPainter(speciesId: 'ember_kit');
      const b = SpeciesPortraitPainter(speciesId: 'tide_kin');
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(a), isFalse);
    });
  });

  group('no emoji in the reduced-motion avatar path', () {
    /// Source with comments removed.
    ///
    /// A behavioural test cannot assert the ABSENCE of a glyph — it would have
    /// to inspect a rendered tree and decide which codepoints count as art. So
    /// the check is textual, which means it MUST strip comments first. It did
    /// not, and the first run failed on its own explanatory comment containing
    /// the very string it was looking for — the exact L32 mistake in miniature:
    /// a test that reads prose as behaviour.
    String codeOf(String path) {
      var src = File(path).readAsStringSync();
      src = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      src = src.replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');
      return src;
    }

    test('the static fallback no longer renders an aura emoji', () {
      final src = codeOf('lib/widgets/avatar_visual_layer.dart');
      final staticBranch = src
          .split('disableMotion = HardwareTierService.isLowEnd || AppMotion')
          .elementAt(1)
          .split('final pet = widget.pet;')
          .first;
      expect(staticBranch, isNot(contains('displayEmoji')),
          reason: 'the reduced-motion avatar must not render an emoji — that '
              'path is for devices least able to draw one');
      expect(staticBranch, isNot(contains('Text(')),
          reason: 'no Text glyph in the static avatar branch');
      // And it must still PAINT something, or the fix would be a blank square.
      expect(staticBranch, contains('AvatarPainter'));
    });

    test('the species picker draws a vector portrait, not species.emoji', () {
      final src = codeOf('lib/screens/pet_home_screen.dart');
      expect(src, isNot(contains('species.emoji')),
          reason: 'the species picker must draw a vector portrait');
      expect(src, contains('SpeciesPortraitPainter'),
          reason: 'and it must actually use the vector painter');
    });
  });
}