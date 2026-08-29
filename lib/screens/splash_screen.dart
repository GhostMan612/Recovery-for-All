// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:local_auth/local_auth.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';
import '../database/recovery_database.dart';

class SplashScreen extends StatefulWidget {
  final RecoveryDatabase database;
  
  const SplashScreen({super.key, required this.database});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _locked = false;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  /// Boot diagnostics: any startup failure surfaces HERE instead of
  /// hanging on splash forever. Paste this string back when reporting.
  String? _bootError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    _zoomController = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );
    _zoomController.repeat(reverse: true);

    // Fire-and-forget is safe now: _routeToNextScreen catches everything
    // internally and reports through _bootError.
    _routeToNextScreen();
  }

  Future<void> _tryUnlock() async {
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Unlock your recovery companion',
        biometricOnly: true,
      );
      if (ok && mounted) {
        setState(() => _locked = false);
        _routeToNextScreen();
      }
    } catch (e) {
      // Device without enrolled biometrics cannot have the flag set, but if
      // it somehow is — allow PIN-less entry rather than a permanent lockout.
      debugPrint('[splash] biometric unavailable: $e');
      if (mounted) {
        setState(() {
          _locked = false;
          _bootError = null;
        });
        _routeToNextScreen();
      }
    }
  }

  Future<void> _routeToNextScreen() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final profile = await widget.database
          .getProfile('active_user_profile')
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      // Privacy gate: biometric lock applies before anything else loads.
      if (profile?.biometricLockEnabled ?? false) {
        setState(() => _locked = true);
        unawaited(_tryUnlock());
        return;
      }

      if (profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(
              database: widget.database,
              onOnboardingComplete: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          DashboardScreen(database: widget.database, isFirstLaunch: true)),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => DashboardScreen(database: widget.database)),
        );
      }
    } catch (e, stack) {
      debugPrint('[splash] BOOT FAILURE: $e\n$stack');
      if (mounted) {
        setState(() => _bootError =
            'Startup stalled at: ${e.runtimeType}\n$e');
      }
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 56, color: Color(0xFF38BDF8)),
              const SizedBox(height: 20),
              const Text(
                'This space stays yours.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Unlock to continue — nothing is shared until you say so.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _tryUnlock,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _zoomAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _zoomAnimation.value,
                  child: child,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/splash_bg.jpg',
                          fit: BoxFit.cover,
                        ),
                        // Living sky: stars drift and twinkle over the art.
                        const CustomPaint(
                          painter: _SplashStarField(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Recovery for All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The path you build.',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_bootError != null) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFF87171), width: 1),
                    ),
                    child: SelectableText(
                      '$_bootError',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
/// Twinkling, slowly drifting stars over the splash art — deterministic
/// layout (seeded), animated from the existing zoom controller's clock.
class _SplashStarField extends CustomPainter {
  const _SplashStarField();

  @override
  void paint(Canvas canvas, Size size) {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 42; i++) {
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final y = (baseY - (t * 6 % size.height) + size.height) % size.height;
      final phase = (t * (0.6 + rnd.nextDouble()) + i) % (2 * math.pi);
      final alpha = 0.25 + 0.65 * (0.5 + 0.5 * math.sin(phase));
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.0 + rnd.nextDouble() * 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashStarField oldDelegate) => true;
}