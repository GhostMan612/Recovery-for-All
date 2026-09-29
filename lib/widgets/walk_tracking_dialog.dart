// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/widgets/walk_tracking_dialog.dart
//
// Walk tracking dialog with step counter verification.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/step_counter_service.dart';

class WalkTrackingDialog extends StatefulWidget {
  final Future<bool> Function() onFinish;
  final Future<void> Function()? onStop;

  const WalkTrackingDialog({super.key, required this.onFinish, this.onStop});

  @override
  State<WalkTrackingDialog> createState() => WalkTrackingDialogState();
}

class WalkTrackingDialogState extends State<WalkTrackingDialog> {
  Timer? _timer;
  int _steps = 0;
  Duration _elapsed = Duration.zero;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _steps = StepCounterService.instance.getCurrentWalkSteps();
    _elapsed = StepCounterService.instance.getCurrentWalkElapsed() ?? Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), _updateDisplay);
  }

  void _updateDisplay(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() {
      _steps = StepCounterService.instance.getCurrentWalkSteps();
      _elapsed = StepCounterService.instance.getCurrentWalkElapsed() ?? Duration.zero;
      _verified = _steps >= StepCounterService.minStepsForWalk;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}h ' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_steps / StepCounterService.minStepsForWalk).clamp(0.0, 1.0);

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Tracking Walk',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step counter
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Text(
                  '$_steps',
                  style: TextStyle(
                    color: _verified ? Theme.of(context).colorScheme.tertiary : Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'of ${StepCounterService.minStepsForWalk} steps',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  color: _verified ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _verified ? 'Walk verified! ✓' : 'Keep walking...',
                  style: TextStyle(
                    color: _verified ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Elapsed time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Time: ${_formatDuration(_elapsed)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info text
          Text(
            'Walk at least ${StepCounterService.minStepsForWalk} steps (≈5 min) to earn Sparks. '
            'Your companion trusts you — no guilt if you stop early.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (widget.onStop != null) {
              await widget.onStop!();
            } else {
              await StepCounterService.instance.stopWalkTracking();
            }
            if (context.mounted) Navigator.pop(context, false);
          },
            child: Text('Stop Walk', style: TextStyle(color: AppColors.dangerSoft)),
        ),
        TextButton(
          onPressed: () async {
            if (widget.onStop != null) {
              await widget.onStop!();
            } else {
              await StepCounterService.instance.stopWalkTracking();
            }
            if (context.mounted) Navigator.pop(context, false);
          },
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          onPressed: _verified
              ? () async {
                  final ok = await widget.onFinish();
                  if (ok && context.mounted) Navigator.pop(context, true);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Theme.of(context).colorScheme.outlineVariant,
            disabledForegroundColor: Theme.of(context).colorScheme.outline,
          ),
          child: const Text('Finish Walk'),
        ),
      ],
    );
  }
}
