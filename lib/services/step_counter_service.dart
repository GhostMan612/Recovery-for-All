// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recovery_pet_service.dart';

class StepCounterService {
  StepCounterService._();

  static final StepCounterService _instance = StepCounterService._();
  static StepCounterService get instance => _instance;

  static const int minStepsForWalk = 500;
  static const Duration walkTimeWindow = Duration(minutes: 30);

  static const List<int> stepMilestones = [1000, 2500, 5000, 7500, 10000, 12500, 15000];
  static const int sparksPerMilestone = 5;

  static const MethodChannel _foregroundChannel =
      MethodChannel('com.recoveryforall/step_counter');

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  int _lastStepCount = 0;
  int _walkStartSteps = 0;
  DateTime? _walkStartTime;
  bool _isTrackingWalk = false;
  bool _autoVerifyEnabled = true;

  int? _initialSensorSteps;
  int? _sensorOffset;
  int? _rawSensorValue;
  int? _lastRawStep;
  DateTime? _lastValidatedTime;

  static const Duration _stepDebounce = Duration(milliseconds: 380);
  static const int _minStepIntervalMs = 380;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastStepCount = prefs.getInt('last_step_count') ?? 0;

    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        developer.log('[step_counter] Activity recognition not granted: $status — deferred until walk');
        await _resetDailyStepsIfNewDay();
        await _checkAndAwardMilestones();
        developer.log('[step_counter] Initialized (no pedometer) with $_lastStepCount steps');
        return;
      }
    } catch (e) {
      developer.log('[step_counter] Permission check failed: $e');
    }

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(_onStepCount);
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(_onPedestrianStatus);
      developer.log('[step_counter] Pedometer streams started');
    } catch (e) {
      developer.log('[step_counter] Pedometer not available: $e');
    }

    await _resetDailyStepsIfNewDay();
    await _checkAndAwardMilestones();
    
    developer.log('[step_counter] Initialized with $_lastStepCount steps');
  }

  void _onStepCount(StepCount event) async {
    final now = DateTime.now();
    final incoming = event.steps;
    _rawSensorValue = incoming;

    if (_lastRawStep != null) {
      final rawDelta = incoming - _lastRawStep!;
      if (rawDelta <= 0) {
        if (incoming < (_sensorOffset ?? incoming)) {
          _sensorOffset = incoming;
          final prefsReboot = await SharedPreferences.getInstance();
          await prefsReboot.setInt('step_sensor_offset_v1', _sensorOffset!);
          _lastStepCount = 0;
          await _updateDailySteps(0);
          if (_isTrackingWalk) {
            _initialSensorSteps = incoming;
          }
        }
        _lastRawStep = incoming;
        _lastValidatedTime = now;
        return;
      }
      final timeDeltaMs = _lastValidatedTime == null
          ? _stepDebounce.inMilliseconds
          : now.difference(_lastValidatedTime!).inMilliseconds;
      if (timeDeltaMs < 0) {
        _lastRawStep = incoming;
        _lastValidatedTime = now;
        return;
      }
      final avgInterval = timeDeltaMs / rawDelta;
      if (avgInterval < _minStepIntervalMs) {
        final allowed = (timeDeltaMs / _minStepIntervalMs).floor().clamp(0, rawDelta);
        if (allowed == 0) {
          return;
        }
        if (allowed < rawDelta) {
          final extra = rawDelta - allowed;
          _sensorOffset = (_sensorOffset ?? incoming) + extra;
          final prefsAdjust = await SharedPreferences.getInstance();
          await prefsAdjust.setInt('step_sensor_offset_v1', _sensorOffset!);
          if (_isTrackingWalk && _initialSensorSteps != null) {
            _initialSensorSteps = _initialSensorSteps! + extra;
          }
          _lastRawStep = incoming;
          _lastValidatedTime = now;
          final today = DateTime.now();
          final todayKey = '${today.year}-${today.month}-${today.day}';
          final storedDate = prefsAdjust.getString('daily_steps_date_v1');
          if (storedDate == todayKey) {
            final computedDaily = (incoming - _sensorOffset!).clamp(0, 1 << 30);
            final previousDaily = _lastStepCount;
            _lastStepCount = computedDaily;
            await _updateDailySteps(_lastStepCount);
            await _checkAndAwardMilestones(previousSteps: previousDaily);
          }
          return;
        }
      }
    }
    _lastRawStep = incoming;
    _lastValidatedTime = now;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final storedDate = prefs.getString('daily_steps_date_v1');

    _sensorOffset ??= prefs.getInt('step_sensor_offset_v1');

    if (storedDate != todayKey) {
      _sensorOffset = incoming;
      await prefs.setInt('step_sensor_offset_v1', _sensorOffset!);
      await prefs.setString('daily_steps_date_v1', todayKey);
      await prefs.setInt('daily_steps_v1', 0);
      await prefs.setInt('daily_sparks_awarded_v1', 0);
      await prefs.setInt('last_sparks_award_step_v1', 0);
      _lastStepCount = 0;
      if (_isTrackingWalk && _initialSensorSteps == null) {
        _initialSensorSteps = incoming;
      }
      await _updateDailySteps(0);
      return;
    }

    if (_sensorOffset == null) {
      _sensorOffset = incoming;
      await prefs.setInt('step_sensor_offset_v1', _sensorOffset!);
      _lastStepCount = 0;
      await _updateDailySteps(0);
      if (_isTrackingWalk && _initialSensorSteps == null) {
        _initialSensorSteps = incoming;
      }
      return;
    }

    if (incoming < _sensorOffset!) {
      _sensorOffset = incoming;
      await prefs.setInt('step_sensor_offset_v1', _sensorOffset!);
      _lastStepCount = 0;
      await _updateDailySteps(0);
      if (_isTrackingWalk) {
        _initialSensorSteps = incoming;
      }
      return;
    }

    if (_isTrackingWalk && _initialSensorSteps == null) {
      _initialSensorSteps = incoming;
    }

    final previousDaily = _lastStepCount;
    final computedDaily = (incoming - _sensorOffset!).clamp(0, 1 << 30);
    _lastStepCount = computedDaily;

    await _updateDailySteps(_lastStepCount);
    await _checkAndAwardMilestones(previousSteps: previousDaily);

    if (_isTrackingWalk && _initialSensorSteps != null) {
      final currentWalk = (incoming - _initialSensorSteps!).clamp(0, 1 << 30);
      if (currentWalk >= minStepsForWalk && _autoVerifyEnabled) {
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

  int getDailySteps() => _lastStepCount;

  Future<int> getDailyStepsAsync() async {
    await _resetDailyStepsIfNewDay();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_steps_v1') ?? _lastStepCount;
  }

  Future<void> _resetDailyStepsIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final storedDate = prefs.getString('daily_steps_date_v1');

    if (storedDate != todayKey) {
      await prefs.setString('daily_steps_date_v1', todayKey);
      await prefs.setInt('daily_steps_v1', 0);
      await prefs.setInt('daily_sparks_awarded_v1', 0);
      await prefs.setInt('last_sparks_award_step_v1', 0);
      _lastStepCount = 0;
      if (_rawSensorValue != null) {
        _sensorOffset = _rawSensorValue;
        await prefs.setInt('step_sensor_offset_v1', _sensorOffset!);
      } else {
        final storedOffset = prefs.getInt('step_sensor_offset_v1');
        if (storedOffset != null) {
          _sensorOffset = storedOffset;
        }
      }
      developer.log('[step_counter] New day - steps reset');
    } else {
      _lastStepCount = prefs.getInt('daily_steps_v1') ?? 0;
      _sensorOffset = prefs.getInt('step_sensor_offset_v1');
      if (_rawSensorValue != null && _sensorOffset != null) {
        final recomputed = (_rawSensorValue! - _sensorOffset!).clamp(0, 1 << 30);
        if (recomputed != _lastStepCount) {
          _lastStepCount = recomputed;
          await prefs.setInt('daily_steps_v1', _lastStepCount);
        }
      }
    }
  }

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
    await RecoveryPetService.logWalk(requireVerification: false);
    developer.log('[step_counter] Awarded $sparksPerMilestone Sparks for $milestone steps milestone');
  }

  Future<bool> hasPermissionBeenRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pedometer_permission_requested_v1') ?? false;
  }

  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pedometer_permission_requested_v1', true);
  }

  void setAutoVerify(bool enabled) {
    _autoVerifyEnabled = enabled;
  }

  Future<void> startWalkTracking() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      developer.log('[step_counter] startWalkTracking denied: $status');
      return;
    }
    await markPermissionRequested();
    _isTrackingWalk = true;
    _initialSensorSteps = _rawSensorValue;
    _walkStartSteps = _lastStepCount;
    _walkStartTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walk_verification_steps_v1', _walkStartSteps);
    await prefs.setInt('walk_start_time_v1', _walkStartTime!.millisecondsSinceEpoch);
    await prefs.setBool('walk_verified_v1', false);
    if (_rawSensorValue != null && _initialSensorSteps == null) {
      _initialSensorSteps = _rawSensorValue;
    }

    try {
      await _foregroundChannel.invokeMethod('startForegroundService');
      developer.log('[step_counter] foreground health service started — Walk Tracking Active');
    } catch (e) {
      developer.log('[step_counter] foreground start failed: $e');
    }
  }

  Future<bool> stopWalkTracking() async {
    _isTrackingWalk = false;

    try {
      await _foregroundChannel.invokeMethod('stopForegroundService');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    int stepsSinceStart = 0;
    if (_rawSensorValue != null && _initialSensorSteps != null) {
      stepsSinceStart = (_rawSensorValue! - _initialSensorSteps!).clamp(0, 1 << 30);
    } else if (_initialSensorSteps != null) {
      stepsSinceStart = (_lastStepCount - _initialSensorSteps!).clamp(0, 1 << 30);
      if (stepsSinceStart < 0) stepsSinceStart = getCurrentWalkSteps();
    } else {
      stepsSinceStart = getCurrentWalkSteps();
    }
    final elapsed = DateTime.now().difference(_walkStartTime ?? DateTime.now());

    final verified = stepsSinceStart >= minStepsForWalk && elapsed <= walkTimeWindow;
    await prefs.setBool('walk_verified_v1', verified);
    await prefs.setInt('last_step_count', _lastStepCount);
    await prefs.setInt('daily_steps_v1', _lastStepCount);

    if (verified) {
      await RecoveryPetService.logWalk(requireVerification: false);
      developer.log('[step_counter] Walk verified - awarded 15 Sparks');
    }

    _initialSensorSteps = null;
    return verified;
  }

  Future<void> _autoVerifyWalk() async {
    if (!_isTrackingWalk || !_autoVerifyEnabled) return;
    
    _autoVerifyEnabled = false;
    
    await stopWalkTracking();
    await Future.delayed(const Duration(seconds: 2));
    _autoVerifyEnabled = true;
  }

  Future<void> manuallyVerifyWalk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('walk_verified_v1', true);
  }

  int getCurrentWalkSteps() {
    if (!_isTrackingWalk) return 0;
    if (_rawSensorValue != null && _initialSensorSteps != null) {
      return (_rawSensorValue! - _initialSensorSteps!).clamp(0, 1 << 30);
    }
    if (_initialSensorSteps != null) {
      return (_lastStepCount - _initialSensorSteps!).clamp(0, 1 << 30);
    }
    return 0;
  }

  bool get isTrackingWalk => _isTrackingWalk;

  Duration? getCurrentWalkElapsed() {
    if (!_isTrackingWalk || _walkStartTime == null) return null;
    return DateTime.now().difference(_walkStartTime!);
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
  }
}