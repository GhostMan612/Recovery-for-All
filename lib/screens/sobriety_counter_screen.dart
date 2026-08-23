// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';

/// Live sobriety counters with milestone chips. A reset is never shameful —
/// it is a new day one, kept privately on-device.
class SobrietyCounterScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const SobrietyCounterScreen({super.key, required this.database});

  @override
  State<SobrietyCounterScreen> createState() => _SobrietyCounterScreenState();
}

class _Chip {
  final String label;
  final Duration at;
  const _Chip(this.label, this.at);
}

class _SobrietyCounterScreenState extends State<SobrietyCounterScreen> {
  static const List<_Chip> _chips = [
    _Chip('24 Hours', Duration(hours: 24)),
    _Chip('30 Days', Duration(days: 30)),
    _Chip('60 Days', Duration(days: 60)),
    _Chip('90 Days', Duration(days: 90)),
    _Chip('6 Months', Duration(days: 183)),
    _Chip('1 Year', Duration(days: 365)),
    _Chip('2 Years', Duration(days: 730)),
  ];

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _formatElapsed(DateTime start) {
    final d = DateTime.now().difference(start);
    if (d.isNegative) return 'Not started';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '$days days · ${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Future<void> _addCounter() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('New Counter', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Alcohol, Nicotine, Gaming',
            hintStyle: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    await widget.database.addCounter(
      Counter(
        id: 'counter_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        startDateTime: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
      ),
    );
  }

  Future<void> _resetCounter(Counter counter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Reset "${counter.label}"?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This starts a new Day One for this counter. Nothing is deleted — '
          'every day you made still counts toward you.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep going', style: TextStyle(color: AppColors.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('New Day One', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.database.updateCounterAnniversary(counter.id, DateTime.now());
    }
  }

  void _showDetails(Counter counter) {
    final start = DateTime.fromMillisecondsSinceEpoch(counter.startDateTime);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(counter.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Began: ${start.toLocal().toString().split(' ').first}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text('Now: ${_formatElapsed(start)}',
                  style: TextStyle(color: AppColors.accent, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                    side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start a New Day One'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _resetCounter(counter);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Counters', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCounter,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Counter', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<Counter>>(
        stream: widget.database.watchAllCounters(),
        builder: (context, snapshot) {
          final counters =
              (snapshot.data ?? const <Counter>[]).where((c) => c.isActive).toList()
                ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (counters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timelapse, size: 56, color: AppColors.textDim),
                  const SizedBox(height: 16),
                  const Text(
                    'No counters yet.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Start one below. Every minute counts, and only you see them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: counters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final counter = counters[index];
              final start = DateTime.fromMillisecondsSinceEpoch(counter.startDateTime);
              final elapsed = DateTime.now().difference(start);
              return Material(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showDetails(counter),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(counter.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.textDim),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_formatElapsed(start),
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final chip in _chips)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: elapsed >= chip.at
                                      ? AppColors.success.withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: elapsed >= chip.at
                                        ? AppColors.success
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (elapsed >= chip.at) ...[
                                      const Icon(Icons.verified,
                                          size: 12, color: AppColors.success),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(chip.label,
                                        style: TextStyle(
                                            color: elapsed >= chip.at
                                                ? AppColors.success
                                                : AppColors.textDim,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                          ],
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
