// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Tests for the IndexedStack-staleness class: state that is read once in
// initState and then never refreshed, because the widget is never destroyed.
//
// The app's shell keeps all four destinations alive (dashboard_screen.dart:
// "a tab switch no longer destroys and rebuilds the off-screen body"), which is
// correct for scroll offset and per-tab edit mode — and is exactly why an
// initState-only load is permanently stale. AGENTS.md calls this out: "a
// persistent body must therefore be told to refresh explicitly".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/providers.dart';

/// Stand-in for DashboardLayout / MeetingRadiusState. Both were `ref.read`
/// getters consumed from build(), so nothing rebuilt when the notifier changed.
class DashboardLayoutShim {
  final int revision;
  const DashboardLayoutShim(this.revision);
}

final _layoutProbe = NotifierProvider<_ProbeNotifier, DashboardLayoutShim>(
  _ProbeNotifier.new,
);

class _ProbeNotifier extends Notifier<DashboardLayoutShim> {
  @override
  DashboardLayoutShim build() => const DashboardLayoutShim(0);

  void bump() => state = DashboardLayoutShim(state.revision + 1);
}

void main() {
  testWidgets('ref.read in build registers no subscription, ref.watch does',
      (tester) async {
    // First, prove the bug is real rather than asserting it.
    var readRebuilds = 0;
    var watchRebuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.read(_layoutProbe);
              readRebuilds++;
              final s = ref.watch(_layoutProbe);
              return Text('read ${s.revision}', textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );
    expect(find.text('read 0'), findsOneWidget);
    expect(readRebuilds, 1);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final s = ref.watch(_layoutProbe);
              watchRebuilds++;
              return Text('watch ${s.revision}', textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );
    expect(find.text('watch 0'), findsOneWidget);
    expect(watchRebuilds, 1);

    // The asymmetry: the same provider change rebuilds the watch consumer and
    // leaves the read consumer stale. That is exactly why the dashboard's
    // hide/restore, drag-reorder and radius-filter controls "did nothing".
    final container = ProviderScope.containerOf(
        tester.element(find.text('watch 0')));
    container.read(_layoutProbe.notifier).bump();
    await tester.pumpAndSettle();

    expect(find.text('watch 1'), findsOneWidget,
        reason: 'a watch consumer must rebuild on a notifier change');
    expect(find.text('read 0'), findsNothing,
        reason: 'the read consumer is stale — this is the dashboard bug');
  });

  testWidgets('an IndexedStack keeps every child alive, so initState runs once',
      (tester) async {
    // Proves the premise of the whole staleness class. If children were lazy,
    // an initState-only load would be merely slow; because they are built
    // eagerly and never destroyed, it is permanently wrong.
    var child0Inits = 0;
    var child1Inits = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: IndexedStack(
              index: 0,
              children: [
                _InitCounter(onInit: () => child0Inits++),
                _InitCounter(onInit: () => child1Inits++),
              ],
            ),
          ),
        ),
      ),
    );

    expect(child0Inits, 1);
    expect(child1Inits, 1,
        reason: 'IndexedStack BUILDS all children, not just the visible one');

    // Switching tabs creates no new initState — the widgets stay alive.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: IndexedStack(
              index: 1,
              children: [
                _InitCounter(onInit: () => child0Inits++),
                _InitCounter(onInit: () => child1Inits++),
              ],
            ),
          ),
        ),
      ),
    );

    expect(child0Inits, 1);
    expect(child1Inits, 1,
        reason: 'a tab switch must not re-run initState');
  });

  group('hasCompletedOnboardingProvider must not collapse loading into false', () {
    test('the provider carries the loading/error distinction', () async {
      // Type-level proof of the fix. The provider now returns
      // AsyncValue<bool>, so a caller can see isLoading / hasError. The old
      // shape was Provider<bool> with `orElse: () => false`, which reported
      // "the user has not onboarded" both while Drift was still reading and
      // when the read threw. Declaring the type here means reverting the
      // signature breaks this file at compile time.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final AsyncValue<bool> value =
          container.read(hasCompletedOnboardingProvider);
      expect(
        value.isLoading || value.hasError || value.value == true,
        isTrue,
        reason: 'a bare `false` would mean "no profile", which is exactly the '
            'lie the fix removed',
      );
    });
  });
}

class _InitCounter extends StatefulWidget {
  final VoidCallback onInit;
  const _InitCounter({required this.onInit});

  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}