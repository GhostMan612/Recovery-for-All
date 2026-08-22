// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/avatar_dresser_screen.dart

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/avatar_visual_layer.dart';
import '../widgets/themed_background.dart';

class AvatarDresserScreen extends StatefulWidget {
  final RecoveryPet initialPet;
  final bool onboardingMode;
  final ValueChanged<RecoveryPet>? onChanged;

  const AvatarDresserScreen({
    super.key,
    required this.initialPet,
    this.onboardingMode = false,
    this.onChanged,
  });

  @override
  State<AvatarDresserScreen> createState() => _AvatarDresserScreenState();
}

class _AvatarDresserScreenState extends State<AvatarDresserScreen>
    with SingleTickerProviderStateMixin {
  late RecoveryPet _pet;
  late TabController _tabController;
  String? _subFilter;
  bool _busy = false;

  static const _categories = CosmeticCategory.values;

  @override
  void initState() {
    super.initState();
    _pet = widget.initialPet;
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _subFilter = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CosmeticCategory get _currentCategory => _categories[_tabController.index];

  Future<void> _swap(PetCosmetic item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var pet = _pet;
      final status = RecoveryPetService.unlockStatus(pet, item.id);
      if (status == OutfitUnlockStatus.alreadyOwned ||
          pet.unlockedItems.contains(item.id)) {
        pet = await RecoveryPetService.equipCosmetic(item.id);
      } else if (status == OutfitUnlockStatus.available) {
        final result = await RecoveryPetService.tryUnlockCosmetic(item.id);
        pet = result.pet;
        if (!result.unlocked && mounted) {
          _toast(_statusMessage(result.status));
        }
      } else {
        if (mounted) _toast(_statusMessage(status));
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _pet = pet;
        _busy = false;
      });
      widget.onChanged?.call(pet);
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  String _statusMessage(OutfitUnlockStatus s) {
    switch (s) {
      case OutfitUnlockStatus.notEnoughSparks:
        return 'Need more Sparks';
      case OutfitUnlockStatus.bondTooLow:
        return 'Bond a little more first';
      case OutfitUnlockStatus.seasonLocked:
        return 'Seasonal item not available right now';
      case OutfitUnlockStatus.unknownItem:
        return 'Unknown item';
      case OutfitUnlockStatus.alreadyOwned:
        return 'Already owned';
      case OutfitUnlockStatus.available:
        return '';
    }
  }

  void _toast(String msg) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.bgCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subs = RecoveryPetService.subcategoriesOf(_currentCategory);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedBackground(
        enableKenBurns: false,
        scrimOpacity: 0.82,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context, _pet),
                    ),
                    Expanded(
                      child: Text(
                        widget.onboardingMode
                            ? 'Shape your avatar'
                            : 'Avatar dresser',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_pet.sparks}✦',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              AvatarVisualLayer(pet: _pet, size: 150),
              Text(
                _pet.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bond ${_pet.bond}% · ${_pet.mood.label}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                tabs: _categories
                    .map((c) => Tab(text: c.label))
                    .toList(),
              ),
              if (subs.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 6),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: _subFilter == null,
                          onSelected: (_) => setState(() => _subFilter = null),
                          selectedColor: AppColors.accent.withValues(alpha: 0.3),
                          labelStyle: TextStyle(
                            color: _subFilter == null
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.bgCard,
                        ),
                      ),
                      ...subs.map((s) {
                        final selected = _subFilter == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, top: 6),
                          child: FilterChip(
                            label: Text(s),
                            selected: selected,
                            onSelected: (_) => setState(
                              () => _subFilter = selected ? null : s,
                            ),
                            selectedColor:
                                AppColors.accent.withValues(alpha: 0.3),
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textMuted,
                              fontSize: 12,
                            ),
                            backgroundColor: AppColors.bgCard,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((cat) {
                    var items = RecoveryPetService.listByCategory(cat);
                    if (_subFilter != null) {
                      items = items
                          .where((i) => i.subcategory == _subFilter)
                          .toList();
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final equipped =
                            _pet.slot(cat) == item.id;
                        final owned =
                            _pet.unlockedItems.contains(item.id);
                        final status =
                            RecoveryPetService.unlockStatus(_pet, item.id);
                        final emoji = item.emoji ??
                            AvatarVisualLayer.displayEmoji(item.id);

                        return InkWell(
                          onTap: _busy ? null : () => _swap(item),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgCard.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: equipped
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: equipped ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  owned
                                      ? (equipped ? 'On' : 'Own')
                                      : item.isSeasonal
                                          ? (status ==
                                                  OutfitUnlockStatus
                                                      .seasonLocked
                                              ? 'Season'
                                              : '${item.cost}✦')
                                          : (item.free || item.cost == 0
                                              ? 'Free'
                                              : '${item.cost}✦'),
                                  style: TextStyle(
                                    color: equipped
                                        ? AppColors.accent
                                        : AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              if (widget.onboardingMode)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, _pet),
                      child: const Text(
                        'Looks good',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}