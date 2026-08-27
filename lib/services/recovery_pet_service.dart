// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'feedback_service.dart';
import '../database/recovery_database.dart';
import 'pet_cosmetic_catalog.dart';
import 'step_counter_service.dart';

enum PetMoodX {
  happy('Happy'),
  neutral('Neutral'),
  sad('Sad');
  
  final String label;
  const PetMoodX(this.label);

  String get emoji {
    switch (this) {
      case PetMoodX.happy:
        return '😊';
      case PetMoodX.neutral:
        return '🙂';
      case PetMoodX.sad:
        return '🥺';
    }
  }

  static PetMoodX fromName(String name) {
    return PetMoodX.values.firstWhere(
      (e) => e.name == name, 
      orElse: () => PetMoodX.neutral
    );
  }
}

enum OutfitUnlockStatus {
  notEnoughSparks,
  bondTooLow,
  seasonLocked,
  unknownItem,
  alreadyOwned,
  available
}

class RecoveryPet {
  final String id;
  final String name;
  final int energy;
  final int bond;
  final PetMoodX mood;
  final int sparks;
  final List<String> unlockedItems;
  final String equippedOutfit;
  final Map<String, String> equippedSlots;
  final String speciesId;
  final int lastFedAt;
  final int createdAt;

  RecoveryPet({
    required this.id,
    required this.name,
    required this.energy,
    required this.bond,
    required this.mood,
    required this.sparks,
    required this.unlockedItems,
    required this.equippedOutfit,
    required this.equippedSlots,
    this.speciesId = PetSpeciesCatalog.emberKitId,
    required this.lastFedAt,
    required this.createdAt,
  });

  String? slot(dynamic category) {
    if (category == null) return null;
    final catName = category.toString().split('.').last;
    return equippedSlots[catName];
  }

  /// Low energy means restful, never dead ("I'm here when you are").
  bool get isResting => energy < 25;
}

/// Adoptable companion styles ("single companion vs unlockable species"
/// checklist decision: multi-species, cosmetic-gated like everything else).
class PetSpecies {
  final String id;
  final String label;
  final String tagline;
  final String emoji;

  /// Catalog body form applied when this species is adopted.
  final String bodyItemId;

  /// Aura equipped alongside the body form.
  final String defaultAuraId;
  final int unlockSparks;
  final double unlockBond; // 0..1 fraction

  const PetSpecies({
    required this.id,
    required this.label,
    required this.tagline,
    required this.emoji,
    required this.bodyItemId,
    required this.defaultAuraId,
    required this.unlockSparks,
    required this.unlockBond,
  });
}

class PetSpeciesCatalog {
  static const String emberKitId = 'ember_kit';
  static const List<PetSpecies> all = [
    PetSpecies(
      id: emberKitId,
      label: 'Ember Kit',
      tagline: 'A warm little flame that never burns out.',
      emoji: '🦊',
      bodyItemId: 'body_ember',
      defaultAuraId: 'aura_warm',
      unlockSparks: 0,
      unlockBond: 0,
    ),
    PetSpecies(
      id: 'tide_kin',
      label: 'Tide Kin',
      tagline: 'Soft as the shore, steady as the moon.',
      emoji: '🦦',
      bodyItemId: 'body_tide',
      defaultAuraId: 'aura_calm_blue',
      unlockSparks: 40,
      unlockBond: 0.15,
    ),
    PetSpecies(
      id: 'moss_sprite',
      label: 'Moss Sprite',
      tagline: 'Grows a little every single day.',
      emoji: '🐿️',
      bodyItemId: 'body_moss',
      defaultAuraId: 'aura_forest',
      unlockSparks: 55,
      unlockBond: 0.25,
    ),
    PetSpecies(
      id: 'star_whelp',
      label: 'Star Whelp',
      tagline: 'Carries its own night sky.',
      emoji: '🐺',
      bodyItemId: 'body_starlit',
      defaultAuraId: 'aura_starfield',
      unlockSparks: 90,
      unlockBond: 0.45,
    ),
    PetSpecies(
      id: 'sovereign_linx',
      label: 'Sovereign Lynx',
      tagline: 'Quiet dignity earned over miles.',
      emoji: '🐈‍⬛',
      bodyItemId: 'body_sovereign',
      defaultAuraId: 'aura_sovereign',
      unlockSparks: 150,
      unlockBond: 0.65,
    ),
    PetSpecies(
      id: 'riverglass_otter',
      label: 'Riverglass Otter',
      tagline: 'Plays through every season.',
      emoji: '🦦',
      bodyItemId: 'body_tide',
      defaultAuraId: 'aura_calm_blue',
      unlockSparks: 70,
      unlockBond: 0.35,
    ),
    PetSpecies(
      id: 'prairie_ember_hare',
      label: 'Prairie Ember Hare',
      tagline: 'Quick heart, warm burrow.',
      emoji: '🐰',
      bodyItemId: 'body_ember',
      defaultAuraId: 'aura_warm',
      unlockSparks: 120,
      unlockBond: 0.55,
    ),
    PetSpecies(
      id: 'north_star_loon',
      label: 'North Star Loon',
      tagline: 'Minnesota\'s state bird carries its own compass.',
      emoji: '🦆',
      bodyItemId: 'body_starlit',
      defaultAuraId: 'aura_starfield',
      unlockSparks: 200,
      unlockBond: 0.75,
    ),
  ];

  static PetSpecies byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

class RecoveryPetService {
  static const String _keyPet = 'recovery_pet_v1';
  static const String _keyWalkDay = 'recovery_pet_walk_day_v1';
  static const String _keyEarnDay = 'recovery_pet_earn_day_v1';
  static const String defaultName = 'Kin';
  static const String defaultPetId = 'active_pet';

  static const int sparksCheckIn = 5;
  static const int sparksJournal = 10;
  static const int sparksGround = 8;
  static const int sparksWalk = 15;
  static const int sparksGratitude = 5;
  static const int sparksMeeting = 8;
  static const int sparksWellness = 6;
  static const int sparksGoalComplete = 15;
  static const int sparksWorksheet = 15;
  static const int sparksSignOff = 40;
  static const int sparksStar = 20;
  static const int outfitUnlockCost = 40;
  static const int maxWalksPerDay = 2;

  /// Soft ceiling on earned Sparks per calendar day across ALL actions.
  /// Store-rule #1: the economy cannot be gamed, and nobody should feel
  /// they must grind to keep their companion well.
  /// CAP-EXEMPT streams (product decision, Aug 25): milestones/seeds,
  /// meeting attendance, and walks — showing up and moving your body
  /// should never be tapered. Exercise-style rewards, if ever added,
  /// stay capped (unverifiable → abusable).
  static const int dailyEarnCap = 150;

  /// Compassionate idle decay (pet checklist §2): after [idleGracePeriod]
  /// of quiet days the companion winds down toward rest at
  /// [idleDecayPerDay] Energy per day, floored at [restingFloor] — it
  /// rests, it never starves, and Bond never decays. Any care action
  /// resets the clock (every reward stamps lastFedAt).
  static const Duration idleGracePeriod = Duration(hours: 48);
  static const int idleDecayPerDay = 4;

  /// Floor inside the resting zone (< 25) — reachable, never crossed.
  static const int restingFloor = 20;

  /// Pure idle-decay math: energy [energy] last interacted at
  /// [lastFedAtMs], evaluated at [now]. Unit-testable by design.
  static int decayedEnergy(int energy, int lastFedAtMs, DateTime now) {
    if (energy <= restingFloor) return energy;
    final idleMs = now.millisecondsSinceEpoch - lastFedAtMs;
    if (idleMs <= idleGracePeriod.inMilliseconds) return energy;
    final idleDays =
        (idleMs - idleGracePeriod.inMilliseconds) ~/
            const Duration(hours: 24).inMilliseconds;
    if (idleDays <= 0) return energy;
    return max(energy - idleDays * idleDecayPerDay, restingFloor);
  }

  /// Counter milestone chip rewards by label tier.
  static const Map<String, int> milestoneRewards = {
    '24 Hours': 25,
    '30 Days': 40,
    '60 Days': 55,
    '90 Days': 70,
    '6 Months': 85,
    '1 Year': 100,
    '2 Years': 150,
  };

  // ---- Daily gentle quest (pet-expansion-spec P3.1) ----

  static const String _keyQuest = 'pet_quest_v1';
  static const int sparksQuestBonus = 10;

  /// Invitations only — never assignments. Unfinished quests vanish at
  /// midnight unmentioned; no streaks, no makeups, no guilt copy.
  static const Map<String, String> questCatalog = {
    'journal': 'Write one honest journal reflection',
    'gratitude': 'Note one thing you are grateful for',
    'grounding': 'Take sixty slow grounding breaths',
    'wellness': 'Check in with your wellness wheel',
    'walk': 'Step outside for a short walk',
    'meeting': 'Sit with your recovery circle',
  };

  /// Today's invitation, rolling over at local midnight. Deterministic
  /// day-of-year rotation so both fresh installs and old pets agree.
  static Future<({String id, String title, bool done})> todayQuest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQuest);
    final today = _todayKey();
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (decoded['date'] == today &&
            questCatalog.containsKey(decoded['id'])) {
          return (
            id: decoded['id'] as String,
            title: questCatalog[decoded['id']]!,
            done: decoded['done'] as bool? ?? false,
          );
        }
      } catch (_) {}
    }
    final dayOfYear = DateTime.now().difference(DateTime(
            DateTime.now().year, 1, 1))
        .inDays;
    final ids = questCatalog.keys.toList();
    final id = ids[dayOfYear % ids.length];
    await prefs.setString(
        _keyQuest, jsonEncode({'date': today, 'id': id, 'done': false}));
    return (id: id, title: questCatalog[id]!, done: false);
  }

  /// If [type] matches today's unfinished invitation, mark it done and
  /// return the bonus Sparks (a CAPPED stream — quests are app actions).
  static Future<int> _consumeQuestBonus(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyQuest);
      if (raw == null) return 0;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['done'] == true || decoded['id'] != type) return 0;
      await prefs.setString(
        _keyQuest,
        jsonEncode({
          'date': decoded['date'],
          'id': decoded['id'],
          'done': true,
        }),
      );

      // Bonus respects the same global cap (never exempt).
      var bonus = sparksQuestBonus;
      final earned = await earnedToday();
      if (earned >= dailyEarnCap) {
        bonus = 0;
      } else {
        bonus = bonus.clamp(0, dailyEarnCap - earned);
      }
      await prefs.setString(
        _keyEarnDay,
        '${_todayKey()}:${earned + sparksQuestBonus}',
      );
      return bonus;
    } catch (_) {
      return 0;
    }
  }

  static RecoveryDatabase? _db;

  static const Map<String, String> starterPresets = {
    'pathwalker': 'pathwalker',
    'tidekeeper': 'tidekeeper',
    'embersmith': 'embersmith'
  };

  static void bindDatabase(RecoveryDatabase database) {
    _db = database;
  }

  static RecoveryDatabase? get database => _db;

  static Future<RecoveryPet> ensureHatched({String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPet);
    
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        final unlocked = (decoded['unlockedItems'] as List?)
                ?.map((e) => e.toString()).toList() ??
            <String>['starter_glow'];
        final slots = Map<String, String>.from(decoded['equippedSlots'] ?? {});
        // Backfill free items + default slots for pets saved by older builds.
        unlocked.addAll(
          PetCosmeticCatalog.freeIds.where((id) => !unlocked.contains(id)),
        );
        PetCosmeticCatalog.defaultEquippedSlots.forEach((category, itemId) {
          slots.putIfAbsent(category.name, () => itemId);
        });
        var pet = RecoveryPet(
          id: decoded['id'] ?? defaultPetId,
          name: decoded['name'] ?? defaultName,
          energy: decoded['energy'] ?? 100,
          bond: decoded['bond'] ?? 0,
          mood: PetMoodX.fromName(decoded['mood'] ?? 'neutral'),
          sparks: decoded['sparks'] ?? 0,
          unlockedItems: unlocked,
          equippedOutfit: decoded['equippedOutfit'] ?? 'default',
          equippedSlots: slots,
          speciesId: decoded['speciesId'] is String
              ? decoded['speciesId'] as String
              : PetSpeciesCatalog.emberKitId,
          lastFedAt: decoded['lastFedAt'] ?? DateTime.now().millisecondsSinceEpoch,
          createdAt: decoded['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        );
        // Lazy idle decay on load: quiet days wind the companion toward
        // rest (never past the floor). Persist so all surfaces agree.
        final rested = decayedEnergy(
            pet.energy, pet.lastFedAt, DateTime.now());
        if (rested != pet.energy) {
          pet = RecoveryPet(
            id: pet.id,
            name: pet.name,
            energy: rested,
            bond: pet.bond,
            mood: pet.mood,
            sparks: pet.sparks,
            unlockedItems: pet.unlockedItems,
            equippedOutfit: pet.equippedOutfit,
            equippedSlots: pet.equippedSlots,
            speciesId: pet.speciesId,
            lastFedAt: pet.lastFedAt,
            createdAt: pet.createdAt,
          );
          await _savePet(pet, prefs);
        }
        return pet;
      } catch (_) {}
    }
    
    final newPet = RecoveryPet(
      id: defaultPetId,
      name: name ?? defaultName,
      energy: 100,
      bond: 0,
      mood: PetMoodX.neutral,
      sparks: 0,
      unlockedItems: PetCosmeticCatalog.freeIds,
      equippedOutfit: 'default',
      equippedSlots: PetCosmeticCatalog.defaultEquippedSlots
          .map((category, itemId) => MapEntry(category.name, itemId)),
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _savePet(newPet, prefs);
    return newPet;
  }

  static Future<RecoveryPet> applyStarterPreset(String presetId) async {
    var pet = await ensureHatched();
    final slots = Map<String, String>.from(pet.equippedSlots);
    final presetSlots = PetCosmeticCatalog.starterPresets[presetId];
    if (presetSlots != null) {
      presetSlots.forEach((category, itemId) {
        slots[category.name] = itemId;
      });
    }
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: presetId,
      speciesId: pet.speciesId,
      equippedSlots: slots,
      lastFedAt: pet.lastFedAt,
      createdAt: pet.createdAt,
    );
    await save(updated);
    return updated;
  }

  static Future<void> save(RecoveryPet pet) async {
    final prefs = await SharedPreferences.getInstance();
    await _savePet(pet, prefs);
  }

  // ---- Reward hooks (pet checklist Â§3.1 / Â§8 integration map) ----

  /// Daily mood check-in â†’ Sparks + Mood update.
  static Future<RecoveryPet> logCheckIn({PetMoodX mood = PetMoodX.happy}) {
    return _applyReward(type: 'check_in', sparksDelta: sparksCheckIn, bondDelta: 1, mood: mood);
  }

  /// Journal entry save â†’ Sparks + Energy.
  static Future<RecoveryPet> logJournalEntry() {
    return _applyReward(type: 'journal', sparksDelta: sparksJournal, energyDelta: 5);
  }

  /// Gratitude entry â†’ Sparks.
  static Future<RecoveryPet> logGratitude() {
    return _applyReward(type: 'gratitude', sparksDelta: sparksGratitude, energyDelta: 3, mood: PetMoodX.happy);
  }

  /// Grounding / breath complete → Sparks + Energy.
  static Future<RecoveryPet> logGrounding() {
    return _applyReward(type: 'grounding', sparksDelta: sparksGround, energyDelta: 6);
  }

  /// Honest meeting attendance (paired with a reflection) → Sparks + Bond.
  static Future<RecoveryPet> logMeeting() {
    return _applyReward(type: 'meeting', sparksDelta: sparksMeeting, bondDelta: 2);
  }

  /// Wellness wheel check-in → Sparks + Energy.
  static Future<RecoveryPet> logWellness() {
    return _applyReward(type: 'wellness', sparksDelta: sparksWellness, energyDelta: 4);
  }

  /// Weekly goal fully completed → bigger Sparks + Bond.
  static Future<RecoveryPet> logGoalComplete() {
    return _applyReward(
        type: 'goal_complete', sparksDelta: sparksGoalComplete, bondDelta: 3);
  }

  /// 12-step worksheet completed → Sparks + Energy.
  static Future<RecoveryPet> logWorksheet(int stepNumber) {
    return _applyReward(
        type: 'worksheet_step$stepNumber', sparksDelta: sparksWorksheet, energyDelta: 4);
  }

  /// Tool worksheet (R2 registry) completed → Sparks + Energy.
  static Future<RecoveryPet> logToolWorksheet(String toolId) {
    return _applyReward(
        type: 'worksheet_$toolId', sparksDelta: sparksWorksheet, energyDelta: 4);
  }

  /// Sponsor confirmed a step → big Sparks + big Bond (safety is care).
  static Future<RecoveryPet> logSignOff(int stepNumber) {
    return _applyReward(
        type: 'signoff_step$stepNumber', sparksDelta: sparksSignOff, bondDelta: 5);
  }

  /// Battle victory → Sparks + Bond (R9 pet RPG).
  static Future<RecoveryPet> logBattleWin() {
    final reward = 15 + Random.secure().nextInt(26); // 15–40
    return _applyReward(type: 'battle_win', sparksDelta: reward, bondDelta: 3);
  }

  /// Battle defeat → small Bond gain (learned something, never punitive).
  static Future<RecoveryPet> logBattleLearned() {
    return _applyReward(type: 'battle_learned', bondDelta: 2);
  }

  /// Constellation star added (manual or milestone) → Sparks.
  static Future<RecoveryPet> logStar(String title) {
    return _applyReward(type: 'star', sparksDelta: sparksStar, mood: PetMoodX.happy);
  }

  /// Counter milestone chip earned → tiered Sparks (cap-exempt by design:
  /// milestones bypass the daily cap — they're the whole point).
  static Future<RecoveryPet> logMilestone(String chipLabel) {
    final reward = milestoneRewards[chipLabel] ?? 25;
    return _applyReward(
        type: 'milestone_$chipLabel', sparksDelta: reward, bondDelta: 5);
  }

  /// Sparks earned so far today across all actions (cap accounting).
  static Future<int> earnedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyEarnDay);
    final dayKey = _todayKey();
    if (stored == null || !stored.startsWith(dayKey)) return 0;
    return int.tryParse(stored.split(':').last) ?? 0;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Verified walk → Sparks + Energy + Bond (capped daily).
  /// Requires step counter verification (min 500 steps in 30 min window).
  /// Falls back to manual if pedometer unavailable.
  static Future<RecoveryPet> logWalk({bool requireVerification = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final dayKey = _todayKey();
    final stored = prefs.getString(_keyWalkDay);
    final count = stored == null || !stored.startsWith(dayKey)
        ? 0
        : int.tryParse(stored.split(':').last) ?? 0;
    if (count >= maxWalksPerDay) {
      return ensureHatched();
    }

    // Check step counter verification
    if (requireVerification) {
      final verified = await StepCounterService.instance.stopWalkTracking();
      if (!verified) {
        // Walk not verified - return pet without rewards
        return ensureHatched();
      }
    } else {
      // Manual override (testing, pedometer unavailable)
      await StepCounterService.instance.manuallyVerifyWalk();
    }

    await prefs.setString(_keyWalkDay, '$dayKey:${count + 1}');
    return _applyReward(type: 'walk', sparksDelta: sparksWalk, energyDelta: 4, bondDelta: 1);
  }

  static Future<RecoveryPet> _applyReward({
    String type = 'reward',
    int sparksDelta = 0,
    int energyDelta = 0,
    int bondDelta = 0,
    PetMoodX? mood,
  }) async {
    final pet = await ensureHatched();

    // Store-rule #1: global soft daily cap. Actions still count toward the
    // audit trail and energy/bond — only extra Sparks taper off.
    // CAP-EXEMPT streams (store-rules §1): milestones/seeds, meeting
    // attendance, and walks — a chip earned on a hard day, a room walked
    // into, and steps taken always pay in full and never consume the
    // daily allowance.
    var grantedSparks = sparksDelta;
    final capExempt = type.startsWith('milestone_') ||
        type == 'meeting' ||
        type == 'walk';
    if (grantedSparks > 0 && !capExempt) {
      final earned = await earnedToday();
      if (earned >= dailyEarnCap) {
        grantedSparks = 0;
      } else {
        grantedSparks =
            grantedSparks.clamp(0, dailyEarnCap - earned);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyEarnDay,
        '${_todayKey()}:${earned + sparksDelta}',
      );
    }

    // Gentle quest: completing today's invited action grants a one-time
    // bonus (capped stream — quests are app actions, not exempt).
    final questBonus = await _consumeQuestBonus(type);

    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: (pet.energy + energyDelta).clamp(0, 100),
      bond: (pet.bond + bondDelta).clamp(0, 100),
      mood: mood ?? pet.mood,
      sparks: pet.sparks + grantedSparks + questBonus,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: pet.equippedOutfit,
      speciesId: pet.speciesId,
      equippedSlots: pet.equippedSlots,
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: pet.createdAt,
    );
    await save(updated);
    await _recordEvent(type, grantedSparks + questBonus);
    if (type.startsWith('milestone_')) {
      await FeedbackService.milestone();
    } else if (type.startsWith('signoff_')) {
      await FeedbackService.milestone();
    } else if (type == 'star') {
      await FeedbackService.star();
    } else if (grantedSparks > 0) {
      await FeedbackService.reward();
    }
    return updated;
  }

  /// Best-effort audit trail in Drift; rewards never depend on it.
  static Future<void> _recordEvent(String eventType, int sparksDelta) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.addPetEvent(
        PetEventRow(
          id: 'pet_event_${DateTime.now().millisecondsSinceEpoch}_${(sparksDelta * 31 + eventType.length) % 9973}',
          petId: defaultPetId,
          eventType: eventType,
          sparksDelta: sparksDelta,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }

  static OutfitUnlockStatus unlockStatus(RecoveryPet pet, String itemId) {
    if (pet.unlockedItems.contains(itemId)) {
      return OutfitUnlockStatus.alreadyOwned;
    }
    final item = PetCosmeticCatalog.byId(itemId);
    if (item == null) {
      return OutfitUnlockStatus.unknownItem;
    }
    if (!item.isAvailableAt(DateTime.now())) {
      return OutfitUnlockStatus.seasonLocked;
    }
    // Bond is stored 0..100; catalog gates are 0..1 fractions.
    if (pet.bond / 100.0 < item.requiredBond) {
      return OutfitUnlockStatus.bondTooLow;
    }
    if (!item.free && pet.sparks < item.cost) {
      return OutfitUnlockStatus.notEnoughSparks;
    }
    return OutfitUnlockStatus.available;
  }

  static PetCosmetic? cosmeticById(String itemId) =>
      PetCosmeticCatalog.byId(itemId);

  static Future<RecoveryPet> equipCosmetic(String itemId) async {
    final pet = await ensureHatched();
    final item = PetCosmeticCatalog.byId(itemId);
    final slots = Map<String, String>.from(pet.equippedSlots);
    if (item != null) {
      slots[item.category.name] = itemId;
    } else {
      slots['last_equipped'] = itemId;
    }
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: pet.equippedOutfit,
      speciesId: pet.speciesId,
      equippedSlots: slots,
      lastFedAt: pet.lastFedAt,
      createdAt: pet.createdAt,
    );
    await save(updated);
    return updated;
  }

  static Future<({RecoveryPet pet, bool unlocked, OutfitUnlockStatus status})> tryUnlockCosmetic(String itemId) async {
    final pet = await ensureHatched();
    if (pet.unlockedItems.contains(itemId)) {
      return (pet: pet, unlocked: false, status: OutfitUnlockStatus.alreadyOwned);
    }
    final status = unlockStatus(pet, itemId);
    if (status != OutfitUnlockStatus.available) {
      return (pet: pet, unlocked: false, status: status);
    }
    final item = PetCosmeticCatalog.byId(itemId)!;
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: item.free ? pet.sparks : pet.sparks - item.cost,
      unlockedItems: [...pet.unlockedItems, itemId],
      equippedOutfit: pet.equippedOutfit,
      speciesId: pet.speciesId,
      equippedSlots: {...pet.equippedSlots, item.category.name: itemId},
      lastFedAt: pet.lastFedAt,
      createdAt: pet.createdAt,
    );
    await save(updated);
    return (pet: updated, unlocked: true, status: OutfitUnlockStatus.available);
  }

  static List<String> subcategoriesOf(dynamic category) {
    if (category is CosmeticCategory) {
      return PetCosmeticCatalog.subcategoriesOf(category);
    }
    return [];
  }

  static List<PetCosmetic> listByCategory(dynamic category) {
    if (category is CosmeticCategory) {
      return PetCosmeticCatalog.byCategory(category);
    }
    return [];
  }

  // ---- Species (adoptable companion styles) ----

  /// Already adopted → alreadyOwned; otherwise gates on sparks + bond.
  static OutfitUnlockStatus speciesStatus(RecoveryPet pet, String speciesId) {
    if (pet.speciesId == speciesId) return OutfitUnlockStatus.alreadyOwned;
    final species = PetSpeciesCatalog.all
        .where((s) => s.id == speciesId)
        .firstOrNull;
    if (species == null) return OutfitUnlockStatus.unknownItem;
    if (pet.bond / 100.0 < species.unlockBond) {
      return OutfitUnlockStatus.bondTooLow;
    }
    if (pet.sparks < species.unlockSparks) {
      return OutfitUnlockStatus.notEnoughSparks;
    }
    return OutfitUnlockStatus.available;
  }

  /// Adopts a species: spends Sparks (if any), applies the body form and its
  /// signature aura. Adoption is a change of style, never a reset of progress.
  static Future<RecoveryPet> adoptSpecies(String speciesId) async {
    final pet = await ensureHatched();
    final status = speciesStatus(pet, speciesId);
    if (status != OutfitUnlockStatus.available &&
        status != OutfitUnlockStatus.alreadyOwned) {
      return pet;
    }
    final species = PetSpeciesCatalog.byId(speciesId);
    final cost = pet.speciesId == speciesId ? 0 : species.unlockSparks;
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks - cost,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: pet.equippedOutfit,
      equippedSlots: {
        ...pet.equippedSlots,
        CosmeticCategory.body.name: species.bodyItemId,
        CosmeticCategory.aura.name: species.defaultAuraId,
      },
      speciesId: species.id,
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: pet.createdAt,
    );
    await save(updated);
    await _recordEvent('species_${species.id}', 0);
    return updated;
  }

  static Future<void> _savePet(RecoveryPet pet, SharedPreferences prefs) async {
    final Map<String, dynamic> data = {
      'id': pet.id,
      'name': pet.name,
      'energy': pet.energy,
      'bond': pet.bond,
      'mood': pet.mood.name,
      'sparks': pet.sparks,
      'unlockedItems': pet.unlockedItems,
      'equippedOutfit': pet.equippedOutfit,
      'equippedSlots': pet.equippedSlots,
      'speciesId': pet.speciesId,
      'lastFedAt': pet.lastFedAt,
      'createdAt': pet.createdAt,
    };
    await prefs.setString(_keyPet, jsonEncode(data));
  }
}