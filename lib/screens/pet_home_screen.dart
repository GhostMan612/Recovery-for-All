// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/avatar_visual_layer.dart';
import '../widgets/recovery_pet_card.dart';
import 'avatar_dresser_screen.dart';
import 'memory_wall_screen.dart';
import 'pet_trials_screen.dart';

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
    _maybeShowCardTip();
  }

  /// One-shot coach-mark (checklist §12.1).
  Future<void> _maybeShowCardTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('seen_pet_card_tip') ?? false) return;
    await prefs.setBool('seen_pet_card_tip', true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 4),
        content: Text(
            'Care actions earn Sparks · walks and meetings always pay in '
            'full · your companion rests, never starves.')));
  }

  Future<void> _load() async {
    final pet = await RecoveryPetService.ensureHatched();
    if (mounted) setState(() => _pet = pet);
  }

  Future<void> _adoptSpecies(PetSpecies species) async {
    final before = _pet?.sparks ?? 0;
    final updated = await RecoveryPetService.adoptSpecies(species.id);
    if (!mounted) return;
    setState(() => _pet = updated);
    final spent = before - updated.sparks;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          spent > 0
              ? 'Welcome, ${updated.name} the ${species.label} · −$spent Sparks'
              : 'Welcome, ${updated.name} the ${species.label}',
        ),
      ),
    );
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

  /// Share pet card as image via share_plus (alias-only, C1–C5 compliant).
  Future<void> _sharePetCard(RecoveryPet pet) async {
    final key = GlobalKey();
    if (!mounted) return;
    
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        child: RepaintBoundary(
          key: key,
          child: Material(
            color: Colors.transparent,
            child: RecoveryPetCard(
              pet: pet,
              onCheckIn: null,
              onWalk: null,
              onOpen: null,
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final renderObject = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) throw Exception('Could not find render object');
      
      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture image');
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pet_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      // Use SharePlus instance (not deprecated Share.shareXFiles)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Meet ${pet.name}! ✦${pet.sparks} Sparks · ${pet.bond}% Bond · ${pet.mood.emoji} ${pet.mood.label}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: AppColors.bgCard),
        );
      }
    } finally {
      overlayEntry.remove();
    }
  }

  /// Memory-wall copy (P2.3): the pet_events ledger retold in the
  /// companion's voice. Read-only — nothing new persisted.
  String _memoryLine(PetEventRow e) {
    final t = e.eventType;
    if (t.startsWith('milestone_')) {
      return 'Kin remembers your ${t.substring(10)} chip.';
    }
    if (t.startsWith('signoff_step')) {
      return 'Kin remembers step ${t.substring(12)} signed off.';
    }
    if (t.startsWith('worksheet_step')) {
      return 'Kin remembers step ${t.substring(14)} worked through.';
    }
    if (t.startsWith('worksheet_')) {
      return 'Kin remembers a worksheet faced honestly.';
    }
    switch (t) {
      case 'battle_win':
        return 'Kin remembers a Trial won.';
      case 'battle_learned':
        return 'Kin remembers learning something the hard way.';
      case 'goal_complete':
        return 'Kin remembers a weekly goal finished.';
      case 'star':
        return 'Kin remembers a star added to your sky.';
      case 'meeting':
        return 'Kin remembers a room you walked into.';
      case 'walk':
        return 'Kin remembers moving together.';
      case 'wellness':
        return 'Kin remembers the wellness wheel checked.';
    }
    return _eventLabels[t] ?? 'Kin remembers a moment of care.';
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
        actions: [
          IconButton(
            tooltip: 'View Memory Wall',
            icon: const Icon(Icons.auto_awesome_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemoryWallScreen(database: widget.database),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Share Pet Card',
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            onPressed: pet == null ? null : () => _sharePetCard(pet),
          ),
        ],
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgCard,
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Trials of the Path',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PetTrialsScreen()),
                    ).then((_) => _load()),
                  ),
                ),
                const SizedBox(height: 20),
                // Daily gentle quest (P3.1): an invitation, never a chore.
                FutureBuilder<({String id, String title, bool done})>(
                  future: RecoveryPetService.todayQuest(),
                  builder: (context, snapshot) {
                    final quest = snapshot.data;
                    if (quest == null) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            quest.done
                                ? Icons.check_circle_outline
                                : Icons.wb_twilight_outlined,
                            color: quest.done
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quest.done
                                      ? quest.title
                                      : quest.title,
                                  style: TextStyle(
                                      color: quest.done
                                          ? AppColors.textMuted
                                          : Colors.white,
                                      fontSize: 13,
                                      decoration: quest.done
                                          ? TextDecoration.lineThrough
                                          : null),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  quest.done
                                      ? 'Done for today — that is all it asked.'
                                      : 'Today\'s gentle invitation · +10 Sparks',
                                  style: TextStyle(
                                      color: quest.done
                                          ? AppColors.textMuted
                                          : AppColors.accent,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Species',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adopting a new style keeps every stat, spark, and memory.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: PetSpeciesCatalog.all.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final species = PetSpeciesCatalog.all[index];
                      final active = pet.speciesId == species.id;
                      final status =
                          RecoveryPetService.speciesStatus(pet, species.id);
                      final affordable = status == OutfitUnlockStatus.available;
                      return InkWell(
                        onTap:
                            active || status == OutfitUnlockStatus.bondTooLow ||
                                    status == OutfitUnlockStatus.notEnoughSparks
                                ? null
                                : () => _adoptSpecies(species),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 132,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? AppColors.accent : AppColors.border,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(species.emoji,
                                  style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 6),
                              Text(species.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                active
                                    ? 'Active'
                                    : status ==
                                            OutfitUnlockStatus.alreadyOwned
                                        ? 'Adopt · free'
                                        : status == OutfitUnlockStatus.available
                                            ? 'Adopt · ${species.unlockSparks}✦'
                                            : status == OutfitUnlockStatus.bondTooLow
                                                ? 'Bond ${species.unlockBond * 100 ~/ 1}%'
                                                : '${species.unlockSparks}✦ needed',
                                style: TextStyle(
                                  color: active
                                      ? AppColors.accent
                                      : affordable
                                          ? AppColors.success
                                          : AppColors.textDim,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                  child: Text('Kin remembers',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<PetEventRow>>(
                  stream: widget.database
                      .watchPetEvents(RecoveryPetService.defaultPetId),
                  builder: (context, snapshot) {
                    final events = (snapshot.data ?? const <PetEventRow>[])
                        .take(50)
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
                          'Check in, journal, ground, or take a walk — '
                          'memories will gather here.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
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
                                  child: Text(_memoryLine(event),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13)),
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
