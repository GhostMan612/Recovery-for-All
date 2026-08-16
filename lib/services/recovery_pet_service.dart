// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Path Companion (Recovery Pet) — local-first MVP.
/// Thrives with care; never "dies". Low energy → resting.
class RecoveryPetService {
  static const String _keyPet = 'recovery_pet_v1';
  static const String defaultName = 'Kin';

  static const int sparksCheckIn = 5;
  static const int sparksJournal = 10;
  static const int sparksGround = 8;
  static const int sparksWalk = 15;
  static const int outfitUnlockCost = 40;

  /// Ensure a pet exists (hatch on first launch / onboarding).
  static Future<RecoveryPet> ensureHatched({String? name}) async {
    final existing = await load();
    if (existing != null) return existing;

    final pet = RecoveryPet(
      name: name?.trim().isNotEmpty == true ? name!.trim() : defaultName,
      energy: 0.7,
      bond: 0.2,
      mood: PetMood.hopeful,
      sparks: 10,
      unlockedItems: ['starter_glow'],
      equippedOutfit: 'starter_glow',
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await save(pet);
    return pet;
  }

  static Future<RecoveryPet?> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_keyPet);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RecoveryPet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(RecoveryPet pet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPet, jsonEncode(pet.toJson()));
  }

  /// Soft decay toward resting when idle (never zeroes bond/shame).
  static RecoveryPet applyIdleDecay(RecoveryPet pet) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hours = (now - pet.lastFedAt) / (1000 * 60 * 60);
    if (hours < 18) return pet;

    final steps = (hours / 24).floor().clamp(0, 7);
    var energy = pet.energy;
    for (var i = 0; i < steps; i++) {
      energy = (energy - 0.08).clamp(0.15, 1.0);
    }
    return pet.copyWith(
      energy: energy,
      mood: energy < 0.35 ? PetMood.resting : pet.mood,
    );
  }

  static Future<RecoveryPet> award({
    required int sparks,
    double energyDelta = 0.05,
    double bondDelta = 0.02,
    PetMood? mood,
  }) async {
    var pet = await ensureHatched();
    pet = applyIdleDecay(pet);
    pet = pet.copyWith(
      sparks: pet.sparks + sparks,
      energy: (pet.energy + energyDelta).clamp(0.15, 1.0),
      bond: (pet.bond + bondDelta).clamp(0.0, 1.0),
      mood: mood ?? PetMood.happy,
      lastFedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await save(pet);
    return pet;
  }

  static Future<RecoveryPet> checkIn(PetMood mood) async {
    return award(
      sparks: sparksCheckIn,
      energyDelta: 0.06,
      bondDelta: 0.03,
      mood: mood == PetMood.struggling ? PetMood.supportive : mood,
    );
  }

  static Future<RecoveryPet> logWalk() async {
    return award(
      sparks: sparksWalk,
      energyDelta: 0.1,
      bondDelta: 0.02,
      mood: PetMood.happy,
    );
  }

  static Future<RecoveryPet> logJournal() async {
    return award(
      sparks: sparksJournal,
      energyDelta: 0.07,
      bondDelta: 0.03,
      mood: PetMood.hopeful,
    );
  }

  static Future<RecoveryPet> logGrounding() async {
    return award(
      sparks: sparksGround,
      energyDelta: 0.08,
      bondDelta: 0.02,
      mood: PetMood.calm,
    );
  }

  static Future<({RecoveryPet pet, bool unlocked})> tryUnlockOutfit(
    String itemId,
  ) async {
    var pet = await ensureHatched();
    if (pet.unlockedItems.contains(itemId)) {
      return (pet: pet, unlocked: false);
    }
    if (pet.sparks < outfitUnlockCost) {
      return (pet: pet, unlocked: false);
    }
    pet = pet.copyWith(
      sparks: pet.sparks - outfitUnlockCost,
      unlockedItems: [...pet.unlockedItems, itemId],
      equippedOutfit: itemId,
    );
    await save(pet);
    return (pet: pet, unlocked: true);
  }
}

enum PetMood { hopeful, happy, calm, resting, supportive, struggling }

extension PetMoodX on PetMood {
  String get label {
    switch (this) {
      case PetMood.hopeful:
        return 'Hopeful';
      case PetMood.happy:
        return 'Happy';
      case PetMood.calm:
        return 'Calm';
      case PetMood.resting:
        return 'Resting';
      case PetMood.supportive:
        return 'With you';
      case PetMood.struggling:
        return 'Soft';
    }
  }

  String get emoji {
    switch (this) {
      case PetMood.hopeful:
        return '✨';
      case PetMood.happy:
        return '🌟';
      case PetMood.calm:
        return '🌿';
      case PetMood.resting:
        return '😴';
      case PetMood.supportive:
        return '🤍';
      case PetMood.struggling:
        return '🤍';
    }
  }

  static PetMood fromName(String? name) {
    return PetMood.values.firstWhere(
      (m) => m.name == name,
      orElse: () => PetMood.hopeful,
    );
  }
}

class RecoveryPet {
  final String name;
  final double energy;
  final double bond;
  final PetMood mood;
  final int sparks;
  final List<String> unlockedItems;
  final String equippedOutfit;
  final int lastFedAt;
  final int createdAt;

  const RecoveryPet({
    required this.name,
    required this.energy,
    required this.bond,
    required this.mood,
    required this.sparks,
    required this.unlockedItems,
    required this.equippedOutfit,
    required this.lastFedAt,
    required this.createdAt,
  });

  bool get isResting => energy < 0.35 || mood == PetMood.resting;

  RecoveryPet copyWith({
    String? name,
    double? energy,
    double? bond,
    PetMood? mood,
    int? sparks,
    List<String>? unlockedItems,
    String? equippedOutfit,
    int? lastFedAt,
    int? createdAt,
  }) {
    return RecoveryPet(
      name: name ?? this.name,
      energy: energy ?? this.energy,
      bond: bond ?? this.bond,
      mood: mood ?? this.mood,
      sparks: sparks ?? this.sparks,
      unlockedItems: unlockedItems ?? this.unlockedItems,
      equippedOutfit: equippedOutfit ?? this.equippedOutfit,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'energy': energy,
        'bond': bond,
        'mood': mood.name,
        'sparks': sparks,
        'unlockedItems': unlockedItems,
        'equippedOutfit': equippedOutfit,
        'lastFedAt': lastFedAt,
        'createdAt': createdAt,
      };

  factory RecoveryPet.fromJson(Map<String, dynamic> json) {
    return RecoveryPet(
      name: json['name'] as String? ?? RecoveryPetService.defaultName,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.7,
      bond: (json['bond'] as num?)?.toDouble() ?? 0.2,
      mood: PetMoodX.fromName(json['mood'] as String?),
      sparks: json['sparks'] as int? ?? 0,
      unlockedItems: (json['unlockedItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['starter_glow'],
      equippedOutfit: json['equippedOutfit'] as String? ?? 'starter_glow',
      lastFedAt: json['lastFedAt'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      createdAt: json['createdAt'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
