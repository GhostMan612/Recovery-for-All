// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/widgets/step_counter_card.dart
//
// Daily step counter card with permission request flow.

import 'package:flutter/material.dart';

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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_walk, color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Steps',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Track your movement',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        // This is the only path to the pedometer permission,
                        // so it needs the 48dp Material minimum, not a 30dp
                        // target.
                        minimumSize: const Size(64, 48),
                      ),
                    )
                  else
                    Text(
                      _formatSteps(_dailySteps),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enable step tracking to verify walks and earn Sparks automatically.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LinearProgressIndicator(
                  value: (_dailySteps / 10000).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  color: Theme.of(context).colorScheme.primary,
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
