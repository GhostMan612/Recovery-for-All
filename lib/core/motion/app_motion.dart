// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/motion/app_motion.dart
//
// Phase 14. Before this file the "reduce motion" decision was made in five
// separate places: a helper in `widgets/themed_background.dart` (used by four
// screens) and three raw `MediaQuery.disableAnimationsOf(context)` reads in
// `avatar_visual_layer.dart`, `companion_guide_overlay.dart` and
// `splash_screen.dart`. Nothing was wrong with any of them individually; the
// problem was that there was no single place to look, so a new animation
// would reasonably have been written without consulting any of them.
//
// This is the one place that answers "should this move?", for ACCESSIBILITY
// reasons only. It is deliberately NOT the same question as "is this device
// too slow to animate?" — that is `HardwareTierService.isLowEnd`, a
// performance decision, and the two are combined at their call sites rather
// than conflated here.

import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  /// Named durations. Kept short on purpose: the Phase 14 rule is that motion
  /// communicates state, so these are transitions, not decoration.
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// The platform's "remove animations" accessibility setting.
  ///
  /// `maybeOf` rather than `of`, because this is called from places that may
  /// legitimately have no MediaQuery ancestor, and "no ancestor" must not
  /// become a crash on a screen that is about to start an animation.
  static bool reduceMotionOf(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns [base] unchanged, or [Duration.zero] when the user asked for
  /// reduced motion, so call sites can pass their natural duration and get
  /// the right behaviour without branching.
  static Duration duration(BuildContext context, Duration base) {
    return reduceMotionOf(context) ? Duration.zero : base;
  }

  /// The same setting, read without a [BuildContext].
  ///
  /// `initState` has no MediaQuery ancestor, so a screen that starts an
  /// animation during construction (the splash's 7-second cold-start zoom)
  /// cannot use [reduceMotionOf]. It reads the platform feature directly
  /// rather than inventing a third way of asking.
  static bool get platformReduceMotion {
    return WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }
}
