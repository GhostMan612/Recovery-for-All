// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/pet_cosmetic_catalog.dart

enum CosmeticCategory {
  body,
  skin,
  face,
  hair,
  top,
  bottom,
  shoes,
  headwear,
  jewelry,
  accessory,
  aura,
}

extension CosmeticCategoryX on CosmeticCategory {
  String get label {
    switch (this) {
      case CosmeticCategory.body:
        return 'Body';
      case CosmeticCategory.skin:
        return 'Skin';
      case CosmeticCategory.face:
        return 'Face';
      case CosmeticCategory.hair:
        return 'Hair';
      case CosmeticCategory.top:
        return 'Tops';
      case CosmeticCategory.bottom:
        return 'Bottoms';
      case CosmeticCategory.shoes:
        return 'Shoes';
      case CosmeticCategory.headwear:
        return 'Headwear';
      case CosmeticCategory.jewelry:
        return 'Jewelry';
      case CosmeticCategory.accessory:
        return 'Accessories';
      case CosmeticCategory.aura:
        return 'Aura';
    }
  }
}

class PetCosmetic {
  final String id;
  final String label;
  final CosmeticCategory category;
  final String subcategory;
  final int cost;
  final double requiredBond;
  final bool free;
  final String? seasonId;
  final int? availableFromMs;
  final int? availableUntilMs;
  final String? emoji;

  const PetCosmetic({
    required this.id,
    required this.label,
    required this.category,
    required this.subcategory,
    required this.cost,
    required this.requiredBond,
    this.free = false,
    this.seasonId,
    this.availableFromMs,
    this.availableUntilMs,
    this.emoji,
  });

  bool get isSeasonal => seasonId != null;

  bool isAvailableAt(DateTime now) {
    if (!isSeasonal) return true;
    final ms = now.millisecondsSinceEpoch;
    if (availableFromMs != null && ms < availableFromMs!) return false;
    if (availableUntilMs != null && ms > availableUntilMs!) return false;
    return true;
  }
}

typedef PetOutfit = PetCosmetic;

class PetCosmeticCatalog {
  static const List<PetCosmetic> all = [
    PetCosmetic(id: 'body_soft_glow', label: 'Soft Glow', category: CosmeticCategory.body, subcategory: 'form', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'body_ember', label: 'Ember Form', category: CosmeticCategory.body, subcategory: 'form', cost: 50, requiredBond: 0.2),
    PetCosmetic(id: 'body_tide', label: 'Tide Form', category: CosmeticCategory.body, subcategory: 'form', cost: 50, requiredBond: 0.2),
    PetCosmetic(id: 'body_moss', label: 'Moss Form', category: CosmeticCategory.body, subcategory: 'form', cost: 50, requiredBond: 0.25),
    PetCosmetic(id: 'body_starlit', label: 'Starlit Form', category: CosmeticCategory.body, subcategory: 'form', cost: 120, requiredBond: 0.55),
    PetCosmetic(id: 'body_sovereign', label: 'Sovereign Form', category: CosmeticCategory.body, subcategory: 'form', cost: 200, requiredBond: 0.85),
    PetCosmetic(id: 'skin_pearl', label: 'Pearl', category: CosmeticCategory.skin, subcategory: 'tone', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'skin_amber', label: 'Amber', category: CosmeticCategory.skin, subcategory: 'tone', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'skin_slate', label: 'Slate', category: CosmeticCategory.skin, subcategory: 'tone', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'skin_rose', label: 'Rose', category: CosmeticCategory.skin, subcategory: 'tone', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'skin_jade', label: 'Jade', category: CosmeticCategory.skin, subcategory: 'tone', cost: 25, requiredBond: 0.1),
    PetCosmetic(id: 'skin_obsidian', label: 'Obsidian', category: CosmeticCategory.skin, subcategory: 'tone', cost: 40, requiredBond: 0.2),
    PetCosmetic(id: 'skin_aurora', label: 'Aurora', category: CosmeticCategory.skin, subcategory: 'tone', cost: 90, requiredBond: 0.5),
    PetCosmetic(id: 'face_calm', label: 'Calm Eyes', category: CosmeticCategory.face, subcategory: 'eyes', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'face_bright', label: 'Bright Eyes', category: CosmeticCategory.face, subcategory: 'eyes', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'face_soft', label: 'Soft Gaze', category: CosmeticCategory.face, subcategory: 'eyes', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'face_fierce', label: 'Fierce Eyes', category: CosmeticCategory.face, subcategory: 'eyes', cost: 30, requiredBond: 0.15),
    PetCosmetic(id: 'face_dream', label: 'Dream Eyes', category: CosmeticCategory.face, subcategory: 'eyes', cost: 45, requiredBond: 0.25),
    PetCosmetic(id: 'face_mark_dot', label: 'Dot Mark', category: CosmeticCategory.face, subcategory: 'marking', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'face_mark_stripe', label: 'Stripe Mark', category: CosmeticCategory.face, subcategory: 'marking', cost: 20, requiredBond: 0.1),
    PetCosmetic(id: 'face_mark_sigil', label: 'Sigil Mark', category: CosmeticCategory.face, subcategory: 'marking', cost: 70, requiredBond: 0.4),
    PetCosmetic(id: 'hair_short_wave', label: 'Short Wave', category: CosmeticCategory.hair, subcategory: 'style', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_crop', label: 'Crop', category: CosmeticCategory.hair, subcategory: 'style', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_long_flow', label: 'Long Flow', category: CosmeticCategory.hair, subcategory: 'style', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_bun', label: 'Soft Bun', category: CosmeticCategory.hair, subcategory: 'style', cost: 15, requiredBond: 0.05),
    PetCosmetic(id: 'hair_braids', label: 'Braids', category: CosmeticCategory.hair, subcategory: 'style', cost: 35, requiredBond: 0.15),
    PetCosmetic(id: 'hair_flame', label: 'Flame Crown', category: CosmeticCategory.hair, subcategory: 'style', cost: 80, requiredBond: 0.45),
    PetCosmetic(id: 'hair_color_ink', label: 'Ink', category: CosmeticCategory.hair, subcategory: 'color', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_color_sun', label: 'Sun', category: CosmeticCategory.hair, subcategory: 'color', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_color_sea', label: 'Sea', category: CosmeticCategory.hair, subcategory: 'color', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'hair_color_violet', label: 'Violet', category: CosmeticCategory.hair, subcategory: 'color', cost: 25, requiredBond: 0.1),
    PetCosmetic(id: 'hair_color_silver', label: 'Silver', category: CosmeticCategory.hair, subcategory: 'color', cost: 40, requiredBond: 0.2),
    PetCosmetic(id: 'top_tee_plain', label: 'Plain Tee', category: CosmeticCategory.top, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'top_hoodie_soft', label: 'Soft Hoodie', category: CosmeticCategory.top, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'top_tank', label: 'Tank', category: CosmeticCategory.top, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'top_flannel', label: 'Flannel', category: CosmeticCategory.top, subcategory: 'casual', cost: 20, requiredBond: 0.05),
    PetCosmetic(id: 'top_jacket_dawn', label: 'Dawn Jacket', category: CosmeticCategory.top, subcategory: 'outer', cost: 45, requiredBond: 0.2),
    PetCosmetic(id: 'top_cloak_forest', label: 'Forest Cloak', category: CosmeticCategory.top, subcategory: 'outer', cost: 60, requiredBond: 0.3),
    PetCosmetic(id: 'top_robe_river', label: 'River Robe', category: CosmeticCategory.top, subcategory: 'ceremonial', cost: 80, requiredBond: 0.45),
    PetCosmetic(id: 'top_armor_light', label: 'Light Armor', category: CosmeticCategory.top, subcategory: 'ceremonial', cost: 110, requiredBond: 0.6),
    PetCosmetic(id: 'top_sovereign_mantle', label: 'Sovereign Mantle', category: CosmeticCategory.top, subcategory: 'ceremonial', cost: 150, requiredBond: 0.8),
    PetCosmetic(id: 'bottom_shorts', label: 'Shorts', category: CosmeticCategory.bottom, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'bottom_joggers', label: 'Joggers', category: CosmeticCategory.bottom, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'bottom_jeans', label: 'Jeans', category: CosmeticCategory.bottom, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'bottom_skirt_flow', label: 'Flow Skirt', category: CosmeticCategory.bottom, subcategory: 'casual', cost: 15, requiredBond: 0.05),
    PetCosmetic(id: 'bottom_cargo', label: 'Cargo', category: CosmeticCategory.bottom, subcategory: 'utility', cost: 25, requiredBond: 0.1),
    PetCosmetic(id: 'bottom_wrap_moss', label: 'Moss Wrap', category: CosmeticCategory.bottom, subcategory: 'ceremonial', cost: 55, requiredBond: 0.3),
    PetCosmetic(id: 'bottom_greaves', label: 'Light Greaves', category: CosmeticCategory.bottom, subcategory: 'ceremonial', cost: 90, requiredBond: 0.5),
    PetCosmetic(id: 'shoes_bare', label: 'Bare', category: CosmeticCategory.shoes, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'shoes_sneakers', label: 'Sneakers', category: CosmeticCategory.shoes, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'shoes_sandals', label: 'Sandals', category: CosmeticCategory.shoes, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'shoes_boots_trail', label: 'Trail Boots', category: CosmeticCategory.shoes, subcategory: 'trail', cost: 30, requiredBond: 0.15),
    PetCosmetic(id: 'shoes_boots_storm', label: 'Storm Boots', category: CosmeticCategory.shoes, subcategory: 'trail', cost: 55, requiredBond: 0.3),
    PetCosmetic(id: 'shoes_slippers_home', label: 'Home Slippers', category: CosmeticCategory.shoes, subcategory: 'comfort', cost: 10, requiredBond: 0.0, free: true),
    PetCosmetic(id: 'shoes_kicks_neon', label: 'Neon Kicks', category: CosmeticCategory.shoes, subcategory: 'style', cost: 70, requiredBond: 0.4),
    PetCosmetic(id: 'shoes_sovereign', label: 'Sovereign Steps', category: CosmeticCategory.shoes, subcategory: 'style', cost: 120, requiredBond: 0.7),
    PetCosmetic(id: 'head_none', label: 'None', category: CosmeticCategory.headwear, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'head_beanie', label: 'Beanie', category: CosmeticCategory.headwear, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'head_cap', label: 'Cap', category: CosmeticCategory.headwear, subcategory: 'casual', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'head_bandana', label: 'Bandana', category: CosmeticCategory.headwear, subcategory: 'casual', cost: 15, requiredBond: 0.05),
    PetCosmetic(id: 'head_hood', label: 'Travel Hood', category: CosmeticCategory.headwear, subcategory: 'trail', cost: 35, requiredBond: 0.2),
    PetCosmetic(id: 'head_crown_leaf', label: 'Leaf Crown', category: CosmeticCategory.headwear, subcategory: 'ceremonial', cost: 60, requiredBond: 0.35),
    PetCosmetic(id: 'head_crown_star', label: 'Star Crown', category: CosmeticCategory.headwear, subcategory: 'ceremonial', cost: 100, requiredBond: 0.55),
    PetCosmetic(id: 'head_halo_soft', label: 'Soft Halo', category: CosmeticCategory.headwear, subcategory: 'ceremonial', cost: 140, requiredBond: 0.75),
    PetCosmetic(id: 'jewelry_none', label: 'None', category: CosmeticCategory.jewelry, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'jewelry_band_simple', label: 'Simple Band', category: CosmeticCategory.jewelry, subcategory: 'hands', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'jewelry_pendant_seed', label: 'Seed Pendant', category: CosmeticCategory.jewelry, subcategory: 'neck', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'jewelry_pendant_wave', label: 'Wave Pendant', category: CosmeticCategory.jewelry, subcategory: 'neck', cost: 25, requiredBond: 0.1),
    PetCosmetic(id: 'jewelry_earring_dot', label: 'Dot Earring', category: CosmeticCategory.jewelry, subcategory: 'ears', cost: 15, requiredBond: 0.05),
    PetCosmetic(id: 'jewelry_earring_moon', label: 'Moon Earring', category: CosmeticCategory.jewelry, subcategory: 'ears', cost: 40, requiredBond: 0.2),
    PetCosmetic(id: 'jewelry_ring_bond', label: 'Bond Ring', category: CosmeticCategory.jewelry, subcategory: 'hands', cost: 50, requiredBond: 0.3),
    PetCosmetic(id: 'jewelry_chain_star', label: 'Star Chain', category: CosmeticCategory.jewelry, subcategory: 'neck', cost: 75, requiredBond: 0.45),
    PetCosmetic(id: 'jewelry_crest_sovereign', label: 'Sovereign Crest', category: CosmeticCategory.jewelry, subcategory: 'neck', cost: 130, requiredBond: 0.7),
    PetCosmetic(id: 'acc_none', label: 'None', category: CosmeticCategory.accessory, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'acc_bag_day', label: 'Day Bag', category: CosmeticCategory.accessory, subcategory: 'carry', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'acc_scarf', label: 'Scarf', category: CosmeticCategory.accessory, subcategory: 'wear', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'acc_glasses', label: 'Glasses', category: CosmeticCategory.accessory, subcategory: 'face', cost: 20, requiredBond: 0.05),
    PetCosmetic(id: 'acc_watch', label: 'Watch', category: CosmeticCategory.accessory, subcategory: 'hands', cost: 30, requiredBond: 0.1),
    PetCosmetic(id: 'acc_lantern', label: 'Night Lantern', category: CosmeticCategory.accessory, subcategory: 'carry', cost: 55, requiredBond: 0.3),
    PetCosmetic(id: 'acc_staff_path', label: 'Path Staff', category: CosmeticCategory.accessory, subcategory: 'carry', cost: 85, requiredBond: 0.5),
    PetCosmetic(id: 'acc_wings_soft', label: 'Soft Wings', category: CosmeticCategory.accessory, subcategory: 'aura', cost: 150, requiredBond: 0.75),
    PetCosmetic(id: 'aura_none', label: 'None', category: CosmeticCategory.aura, subcategory: 'basic', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'aura_warm', label: 'Warm Light', category: CosmeticCategory.aura, subcategory: 'glow', cost: 0, requiredBond: 0, free: true),
    PetCosmetic(id: 'aura_calm_blue', label: 'Calm Blue', category: CosmeticCategory.aura, subcategory: 'glow', cost: 30, requiredBond: 0.15),
    PetCosmetic(id: 'aura_forest', label: 'Forest Mist', category: CosmeticCategory.aura, subcategory: 'glow', cost: 50, requiredBond: 0.3),
    PetCosmetic(id: 'aura_ember', label: 'Ember Ring', category: CosmeticCategory.aura, subcategory: 'glow', cost: 70, requiredBond: 0.4),
    PetCosmetic(id: 'aura_starfield', label: 'Starfield', category: CosmeticCategory.aura, subcategory: 'glow', cost: 110, requiredBond: 0.6),
    PetCosmetic(id: 'aura_sovereign', label: 'Sovereign Radiance', category: CosmeticCategory.aura, subcategory: 'glow', cost: 180, requiredBond: 0.85),
    PetCosmetic(id: 'season_solstice_crown', label: 'Solstice Crown', category: CosmeticCategory.headwear, subcategory: 'seasonal', cost: 40, requiredBond: 0.1, seasonId: 'winter_solstice', availableFromMs: 1734307200000, availableUntilMs: 1735689600000, emoji: '❄️'),
    PetCosmetic(id: 'season_solstice_cloak', label: 'Solstice Cloak', category: CosmeticCategory.top, subcategory: 'seasonal', cost: 55, requiredBond: 0.15, seasonId: 'winter_solstice', availableFromMs: 1734307200000, availableUntilMs: 1735689600000, emoji: '🌨️'),
    PetCosmetic(id: 'season_equinox_bloom', label: 'Equinox Bloom', category: CosmeticCategory.accessory, subcategory: 'seasonal', cost: 35, requiredBond: 0.1, seasonId: 'spring_equinox', availableFromMs: 1741737600000, availableUntilMs: 1743465600000, emoji: '🌸'),
    PetCosmetic(id: 'season_harvest_lantern', label: 'Harvest Lantern', category: CosmeticCategory.accessory, subcategory: 'seasonal', cost: 45, requiredBond: 0.15, seasonId: 'autumn_harvest', availableFromMs: 1759276800000, availableUntilMs: 1761955200000, emoji: '🎃'),
    PetCosmetic(id: 'season_newyear_spark', label: 'New Year Spark', category: CosmeticCategory.aura, subcategory: 'seasonal', cost: 60, requiredBond: 0.2, seasonId: 'new_year', availableFromMs: 1735689600000, availableUntilMs: 1737331200000, emoji: '🎆'),
    PetCosmetic(id: 'season_always_comet', label: 'Comet Trail', category: CosmeticCategory.aura, subcategory: 'seasonal', cost: 0, requiredBond: 0, free: true, seasonId: 'launch', emoji: '☄️'),
  ];

  static List<String> get freeIds =>
      all.where((c) => c.free || c.cost == 0).map((c) => c.id).toList();

  static Map<CosmeticCategory, String> get defaultEquippedSlots => {
        CosmeticCategory.body: 'body_soft_glow',
        CosmeticCategory.skin: 'skin_pearl',
        CosmeticCategory.face: 'face_calm',
        CosmeticCategory.hair: 'hair_short_wave',
        CosmeticCategory.top: 'top_tee_plain',
        CosmeticCategory.bottom: 'bottom_joggers',
        CosmeticCategory.shoes: 'shoes_sneakers',
        CosmeticCategory.headwear: 'head_none',
        CosmeticCategory.jewelry: 'jewelry_pendant_seed',
        CosmeticCategory.accessory: 'acc_none',
        CosmeticCategory.aura: 'aura_warm',
      };

  static const Map<String, Map<CosmeticCategory, String>> starterPresets = {
    'pathwalker': {
      CosmeticCategory.body: 'body_soft_glow',
      CosmeticCategory.skin: 'skin_amber',
      CosmeticCategory.face: 'face_bright',
      CosmeticCategory.hair: 'hair_crop',
      CosmeticCategory.top: 'top_hoodie_soft',
      CosmeticCategory.bottom: 'bottom_joggers',
      CosmeticCategory.shoes: 'shoes_sneakers',
      CosmeticCategory.headwear: 'head_cap',
      CosmeticCategory.jewelry: 'jewelry_band_simple',
      CosmeticCategory.accessory: 'acc_bag_day',
      CosmeticCategory.aura: 'aura_warm',
    },
    'tidekeeper': {
      CosmeticCategory.body: 'body_soft_glow',
      CosmeticCategory.skin: 'skin_pearl',
      CosmeticCategory.face: 'face_soft',
      CosmeticCategory.hair: 'hair_long_flow',
      CosmeticCategory.top: 'top_tee_plain',
      CosmeticCategory.bottom: 'bottom_shorts',
      CosmeticCategory.shoes: 'shoes_sandals',
      CosmeticCategory.headwear: 'head_none',
      CosmeticCategory.jewelry: 'jewelry_pendant_seed',
      CosmeticCategory.accessory: 'acc_scarf',
      CosmeticCategory.aura: 'aura_warm',
    },
    'embersmith': {
      CosmeticCategory.body: 'body_soft_glow',
      CosmeticCategory.skin: 'skin_slate',
      CosmeticCategory.face: 'face_calm',
      CosmeticCategory.hair: 'hair_short_wave',
      CosmeticCategory.top: 'top_tank',
      CosmeticCategory.bottom: 'bottom_jeans',
      CosmeticCategory.shoes: 'shoes_sneakers',
      CosmeticCategory.headwear: 'head_beanie',
      CosmeticCategory.jewelry: 'jewelry_none',
      CosmeticCategory.accessory: 'acc_none',
      CosmeticCategory.aura: 'aura_warm',
    },
  };

  static const Map<String, String> presetEmojis = {
    'pathwalker': '🥾',
    'tidekeeper': '🌊',
    'embersmith': '🔥',
  };

  static const Map<String, String> presetReactions = {
    'pathwalker': 'Ready for the long road.',
    'tidekeeper': 'Soft as the shore.',
    'embersmith': 'Warm and steady.',
  };

  static PetCosmetic? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<PetCosmetic> availableNow([DateTime? now]) {
    final n = now ?? DateTime.now();
    return all.where((c) => c.isAvailableAt(n)).toList();
  }

  static List<PetCosmetic> byCategory(CosmeticCategory category, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return all.where((c) => c.category == category && c.isAvailableAt(n)).toList();
  }

  static List<PetCosmetic> bySubcategory(
    CosmeticCategory category,
    String subcategory, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return all
        .where((c) =>
            c.category == category &&
            c.subcategory == subcategory &&
            c.isAvailableAt(n))
        .toList();
  }

  static List<String> subcategoriesOf(CosmeticCategory category) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in all) {
      if (c.category != category) continue;
      if (seen.add(c.subcategory)) out.add(c.subcategory);
    }
    return out;
  }
}
