// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/llama_ffi_service.dart';
import '../services/local_embedding_service.dart';
import '../services/meeting_finder_service.dart';
import '../services/nwi_progress_service.dart';
import '../services/ollama_service.dart';
import '../services/safety_guardrail_service.dart';
import '../services/sos_notification_service.dart';

final databaseProvider = Provider<RecoveryDatabase>((ref) {
  final db = RecoveryDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  return OllamaService(
    baseUrl: 'http://192.168.4.144:8000',
    modelName: 'qwen2.5',
  );
});

final llamaFfiServiceProvider = Provider<LlamaFfiService>((ref) {
  final service = LlamaFfiService();
  ref.onDispose(() => service.unloadModel());
  return service;
});

final localEmbeddingServiceProvider = Provider<LocalEmbeddingService>((ref) {
  return LocalEmbeddingService();
});

final meetingFinderServiceProvider = Provider<MeetingFinderService>((ref) {
  return MeetingFinderService();
});

final nwiProgressServiceProvider = Provider<NwiProgressService>((ref) {
  return NwiProgressService();
});

final safetyGuardrailServiceProvider = Provider<SafetyGuardrailService>((ref) {
  return SafetyGuardrailService();
});

final sosNotificationServiceProvider = Provider<SosNotificationService>((ref) {
  return SosNotificationService();
});

/// Restores the persistent SOS lifeline from the stored profile.
///
/// Named to make the side effect explicit. This used to be called
/// `startSosFromProfileProvider` and returned void, so it read like a query —
/// the natural next edit was `ref.watch(...)` for a bool, which would have
/// fired the crisis notification. `main.dart` already performs this same
/// restore at boot, so wiring it up would have started the lifeline twice.
/// Keep it opt-in.
final restoreSosLifelineProvider = FutureProvider.autoDispose((ref) async {
  final db = ref.watch(databaseProvider);
  final profile = await db.getProfile('active_user_profile');
  if (profile == null) return false;

  await SosNotificationService.startPersistentSos(
    sponsorPhone: profile.sponsorPhone,
    customHelpPhone: profile.customHelpPhone,
  );
  return true;
});

final countersProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCounters();
});

final recentJournalsProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentJournals();
});

final constellationPointsProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchConstellationPoints();
});

final weeklyGoalsProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWeeklyGoals();
});

final activeProfileProvider = FutureProvider.autoDispose((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getProfile('active_user_profile');
});

/// AsyncValue, not a collapsed bool: the previous shape used `orElse: () =>
/// false`, which reports "the user has not onboarded" both while Drift is still
/// reading and when the read throws. Any routing guard built on it would bounce
/// a returning user into onboarding. Callers can now distinguish
/// `isLoading` / `hasError` from a genuinely absent profile.
///
/// A `FutureProvider`, not a `Provider` over a FutureProvider, so a caller can
/// `await ...future` directly. `SplashScreen` does exactly that: it must know
/// the answer before it can route, and awaiting the provider's `.future` gives
/// it the value without a second subscription or a loading callback. Reading it
/// still yields `AsyncValue<bool>`, so the staleness test's type assertion
/// still compiles — which is deliberate, because that assertion is the contract.
final hasCompletedOnboardingProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final profile = await ref.watch(activeProfileProvider.future);
  return profile != null;
});

class ThemeNotifier extends Notifier<ThemePreference> {
  static const _paletteKey = 'theme_preference_v1';
  @override
  ThemePreference build() {
    _restore();
    return const ThemePreference();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    // The read and the write are separated by a getInstance() await. If the
    // user changed the theme inside that window, this write put the STALE read
    // value back into state while the newer choice was already on disk — disk
    // and UI then disagreed until the next launch. A generation counter
    // incremented by every setter lets us detect exactly that.
    final gen = _generation;
    final restored = ThemePreference.fromJson({
      'palette': prefs.getString(_paletteKey) ?? '',
      'mode': prefs.getString(ThemePreference.modeKey) ?? '',
    });
    if (!ref.mounted || gen != _generation) return;
    if (restored.palette != state.palette || restored.mode != state.mode) {
      state = restored;
    }
  }

  int _generation = 0;

  Future<void> setPalette(AppTheme palette) async {
    _generation++;
    state = ThemePreference(palette: palette, mode: state.mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }

  Future<void> setMode(AppThemeMode mode) async {
    _generation++;
    state = ThemePreference(palette: state.palette, mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ThemePreference.modeKey, mode.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemePreference>(ThemeNotifier.new);