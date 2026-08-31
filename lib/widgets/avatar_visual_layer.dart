// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/avatar_visual_layer.dart
//
// Companion rendering: species creature base + cosmetic emoji stack.
// Auras play a Lottie loop when one ships for the equipped aura id;
// everything degrades to static emoji when assets are missing or the user
// prefers reduced motion.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';

import '../core/theme/app_colors.dart';
import '../services/hardware_tier_service.dart';
import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import 'avatar_painter.dart';

/// Companion rendering: Lottie aura + Lottie mood underlay + a fully
/// PAINTED vector creature (AvatarPainter). Zero emoji in the composite —
/// emoji survive only in the dresser grid as item thumbnails.
class AvatarVisualLayer extends StatefulWidget {
  final RecoveryPet pet;
  final double size;
  final bool showAura;
  final bool compact;

  const AvatarVisualLayer({
    super.key,
    required this.pet,
    this.size = 160,
    this.showAura = true,
    this.compact = false,
  });

  /// Equipped aura id -> bundled Lottie loop. Unmapped ids fall back to emoji.
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

  static String emojiForCosmetic(String? id) {
    if (id == null) return '✨';
    const map = <String, String>{
      'body_soft_glow': '🌟', 'body_ember': '🔥', 'body_tide': '🌊',
      'body_moss': '🌿', 'body_starlit': '✨', 'body_sovereign': '👑',
      'skin_pearl': '🤍', 'skin_amber': '🧡', 'skin_slate': '🩶',
      'skin_rose': '💗', 'skin_jade': '💚', 'skin_obsidian': '🖤',
      'skin_aurora': '🌈',
      'face_calm': '😌', 'face_bright': '😊', 'face_soft': '🙂',
      'face_fierce': '😤', 'face_dream': '😴',
      'hair_short_wave': '💇', 'hair_crop': '✂️', 'hair_long_flow': '💇‍♀️',
      'hair_bun': '🎀', 'hair_braids': '🪢', 'hair_flame': '🔥',
      'top_tee_plain': '👕', 'top_hoodie_soft': '🧥', 'top_tank': '🎽',
      'top_flannel': '🧥', 'top_jacket_dawn': '🧥', 'top_cloak_forest': '🧙',
      'top_robe_river': '👘', 'top_armor_light': '🛡️',
      'top_sovereign_mantle': '👑',
      'bottom_shorts': '🩳', 'bottom_joggers': '👖', 'bottom_jeans': '👖',
      'bottom_skirt_flow': '👗',
      'shoes_bare': '🦶', 'shoes_sneakers': '👟', 'shoes_sandals': '🩴',
      'shoes_boots_trail': '🥾', 'shoes_boots_storm': '⛈️',
      'shoes_slippers_home': '🥿', 'shoes_kicks_neon': '⚡',
      'shoes_sovereign': '✨',
      'head_none': '🚫', 'head_beanie': '🧢', 'head_cap': '🧢',
      'head_bandana': '🎽', 'head_hood': '🧥', 'head_crown_leaf': '🍃',
      'head_crown_star': '⭐', 'head_halo_soft': '😇',
      'jewelry_none': '🚫', 'jewelry_band_simple': '💍',
      'jewelry_pendant_seed': '🌱', 'jewelry_pendant_wave': '🌊',
      'jewelry_earring_dot': '💠', 'jewelry_earring_moon': '🌙',
      'jewelry_ring_bond': '💞', 'jewelry_chain_star': '⭐',
      'jewelry_crest_sovereign': '⚜️',
      'acc_none': '🚫', 'acc_bag_day': '🎒', 'acc_scarf': '🧣',
      'acc_glasses': '👓', 'acc_watch': '⌚', 'acc_lantern': '🏮',
      'acc_staff_path': '🪄', 'acc_wings_soft': '🪽',
      'aura_none': '🚫', 'aura_warm': '☀️', 'aura_calm_blue': '💧',
      'aura_forest': '🌲', 'aura_ember': '🔥', 'aura_starfield': '🌌',
      'aura_sovereign': '💫',
      'season_solstice_crown': '❄️', 'season_solstice_cloak': '🌨️',
      'season_equinox_bloom': '🌸', 'season_harvest_lantern': '🎃',
      'season_newyear_spark': '🎆', 'season_always_comet': '☄️',
    };
    return map[id] ?? '✨';
  }

  static String displayEmoji(String? id) {
    return emojiForCosmetic(id);
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
    _resolveAnimations();
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
      _resolveAnimations();
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

  Future<void> _resolveAnimations() async {
    LottieComposition? aura;
    LottieComposition? mood;

    final disableMotion = HardwareTierService.isLowEnd || _reducedMotion;
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

  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final disableMotion = HardwareTierService.isLowEnd || MediaQuery.disableAnimationsOf(context);
    if (disableMotion) {
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
            // Static emoji fallback — bypasses Lottie ticker entirely.
            Center(
              child: Text(
                AvatarVisualLayer.displayEmoji(widget.pet.slot(CosmeticCategory.aura)),
                style: TextStyle(fontSize: widget.size * 0.85),
              ),
            ),
            CustomPaint(
              size: Size.square(widget.size),
              painter: AvatarPainter(widget.pet),
            ),
            _buildCelebrationOverlay(widget.size),
          ],
        ),
      );
    }

    final pet = widget.pet;
    final size = widget.size;

    final lottieAura = _auraComposition;
    final showLottieAura =
        widget.showAura && lottieAura != null && !_reducedMotion;
    // Mood underlay only when it matches the CURRENT state (a resolve may
    // have raced a mood change) and the surface is large enough.
    final moodKey = _moodKey;
    final showMoodLottie = !_reducedMotion &&
        !widget.compact &&
        _resolvedMoodKey == moodKey &&
        _moodComposition != null;

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
          // The painted creature — every equipped slot rendered as vector art.
          CustomPaint(
            size: Size.square(size),
            painter: AvatarPainter(pet),
          ),
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
      color: AppColors.accent,
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