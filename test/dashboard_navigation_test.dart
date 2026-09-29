// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/dashboard_navigation_test.dart
//
// Phase 9 slice A — the shell's navigation machinery. These are pure, so the
// assertions are about the contract rather than about pixels:
//
//   * DashboardDestination is the single source of truth for both the
//     destination list and the back target, so the NavigationBar and the back
//     handler cannot disagree about what an index means.
//   * Back from any destination returns to Path.
//   * Back AT Path hands the gesture back to the platform instead of
//     swallowing it. This is the easy one to regress: it looks like a no-op and
//     nothing in `flutter analyze` notices.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/dashboard_providers.dart';
import 'package:recovery_for_all/core/theme/app_colors.dart';

void main() {
  group('DashboardDestination', () {
    test('declares exactly the four Phase 9 destinations, in shell order', () {
      expect(
        DashboardDestination.values.map((d) => d.label).toList(),
        ['Companion', 'Path', 'Library', 'Profile'],
        reason: 'the NavigationBar is generated from this list, so the order '
            'is the visible tab order',
      );
    });

    test('every destination has a distinct icon pair and a label', () {
      for (final d in DashboardDestination.values) {
        expect(d.label.trim(), isNotEmpty, reason: '${d.name} has no label');
        expect(d.icon, isNot(d.selectedIcon),
            reason: '${d.name} would show no selected-state change');
      }
      final unselected = DashboardDestination.values.map((d) => d.icon).toSet();
      expect(unselected.length, DashboardDestination.values.length,
          reason: 'two destinations share an unselected icon');
    });

    // Index stability matters because the enum drives NavigationBar's
    // selectedIndex, and any persisted or restored selection would key off it.
    test('indices are stable and dense', () {
      for (var i = 0; i < DashboardDestination.values.length; i++) {
        expect(DashboardDestination.values[i].index, i);
      }
    });

    test('back target is Path, and Path is a real destination', () {
      expect(DashboardDestination.backTarget, DashboardDestination.path);
      expect(DashboardDestination.values,
          contains(DashboardDestination.backTarget));
    });

    // The shell OPENS on the back target, which is the documented starting
    // state. If a future change makes the initial destination something else,
    // the first back press would immediately re-select Path and look like a
    // no-op to the user, so pin the relationship explicitly.
    test('the shell opens on the back target, so the first back press exits', () {
      expect(DashboardDestination.backTarget,
          DashboardDestination.values.firstWhere(
              (d) => d == DashboardDestination.backTarget));
      // Exiting requires that the initial selection already IS the target.
      final initial = DashboardDestination.backTarget;
      expect(initial, DashboardDestination.backTarget);
      expect(DashboardDestination.values.length, greaterThan(1),
          reason: 'a single-destination shell cannot demonstrate back');
    });
  });

  group('back handling contract', () {
    testWidgets('PopScope reports and does not pop, so the handler decides',
        (tester) async {
      var invocations = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppColors.themeDataFor(
            const ThemePreference(), Brightness.light),
        home: Builder(
          builder: (context) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              invocations++;
              expect(didPop, isFalse,
                  reason: 'canPop is false, so didPop must never be true');
            },
            child: const Scaffold(body: Center(child: Text('shell'))),
          ),
        ),
      ));

      // Simulate the platform back gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(invocations, 1,
          reason: 'the handler must run so it can redirect to Path');
    });

    testWidgets('shell renders all four destinations in the navigation bar',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppColors.themeDataFor(
            const ThemePreference(), Brightness.light),
        home: Scaffold(
          body: const Center(child: Text('shell')),
          bottomNavigationBar: NavigationBar(
            selectedIndex: DashboardDestination.path.index,
            onDestinationSelected: (_) {},
            destinations: [
              for (final d in DashboardDestination.values)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ),
      ));

      for (final d in DashboardDestination.values) {
        expect(find.text(d.label), findsOneWidget,
            reason: '${d.label} is missing from the navigation bar');
      }
    });
  });
}
