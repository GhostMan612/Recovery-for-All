// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/dashboard_providers.dart
//
// Phase 7 — dashboard state ownership.
//
// The dashboard used to hold every one of these fields as local State. They are
// persisted user preferences, so they belong to a notifier: that gives them one
// owner, makes them independently testable, and keeps the widget responsible
// only for presentation and navigation.
//
// Ephemeral interaction state (edit mode, tap-debounce timestamps) deliberately
// stays local to the widget — it is meaningless anywhere else.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/recovery_database.dart';
import '../services/raid_service.dart';
import '../services/recovery_pet_service.dart';
import 'meeting_radius_logic.dart' show MeetingRadiusPrefs;
import 'providers.dart' show databaseProvider;

/// Alias so this file names the keys the same way it names its own state.
class MeetingRadiusKeys {
  MeetingRadiusKeys._();
  static const String lat = MeetingRadiusPrefs.latKey;
  static const String lng = MeetingRadiusPrefs.lngKey;
  static const String time = MeetingRadiusPrefs.timeKey;
  static const String enforce = MeetingRadiusPrefs.enforceKey;
}

/// Which dashboard tab is showing. Kept separate from domain state so
/// navigation can change without re-running a data loader.
class DashboardTab {
  static const int path = 0;
  static const int library = 1;
}

/// Ordering + visibility of the dashboard's tool and library cards.
class DashboardLayout {
  final List<String> toolOrder;
  final List<String> libraryOrder;
  final Set<String> hiddenTools;
  final Set<String> hiddenLibrary;

  const DashboardLayout({
    this.toolOrder = const [],
    this.libraryOrder = const [],
    this.hiddenTools = const {},
    this.hiddenLibrary = const {},
  });

  DashboardLayout copyWith({
    List<String>? toolOrder,
    List<String>? libraryOrder,
    Set<String>? hiddenTools,
    Set<String>? hiddenLibrary,
  }) {
    return DashboardLayout(
      toolOrder: toolOrder ?? this.toolOrder,
      libraryOrder: libraryOrder ?? this.libraryOrder,
      hiddenTools: hiddenTools ?? this.hiddenTools,
      hiddenLibrary: hiddenLibrary ?? this.hiddenLibrary,
    );
  }

  /// Applies a saved order to a freshly built card list. Unknown ids are
  /// dropped, and cards the user has never seen append in build order, so a
  /// newly shipped card is never hidden by a stale preference.
  List<T> ordered<T>(List<T> cards, String Function(T) labelOf, List<String> order,
      Set<String> hidden) {
    final visible = cards.where((c) => !hidden.contains(labelOf(c))).toList();
    if (order.isEmpty) return visible;
    final byLabel = {for (final c in visible) labelOf(c): c};
    final result = <T>[];
    for (final id in order) {
      final card = byLabel.remove(id);
      if (card != null) result.add(card);
    }
    result.addAll(byLabel.values);
    return result;
  }
}

class DashboardLayoutNotifier extends Notifier<DashboardLayout> {
  static const String toolOrderKey = 'dashboard_tool_order_v1';
  static const String libraryOrderKey = 'dashboard_library_order_v1';
  static const String hiddenToolsKey = 'dashboard_hidden_tools_v1';
  static const String hiddenLibraryKey = 'dashboard_hidden_library_v1';

  @override
  DashboardLayout build() {
    _restore();
    return const DashboardLayout();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final restored = DashboardLayout(
      toolOrder: prefs.getStringList(toolOrderKey) ?? const <String>[],
      libraryOrder: prefs.getStringList(libraryOrderKey) ?? const <String>[],
      hiddenTools: (prefs.getStringList(hiddenToolsKey) ?? const <String>[]).toSet(),
      hiddenLibrary:
          (prefs.getStringList(hiddenLibraryKey) ?? const <String>[]).toSet(),
    );
    if (restored.toolOrder.isNotEmpty ||
        restored.libraryOrder.isNotEmpty ||
        restored.hiddenTools.isNotEmpty ||
        restored.hiddenLibrary.isNotEmpty) {
      state = restored;
    }
  }

  Future<void> saveToolOrder(List<String> order, Set<String> hidden) async {
    state = state.copyWith(toolOrder: order, hiddenTools: hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(toolOrderKey, order);
    await prefs.setStringList(hiddenToolsKey, hidden.toList());
  }

  Future<void> saveLibraryOrder(List<String> order, Set<String> hidden) async {
    state = state.copyWith(libraryOrder: order, hiddenLibrary: hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(libraryOrderKey, order);
    await prefs.setStringList(hiddenLibraryKey, hidden.toList());
  }

  Future<void> resetAll() async {
    state = const DashboardLayout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(toolOrderKey);
    await prefs.remove(libraryOrderKey);
    await prefs.remove(hiddenToolsKey);
    await prefs.remove(hiddenLibraryKey);
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, DashboardLayout>(
        DashboardLayoutNotifier.new);

/// Last known device location plus the user's radius-filter preference.
class MeetingRadiusState {
  final double? lat;
  final double? lng;
  final int? cachedAtMs;
  final bool enforce;

  const MeetingRadiusState({this.lat, this.lng, this.cachedAtMs, this.enforce = true});

  bool get hasFix => lat != null && lng != null;
}

class MeetingRadiusNotifier extends Notifier<MeetingRadiusState> {
  @override
  MeetingRadiusState build() {
    _restore();
    return const MeetingRadiusState();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final restored = MeetingRadiusState(
      lat: prefs.getDouble(MeetingRadiusKeys.lat),
      lng: prefs.getDouble(MeetingRadiusKeys.lng),
      cachedAtMs: prefs.getInt(MeetingRadiusKeys.time),
      enforce: prefs.getBool(MeetingRadiusKeys.enforce) ?? true,
    );
    if (restored.hasFix || !restored.enforce) {
      state = restored;
    }
  }

  Future<void> setEnforce(bool value) async {
    state = MeetingRadiusState(
      lat: state.lat,
      lng: state.lng,
      cachedAtMs: state.cachedAtMs,
      enforce: value,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(MeetingRadiusKeys.enforce, value);
  }
}

final meetingRadiusProvider =
    NotifierProvider<MeetingRadiusNotifier, MeetingRadiusState>(
        MeetingRadiusNotifier.new);

/// Has the user made their daily pledge today? Persisted as a date string so a
/// new day resets it without a background job.
class DailyPledgeNotifier extends Notifier<bool> {
  static const String key = 'daily_pledge_date';

  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final pledged = prefs.getString(key) == _today();
    if (pledged) state = true;
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> markPledged() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _today());
  }
}

final dailyPledgeProvider =
    NotifierProvider<DailyPledgeNotifier, bool>(DailyPledgeNotifier.new);

/// The user's saved constellation sky name.
/// Async domain state the dashboard needs on open: who the user is, their pet,
/// and any active community raid. Owned here rather than in the widget so the
/// load order is explicit and testable (pet before the XP bar, profile before
/// the sponsor phone), and so a tab switch cannot accidentally re-trigger a
/// load.
class DashboardDataState {
  final Profile? profile;
  final RecoveryPet? pet;
  final ActiveRaid? raid;
  final bool loading;

  const DashboardDataState({
    this.profile,
    this.pet,
    this.raid,
    this.loading = true,
  });

  DashboardDataState copyWith({
    Profile? profile,
    RecoveryPet? pet,
    ActiveRaid? raid,
    bool? loading,
  }) {
    return DashboardDataState(
      profile: profile ?? this.profile,
      pet: pet ?? this.pet,
      raid: raid ?? this.raid,
      loading: loading ?? this.loading,
    );
  }

  String get username {
    final name = profile?.anonymousUsername;
    if (name == null || name.isEmpty) return 'Friend';
    return name;
  }

  /// The profile stores these as JSON arrays; a malformed value must degrade
  /// to an empty list rather than taking down the dashboard.
  static List<String> decodeList(String? json) {
    if (json == null || json.isEmpty) return <String>[];
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  List<String> get paths => decodeList(profile?.activePaths);
  List<String> get tools => decodeList(profile?.selectedValues);
  String? get sponsorPhone => profile?.sponsorPhone;
}

class DashboardDataNotifier extends Notifier<DashboardDataState> {
  @override
  DashboardDataState build() {
    _load();
    return const DashboardDataState();
  }

  Future<void> _load() async {
    final db = ref.watch(databaseProvider);
    final profile = await db.getProfile('active_user_profile');
    final pet = await RecoveryPetService.ensureHatched();
    if (!ref.mounted) return;
    state = state.copyWith(profile: profile, pet: pet, loading: false);
    // Raid lookup is best-effort: a raid miss must not block the dashboard.
    try {
      final raid = await RaidService.getActiveRaid(db);
      if (!ref.mounted) return;
      state = state.copyWith(raid: raid);
    } catch (_) {}
  }

  Future<void> refreshPet() async {
    final pet = await RecoveryPetService.ensureHatched();
    if (!ref.mounted) return;
    state = state.copyWith(pet: pet);
  }

  Future<void> refreshProfile() async {
    final db = ref.watch(databaseProvider);
    final profile = await db.getProfile('active_user_profile');
    if (!ref.mounted) return;
    state = state.copyWith(profile: profile);
  }

  Future<void> setPet(RecoveryPet pet) async {
    if (!ref.mounted) return;
    state = state.copyWith(pet: pet);
  }

  Future<void> setRaid(ActiveRaid raid) async {
    if (!ref.mounted) return;
    state = state.copyWith(raid: raid);
  }
}

final dashboardDataProvider =
    NotifierProvider<DashboardDataNotifier, DashboardDataState>(
        DashboardDataNotifier.new);

class SkyNameNotifier extends Notifier<String?> {
  static const String key = 'constellation_sky_name_v1';

  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final name = prefs.getString(key);
    if (name != null && name.isNotEmpty) state = name;
  }

  Future<void> setName(String value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

final skyNameProvider = NotifierProvider<SkyNameNotifier, String?>(
    SkyNameNotifier.new);
