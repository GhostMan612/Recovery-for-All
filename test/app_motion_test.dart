// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/app_motion_test.dart
//
// Phase 14. The reduce-motion decision used to be made in five places. This
// pins the consolidated policy, and pins the one behavioural change the
// consolidation bought: `duration()` collapsing to zero so call sites stop
// branching.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/motion/app_motion.dart';
import 'package:recovery_for_all/widgets/themed_background.dart' show appReduceMotion;

/// Pumps [child] under a MediaQuery with the given accessibility setting and
/// hands back a BuildContext from inside it.
Future<BuildContext> _contextWith(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      }),
    ),
  );
  return captured;
}

void main() {
  group('AppMotion.reduceMotionOf', () {
    testWidgets('is false when the setting is off', (tester) async {
      final context = await _contextWith(tester, disableAnimations: false);
      expect(AppMotion.reduceMotionOf(context), isFalse);
    });

    testWidgets('is true when the setting is on', (tester) async {
      final context = await _contextWith(tester, disableAnimations: true);
      expect(AppMotion.reduceMotionOf(context), isTrue);
    });

    testWidgets('does not throw without a MediaQuery ancestor',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(Builder(builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      }));
      // An animation must not be the thing that crashes a screen that is
      // about to start one.
      expect(AppMotion.reduceMotionOf(captured), isFalse);
    });
  });

  group('AppMotion.duration', () {
    testWidgets('passes the duration through when motion is allowed',
        (tester) async {
      final context = await _contextWith(tester, disableAnimations: false);
      expect(AppMotion.duration(context, AppMotion.normal), AppMotion.normal);
      expect(AppMotion.duration(context, AppMotion.fast), AppMotion.fast);
    });

    testWidgets('collapses to zero when motion is reduced', (tester) async {
      final context = await _contextWith(tester, disableAnimations: true);
      expect(AppMotion.duration(context, AppMotion.normal), Duration.zero);
      expect(AppMotion.duration(context, AppMotion.slow), Duration.zero);
    });
  });

  test('platformReduceMotion is readable without a context', () {
    // The splash needs this in initState, where no MediaQuery exists. Under
    // the test binding the platform features are the default (animations
    // allowed), so this must not throw and must read false.
    expect(AppMotion.platformReduceMotion, isFalse);
  });

  testWidgets('the legacy appReduceMotion helper agrees with the policy',
      (tester) async {
    // constellation, pet trials and grounding still call the old helper; it
    // must not have been left reading MediaQuery independently.
    final off = await _contextWith(tester, disableAnimations: false);
    expect(appReduceMotion(off), AppMotion.reduceMotionOf(off));

    final on = await _contextWith(tester, disableAnimations: true);
    expect(appReduceMotion(on), AppMotion.reduceMotionOf(on));
    expect(appReduceMotion(on), isTrue);
  });
}
