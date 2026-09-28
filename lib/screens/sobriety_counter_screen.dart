// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/recovery_pet_service.dart';
import '../services/constellation_service.dart';

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

  static const List<(int, String)> _healthMilestones = [
    (1, 'Heart attack risk begins dropping'),
    (3, 'Bronchial tubes relax, breathing easier'),
    (7, 'Sleep improves, more energy'),
    (14, 'Circulation improves, lung function up 30%'),
    (30, 'Liver begins repairing, skin clearer'),
    (90, 'Immune system strengthened, anxiety decreases'),
    (180, 'Brain chemistry rebalancing'),
    (365, 'Heart disease risk cut in half'),
  ];

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final snapshot = await widget.database.watchAllCounters().first;
      await _awardNewMilestones(snapshot);
    });
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
    final costController = TextEditingController();
    DateTime chosenDate = DateTime.now();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: const Text('New Counter', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Alcohol, Nicotine, Gaming',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Avg daily cost (optional)',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                  prefixText: r'$ ',
                  prefixStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                title: const Text('Started on',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                trailing: Text(
                  '${chosenDate.month}/${chosenDate.day}/${chosenDate.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: chosenDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialog(() => chosenDate = picked);
                },
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
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Start', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (label == null || label.isEmpty) return;
    final dailyCost = double.tryParse(costController.text) ?? 0.0;
    await widget.database.addCounter(
      Counter(
        id: 'counter_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        startDateTime: chosenDate.millisecondsSinceEpoch,
        isActive: true,
        dailyCost: dailyCost,
      ),
    );
  }

  /// Awards Sparks for milestone chips crossed since last check.
  /// Runs on open — slow crossings get caught the next time the user opens.
  Future<void> _awardNewMilestones(List<Counter> counters) async {
    for (final counter in counters) {
      if (!counter.isActive) continue;
      final prefs = await SharedPreferences.getInstance();
      final key = 'counter_chips_${counter.id}';
      final awarded = (prefs.getStringList(key) ?? <String>[]).toSet();
      final start = DateTime.fromMillisecondsSinceEpoch(counter.startDateTime);
      final elapsed = DateTime.now().difference(start);
      for (final chip in _chips) {
        if (elapsed >= chip.at && !awarded.contains(chip.label)) {
          awarded.add(chip.label);
          await prefs.setStringList(key, awarded.toList());
          await RecoveryPetService.logMilestone(chip.label);
          await ConstellationService.addMilestoneStar(
            widget.database, counter.label, chip.label,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                content: Text(
                    '${counter.label}: ${chip.label} chip earned — companion celebrates!'),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _resetCounter(Counter counter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Reset "${counter.label}"?', style: const TextStyle(color: Colors.white)),
        content: Text(
          'This starts a new Day One for this counter. Nothing is deleted — '
          'every day you made still counts toward you.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep going', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
    final elapsed = DateTime.now().difference(start);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              Text('Now: ${_formatElapsed(start)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14)),
              if (counter.dailyCost > 0) ...[
                const SizedBox(height: 4),
                Text(
                    'Saved: \$${(elapsed.inDays * counter.dailyCost).toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 14),
              const Text('Your Body Is Healing',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ..._healthMilestones.map((milestone) {
                final reached = elapsed.inDays >= milestone.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        reached ? Icons.check_circle : Icons.radio_button_off,
                        size: 14,
                        color: reached ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${milestone.$1}d — ${milestone.$2}',
                          style: TextStyle(
                            color: reached
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerSoft,
                    side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Counters', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCounter,
        backgroundColor: Theme.of(context).colorScheme.primary,
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
                  Icon(Icons.timelapse, size: 56, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text(
                    'No counters yet.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Start one below. Every minute counts, and only you see them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
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
                color: Theme.of(context).colorScheme.surfaceContainer,
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
                            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_formatElapsed(start),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
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
                                      ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: elapsed >= chip.at
                                        ? Theme.of(context).colorScheme.tertiary
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (elapsed >= chip.at) ...[
                                      Icon(Icons.verified,
                                          size: 12, color: Theme.of(context).colorScheme.tertiary),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(chip.label,
                                        style: TextStyle(
                                            color: elapsed >= chip.at
                                                ? Theme.of(context).colorScheme.tertiary
                                                : Theme.of(context).colorScheme.outline,
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
