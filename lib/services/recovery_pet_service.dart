// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/recovery_database.dart';

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

class RecoveryPetService {
  static const String _keyPet = 'recovery_pet_v1';
  static const String _keyWalkDay = 'recovery_pet_walk_day_v1';
  static const String defaultName = 'Kin';
  static const String defaultPetId = 'active_pet';

  static const int sparksCheckIn = 5;
  static const int sparksJournal = 10;
  static const int sparksGround = 8;
  static const int sparksWalk = 15;
  static const int outfitUnlockCost = 40;
  static const int maxWalksPerDay = 2;

  static RecoveryDatabase? _db;

  static const Map<String, dynamic> starterPresets = {
    'default': 'default',
    'nature': 'nature',
    'urban': 'urban'
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
        return RecoveryPet(
          id: decoded['id'] ?? defaultPetId,
          name: decoded['name'] ?? defaultName,
          energy: decoded['energy'] ?? 100,
          bond: decoded['bond'] ?? 0,
          mood: PetMoodX.fromName(decoded['mood'] ?? 'neutral'),
          sparks: decoded['sparks'] ?? 0,
          unlockedItems: (decoded['unlockedItems'] as List?)?.map((e) => e.toString()).toList() ?? ['starter_glow'],
          equippedOutfit: decoded['equippedOutfit'] ?? 'default',
          equippedSlots: Map<String, String>.from(decoded['equippedSlots'] ?? {}),
          lastFedAt: decoded['lastFedAt'] ?? DateTime.now().millisecondsSinceEpoch,
          createdAt: decoded['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {}
    }
    
    final newPet = RecoveryPet(
      id: defaultPetId,
      name: name ?? defaultName,
      energy: 100,
      bond: 0,
      mood: PetMoodX.neutral,
      sparks: 0,
      unlockedItems: ['starter_glow'],
      equippedOutfit: 'default',
      equippedSlots: {},
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _savePet(newPet, prefs);
    return newPet;
  }

  static Future<RecoveryPet> applyStarterPreset(String presetId) async {
    var pet = await ensureHatched();
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: presetId,
      equippedSlots: pet.equippedSlots,
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

  // ---- Reward hooks (pet checklist §3.1 / §8 integration map) ----

  /// Daily mood check-in → Sparks + Mood update.
  static Future<RecoveryPet> logCheckIn({PetMoodX mood = PetMoodX.happy}) {
    return _applyReward(sparksDelta: sparksCheckIn, bondDelta: 1, mood: mood);
  }

  /// Journal entry save → Sparks + Energy.
  static Future<RecoveryPet> logJournalEntry() {
    return _applyReward(sparksDelta: sparksJournal, energyDelta: 5);
  }

  /// Grounding / breath complete → Sparks + Energy.
  static Future<RecoveryPet> logGrounding() {
    return _applyReward(sparksDelta: sparksGround, energyDelta: 6);
  }

  /// Manual "I took a walk" → Sparks + Energy + Bond (capped daily).
  static Future<RecoveryPet> logWalk() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final stored = prefs.getString(_keyWalkDay);
    final count = stored == null || !stored.startsWith(dayKey)
        ? 0
        : int.tryParse(stored.split(':').last) ?? 0;
    if (count >= maxWalksPerDay) {
      return ensureHatched();
    }
    await prefs.setString(_keyWalkDay, '$dayKey:${count + 1}');
    return _applyReward(sparksDelta: sparksWalk, energyDelta: 4, bondDelta: 1);
  }

  static Future<RecoveryPet> _applyReward({
    int sparksDelta = 0,
    int energyDelta = 0,
    int bondDelta = 0,
    PetMoodX? mood,
  }) async {
    final pet = await ensureHatched();
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: (pet.energy + energyDelta).clamp(0, 100),
      bond: (pet.bond + bondDelta).clamp(0, 100),
      mood: mood ?? pet.mood,
      sparks: pet.sparks + sparksDelta,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: pet.equippedOutfit,
      equippedSlots: pet.equippedSlots,
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: pet.createdAt,
    );
    await save(updated);
    return updated;
  }

  static OutfitUnlockStatus unlockStatus(RecoveryPet pet, String itemId) {
    if (pet.unlockedItems.contains(itemId)) {
      return OutfitUnlockStatus.alreadyOwned;
    }
    return OutfitUnlockStatus.available;
  }

  static Future<RecoveryPet> equipCosmetic(String itemId) async {
    final pet = await ensureHatched();
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks,
      unlockedItems: pet.unlockedItems,
      equippedOutfit: pet.equippedOutfit,
      equippedSlots: {...pet.equippedSlots, 'last_equipped': itemId},
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
    final updated = RecoveryPet(
      id: pet.id,
      name: pet.name,
      energy: pet.energy,
      bond: pet.bond,
      mood: pet.mood,
      sparks: pet.sparks,
      unlockedItems: [...pet.unlockedItems, itemId],
      equippedOutfit: pet.equippedOutfit,
      equippedSlots: pet.equippedSlots,
      lastFedAt: pet.lastFedAt,
      createdAt: pet.createdAt,
    );
    await save(updated);
    return (pet: updated, unlocked: true, status: OutfitUnlockStatus.available);
  }

  static List<String> subcategoriesOf(dynamic category) {
    return [];
  }

  static List<dynamic> listByCategory(dynamic category) {
    return [];
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
      'lastFedAt': pet.lastFedAt,
      'createdAt': pet.createdAt,
    };
    await prefs.setString(_keyPet, jsonEncode(data));
  }
}