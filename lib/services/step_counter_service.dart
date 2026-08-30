// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/services/step_counter_service.dart
//
// Step counter service using pedometer plugin.
// - Background step counting (foreground service on Android)
// - Verifies actual walking movement before awarding Sparks (walk verification)
// - Tracks daily steps for dashboard display + auto Sparks awards
// - Auto-verifies walks when threshold reached
// Offline-first, respects privacy — no cloud upload.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recovery_pet_service.dart';

class StepCounterService {
  StepCounterService._();

  static final StepCounterService _instance = StepCounterService._();
  static StepCounterService get instance => _instance;

  /// Minimum steps required to verify a walk (approx. 500 steps = ~5 min walk)
  static const int minStepsForWalk = 500;

  /// Maximum time window for a walk session (30 minutes)
  static const Duration walkTimeWindow = Duration(minutes: 30);

  /// Step milestones for Sparks awards
  static const List<int> stepMilestones = [1000, 2500, 5000, 7500, 10000, 12500, 15000];
  static const int sparksPerMilestone = 5;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  int _lastStepCount = 0;
  int _walkStartSteps = 0;
  DateTime? _walkStartTime;
  bool _isTrackingWalk = false;
  bool _autoVerifyEnabled = true;

  /// Initialize step counter with foreground service for background tracking
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastStepCount = prefs.getInt('last_step_count') ?? 0;

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(_onStepCount);
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(_onPedestrianStatus);
      developer.log('[step_counter] Pedometer streams started');
    } catch (e) {
      developer.log('[step_counter] Pedometer not available: $e');
    }

    // Reset daily steps if new day
    await _resetDailyStepsIfNewDay();
    
    // Check for missed milestones on startup
    await _checkAndAwardMilestones();
    
    developer.log('[step_counter] Initialized with $_lastStepCount steps');
  }

  void _onStepCount(StepCount event) {
    final previousSteps = _lastStepCount;
    _lastStepCount = event.steps;
    
    // Update daily steps asynchronously
    _updateDailySteps(_lastStepCount);

    // Check for milestone awards
    _checkAndAwardMilestones(previousSteps: previousSteps);

    if (_isTrackingWalk) {
      final stepsSinceStart = _lastStepCount - _walkStartSteps;
      if (stepsSinceStart >= minStepsForWalk && _autoVerifyEnabled) {
        // Auto-verify walk when threshold reached
        _autoVerifyWalk();
      }
    }
  }

  void _onPedestrianStatus(PedestrianStatus status) {
    developer.log('[step_counter] Pedestrian status: ${status.toString()}');
  }

  Future<void> _updateDailySteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_steps_v1', steps);
    await prefs.setInt('last_step_count', steps);
  }

  /// Get current daily step count
  int getDailySteps() => _lastStepCount;

  /// Get daily steps asynchronously (forces refresh)
  /// Gap D fix: reset at midnight boundary before returning (prevents double-award).
  Future<int> getDailyStepsAsync() async {
    await _resetDailyStepsIfNewDay();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_steps_v1') ?? _lastStepCount;
  }

  /// Reset daily steps if new day
  Future<void> _resetDailyStepsIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final storedDate = prefs.getString('daily_steps_date_v1');
    
    if (storedDate != todayKey) {
      // New day - reset daily steps and awards
      await prefs.setString('daily_steps_date_v1', todayKey);
      await prefs.setInt('daily_steps_v1', 0);
      await prefs.setInt('daily_sparks_awarded_v1', 0);
      await prefs.setInt('last_sparks_award_step_v1', 0);
      _lastStepCount = 0;
      developer.log('[step_counter] New day - steps reset');
    } else {
      _lastStepCount = prefs.getInt('daily_steps_v1') ?? 0;
    }
  }

  /// Check and award step milestones
  Future<void> _checkAndAwardMilestones({int previousSteps = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastAwardStep = prefs.getInt('last_sparks_award_step_v1') ?? 0;
    
    for (final milestone in stepMilestones) {
      if (previousSteps < milestone && _lastStepCount >= milestone && lastAwardStep < milestone) {
        await _awardStepMilestoneSparks(milestone);
        await prefs.setInt('last_sparks_award_step_v1', milestone);
      }
    }
  }

  Future<void> _awardStepMilestoneSparks(int milestone) async {
    // Award sparks (cap-exempt for movement)
    await RecoveryPetService.logWalk(requireVerification: false);
    
    developer.log('[step_counter] Awarded $sparksPerMilestone Sparks for $milestone steps milestone');
  }

  /// Check if pedometer permission has been requested
  Future<bool> hasPermissionBeenRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pedometer_permission_requested_v1') ?? false;
  }

  /// Mark permission as requested
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pedometer_permission_requested_v1', true);
  }

  /// Enable/disable auto-verification
  void setAutoVerify(bool enabled) {
    _autoVerifyEnabled = enabled;
  }

  /// Start tracking a walk session
  Future<void> startWalkTracking() async {
    _isTrackingWalk = true;
    _walkStartSteps = _lastStepCount;
    _walkStartTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walk_verification_steps_v1', _walkStartSteps);
    await prefs.setInt('walk_start_time_v1', _walkStartTime!.millisecondsSinceEpoch);
    await prefs.setBool('walk_verified_v1', false);
  }

  /// Stop tracking and check if walk is verified
  Future<bool> stopWalkTracking() async {
    _isTrackingWalk = false;

    final prefs = await SharedPreferences.getInstance();
    final stepsSinceStart = _lastStepCount - _walkStartSteps;
    final elapsed = DateTime.now().difference(_walkStartTime ?? DateTime.now());

    final verified = stepsSinceStart >= minStepsForWalk && elapsed <= walkTimeWindow;
    await prefs.setBool('walk_verified_v1', verified);
    await prefs.setInt('last_step_count', _lastStepCount);

    if (verified) {
      // Award walk sparks (cap-exempt)
      await RecoveryPetService.logWalk(requireVerification: false);
      developer.log('[step_counter] Walk verified - awarded 15 Sparks');
    }

    return verified;
  }

  /// Auto-verify walk when threshold reached during tracking
  Future<void> _autoVerifyWalk() async {
    if (!_isTrackingWalk || !_autoVerifyEnabled) return;
    
    _autoVerifyEnabled = false; // Prevent double-trigger
    
    await stopWalkTracking();
    await Future.delayed(const Duration(seconds: 2));
    _autoVerifyEnabled = true;
  }

  /// Manually verify a walk (for testing or when pedometer unavailable)
  Future<void> manuallyVerifyWalk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('walk_verified_v1', true);
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