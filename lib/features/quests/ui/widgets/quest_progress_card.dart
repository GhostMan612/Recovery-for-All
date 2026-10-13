// lib/features/quests/ui/widgets/quest_progress_card.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../../data/quest_catalog.dart';
import '../../domain/quest_definition.dart';
import '../../domain/quest_instance.dart';

/// Card widget displaying gentle recovery quest progress, alternative
/// accommodations, and voluntary skip options.
class QuestProgressCard extends StatelessWidget {
  final QuestInstance instance;
  final QuestDefinition? definition;
  final VoidCallback? onSkip;
  final ValueChanged<String>? onSelectAlternative;
  final VoidCallback? onCompleteAlternative;

  const QuestProgressCard({
    super.key,
    required this.instance,
    this.definition,
    this.onSkip,
    this.onSelectAlternative,
    this.onCompleteAlternative,
  });

  @override
  Widget build(BuildContext context) {
    final def = definition ?? QuestCatalog.getDefinition(instance.definitionId);
    final title = def?.title ?? 'Recovery Quest';
    final intent = def?.intent ?? 'A gentle step on your path.';
    final isDone = instance.isCompleted;
    final isSkipped = instance.isSkipped;

    return Semantics(
      label: 'Quest: $title. ${isDone ? 'Completed' : isSkipped ? 'Skipped' : 'In progress'}',
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
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
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(context, isDone, isSkipped),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                intent,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: instance.targetCount > 0
                      ? (instance.currentProgress / instance.targetCount).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (def != null &&
                  def.alternativeAccommodations.isNotEmpty &&
                  !isDone &&
                  !isSkipped) ...[
                Text(
                  'Accessible Accommodations:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final alt in def.alternativeAccommodations)
                      ActionChip(
                        label: Text(alt, style: const TextStyle(fontSize: 11)),
                        onPressed: onSelectAlternative != null
                            ? () => onSelectAlternative!(alt)
                            : null,
                      ),
                  ],
                ),
                if (instance.selectedAlternative != null &&
                    onCompleteAlternative != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onCompleteAlternative,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Complete: ${instance.selectedAlternative}'),
                  ),
                ],
              ],
              if (!isDone && !isSkipped && onSkip != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip today (no penalty)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, bool isDone, bool isSkipped) {
    if (isDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                size: 14, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                color: Theme.of(context).colorScheme.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (isSkipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Skipped',
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 11,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Active',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
