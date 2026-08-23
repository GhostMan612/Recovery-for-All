// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'dart:async';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _locked = false;

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

    // Fire-and-forget is safe now: _routeToNextScreen catches everything
    // internally and reports through _bootError.
    _routeToNextScreen();
  }

  Future<void> _tryUnlock() async {
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Unlock your recovery companion',
        options: const AuthenticationOptions(biometricOnly: true),
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
                          DashboardScreen(database: widget.database)),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/splash_bg.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
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