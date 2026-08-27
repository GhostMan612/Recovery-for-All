// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/services/step_counter_service.dart
//
// Step counter service using pedometer plugin.
// Verifies actual walking movement before awarding Sparks.
// Offline-first, respects privacy — no cloud upload.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  StepCounterService._();

  static final StepCounterService _instance = StepCounterService._();
  static StepCounterService get instance => _instance;

  static const String _keyWalkSteps = 'walk_verification_steps_v1';
  static const String _keyWalkStartTime = 'walk_start_time_v1';
  static const String _keyWalkVerified = 'walk_verified_v1';

  /// Minimum steps required to verify a walk (approx. 500 steps = ~5 min walk)
  static const int minStepsForWalk = 500;

  /// Maximum time window for a walk session (30 minutes)
  static const Duration walkTimeWindow = Duration(minutes: 30);

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  int _lastStepCount = 0;
  int _walkStartSteps = 0;
  DateTime? _walkStartTime;
  bool _isTrackingWalk = false;

  /// Initialize step counter
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastStepCount = prefs.getInt('last_step_count') ?? 0;

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(_onStepCount);
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(_onPedestrianStatus);
    } catch (e) {
      // Pedometer not available on this device
      developer.log('[step_counter] Pedometer not available: $e');
    }
  }

  void _onStepCount(StepCount event) {
    _lastStepCount = event.steps;
    if (_isTrackingWalk) {
      final stepsSinceStart = _lastStepCount - _walkStartSteps;
      if (stepsSinceStart >= minStepsForWalk) {
        // Walk threshold reached - verification will happen on stop
      }
    }
  }

  void _onPedestrianStatus(PedestrianStatus status) {
    // Optional: track walking vs running vs stopped
  }

  /// Start tracking a walk session
  Future<void> startWalkTracking() async {
    _isTrackingWalk = true;
    _walkStartSteps = _lastStepCount;
    _walkStartTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWalkSteps, _walkStartSteps);
    await prefs.setInt(_keyWalkStartTime, _walkStartTime!.millisecondsSinceEpoch);
    await prefs.setBool(_keyWalkVerified, false);
  }

  /// Stop tracking and check if walk is verified
  Future<bool> stopWalkTracking() async {
    _isTrackingWalk = false;

    final prefs = await SharedPreferences.getInstance();
    final stepsSinceStart = _lastStepCount - _walkStartSteps;
    final elapsed = DateTime.now().difference(_walkStartTime ?? DateTime.now());

    final verified = stepsSinceStart >= minStepsForWalk && elapsed <= walkTimeWindow;
    await prefs.setBool(_keyWalkVerified, verified);
    await prefs.setInt('last_step_count', _lastStepCount);

    return verified;
  }

  /// Check if current walk session is verified
  Future<bool> isWalkVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWalkVerified) ?? false;
  }

  /// Get steps taken in current walk session
  int getCurrentWalkSteps() {
    if (!_isTrackingWalk) return 0;
    return _lastStepCount - _walkStartSteps;
  }

  /// Get elapsed time in current walk session
  Duration? getCurrentWalkElapsed() {
    if (!_isTrackingWalk || _walkStartTime == null) return null;
    return DateTime.now().difference(_walkStartTime!);
  }

  /// Manually verify a walk (for testing or when pedometer unavailable)
  Future<void> manuallyVerifyWalk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWalkVerified, true);
  }

  /// Reset walk verification state
  Future<void> resetWalkState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWalkSteps);
    await prefs.remove(_keyWalkStartTime);
    await prefs.remove(_keyWalkVerified);
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
  }
}