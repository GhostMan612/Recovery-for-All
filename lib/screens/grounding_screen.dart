// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/recovery_pet_service.dart';

/// Full-screen grounding / breathing exercise.
/// Two modes: Box Breathing (4-4-4-4) and 4-7-8 (inhale-hold-exhale).
/// Designed for crisis: large targets, minimal text, no guilt.
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

enum _BreathMode { select, box, extended }

enum _BreathPhase { inhale, hold, exhale }

class _GroundingScreenState extends State<GroundingScreen>
    with SingleTickerProviderStateMixin {
  _BreathMode _mode = _BreathMode.select;
  int _remaining = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  late AnimationController _breathController;
  String _phase = 'Inhale';
  int _cycle = 0;

  // 4-7-8 specific
  int _phaseSecondsLeft = 0;
  _BreathPhase _extendedPhase = _BreathPhase.inhale;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _breathController.addListener(_onBreathTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _onBreathTick() {
    if (_mode == _BreathMode.box) {
      final v = _breathController.value;
      final next = v < 0.5 ? 'Inhale' : 'Exhale';
      if (next != _phase && mounted) setState(() => _phase = next);
    }
  }

  void _startBox() {
    setState(() {
      _mode = _BreathMode.box;
      _totalSeconds = 60;
      _remaining = _totalSeconds;
    });
    _breathController.duration = const Duration(seconds: 4);
    _breathController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        if (mounted) setState(() => _remaining = 0);
        RecoveryPetService.logGrounding();
        return;
      }
      if (mounted) setState(() => _remaining--);
    });
  }

  void _startExtended() {
    setState(() {
      _mode = _BreathMode.extended;
      _totalSeconds = 76; // 4 cycles x 19s
      _remaining = _totalSeconds;
      _cycle = 0;
      _extendedPhase = _BreathPhase.inhale;
      _phaseSecondsLeft = 4;
      _phase = 'Inhale';
    });
    _breathController.stop();
    _runExtendedCycle();
  }

  void _runExtendedCycle() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _phaseSecondsLeft--);

      if (_phaseSecondsLeft <= 0) {
        t.cancel();
        switch (_extendedPhase) {
          case _BreathPhase.inhale:
            _extendedPhase = _BreathPhase.hold;
            _phase = 'Hold';
            _phaseSecondsLeft = 7;
            HapticFeedback.mediumImpact();
          case _BreathPhase.hold:
            _extendedPhase = _BreathPhase.exhale;
            _phase = 'Exhale';
            _phaseSecondsLeft = 8;
            HapticFeedback.lightImpact();
          case _BreathPhase.exhale:
            _cycle++;
            if (_cycle >= 4) {
              setState(() => _remaining = 0);
              RecoveryPetService.logGrounding();
              return;
            }
            _extendedPhase = _BreathPhase.inhale;
            _phase = 'Inhale';
            _phaseSecondsLeft = 4;
            HapticFeedback.selectionClick();
        }
        _runExtendedCycle();
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _mode == _BreathMode.select
              ? _buildModeSelector()
              : _buildExercise(),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ),
        const Spacer(),
        const Text('Choose your breathing pattern',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        _ModeCard(
          title: 'Box Breathing',
          subtitle: 'Inhale 4 · Hold 4 · Exhale 4\n60 seconds',
          icon: Icons.crop_square,
          onTap: _startBox,
        ),
        const SizedBox(height: 16),
        _ModeCard(
          title: '4-7-8 Breathing',
          subtitle: 'Inhale 4 · Hold 7 · Exhale 8\n4 cycles (~76 seconds)',
          icon: Icons.air,
          onTap: _startExtended,
        ),
        const SizedBox(height: 16),
        const Text(
          'Both patterns activate the parasympathetic\nnervous system — rest and digest.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildExercise() {
    final progress = _totalSeconds > 0 ? 1.0 - (_remaining / _totalSeconds) : 0.0;
    final isDone = _remaining <= 0;
    final isExtended = _mode == _BreathMode.extended;
    final breathScale = isExtended
        ? (_extendedPhase == _BreathPhase.exhale ? 0.75 : 1.1)
        : Tween<double>(begin: 0.75, end: 1.15)
            .animate(CurvedAnimation(
                parent: _breathController, curve: Curves.easeInOut))
            .value;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.of(context).maybePop();
            },
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ),
        const Spacer(),
        Text(
          isDone
              ? 'You showed up for yourself.'
              : isExtended
                  ? '$_phase ${_phaseSecondsLeft > 0 ? "($_phaseSecondsLeft s)" : ""}'
                  : _phase,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        ScaleTransition(
          scale: AlwaysStoppedAnimation(breathScale),
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.9),
                  const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          isDone ? 'Done' : '$_remaining s',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFF1E293B),
            color: const Color(0xFF38BDF8),
          ),
        ),
        const Spacer(),
        Text(
          isExtended
              ? 'Inhale through your nose.\nExhale slowly through your mouth.'
              : 'Feel your feet on the floor.\nName one thing you can see.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF38BDF8), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13,
                            height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
