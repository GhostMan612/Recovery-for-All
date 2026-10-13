// lib/features/circle/ui/cooperative_quest_card.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../domain/cooperative_quest.dart';

class CooperativeQuestCard extends StatelessWidget {
  final CooperativeQuest quest;
  final bool isMember;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onContribute;

  const CooperativeQuestCard({
    super.key,
    required this.quest,
    this.isMember = false,
    this.onJoin,
    this.onLeave,
    this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = quest.progressRatio;
    final isComplete = quest.isCompleted;

    return Semantics(
      label: 'Circle Quest: ${quest.title}. ${isComplete ? "Completed" : "${quest.currentContributions} of ${quest.targetContributions} contributions"}.',
      child: Card(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      quest.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isComplete
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isComplete
                          ? 'Complete'
                          : '${quest.currentContributions} / ${quest.targetContributions}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isComplete
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                quest.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isMember) ...[
                    OutlinedButton(
                      onPressed: onJoin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                      child: const Text('Join Quest'),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: onLeave,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Leave'),
                    ),
                    const SizedBox(width: 8),
                    if (!isComplete) ...[
                      ElevatedButton(
                        onPressed: onContribute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        child: const Text('Contribute'),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
