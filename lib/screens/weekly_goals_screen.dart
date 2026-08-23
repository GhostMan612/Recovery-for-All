// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';

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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('New Weekly Goal', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. Attend 3 meetings',
                hintStyle: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Times this week',
                hintStyle: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final title = titleController.text.trim();
              final target = int.tryParse(targetController.text) ?? 1;
              if (title.isEmpty || target < 1) return;
              Navigator.pop(dialogContext, (title, target));
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Start a new week?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All goal progress resets to zero. Your goals stay.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('New Week', style: TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Weekly Goals', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Start new week',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _startNewWeek,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoal,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Goal', style: TextStyle(color: Colors.white)),
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
                  Icon(Icons.flag_outlined, size: 56, color: AppColors.textDim),
                  const SizedBox(height: 16),
                  const Text('No goals for this week yet.',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text(
                    'Small promises kept build trust in yourself.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                    color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                ),
                onDismissed: (_) =>
                    widget.database.deleteWeeklyGoal(goal.id),
                child: Material(
                  color: AppColors.bgCard,
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
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  color: goal.isCompleted
                                      ? AppColors.success
                                      : AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${goal.currentCount}/${goal.targetCount}',
                            style: TextStyle(
                                color: goal.isCompleted
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Log one',
                          icon: Icon(Icons.check_circle_outline,
                              color: goal.isCompleted
                                  ? AppColors.success
                                  : AppColors.accent),
                          onPressed: () =>
                              widget.database.incrementWeeklyGoal(goal.id),
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
