// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/widgets/avatar_painter.dart';
import 'package:recovery_for_all/widgets/avatar_visual_layer.dart';
import 'package:recovery_for_all/widgets/game_sprite_stage.dart';
import 'package:recovery_for_all/widgets/trial_monster_painter.dart';

void main() {
  group('G-02 Character Sprite Animation Integration Tests', () {
    RecoveryPet createTestPet({
      String name = 'Ember',
      String speciesId = 'ember_kit',
      String equippedOutfit = 'default',
      Map<String, String> equippedSlots = const {},
    }) {
      return RecoveryPet(
        id: 'test_pet_id',
        name: name,
        energy: 80,
        bond: 50,
        mood: PetMoodX.happy,
        sparks: 100,
        unlockedItems: const [],
        equippedOutfit: equippedOutfit,
        equippedSlots: equippedSlots,
        speciesId: speciesId,
        lastFedAt: 0,
        createdAt: 0,
      );
    }

    test(
      'Ember Kit sprite config has valid 4x4 atlas layout and animation frames',
      () {
        expect(EmberKitSpriteConfig.columns, equals(4));
        expect(EmberKitSpriteConfig.rows, equals(4));
        expect(EmberKitSpriteConfig.frameSize, equals(256.0));
        expect(EmberKitSpriteConfig.totalFrames, equals(16));
        expect(
          EmberKitSpriteConfig.asset,
          equals('assets/game/sprites/ember_kit_v1.png'),
        );

        // Idle: 8 frames (0..7)
        expect(EmberKitSpriteConfig.idleStart, equals(0));
        expect(EmberKitSpriteConfig.idleCount, equals(8));
        expect(
          EmberKitSpriteConfig.idleDuration,
          equals(const Duration(milliseconds: 125)),
        );

        // Joy: 4 frames (8..11)
        expect(EmberKitSpriteConfig.joyStart, equals(8));
        expect(EmberKitSpriteConfig.joyCount, equals(4));
        expect(
          EmberKitSpriteConfig.joyDuration,
          equals(const Duration(milliseconds: 100)),
        );

        // Rest: 4 frames (12..15)
        expect(EmberKitSpriteConfig.restStart, equals(12));
        expect(EmberKitSpriteConfig.restCount, equals(4));
        expect(
          EmberKitSpriteConfig.restDuration,
          equals(const Duration(milliseconds: 250)),
        );

        // Static frame for reduced motion
        expect(EmberKitSpriteConfig.staticFrame, equals(0));
      },
    );

    test(
      'Craving Wraith sprite config has valid 4x4 atlas layout and animation frames',
      () {
        expect(CravingWraithSpriteConfig.columns, equals(4));
        expect(CravingWraithSpriteConfig.rows, equals(4));
        expect(CravingWraithSpriteConfig.frameSize, equals(256.0));
        expect(CravingWraithSpriteConfig.totalFrames, equals(16));
        expect(
          CravingWraithSpriteConfig.asset,
          equals('assets/game/sprites/craving_wraith_v1.png'),
        );

        // Idle: 8 frames (0..7)
        expect(CravingWraithSpriteConfig.idleStart, equals(0));
        expect(CravingWraithSpriteConfig.idleCount, equals(8));
        expect(
          CravingWraithSpriteConfig.idleDuration,
          equals(const Duration(milliseconds: 150)),
        );

        // Hit: 4 frames (8..11)
        expect(CravingWraithSpriteConfig.hitStart, equals(8));
        expect(CravingWraithSpriteConfig.hitCount, equals(4));
        expect(
          CravingWraithSpriteConfig.hitDuration,
          equals(const Duration(milliseconds: 80)),
        );

        // Fade: 4 frames (12..15)
        expect(CravingWraithSpriteConfig.fadeStart, equals(12));
        expect(CravingWraithSpriteConfig.fadeCount, equals(4));
        expect(
          CravingWraithSpriteConfig.fadeDuration,
          equals(const Duration(milliseconds: 150)),
        );

        // Static frame for reduced motion
        expect(CravingWraithSpriteConfig.staticFrame, equals(0));
      },
    );

    test(
      'SpriteAtlasPainter frame rect computation correctly computes 4x4 grid coordinates',
      () {
        // Test frame 0: column 0, row 0 -> (0, 0, 256, 256)
        final rect0 = SpriteAtlasPainter.calculateFrameRect(
          frameIndex: 0,
          columns: 4,
          rows: 4,
          frameSize: 256.0,
        );
        expect(rect0.left, equals(0.0));
        expect(rect0.top, equals(0.0));
        expect(rect0.width, equals(256.0));
        expect(rect0.height, equals(256.0));

        // Test frame 5: row 1, col 1 -> (256, 256, 256, 256)
        final rect5 = SpriteAtlasPainter.calculateFrameRect(
          frameIndex: 5,
          columns: 4,
          rows: 4,
          frameSize: 256.0,
        );
        expect(rect5.left, equals(256.0));
        expect(rect5.top, equals(256.0));

        // Test frame 15 (last frame): row 3, col 3 -> (768, 768, 256, 256)
        final rect15 = SpriteAtlasPainter.calculateFrameRect(
          frameIndex: 15,
          columns: 4,
          rows: 4,
          frameSize: 256.0,
        );
        expect(rect15.left, equals(768.0));
        expect(rect15.top, equals(768.0));
      },
    );

    test(
      'AvatarVisualLayer isEmberKit recognizes ember_kit and default kin species',
      () {
        final emberPet = createTestPet(speciesId: 'ember_kit');
        expect(AvatarVisualLayer.isEmberKit(emberPet), isTrue);

        final kinPet = createTestPet(speciesId: 'kin');
        expect(AvatarVisualLayer.isEmberKit(kinPet), isTrue);

        final defaultPet = createTestPet(speciesId: 'default');
        expect(AvatarVisualLayer.isEmberKit(defaultPet), isTrue);

        final emptyPet = createTestPet(speciesId: '');
        expect(AvatarVisualLayer.isEmberKit(emptyPet), isTrue);

        final tidePet = createTestPet(speciesId: 'tide_kin');
        expect(AvatarVisualLayer.isEmberKit(tidePet), isFalse);

        final unknownPet = createTestPet(speciesId: 'future_species');
        expect(AvatarVisualLayer.isEmberKit(unknownPet), isFalse);

        final upperTidePet = createTestPet(speciesId: 'TIDE_KIN');
        expect(AvatarVisualLayer.isEmberKit(upperTidePet), isFalse);

        final upperEmberPet = createTestPet(speciesId: 'Ember_Kit');
        expect(AvatarVisualLayer.isEmberKit(upperEmberPet), isTrue);
      },
    );

    test(
      'AvatarVisualLayer hasCustomCosmetics detects default vs customized companion',
      () {
        final defaultPet = createTestPet();
        expect(AvatarVisualLayer.hasCustomCosmetics(defaultPet), isFalse);

        final customPet = createTestPet(
          equippedSlots: {'top': 'hoodie_crimson'},
        );
        expect(AvatarVisualLayer.hasCustomCosmetics(customPet), isTrue);

        final hatPet = createTestPet(
          equippedSlots: {'headwear': 'cap_baseball'},
        );
        expect(AvatarVisualLayer.hasCustomCosmetics(hatPet), isTrue);

        final bareShoesPet = createTestPet(
          equippedSlots: {'shoes': 'shoes_bare'},
        );
        expect(AvatarVisualLayer.hasCustomCosmetics(bareShoesPet), isFalse);
      },
    );

    testWidgets('GameSpriteStage renders fallback when the atlas is missing', (
      tester,
    ) async {
      const fallbackKey = Key('fallback_widget');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameSpriteStage(
              assetPath: 'assets/game/sprites/__missing_for_test__.png',
              startFrame: EmberKitSpriteConfig.idleStart,
              frameCount: EmberKitSpriteConfig.idleCount,
              frameDuration: EmberKitSpriteConfig.idleDuration,
              fallback: const SizedBox(
                key: fallbackKey,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // On load failure the fallback remains visible.
      expect(find.byKey(fallbackKey), findsOneWidget);
    });

    testWidgets('GameSpriteStage actively advances frames during playback', (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final testImage = await picture.toImage(1024, 1024);

      GameSpriteStage.cacheAtlasForTesting(
        'synthetic_atlas_test.png',
        testImage,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameSpriteStage(
              assetPath: 'synthetic_atlas_test.png',
              startFrame: 0,
              frameCount: 4,
              frameDuration: const Duration(milliseconds: 100),
              loop: true,
              staticFrame: 0,
              width: 160,
              height: 160,
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pump();
      CustomPaint customPaint = tester.widget(find.byType(CustomPaint).last);
      SpriteAtlasPainter painter = customPaint.painter as SpriteAtlasPainter;
      expect(painter.frameIndex, equals(0));

      // Advance by 150ms -> progresses into frame 1
      await tester.pump(const Duration(milliseconds: 150));
      customPaint = tester.widget(find.byType(CustomPaint).last);
      painter = customPaint.painter as SpriteAtlasPainter;
      expect(painter.frameIndex, equals(1));

      // Advance by another 100ms -> progresses into frame 2
      await tester.pump(const Duration(milliseconds: 100));
      customPaint = tester.widget(find.byType(CustomPaint).last);
      painter = customPaint.painter as SpriteAtlasPainter;
      expect(painter.frameIndex, equals(2));

      GameSpriteStage.clearCache();
    });

    testWidgets(
      'Trial monster painter remains functional for non-wraith monsters',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: TrialMonsterPainter(
                    kind: TrialMonsterKind.reaper,
                    baseColor: Colors.red,
                    t: 0.5,
                    hitFlash: 0.0,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('AvatarPainter vector fallback remains functional', (
      tester,
    ) async {
      final pet = createTestPet(name: 'VectorKit');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(painter: AvatarPainter(pet)),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
