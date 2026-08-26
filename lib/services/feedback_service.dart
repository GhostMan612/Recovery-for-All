// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/feedback_service.dart
//
// Toggle-able sound effects + haptics for reward moments. Both default
// ON but respect the Settings toggles; every call is fire-and-forget and
// never throws into the caller's flow.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedbackSound { spark, milestone, star, hit, shield, heal, defeat }

enum FeedbackHaptic { light, medium, heavy, tick }

class FeedbackService {
  static const String _keySound = 'feedback_sound_v1';
  static const String _keyHaptics = 'feedback_haptics_v1';

  static final AudioPlayer _player = AudioPlayer();

  static Future<bool> soundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySound) ?? true;
  }

  static Future<void> setSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, value);
  }

  static Future<bool> hapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHaptics) ?? true;
  }

  static Future<void> setHaptics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, value);
  }

  static Future<void> _play(FeedbackSound sound) async {
    try {
      if (!await soundEnabled()) return;
      final file = switch (sound) {
        FeedbackSound.spark => 'sounds/spark.wav',
        FeedbackSound.milestone => 'sounds/milestone.wav',
        FeedbackSound.star => 'sounds/star.wav',
        FeedbackSound.hit => 'sounds/hit.wav',
        FeedbackSound.shield => 'sounds/shield.wav',
        FeedbackSound.heal => 'sounds/heal.wav',
        FeedbackSound.defeat => 'sounds/defeat.wav',
      };
      await _player.stop();
      await _player.play(AssetSource(file));
    } catch (_) {
      // Audio garnish — never a blocker.
    }
  }

  static Future<void> _haptic(FeedbackHaptic kind) async {
    try {
      if (!await hapticsEnabled()) return;
      switch (kind) {
        case FeedbackHaptic.light:
          await HapticFeedback.lightImpact();
        case FeedbackHaptic.medium:
          await HapticFeedback.mediumImpact();
        case FeedbackHaptic.heavy:
          await HapticFeedback.heavyImpact();
        case FeedbackHaptic.tick:
          await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Small reward (check-in, journal, gratitude, meeting…).
  static Future<void> reward() async {
    await _haptic(FeedbackHaptic.light);
    await _play(FeedbackSound.spark);
  }

  /// Big moment (milestone chip, sponsor sign-off, goal complete).
  static Future<void> milestone() async {
    await _haptic(FeedbackHaptic.heavy);
    await _play(FeedbackSound.milestone);
  }

  /// Constellation star added.
  static Future<void> star() async {
    await _haptic(FeedbackHaptic.medium);
    await _play(FeedbackSound.star);
  }

  /// Subtle selection tick (haptics only, no sound).
  static Future<void> selection() => _haptic(FeedbackHaptic.tick);

  static Future<void> battleHit() async {
    await _haptic(FeedbackHaptic.medium);
    await _play(FeedbackSound.hit);
  }

  static Future<void> battleShield() async {
    await _haptic(FeedbackHaptic.light);
    await _play(FeedbackSound.shield);
  }

  static Future<void> battleHeal() async {
    await _haptic(FeedbackHaptic.light);
    await _play(FeedbackSound.heal);
  }

  static Future<void> battleDefeat() async {
    await _haptic(FeedbackHaptic.heavy);
    await _play(FeedbackSound.defeat);
  }
}
