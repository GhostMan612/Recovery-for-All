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

import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';

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
  static const Map<String, String> _auraLottie = {
    'aura_warm': 'assets/lottie/aura_warm.json',
    'aura_calm_blue': 'assets/lottie/aura_calm_blue.json',
    'aura_starfield': 'assets/lottie/aura_starfield.json',
    'aura_ember': 'assets/lottie/aura_ember.json',
  };

  /// PetMoodX name / resting -> mood-face underlay loop.
  static const Map<String, String> _moodLottie = {
    'happy': 'assets/lottie/mood_happy.json',
    'neutral': 'assets/lottie/mood_calm.json',
    'sad': 'assets/lottie/mood_sad.json',
    '@resting': 'assets/lottie/mood_resting.json',
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
    if (id == null) return 'âœ¨';
    final map = <String, String>{
      'body_soft_glow': 'ðŸŒŸ',
      'body_ember': 'ðŸ”¥',
      'body_tide': 'ðŸŒŠ',
      'body_moss': 'ðŸŒ¿',
      'body_starlit': 'âœ¨',
      'body_sovereign': 'ðŸ‘‘',
      'skin_pearl': 'ðŸ¤',
      'skin_amber': 'ðŸ§¡',
      'skin_slate': 'ðŸ©¶',
      'skin_rose': 'ðŸ’—',
      'skin_jade': 'ðŸ’š',
      'skin_obsidian': 'ðŸ–¤',
      'skin_aurora': 'ðŸŒˆ',
      'face_calm': 'ðŸ˜Œ',
      'face_bright': 'ðŸ˜Š',
      'face_soft': 'ðŸ™‚',
      'face_fierce': 'ðŸ˜¤',
      'face_dream': 'ðŸ˜´',
      'hair_short_wave': 'ðŸ’‡',
      'hair_crop': 'âœ‚ï¸',
      'hair_long_flow': 'ðŸ’‡â€â™€ï¸',
      'hair_bun': 'ðŸŽ€',
      'hair_braids': 'ðŸª¢',
      'hair_flame': 'ðŸ”¥',
      'top_tee_plain': 'ðŸ‘•',
      'top_hoodie_soft': 'ðŸ§¥',
      'top_tank': 'ðŸŽ½',
      'top_flannel': 'ðŸ§¥',
      'top_jacket_dawn': 'ðŸ§¥',
      'top_cloak_forest': 'ðŸ§™',
      'top_robe_river': 'ðŸ‘˜',
      'top_armor_light': 'ðŸ›¡ï¸',
      'top_sovereign_mantle': 'ðŸ‘‘',
      'bottom_shorts': 'ðŸ©³',
      'bottom_joggers': 'ðŸ‘–',
      'bottom_jeans': 'ðŸ‘–',
      'bottom_skirt_flow': 'ðŸ‘—',
      'shoes_sneakers': 'ðŸ‘Ÿ',
      'shoes_sandals': 'ðŸ©´',
      'shoes_boots_trail': 'ðŸ¥¾',
      'shoes_kicks_neon': 'âš¡',
      'shoes_sovereign': 'âœ¨',
      'head_beanie': 'ðŸ§¢',
      'head_cap': 'ðŸ§¢',
      'head_crown_leaf': 'ðŸƒ',
      'head_crown_star': 'â­',
      'head_halo_soft': 'ðŸ˜‡',
      'jewelry_pendant_seed': 'ðŸŒ±',
      'jewelry_pendant_wave': 'ðŸŒŠ',
      'jewelry_crest_sovereign': 'âšœï¸',
      'acc_bag_day': 'ðŸŽ’',
      'acc_scarf': 'ðŸ§£',
      'acc_lantern': 'ðŸ®',
      'acc_staff_path': 'ðŸª„',
      'acc_wings_soft': 'ðŸª½',
      'aura_warm': 'â˜€ï¸',
      'aura_calm_blue': 'ðŸ’§',
      'aura_forest': 'ðŸŒ²',
      'aura_ember': 'ðŸ”¥',
      'aura_starfield': 'ðŸŒŒ',
      'aura_sovereign': 'ðŸ’«',
      'season_solstice_crown': 'â„ï¸',
      'season_solstice_cloak': 'ðŸŒ¨ï¸',
      'season_equinox_bloom': 'ðŸŒ¸',
      'season_harvest_lantern': 'ðŸŽƒ',
      'season_newyear_spark': 'ðŸŽ†',
      'season_always_comet': 'â˜„ï¸',
    };
    return map[id] ?? 'âœ¨';
  }

  static String displayEmoji(String? id) {
    return emojiForCosmetic(id);
  }

  @override
  State<AvatarVisualLayer> createState() => _AvatarVisualLayerState();
}

class _AvatarVisualLayerState extends State<AvatarVisualLayer> {
  LottieComposition? _auraComposition;
  LottieComposition? _moodComposition;
  String _resolvedMoodKey = '';

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
  void didUpdateWidget(covariant AvatarVisualLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.slot(CosmeticCategory.aura) != _equippedAuraId ||
        oldWidget.showAura != widget.showAura ||
        oldWidget.pet.isResting != widget.pet.isResting ||
        oldWidget.pet.mood != widget.pet.mood) {
      _resolveAnimations();
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveAnimations();
  }

  Future<void> _resolveAnimations() async {
    LottieComposition? aura;
    LottieComposition? mood;

    if (!_reducedMotion) {
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
    final pet = widget.pet;
    final size = widget.size;
    final face = AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.face));
    final hair = AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.hair));
    final top = AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.top));
    final head = AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.headwear));
    final jewelry =
        AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.jewelry));
    final shoes = AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.shoes));
    final acc =
        AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.accessory));
    final bodyItem =
        AvatarVisualLayer.displayEmoji(pet.slot(CosmeticCategory.body));

    // Species creature is the base; body-form emoji stays as a small badge so
    // the chosen style still reads at a glance.
    final species = PetSpeciesCatalog.byId(pet.speciesId);
    final core = size * (widget.compact ? 0.55 : 0.7);

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
                : Text(
                    AvatarVisualLayer.displayEmoji(_equippedAuraId),
                    style: TextStyle(fontSize: size * 0.85),
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
          Text(species.emoji, style: TextStyle(fontSize: core)),
          Positioned(
            right: size * 0.04,
            bottom: size * 0.30,
            child: Text(bodyItem,
                style: TextStyle(fontSize: size * 0.14, shadows: [
                  Shadow(
                      blurRadius: 6,
                      color: Colors.black.withValues(alpha: 0.35)),
                ])),
          ),
          Positioned(
            top: size * 0.12,
            child: Text(hair, style: TextStyle(fontSize: size * 0.22)),
          ),
          Positioned(
            top: size * 0.08,
            child: Text(head, style: TextStyle(fontSize: size * 0.18)),
          ),
          Text(face, style: TextStyle(fontSize: size * 0.28)),
          Positioned(
            bottom: size * 0.28,
            child: Text(top, style: TextStyle(fontSize: size * 0.26)),
          ),
          Positioned(
            bottom: size * 0.12,
            child: Text(shoes, style: TextStyle(fontSize: size * 0.16)),
          ),
          Positioned(
            right: size * 0.08,
            top: size * 0.38,
            child: Text(jewelry, style: TextStyle(fontSize: size * 0.14)),
          ),
          Positioned(
            left: size * 0.06,
            bottom: size * 0.22,
            child: Text(acc, style: TextStyle(fontSize: size * 0.16)),
          ),
        ],
      ),
    );
  }
}
