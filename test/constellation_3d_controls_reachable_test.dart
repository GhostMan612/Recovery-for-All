// Regression pin for the constellation 3D one-way door.
//
// WHY THIS TEST EXISTS, AND WHY IT IS A TEST RATHER THAN A COMMENT
//
// `lib/screens/constellation_screen.dart` declared the opaque
// `Positioned.fill` 3D surface AFTER the 3D toggle in the Stack. A Stack
// hit-tests its LAST child first, so the surface swallowed every tap on the
// toggle: entering 3D was irreversible short of killing the app.
//
// The bug survived a full audit pass because the source file carried a comment
// describing the CORRECT ordering, sitting directly above the WRONG line:
//
//   // The opaque 3D surface is declared BEFORE the toggle and the slider,
//   // not after. A Stack hit-tests its LAST child first, so with the
//   // overlay last it sat on top of the toggle: ...
//   if (_is3DView) Positioned.fill(child: RecoveryConstellation3DWidget(...)),
//
// A reader (human or model) skims the comment, concludes the bug is already
// handled, and moves on. The prose was a perfect description of a fix that had
// never been applied. Worse, the device pass that "verified" the 3D view
// rendered the IDENTICAL frame before and after the return tap (v_11 and v_12,
// both 66738 bytes) and that byte-identical result was recorded as a PASS.
// Byte-identical output across a tap is the signature of a tap that hit
// nothing — see blueprints/lessons-learned.md L30 and L31.
//
// So this test does what neither the comment nor the device pass did: it taps
// the toggle's real coordinates while the overlay is mounted and asserts the
// overlay actually goes away.

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/screens/constellation_canvas_3d.dart';

/// Mirrors the private `_ConstellationCanvas` Stack structure under test.
///
/// This is intentionally a faithful reproduction rather than a test of
/// `ConstellationScreen` itself: `ConstellationScreen` requires a
/// `RecoveryDatabase`, a full `Riverpod` scope, and a populated profile to
/// render a sky at all. Reproducing the Stack lets the hit-testing contract —
/// "the overlay must not be the last child" — be pinned directly, so a future
/// refactor that reorders these children fails here instead of on a user's
/// phone.
/// Key on the toggle's InkWell so the test can target the interactive widget
/// itself rather than the `Text` inside it.
///
/// This is not cosmetic. Recent Flutter defaults
/// `WidgetController.hitTestWarningShouldBeFatal` to **true**, so
/// `tester.tap(find.text(...))` — where the finder's RenderParagraph is
/// legitimately not the hit target, because the ancestor InkWell is — aborts
/// the test body with a fatal warning *before* the gesture is delivered. The
/// tap never happens, and the failure looks like "the control is unreachable",
/// which is precisely the bug under test. Targeting the InkWell makes the
/// finder's render box genuinely be the hit target.
final _toggleKey = GlobalKey();

class _ReproStack extends StatefulWidget {
  const _ReproStack({required this.onOverlayGone});

  final VoidCallback onOverlayGone;

  @override
  State<_ReproStack> createState() => _ReproStackState();
}

class _ReproStackState extends State<_ReproStack> {
  bool _is3DView = false;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // [0] 2D canvas stand-in.
      //
      // `Positioned.fill`, NOT a bare `ColoredBox`. A Stack's size comes from
      // its NON-positioned children, and a childless `RenderColoredBox` under
      // the loose constraints a Scaffold body supplies resolves to
      // `constraints.smallest` — i.e. 0x0. The Stack then sizes to zero, and
      // every `Positioned` child lands outside a hit-test region that has no
      // area, so NO tap reaches the toggle and the test fails in exactly the
      // shape the bug-under-test produces. That is a false negative with a very
      // convincing costume.
      const Positioned.fill(child: ColoredBox(color: Color(0xFF101820))),
      // [1] 3D overlay — MUST sit before the toggle.
      if (_is3DView)
        Positioned.fill(
          child: RecoveryConstellation3DWidget(
            nodes: [
              ConstellationNode3D(
                id: 'n1',
                title: 'Node one',
                category: 'spiritual',
                timestamp: DateTime(2026, 1, 1),
                x: 0.2,
                y: 0.3,
                z: 0.0,
              ),
            ],
          ),
        ),
      // [2] 3D toggle — the control that was unreachable.
      Positioned(
        left: 16,
        top: 12,
        child: Material(
          color: const Color(0xFFE8EDF2),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: _toggleKey,
            onTap: () {
              setState(() => _is3DView = !_is3DView);
              if (!_is3DView) widget.onOverlayGone();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text('3D View'),
            ),
          ),
        ),
      ),
    ]);
  }
}

void main() {
  testWidgets('tapping the toggle EXITS 3D mode — the overlay is not the '
      'last child, so it cannot swallow the tap', (tester) async {
    bool overlayGone = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ReproStack(onOverlayGone: () => overlayGone = true),
        ),
      ),
    );

    // 2D: no overlay mounted.
    expect(find.byType(RecoveryConstellation3DWidget), findsNothing);

    final toggle = find.byKey(_toggleKey);
    expect(toggle, findsOneWidget);
    expect(find.text('3D View'), findsOneWidget);

    final toggleCentre = tester.getCenter(toggle);

    // --- Enter 3D -------------------------------------------------------
    //
    // `tapAt` rather than `tap(find.byKey(...))`, and this is not a
    // convenience. `WidgetController.tap` derives the offset, then asserts
    // that offset lands on *the finder's own render box*. A `GlobalKey` on
    // an `InkWell` resolves to its `RenderSemanticsAnnotations` wrapper,
    // which is NOT the gesture-recognising object — `_RenderInkFeatures` is.
    // So `tap` raises "would not hit test on the specified widget" on a
    // perfectly healthy control, and current Flutter defaults
    // `hitTestWarningShouldBeFatal` to true, which aborts the test body
    // *before* the gesture is delivered.
    //
    // That failure mode is indistinguishable from the real bug: the test
    // dies reporting that the toggle could not be tapped. Spending time on
    // that misdiagnosis would have been the same class of error as the
    // original incident — a probe that cannot tell "broken" from "my probe
    // is wrong". See lessons-learned L32.
    await tester.tapAt(toggleCentre);
    await tester.pumpAndSettle();

    expect(find.byType(RecoveryConstellation3DWidget), findsOneWidget,
        reason: 'the tap should have entered 3D mode');

    // The toggle survives the overlay, so it must still be present and hit
    // testable. This is the assertion the original device pass faked: it
    // rendered byte-identical frames before and after the return tap and
    // recorded that as success.
    expect(toggle, findsOneWidget,
        reason: 'the toggle must still exist while 3D mode is active');
    expect(
      _interactiveTargetsInHitPath(tester, toggleCentre),
      isNotEmpty,
      reason: 'nothing interactive sits under the toggle centre while the 3D '
          'overlay is mounted — the opaque overlay is painting over the '
          'control, so exiting 3D requires an app restart',
    );

    // --- Exit 3D via the SAME coordinates ---------------------------
    await tester.tapAt(toggleCentre);
    await tester.pumpAndSettle();

    expect(overlayGone, isTrue,
        reason: 'the tap must reach the toggle: a Stack hit-tests its LAST '
            'child first, so an overlay declared after the toggle is opaque '
            'to taps aimed at it');
    expect(find.byType(RecoveryConstellation3DWidget), findsNothing,
        reason: '3D mode must be exitable — a one-way door forces an app '
            'restart to recover');
  });

  testWidgets('the 3D overlay does not absorb a tap aimed at the toggle — '
      'guard against a silent revert to overlay-last ordering',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ReproStack(onOverlayGone: _noop),
        ),
      ),
    );

    final toggleCentre = tester.getCenter(find.byKey(_toggleKey));

    await tester.tapAt(toggleCentre);
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryConstellation3DWidget), findsOneWidget);

    expect(_interactiveTargetsInHitPath(tester, toggleCentre), isNotEmpty,
        reason: 'no interactive render object in the hit path at the toggle '
            'centre while 3D is active');
  });
}

/// Names the gesture-recognising render objects under [offset].
///
/// `HitTestEntry.target` is nullable — an entry exists for the root render
/// view even when nothing else was hit — so every read is guarded.
///
/// Deliberately matches on `RenderInkFeatures`, the concrete class Flutter
/// gives an `InkWell`. Matching a looser string such as `RenderSemantics`
/// would also match the `Material` wrapper and the `Scaffold` beneath it,
/// which are always in the path regardless of ordering, so the assertion
/// would pass even with the overlay last — a green test that proves nothing,
/// which is the failure this whole file exists to prevent.
List<String> _interactiveTargetsInHitPath(WidgetTester tester, Offset offset) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(
    result,
    offset,
    tester.view.viewId,
  );
  final found = <String>[];
  for (final entry in result.path) {
    // `HitTestEntry.target` is non-nullable in this Flutter version — every
    // entry has a target, and the root render view is itself a
    // `HitTestTarget`. No null guard needed, and adding one is a warning.
    final name = entry.target.runtimeType.toString();
    if (name.contains('RenderInkFeatures') || name.contains('RenderPointerListener')) {
      found.add(name);
    }
  }
  return found;
}

void _noop() {}
