// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// Reader for the Twelve Steps of Alcoholics Anonymous (public domain).
/// Personal completion marks stay on-device only.
class StepsViewerScreen extends StatefulWidget {
  const StepsViewerScreen({super.key});

  @override
  State<StepsViewerScreen> createState() => _StepsViewerScreenState();
}

class _StepData {
  final int number;
  final String title;
  final String text;
  const _StepData(this.number, this.title, this.text);
}

class _StepsViewerScreenState extends State<StepsViewerScreen> {
  static const String _prefsKey = 'steps_completed_v1';

  // The Twelve Steps (Alcoholics Anonymous, 1st ed., public domain).
  static const List<_StepData> _steps = [
    _StepData(1, 'Honesty', 'We admitted we were powerless over alcohol — that our lives had become unmanageable.'),
    _StepData(2, 'Hope', 'Came to believe that a Power greater than ourselves could restore us to sanity.'),
    _StepData(3, 'Faith', 'Made a decision to turn our will and our lives over to the care of God as we understood Him.'),
    _StepData(4, 'Courage', 'Made a searching and fearless moral inventory of ourselves.'),
    _StepData(5, 'Integrity', 'Admitted to God, to ourselves, and to another human being the exact nature of our wrongs.'),
    _StepData(6, 'Willingness', 'Were entirely ready to have God remove all these defects of character.'),
    _StepData(7, 'Humility', 'Humbly asked Him to remove our shortcomings.'),
    _StepData(8, 'Brotherly Love', 'Made a list of all persons we had harmed, and became willing to make amends to them all.'),
    _StepData(9, 'Justice', 'Made direct amends to such people wherever possible, except when to do so would injure them or others.'),
    _StepData(10, 'Perseverance', 'Continued to take personal inventory and when we were wrong promptly admitted it.'),
    _StepData(11, 'Spirituality', 'Sought through prayer and meditation to improve our conscious contact with God as we understood Him, praying only for knowledge of His will for us and the power to carry that out.'),
    _StepData(12, 'Service', 'Having had a spiritual awakening as the result of these steps, we tried to carry this message to alcoholics, and to practice these principles in all our affairs.'),
  ];

  Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _completed = raw == null
          ? <int>{}
          : (jsonDecode(raw) as List).map((e) => e as int).toSet();
    });
  }

  Future<void> _toggle(int number) async {
    setState(() {
      if (!_completed.add(number)) _completed.remove(number);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_completed.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('The Twelve Steps', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final step = _steps[index];
          final done = _completed.contains(step.number);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done ? AppColors.success.withValues(alpha: 0.5) : AppColors.border,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                iconColor: AppColors.accent,
                collapsedIconColor: AppColors.textMuted,
                title: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.success : AppColors.accent.withValues(alpha: 0.15),
                      ),
                      child: Text(
                        '${step.number}',
                        style: TextStyle(
                          color: done ? Colors.white : AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(step.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(step.text,
                        style:
                            TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 10),
                      child: TextButton.icon(
                        onPressed: () => _toggle(step.number),
                        icon: Icon(done ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                            color: done ? AppColors.success : AppColors.accent),
                        label: Text(done ? 'Worked' : 'Mark worked',
                            style: TextStyle(
                                color: done ? AppColors.success : AppColors.accent,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
