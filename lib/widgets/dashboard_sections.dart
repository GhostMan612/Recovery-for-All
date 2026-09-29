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
import 'app_primitives.dart';
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
              'still work \u2014 try again or find a room below.',
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
                      'get started \u2014 hiding something is not the same as '
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
