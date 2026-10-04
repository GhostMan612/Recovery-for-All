// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/avatar_dresser_screen.dart

import 'package:flutter/material.dart';

import '../services/pet_cosmetic_catalog.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/avatar_visual_layer.dart';
import '../widgets/cosmetic_icon_painter.dart';
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
    var pet = _pet;
    final owned = pet.unlockedItems.contains(item.id);
    final status = RecoveryPetService.unlockStatus(pet, item.id);
    if (owned || status == OutfitUnlockStatus.alreadyOwned) {
      setState(() => _busy = true);
      try {
        pet = await RecoveryPetService.equipCosmetic(item.id);
        setState(() {
          _pet = pet;
          _busy = false;
        });
        widget.onChanged?.call(pet);
      } catch (_) {
        setState(() => _busy = false);
      }
      return;
    }
    if (status != OutfitUnlockStatus.available) {
      if (mounted) _toast(_statusMessage(status));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Unlock Item?', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text('Unlock ${item.label} for ${item.cost} Sparks?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unlock ${item.cost}✦', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await RecoveryPetService.tryUnlockCosmetic(item.id, item.cost);
      if (!result.unlocked) {
        if (mounted) _toast(_statusMessage(result.status));
        setState(() => _busy = false);
        return;
      }
      pet = result.pet;
      pet = await RecoveryPetService.equipCosmetic(item.id);
      setState(() {
        _pet = pet;
        _busy = false;
      });
      widget.onChanged?.call(pet);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.celebration, color: Theme.of(context).colorScheme.primary, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text('${item.label} unlocked! Equipped.', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600))),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subs = RecoveryPetService.subcategoriesOf(_currentCategory);

    // One text scale for the whole screen, computed once. The header below and
    // the grid both have to respond to it, and they have to agree: a header that
    // keeps its full-height avatar while the grid shrinks is how you fix a
    // 12px clip and create a 28px one.
    //
    // Capped at 1.6x. Beyond that the extra height stops buying useful space and
    // just pushes the grid further off-screen; the user's own setting is not
    // ours to second-guess past the point of diminishing returns.
    final rawScale = MediaQuery.textScalerOf(context).scale(1.0);
    final textScale = rawScale < 1.0 ? 1.0 : (rawScale > 1.6 ? 1.6 : rawScale);

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
                      tooltip: 'Close dresser',
                      icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context, _pet),
                    ),
                    Expanded(
                      child: Text(
                        widget.onboardingMode
                            ? 'Shape your avatar'
                            : 'Avatar dresser',
                        // One line, ellipsized. This is the whole trap of this
                        // header: `Expanded` protects the *flex* child, but a
                        // non-flexible Spark readout beside it is laid out at
                        // INTRINSIC width first, so a wide total ("999999✦")
                        // takes the space before the title gets any. The title
                        // then wraps, and because the header Column is not
                        // scrollable — it has an Expanded(TabBarView) under it
                        // that needs a bounded height — that extra line shows up
                        // as a 65px overflow at the bottom of the screen.
                        //
                        // A short fixed title truncating is right; a tall header
                        // is not.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_pet.sparks}✦',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // The header Column is NOT scrollable — it has an Expanded(TabBarView) beneath
              // it, which needs a bounded height — so when the user's text grows,
              // something has to give. The portrait yields: it shrinks as the
              // text scale rises, which measured 40px of relief at 1.6x against
              // the 28px overflow a long pet name produced at 2x.
              AvatarVisualLayer(
                  pet: _pet, size: 150.0 - 40.0 * (textScale - 1.0)),
              Text(
                _pet.name,
                textAlign: TextAlign.center,
                // The name is user-supplied, so its length is not ours to bound.
                // Two lines with an ellipsis is what stops a long name from
                // pushing the portrait and the tab bar off the screen.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bond ${_pet.bond}% · ${_pet.mood.label}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          labelStyle: TextStyle(
                            // onSurface, not Colors.white. The selected fill
                            // is `primary` at 30% alpha composited over
                            // `surfaceContainer`, so the effective background
                            // is a light tint in light mode — white text on it
                            // was invisible. `onSurface` contrasts with that
                            // tint in both brightnesses, because the tint
                            // tracks `surface` far more closely than it tracks
                            // `primary`.
                            color: _subFilter == null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            labelStyle: TextStyle(
                              // onSurface, not Colors.white — same reasoning
                              // as the 'All' chip above.
                              color: selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
                    // A fixed `childAspectRatio` is only correct at ONE text
                    // scale. These cells hold a fixed 34dp painted icon plus two
                    // lines of text, so at 1.5x/2.0x the content outgrows the
                    // cell: measured overflow was 14px at 1.5x and 12px at 2.0x
                    // on a 360dp phone (lessons-learned L14 — a card in a
                    // fixed-aspect-ratio grid needs a multi-scale test, and
                    // reading the code is not enough). `textScale` is the
                    // screen-wide value computed at the top of this build.
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85 / textScale,
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

                        return Semantics(
                          button: true,
                          enabled: !_busy,
                          label: '${item.label}, ${item.cost} Sparks',
                          child: InkWell(
                          onTap: _busy ? null : () => _swap(item),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: equipped
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: equipped ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Vector art, not a font glyph. This grid was
                                // the last surface still rendering an emoji per
                                // item, and it is the surface a player scrolls
                                // for the longest, so it is the worst place to
                                // ship system-font art that differs per device.
                                //
                                // Flexible so this is the child that yields when
                                // a large text scale leaves the cell too short
                                // for both text lines. Text is never the thing
                                // that gets clipped.
                                Flexible(
                                  child: SizedBox(
                                    height: 34,
                                    width: 34,
                                    child: CustomPaint(
                                      painter: CosmeticIconPainter(
                                        itemId: item.id,
                                        item: item,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                  // A cell has a fixed height, so an unbounded
                                  // status line wraps until the column
                                  // overflows. `${item.cost}✦` is short for
                                  // every current cosmetic, but it is a number
                                  // formatted from data — a four- or five-digit
                                  // value must ellipsize, not push the cell.
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: equipped
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, _pet),
                      child: Text(
                        'Looks good',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
