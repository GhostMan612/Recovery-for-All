// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/services/step_counter_service.dart
//
// Step counter service using pedometer plugin.
// - Verifies actual walking movement before awarding Sparks (walk verification)
// - Tracks daily steps for dashboard display (daily step counter)
// Offline-first, respects privacy — no cloud upload.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  StepCounterService._();

  static final StepCounterService _instance = StepCounterService._();
  static StepCounterService get instance => _instance;

  // Walk verification keys
  static const String _keyWalkSteps = 'walk_verification_steps_v1';
  static const String _keyWalkStartTime = 'walk_start_time_v1';
  static const String _keyWalkVerified = 'walk_verified_v1';

  // Daily step counter keys
  static const String _keyDailySteps = 'daily_steps_v1';
  static const String _keyDailyStepsDate = 'daily_steps_date_v1';
  static const String _keyPermissionRequested = 'pedometer_permission_requested_v1';

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

    // Reset daily steps if new day
    await _resetDailyStepsIfNewDay();
  }

  void _onStepCount(StepCount event) {
    _lastStepCount = event.steps;
    
    // Update daily steps asynchronously
    _updateDailySteps(_lastStepCount);

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

  Future<void> _updateDailySteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailySteps, steps);
    await prefs.setInt('last_step_count', steps);
  }

  /// Get current daily step count
  int getDailySteps() => _lastStepCount;

  /// Get daily steps asynchronously (forces refresh)
  Future<int> getDailyStepsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailySteps) ?? _lastStepCount;
  }

  /// Reset daily steps if new day
  Future<void> _resetDailyStepsIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final storedDate = prefs.getString(_keyDailyStepsDate);
    
    if (storedDate != todayKey) {
      // New day - reset daily steps
      await prefs.setString(_keyDailyStepsDate, todayKey);
      await prefs.setInt(_keyDailySteps, 0);
      _lastStepCount = 0;
    } else {
      _lastStepCount = prefs.getInt(_keyDailySteps) ?? 0;
    }
  }

  /// Check if pedometer permission has been requested
  Future<bool> hasPermissionBeenRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPermissionRequested) ?? false;
  }

  /// Mark permission as requested
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPermissionRequested, true);
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

  /// Manually verify a walk (for testing or when pedometer unavailable)
  Future<void> manuallyVerifyWalk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWalkVerified, true);
  }

  /// Get current walk session steps
  int getCurrentWalkSteps() {
    if (!_isTrackingWalk) return 0;
    return _lastStepCount - _walkStartSteps;
  }

  /// Get current walk session elapsed time
  Duration? getCurrentWalkElapsed() {
    if (!_isTrackingWalk || _walkStartTime == null) return null;
    return DateTime.now().difference(_walkStartTime!);
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
  }
}