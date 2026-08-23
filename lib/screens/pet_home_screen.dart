// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/avatar_visual_layer.dart';
import 'avatar_dresser_screen.dart';

/// Full companion view: stats, equipped cosmetics, and the care activity log.
class PetHomeScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const PetHomeScreen({super.key, required this.database});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  static const Map<String, String> _eventLabels = {
    'check_in': 'Daily check-in',
    'journal': 'Journal entry',
    'gratitude': 'Gratitude',
    'grounding': 'Grounding practice',
    'walk': 'Took a walk',
    'reward': 'Care action',
  };

  RecoveryPet? _pet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pet = await RecoveryPetService.ensureHatched();
    if (mounted) setState(() => _pet = pet);
  }

  void _openDresser() async {
    final pet = _pet;
    if (pet == null) return;
    final updated = await Navigator.push<RecoveryPet>(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarDresserScreen(initialPet: pet),
      ),
    );
    if (updated != null) {
      setState(() => _pet = updated);
    } else {
      _load();
    }
  }

  Widget _statBar(String label, double fraction, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text('${(fraction * 100).round()}',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Companion', style: TextStyle(color: Colors.white)),
      ),
      body: pet == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      AvatarVisualLayer(pet: pet, size: 160, showAura: true),
                      const SizedBox(height: 12),
                      Text(pet.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        pet.isResting
                            ? 'Resting · here when you are'
                            : '${pet.mood.emoji} ${pet.mood.label}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _statBar('Energy', pet.energy / 100.0, AppColors.success),
                      const SizedBox(height: 10),
                      _statBar('Bond', pet.bond / 100.0, AppColors.accent),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text('${pet.sparks} Sparks',
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openDresser,
                    icon: const Icon(Icons.checkroom_outlined),
                    label: const Text('Open Dresser',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Wearing Today',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in CosmeticCategory.values)
                      if (pet.equippedSlots[category.name] != null)
                        Builder(builder: (context) {
                          final item = PetCosmeticCatalog.byId(
                              pet.equippedSlots[category.name]!);
                          if (item == null) return const SizedBox.shrink();
                          return Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text('${item.emoji ?? '✦'} ${item.label}',
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 12)),
                          );
                        }),
                  ],
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recent Care',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<PetEventRow>>(
                  stream: widget.database.watchPetEvents(RecoveryPetService.defaultPetId),
                  builder: (context, snapshot) {
                    final events = (snapshot.data ?? const <PetEventRow>[])
                        .take(10)
                        .toList();
                    if (events.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Check in, journal, ground, or take a walk — your care history will appear here.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final event in events)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _eventLabels[event.eventType] ?? event.eventType,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ),
                                if (event.sparksDelta > 0)
                                  Text('+${event.sparksDelta} ✦',
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
