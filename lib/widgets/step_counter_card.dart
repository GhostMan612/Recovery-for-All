// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/widgets/step_counter_card.dart
//
// Daily step counter card with permission request flow.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/step_counter_service.dart';

class StepCounterCard extends StatefulWidget {
  final VoidCallback? onTap;

  const StepCounterCard({super.key, this.onTap});

  @override
  State<StepCounterCard> createState() => _StepCounterCardState();
}

class _StepCounterCardState extends State<StepCounterCard> {
  int _dailySteps = 0;
  bool _permissionRequested = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final steps = await StepCounterService.instance.getDailyStepsAsync();
    final permRequested = await StepCounterService.instance.hasPermissionBeenRequested();
    
    if (mounted) {
      setState(() {
        _dailySteps = steps;
        _permissionRequested = permRequested;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    try {
      // The pedometer plugin handles permissions via OS dialogs when streams are started
      // Just mark as requested and reload
      await StepCounterService.instance.markPermissionRequested();
      if (mounted) {
        setState(() => _permissionRequested = true);
        _loadData(); // Refresh steps after permission
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not request permission: $e'),
            backgroundColor: AppColors.bgCard,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: AppColors.bgCard,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
      );
    }

    return Card(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_walk, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Steps',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Track your movement',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!_permissionRequested)
                    TextButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Enable'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    )
                  else
                    Text(
                      _formatSteps(_dailySteps),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_permissionRequested)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enable step tracking to verify walks and earn Sparks automatically.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LinearProgressIndicator(
                  value: (_dailySteps / 10000).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }
}