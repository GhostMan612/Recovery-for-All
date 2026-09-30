// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';
import '../services/constellation_service.dart';

/// Simple weekly goals tracker: add goals with a target count, check off
/// completions, start a fresh week when ready. Data lives locally forever.
class WeeklyGoalsScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const WeeklyGoalsScreen({super.key, required this.database});

  @override
  State<WeeklyGoalsScreen> createState() => _WeeklyGoalsScreenState();
}

class _WeeklyGoalsScreenState extends State<WeeklyGoalsScreen> {
  Future<void> _addGoal() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '3');
    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('New Weekly Goal', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. Attend 3 meetings',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Times this week',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              final title = titleController.text.trim();
              final target = int.tryParse(targetController.text) ?? 1;
              if (title.isEmpty || target < 1) return;
              Navigator.pop(dialogContext, (title, target));
            },
            child: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
    if (result == null) return;
    await widget.database.addWeeklyGoal(
      WeeklyGoal(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: result.$1,
        targetCount: result.$2,
        currentCount: 0,
        isCompleted: false,
      ),
    );
  }

  Future<void> _startNewWeek() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Start a new week?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'All goal progress resets to zero. Your goals stay.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('New Week', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.database.resetAllWeeklyGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('Weekly Goals', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Start new week',
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: _startNewWeek,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoal,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
        label: Text('Add Goal', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
      ),
      body: StreamBuilder<List<WeeklyGoal>>(
        stream: widget.database.watchAllWeeklyGoals(),
        builder: (context, snapshot) {
          final goals = snapshot.data ?? const <WeeklyGoal>[];
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No goals for this week yet.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Small promises kept build trust in yourself.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progress =
                  goal.targetCount == 0 ? 0.0 : goal.currentCount / goal.targetCount;
              return Dismissible(
                key: ValueKey(goal.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.delete_outline, color: AppColors.dangerSoft),
                ),
                onDismissed: (_) =>
                    widget.database.deleteWeeklyGoal(goal.id),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(goal.title,
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                                  color: goal.isCompleted
                                      ? Theme.of(context).colorScheme.tertiary
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${goal.currentCount}/${goal.targetCount}',
                            style: TextStyle(
                                color: goal.isCompleted
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Log one — ${goal.title}',
                          icon: Icon(Icons.check_circle_outline,
                              color: goal.isCompleted
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.primary),
                          onPressed: () async {
                            final wasComplete = goal.isCompleted;
                            await widget.database
                                .incrementWeeklyGoal(goal.id);
                            final refreshed = (await widget.database
                                    .watchAllWeeklyGoals()
                                    .first)
                                .firstWhere((g) => g.id == goal.id);
                            if (!wasComplete && refreshed.isCompleted) {
                              await RecoveryPetService.logGoalComplete();
                              await ConstellationService.addGoalStar(
                                widget.database, goal.title,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                  content: Text(
                                      '"${goal.title}" complete · +${RecoveryPetService.sparksGoalComplete} Sparks'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
