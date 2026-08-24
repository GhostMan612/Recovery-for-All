// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

/// Six-dimension wellness wheel check-in (NWI model) with a 7-check-in trend.
class WellnessCheckInScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const WellnessCheckInScreen({super.key, required this.database});

  @override
  State<WellnessCheckInScreen> createState() => _WellnessCheckInScreenState();
}

class _Dimension {
  final String key;
  final String label;
  final IconData icon;
  const _Dimension(this.key, this.label, this.icon);
}

class _WellnessCheckInScreenState extends State<WellnessCheckInScreen> {
  static const List<_Dimension> _dimensions = [
    _Dimension('spiritual', 'Spiritual', Icons.self_improvement),
    _Dimension('intellectual', 'Intellectual', Icons.psychology_outlined),
    _Dimension('emotional', 'Emotional', Icons.favorite_outline),
    _Dimension('physical', 'Physical', Icons.directions_run),
    _Dimension('social', 'Social', Icons.groups_2_outlined),
    _Dimension('occupational', 'Occupational', Icons.work_outline),
  ];

  final Map<String, double> _scores = {
    for (final d in _dimensions) d.key: 5,
  };

  List<WellnessCheckIn>? _history;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final end = DateTime.now().millisecondsSinceEpoch + 86400000;
    final start = end - 30 * 86400000;
    final rows = await widget.database.getCheckInsForRange(start, end);
    if (mounted) setState(() => _history = rows.take(7).toList());
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.database.addWellnessCheckIn(
      WellnessCheckIn(
        id: 'checkin_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        spiritual: _scores['spiritual']!,
        intellectual: _scores['intellectual']!,
        emotional: _scores['emotional']!,
        physical: _scores['physical']!,
        social: _scores['social']!,
        occupational: _scores['occupational']!,
      ),
    );
    await RecoveryPetService.logWellness();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Check-in saved · your wheel is balanced by honesty, not perfection'),
        backgroundColor: AppColors.bgCard,
      ),
    );
    Navigator.pop(context);
  }

  String _averageOf(WellnessCheckIn row) {
    final avg = (row.spiritual +
            row.intellectual +
            row.emotional +
            row.physical +
            row.social +
            row.occupational) /
        6;
    return avg.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Wellness Check-In', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'How full is each spoke today?',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Slide honestly from 1 to 10. Low numbers are information, not failure.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final d in _dimensions)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(d.icon, color: AppColors.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d.label,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            Text(_scores[d.key]!.round().toString(),
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: Colors.white,
                            overlayColor: AppColors.accent.withValues(alpha: 0.15),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _scores[d.key]!,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (v) => setState(() => _scores[d.key] = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Check-In',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recent Check-Ins',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_history == null)
            const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          else if (_history!.isEmpty)
            Text('Your history will appear here after your first check-in.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            ..._history!.map((row) {
              final date =
                  DateTime.fromMillisecondsSinceEpoch(row.timestamp);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('${date.month}/${date.day}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const Spacer(),
                    Text('avg ${_averageOf(row)} / 10',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
