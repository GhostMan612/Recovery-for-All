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

final startSosFromProfileProvider = FutureProvider.autoDispose((ref) async {
  final db = ref.watch(databaseProvider);
  final profile = await db.getProfile('active_user_profile');

  if (profile == null) return;

  await SosNotificationService.startPersistentSos(
    sponsorPhone: profile.sponsorPhone,
    customHelpPhone: profile.customHelpPhone,
  );
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

final hasCompletedOnboardingProvider = Provider.autoDispose<bool>((ref) {
  final profileAsync = ref.watch(activeProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile != null,
    orElse: () => false,
  );
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
    final restored = ThemePreference.fromJson({
      'palette': prefs.getString(_paletteKey) ?? '',
      'mode': prefs.getString(ThemePreference.modeKey) ?? '',
    });
    if (restored.palette != state.palette || restored.mode != state.mode) {
      state = restored;
    }
  }

  Future<void> setPalette(AppTheme palette) async {
    state = ThemePreference(palette: palette, mode: state.mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = ThemePreference(palette: state.palette, mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ThemePreference.modeKey, mode.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemePreference>(ThemeNotifier.new);