// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/dashboard_sections.dart
//
// Phase 8 slice 3 — the Path and Library section *bodies*, extracted so the
// dashboard screen stops assembling raw Column/Grid trees inline.
//
// Two behaviors are deliberate here rather than incidental:
//
//  * MeetingSpotlight distinguishes waiting / error / empty. The dashboard
//    used to collapse all three into "No meetings in the next 6 hours",
//    which told the user there was nothing happening when in fact we simply
//    had not read the cache yet. That is a Phase 6 gap being closed.
//  * ToolGrid has a real empty state. If a user hides every tool, the grid
//    used to collapse to nothing with no way back; now it explains itself
//    and offers a restore.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/meeting_finder_service.dart';
import '../services/recovery_pet_service.dart';
import 'app_primitives.dart';
import '../screens/constellation_canvas_3d.dart';
import 'recovery_pet_card.dart';
import 'themed_background.dart';
import 'next_meeting_card.dart';

/// The user's chosen recovery paths, as tappable-looking chips.
///
/// Reads a plain `List<String>` so it can be rendered in a test without
/// touching the profile provider.
class PathChips extends StatelessWidget {
  final List<String> paths;

  const PathChips({super.key, required this.paths});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (paths.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              path,
              style: TextStyle(color: scheme.onSurface, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Meetings / Support surface.
///
/// The caller owns the future and the picking logic; this widget owns the
/// *state presentation*, which is what Phase 8 asked to be deliberate.
class MeetingSpotlight extends StatelessWidget {
  final AsyncSnapshot<List<RecoveryMeeting>> snapshot;
  final ({RecoveryMeeting meeting, bool isLive})? pick;
  final String? tierLabel;
  final VoidCallback? onOpenMap;
  final VoidCallback? onFindMeetings;
  final VoidCallback? onRetry;

  const MeetingSpotlight({
    super.key,
    required this.snapshot,
    this.pick,
    this.tierLabel,
    this.onOpenMap,
    this.onFindMeetings,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Waiting on the local cache. Distinct from "nothing scheduled": we
    // simply do not know yet, and saying otherwise would be a lie.
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: AppLoadingState(message: 'Checking today\u2019s meetings\u2026'),
      );
    }

    if (snapshot.hasError) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppErrorState(
          icon: Icons.cloud_off,
          title: 'Could not load meetings',
          message:
              'The local meeting cache could not be read. Your other tools '
              'still work — try again or find a room below.',
          onRetry: onRetry,
        ),
      );
    }

    return NextMeetingCard(
      meeting: pick?.meeting,
      isLive: pick?.isLive ?? false,
      tierLabel: tierLabel,
      onOpenMap: onOpenMap,
      onFindMeetings: onFindMeetings,
    );
  }
}

/// Toolbox / Library grid plus the "hidden" editing tray.
///
/// [children] are already-built card widgets; the caller owns ordering and
/// drag handling. This widget owns the header, the restore tray, and the
/// empty state, all of which were duplicated between the two tabs.
class ToolGrid extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool editing;
  final Set<String> hidden;
  final ValueChanged<String> onRestore;
  final VoidCallback onToggleEditing;
  final VoidCallback? onResetLayout;

  const ToolGrid({
    super.key,
    required this.title,
    required this.children,
    required this.editing,
    required this.hidden,
    required this.onRestore,
    required this.onToggleEditing,
    this.subtitle,
    this.onResetLayout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onResetLayout != null)
                IconButton(
                  tooltip: 'Reset layout',
                  icon: Icon(Icons.refresh,
                      color: scheme.primary, size: 18),
                  onPressed: onResetLayout,
                ),
              IconButton(
                tooltip: editing ? 'Done' : 'Edit layout',
                icon: Icon(editing ? Icons.check : Icons.edit_outlined,
                    color: scheme.primary, size: 18),
                onPressed: onToggleEditing,
              ),
            ],
          ),
        ),
        if (editing && hidden.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in hidden)
                  ActionChip(
                    label: Text(id, style: const TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.visibility_off, size: 14),
                    onPressed: () => onRestore(id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (children.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: hidden.isEmpty
                  ? 'No tools here yet'
                  : 'Every tool is hidden',
              message: hidden.isEmpty
                  ? 'Nothing is available in this section right now.'
                  : 'All ${hidden.length} tools are hidden. Restore one below to '
                      'get started — hiding something is not the same as '
                      'deleting it.',
              action: hidden.isEmpty
                  ? null
                  : (onResetLayout != null
                      ? FilledButton.tonalIcon(
                          onPressed: onResetLayout,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Restore all'),
                        )
                      : FilledButton.tonal(
                          onPressed: () {
                            for (final id in hidden) {
                              onRestore(id);
                            }
                          },
                          child: const Text('Restore all'),
                        )),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: children,
          ),
      ],
    );
  }
}

/// The constellation as a compact, tappable crown.
///
/// Takes the already-sorted node list (the screen owns loading) plus the
/// user-chosen sky name, so this stays a pure view.
class SkyCrown extends StatelessWidget {
  final List<ConstellationNode3D> nodes;
  final String skyName;
  final VoidCallback onTap;

  const SkyCrown({
    super.key,
    required this.nodes,
    required this.skyName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasStars = nodes.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Open your constellation, $skyName'
          '${hasStars ? ', ${nodes.length} stars' : ', no stars yet'}',
      // Phase 12: the Stack paints the sky name and the "plant your first
      // star" prompt as Text, so the curated label was being concatenated
      // with them and the whole thing was read twice. `onTap` is repeated
      // because excluding the GestureDetector also drops its action.
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 150,
          color: AppColors.starfield,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasStars)
                RecoveryConstellation3DWidget(nodes: nodes.take(24).toList())
              else
                ThemedBackground(
                  enableKenBurns: false,
                  scrimOpacity: 0.55,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 30, color: scheme.primary),
                        const SizedBox(height: 8),
                        Text(
                          'Plant your first star — name your sky',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Phase 13 follow-up (found on a B160V at 2.0x text scale, not by
              // any test): the centred empty-state prompt and this bottom-left
              // label are two independent Stack children inside a fixed 150px
              // box, so neither knows the other exists. At 2.0x the prompt wraps
              // to two lines and grows down into the label. No RenderFlex ever
              // overflowed, which is exactly why the 3x2x4x3 matrix was green.
              //
              // Fixed by not showing the label until there is a sky to name: with
              // no stars, `skyName` is only ever the caller's fallback
              // ('Your Constellation'), and the centred prompt already says
              // "name your sky". The stars count was already gated this way.
              if (hasStars)
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: ConstrainedBox(
                    // Bounded width so the user-supplied sky name has
                    // something to ellipsize against. Unbounded, a long name at
                    // 2.0x scale wrapped to three lines and grew UPWARD from
                    // bottom:10, covering most of the star canvas — the same
                    // class of bug as the Phase 13 empty-state collision above,
                    // and equally invisible to a RenderFlex-overflow assertion.
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          skyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${nodes.length} stars',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                right: 10,
                top: 8,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.expand_outlined,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Companion surface: the pet card plus its XP progress bar.
///
/// The whole block is one tap target that opens the skill tree, which is
/// what the original GestureDetector wrapped. [RecoveryPet] is passed in
/// already loaded by the caller.
class CompanionSection extends StatelessWidget {
  final RecoveryPet pet;
  final VoidCallback onTap;
  final VoidCallback onCheckIn;
  final VoidCallback onWalk;
  final VoidCallback onOpen;

  const CompanionSection({
    super.key,
    required this.pet,
    required this.onTap,
    required this.onCheckIn,
    required this.onWalk,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final evaluated = RecoveryPetService.evaluateLevel(pet);
    final xpInto = evaluated.pathXp % 100;
    final progress = xpInto / 100;

    return Semantics(
      button: true,
      label: 'Open Skill Tree. '
          '${pet.name}, level ${evaluated.pathLevel}, $xpInto of 100 XP.',
      // Phase 12: `excludeSemantics` is DELIBERATELY not used here, unlike on
      // SkyCrown and the dashboard cards. RecoveryPetCard renders an InkWell
      // and two real buttons (check in, walk) inside this subtree, and
      // excluding their semantics would leave a screen-reader user with no
      // way to reach ANY of them. The cost is that the level and XP text is
      // announced both from the curated label above and from the Text below.
      // A duplicated announcement is a far smaller problem than an
      // unreachable daily-care action, so the trade goes this way on purpose.
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecoveryPetCard(
              pet: pet,
              onCheckIn: onCheckIn,
              onWalk: onWalk,
              onOpen: onOpen,
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Level ${evaluated.pathLevel} • $xpInto/100 XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Phase 13: this hint is a NON-flexible child, so it was
                    // laid out at its intrinsic width before the Expanded
                    // level text got any space. At 2.0x on a 320dp screen the
                    // row needed ~450dp in 292dp and overflowed.
                    // The essential information is the level and XP, which is
                    // the Expanded child; the "tap for skill tree" cue is
                    // reinforcement, and the Semantics label above already
                    // announces "Open Skill Tree". So the visible hint steps
                    // aside once the user's text is large enough for it to
                    // collide, rather than truncating the level instead.
                    if (MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Tap for Skill Tree',
                        style:
                            TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.account_tree_outlined,
                        size: 14, color: AppColors.pink),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: scheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
