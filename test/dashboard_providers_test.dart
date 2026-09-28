// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/dashboard_providers_test.dart
//
// Phase 7 gate: state extracted from the dashboard widget must be independently
// testable AND behaviour-preserving. These tests pin the two things that were
// easy to get wrong in the move:
//   * ordering/hiding semantics, including "a new card is never hidden by a
//     stale preference", and
//   * persistence round-trips through the existing key names, because a key
//     rename would silently reset every existing user's layout.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recovery_for_all/core/dashboard_providers.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardLayout.ordered', () {
    final cards = ['a', 'b', 'c', 'd'];

    test('returns build order when no preference is stored', () {
      const layout = DashboardLayout();
      expect(layout.ordered(cards, (c) => c, const [], const {}), cards);
    });

    test('applies a stored order', () {
      const layout = DashboardLayout();
      expect(
        layout.ordered(cards, (c) => c, ['c', 'a'], const {}),
        ['c', 'a', 'b', 'd'],
      );
    });

    test('hides cards in the hidden set', () {
      const layout = DashboardLayout();
      expect(
        layout.ordered(cards, (c) => c, const [], {'b', 'd'}),
        ['a', 'c'],
      );
    });

    test('drops ids that no longer exist, and never hides a new card',
        () {
      // 'zz' was removed from the app; 'd' is brand new and unlisted.
      const layout = DashboardLayout();
      final result = layout.ordered(cards, (c) => c, ['c', 'zz'], const {'a'});
      expect(result, ['c', 'b', 'd'],
          reason: 'unknown ids drop, new cards still appear');
    });
  });

  group('DashboardLayoutNotifier persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('saveToolOrder round-trips under the pre-existing key', () async {
      final c = _container();
      await c.read(dashboardLayoutProvider.notifier).saveToolOrder(
            ['b', 'a'],
            {'z'},
          );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('dashboard_tool_order_v1'), ['b', 'a']);
      expect(prefs.getStringList('dashboard_hidden_tools_v1'), ['z']);
    });

    test('restores a previously saved layout', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_tool_order_v1': <String>['b', 'a'],
        'dashboard_hidden_library_v1': <String>['q'],
      });
      final c = _container();
      await Future<void>.delayed(Duration.zero);
      c.read(dashboardLayoutProvider);
      await Future<void>.delayed(Duration.zero);
      final s = c.read(dashboardLayoutProvider);
      expect(s.toolOrder, ['b', 'a']);
      expect(s.hiddenLibrary, {'q'});
    });

    test('resetAll clears persisted layout', () async {
      final c = _container();
      await c.read(dashboardLayoutProvider.notifier)
          .saveLibraryOrder(['x'], {'y'});
      await c.read(dashboardLayoutProvider.notifier).resetAll();
      final s = c.read(dashboardLayoutProvider);
      expect(s.libraryOrder, isEmpty);
      expect(s.hiddenLibrary, isEmpty);
    });
  });

  group('MeetingRadiusNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to enforcing the radius with no cached fix', () {
      final c = _container();
      final s = c.read(meetingRadiusProvider);
      expect(s.enforce, isTrue);
      expect(s.hasFix, isFalse);
    });

    test('restores a cached fix and the stored enforce flag', () async {
      SharedPreferences.setMockInitialValues({
        'last_known_location_lat_v1': 44.9778,
        'last_known_location_lng_v1': -93.2650,
        'last_known_location_time_v1': 123,
        'dashboard_enforce_radius_v1': false,
      });
      final c = _container();
      c.read(meetingRadiusProvider);
      await Future<void>.delayed(Duration.zero);
      final s = c.read(meetingRadiusProvider);
      expect(s.lat, 44.9778);
      expect(s.lng, -93.2650);
      expect(s.cachedAtMs, 123);
      expect(s.enforce, isFalse);
      expect(s.hasFix, isTrue);
    });

    test('setEnforce toggles without losing the cached fix', () async {
      SharedPreferences.setMockInitialValues({
        'last_known_location_lat_v1': 44.9,
        'last_known_location_lng_v1': -93.2,
      });
      final c = _container();
      c.read(meetingRadiusProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(meetingRadiusProvider.notifier).setEnforce(false);
      final s = c.read(meetingRadiusProvider);
      expect(s.enforce, isFalse);
      expect(s.hasFix, isTrue, reason: 'toggling must not discard the fix');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dashboard_enforce_radius_v1'), isFalse);
    });
  });

  group('DailyPledgeNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('starts unpledged and persists today on mark', () async {
      final c = _container();
      expect(c.read(dailyPledgeProvider), isFalse);
      await c.read(dailyPledgeProvider.notifier).markPledged();
      expect(c.read(dailyPledgeProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('daily_pledge_date'),
        DateTime.now().toIso8601String().substring(0, 10),
      );
    });

    test('a stale date does not count as pledged', () async {
      SharedPreferences.setMockInitialValues({'daily_pledge_date': '1999-01-01'});
      final c = _container();
      c.read(dailyPledgeProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(dailyPledgeProvider), isFalse);
    });
  });

  group('SkyNameNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('restores and updates the saved sky name', () async {
      SharedPreferences.setMockInitialValues(
          {'constellation_sky_name_v1': 'Old Sky'});
      final c = _container();
      c.read(skyNameProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(skyNameProvider), 'Old Sky');
      await c.read(skyNameProvider.notifier).setName('New Sky');
      expect(c.read(skyNameProvider), 'New Sky');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('constellation_sky_name_v1'), 'New Sky');
    });
  });
}
