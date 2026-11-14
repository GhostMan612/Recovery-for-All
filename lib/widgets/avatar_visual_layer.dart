// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/avatar_visual_layer.dart
//
// Companion rendering: species creature base + cosmetic layer stack.
// Auras play a Lottie loop when one ships for the equipped aura id;
// everything degrades to the static painted glow when assets are missing or the
// user prefers reduced motion.
//
// Ember Kit features pre-rendered 2D sprite animations (idle, joy, rest)
// when in default form, falling back to AvatarPainter vector art when custom
// cosmetics are equipped or on asset-load failure.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';

import '../core/motion/app_motion.dart';
import '../services/hardware_tier_service.dart';
import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import 'avatar_painter.dart';
import 'game_sprite_stage.dart';

/// Companion rendering: Lottie aura + Lottie mood underlay + animated sprite
/// stage (Ember Kit) or fully PAINTED vector creature (AvatarPainter).
class AvatarVisualLayer extends StatefulWidget {
  final RecoveryPet pet;
  final double size;
  final bool showAura;
  final bool compact;
  final bool allowSprite;

  const AvatarVisualLayer({
    super.key,
    required this.pet,
    this.size = 160,
    this.showAura = true,
    this.compact = false,
    this.allowSprite = true,
  });

  /// Equipped aura id -> bundled Lottie loop. An unmapped id falls back to the
  /// painted glow in `_SimpleGlowPainter`, never to a glyph.
  /// DotLottie (.lottie zip) — lottie ^3.1 parses both .json and .lottie.
  static const Map<String, String> _auraLottie = {
    'aura_warm': 'assets/lottie/aura_warm.lottie',
    'aura_calm_blue': 'assets/lottie/aura_calm_blue.lottie',
    'aura_starfield': 'assets/lottie/aura_starfield.lottie',
    'aura_ember': 'assets/lottie/aura_ember.lottie',
  };

  /// PetMoodX name / resting -> mood-face underlay loop.
  static const Map<String, String> _moodLottie = {
    'happy': 'assets/lottie/mood_happy.lottie',
    'neutral': 'assets/lottie/mood_calm.lottie',
    'sad': 'assets/lottie/mood_sad.lottie',
    '@resting': 'assets/lottie/mood_resting.lottie',
  };

  static final Map<String, LottieComposition?> _compositionCache = {};

  static Future<LottieComposition?> _compositionFor(String asset) async {
    if (_compositionCache.containsKey(asset)) return _compositionCache[asset];
    LottieComposition? composition;
    try {
      final data = await rootBundle.load(asset);
      composition = await LottieComposition.fromByteData(data);
    } catch (_) {
      composition = null;
    }
    _compositionCache[asset] = composition;
    return composition;
  }

  /// Returns true if the pet belongs to the Ember Kit species (including legacy 'kin' default).
  static bool isEmberKit(RecoveryPet pet) {
    final speciesId = pet.speciesId.trim().toLowerCase();
    return speciesId == PetSpeciesCatalog.emberKitId ||
        speciesId == 'kin' ||
        speciesId == 'default' ||
        speciesId.isEmpty;
  }

  /// Returns true if the pet has equipped custom unlocked / purchased cosmetics
  /// that deviate from starter companion forms (e.g. cloaks, robes, armor, leaf crowns, wings)
  /// which cannot yet be faithfully displayed on the fixed sprite atlas.
  /// Starter preset items (Pathwalker, Tidekeeper, Embersmith) are considered unadorned
  /// baseline forms and do not suppress the 2D sprite.
  static bool hasCustomCosmetics(RecoveryPet pet) {
    final head = pet.slot(CosmeticCategory.headwear);
    if (head != null &&
        head != 'head_none' &&
        head != 'head_cap' &&
        head != 'head_beanie' &&
        !head.endsWith('_none')) {
      return true;
    }

    final acc = pet.slot(CosmeticCategory.accessory);
    if (acc != null &&
        acc != 'acc_none' &&
        acc != 'acc_bag_day' &&
        acc != 'acc_scarf' &&
        !acc.endsWith('_none')) {
      return true;
    }

    final top = pet.slot(CosmeticCategory.top);
    if (top != null &&
        top != 'top_tee_plain' &&
        top != 'top_hoodie_soft' &&
        top != 'top_tank' &&
        !top.endsWith('_none')) {
      return true;
    }

    final bottom = pet.slot(CosmeticCategory.bottom);
    if (bottom != null &&
        bottom != 'bottom_joggers' &&
        bottom != 'bottom_shorts' &&
        bottom != 'bottom_jeans' &&
        !bottom.endsWith('_none')) {
      return true;
    }

    final shoes = pet.slot(CosmeticCategory.shoes);
    if (shoes != null &&
        shoes != 'shoes_sneakers' &&
        shoes != 'shoes_sandals' &&
        shoes != 'shoes_bare' &&
        shoes != 'shoes_slippers_home' &&
        !shoes.endsWith('_none')) {
      return true;
    }

    return false;
  }

  @override
  State<AvatarVisualLayer> createState() => _AvatarVisualLayerState();
}

class _AvatarVisualLayerState extends State<AvatarVisualLayer>
    with TickerProviderStateMixin {
  LottieComposition? _auraComposition;
  LottieComposition? _moodComposition;
  String _resolvedMoodKey = '';

  // Celebration animation controller for mood flash on Sparks earn
  late final AnimationController _celebrationController;
  bool _isCelebrating = false;

  String get _equippedAuraId =>
      widget.pet.slot(CosmeticCategory.aura) ?? '';

  /// Resting overrides mood for the face underlay (sleepy drift).
  String get _moodKey => widget.pet.isResting
      ? '@resting'
      : switch (widget.pet.mood) {
          PetMoodX.happy => 'happy',
          PetMoodX.sad => 'sad',
          PetMoodX.neutral => 'neutral',
        };

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resolveAnimations(disableMotion: HardwareTierService.isLowEnd);
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AvatarVisualLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.slot(CosmeticCategory.aura) != _equippedAuraId ||
        oldWidget.showAura != widget.showAura ||
        oldWidget.pet.isResting != widget.pet.isResting ||
        oldWidget.pet.mood != widget.pet.mood) {
      _resolveAnimations(disableMotion: HardwareTierService.isLowEnd);
    }
    // Trigger celebration when sparks increase
    if (oldWidget.pet.sparks < widget.pet.sparks) {
      _triggerCelebration();
    }
  }

  /// Trigger celebration animation (mood flash + scale pulse) when Sparks earned
  void _triggerCelebration() {
    if (_isCelebrating) return;
    setState(() => _isCelebrating = true);
    _celebrationController.forward(from: 0).then((_) {
      if (mounted) setState(() => _isCelebrating = false);
    });
  }

  Future<void> _resolveAnimations({required bool disableMotion}) async {
    LottieComposition? aura;
    LottieComposition? mood;

    if (!disableMotion) {
      final auraAsset =
          widget.showAura ? AvatarVisualLayer._auraLottie[_equippedAuraId] : null;
      // Concurrency guard (checklist §12.3): compact surfaces render at most
      // one loop — the aura wins, mood stays emoji-static there.
      final moodAsset = widget.compact
          ? null
          : AvatarVisualLayer._moodLottie[_moodKey];
      if (auraAsset != null) {
        aura = await AvatarVisualLayer._compositionFor(auraAsset);
      }
      if (moodAsset != null) {
        mood = await AvatarVisualLayer._compositionFor(moodAsset);
      }
    }
    if (!mounted) return;
    setState(() {
      _auraComposition = aura;
      _moodComposition = mood;
      _resolvedMoodKey = _moodKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotionOf(context);
    final disableLottie = HardwareTierService.isLowEnd || reduceMotion;

    final targetPet = widget.pet;
    final size = widget.size;
    final useSprite = widget.allowSprite &&
        AvatarVisualLayer.isEmberKit(targetPet) &&
        !AvatarVisualLayer.hasCustomCosmetics(targetPet);

    if (reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.showAura)
              CustomPaint(
                size: Size.square(widget.size * 0.98),
                painter: _SimpleGlowPainter(
                  color: AvatarPainter.auraColorFor(_equippedAuraId),
                ),
              ),
            useSprite
                ? GameSpriteStage(
                    assetPath: EmberKitSpriteConfig.asset,
                    startFrame: EmberKitSpriteConfig.staticFrame,
                    frameCount: 1,
                    staticFrame: EmberKitSpriteConfig.staticFrame,
                    width: widget.size,
                    height: widget.size,
                    fallback: CustomPaint(
                      size: Size.square(widget.size),
                      painter: AvatarPainter(widget.pet),
                    ),
                  )
                : CustomPaint(
                    size: Size.square(widget.size),
                    painter: AvatarPainter(widget.pet),
                  ),
            _buildCelebrationOverlay(widget.size),
          ],
        ),
      );
    }

    final pet = widget.pet;

    final lottieAura = _auraComposition;
    final showLottieAura =
        widget.showAura && lottieAura != null && !disableLottie;
    // Mood underlay only when it matches the CURRENT state (a resolve may
    // have raced a mood change) and the surface is large enough.
    final moodKey = _moodKey;
    final showMoodLottie = !disableLottie &&
        !widget.compact &&
        _resolvedMoodKey == moodKey &&
        _moodComposition != null;

    final Widget creatureVisual;
    if (useSprite) {
      final int startFrame;
      final int frameCount;
      final Duration frameDuration;
      final bool loop;

      if (_isCelebrating) {
        startFrame = EmberKitSpriteConfig.joyStart;
        frameCount = EmberKitSpriteConfig.joyCount;
        frameDuration = EmberKitSpriteConfig.joyDuration;
        loop = false;
      } else if (pet.isResting) {
        startFrame = EmberKitSpriteConfig.restStart;
        frameCount = EmberKitSpriteConfig.restCount;
        frameDuration = EmberKitSpriteConfig.restDuration;
        loop = true;
      } else {
        startFrame = EmberKitSpriteConfig.idleStart;
        frameCount = EmberKitSpriteConfig.idleCount;
        frameDuration = EmberKitSpriteConfig.idleDuration;
        loop = true;
      }

      creatureVisual = GameSpriteStage(
        key: ValueKey('ember_kit_${startFrame}_$loop'),
        assetPath: EmberKitSpriteConfig.asset,
        startFrame: startFrame,
        frameCount: frameCount,
        frameDuration: frameDuration,
        loop: loop,
        staticFrame: EmberKitSpriteConfig.staticFrame,
        width: size,
        height: size,
        fallback: CustomPaint(
          size: Size.square(size),
          painter: AvatarPainter(pet),
        ),
      );
    } else {
      creatureVisual = CustomPaint(
        size: Size.square(size),
        painter: AvatarPainter(pet),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showAura)
            showLottieAura
                ? Lottie(
                    composition: lottieAura,
                    width: size * 0.98,
                    height: size * 0.98,
                    repeat: true,
                    animate: true,
                  )
                : CustomPaint(
                    size: Size.square(size * 0.98),
                    painter: _SimpleGlowPainter(
                      color: AvatarPainter.auraColorFor(_equippedAuraId),
                    ),
                  ),
          if (showMoodLottie)
            Positioned(
              top: size * 0.16,
              child: Opacity(
                opacity: 0.9,
                child: Lottie(
                  composition: _moodComposition!,
                  width: size * 0.5,
                  height: size * 0.5,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          // The companion creature: animated 2D sprite or vector art fallback
          creatureVisual,
          // Celebration overlay: flash + scale pulse when Sparks earned
          _buildCelebrationOverlay(size),
        ],
      ),
    );
  }

  Widget _buildCelebrationOverlay(double size) {
    if (!_isCelebrating) return const SizedBox.shrink();
    return _CelebrationOverlay(
      size: size,
      progress: _celebrationController.value,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Static radial glow used when a Lottie aura isn't available.
class _SimpleGlowPainter extends CustomPainter {
  final Color color;
  _SimpleGlowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (color == const Color(0x00000000)) return;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleGlowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Celebration overlay: radial flash + scale pulse when Sparks earned.
class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({
    required this.size,
    required this.progress,
    required this.color,
  });

  final double size;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progressValue = progress.clamp(0.0, 1.0);
    final flashOpacity = (1.0 - progressValue).clamp(0.0, 1.0);
    final scale = 1.0 + 0.15 * (1.0 - (progressValue - 0.5).abs() * 2.0);
    final alpha = (0.6 * (1.0 - progressValue).clamp(0.0, 1.0) * 255).round();
    final colorAlpha = color.withAlpha(alpha);
    final transparentColor = color.withAlpha(0);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: flashOpacity,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [colorAlpha, transparentColor],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
