// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/recovery_pet_service.dart';

/// Full-screen 60-second box-breathing / grounding exercise.
/// Designed for crisis: large targets, minimal text, no guilt.
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen>
    with SingleTickerProviderStateMixin {
  static const int totalSeconds = 60;
  int _remaining = totalSeconds;
  Timer? _timer;
  late AnimationController _breathController;
  String _phase = 'Inhale';

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathController.addListener(() {
      final v = _breathController.value;
      final next = v < 0.5 ? 'Inhale' : 'Exhale';
      if (next != _phase && mounted) {
        setState(() => _phase = next);
      }
    });

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

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_remaining / totalSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ),
              const Spacer(),
              Text(
                _remaining == 0 ? 'You showed up for yourself.' : _phase,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ScaleTransition(
                scale: Tween<double>(begin: 0.75, end: 1.15).animate(
                  CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
                ),
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
                _remaining == 0 ? 'Done' : '$_remaining s',
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
              const Text(
                'Feel your feet on the floor.\nName one thing you can see.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
