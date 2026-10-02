import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/screens/constellation_canvas_3d.dart';

/// Regression tests for the constellation defects that only a real device could
/// find. Both are *semantics* defects, so neither throws and neither shows up as
/// an overflow — the UI simply misbehaves for the person using it.
void main() {
  group('constellation 3D view', () {
    // The 3D surface is drawn entirely with canvas calls, which emit no
    // semantics of their own. Without an explicit label a screen-reader user
    // got an unlabelled region where the star list used to be — the same class
    // of bug as the Wellness Check-In.
    testWidgets(
        'is announced to a screen reader, with a star count and the gesture '
        'that changes it', (tester) async {
      await _pump3D(tester, [_star]);

      expect(find.bySemanticsLabel(RegExp(r'3D constellation view')),
          findsOneWidget,
          reason: 'a canvas-only region emits no semantics of its own; without '
              'an explicit label a screen reader announces nothing here');
      expect(find.bySemanticsLabel(RegExp(r'1 star\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Drag to rotate')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pluralises the star count', (tester) async {
      await _pump3D(tester, [_star, _star2, _star3]);
      expect(find.bySemanticsLabel(RegExp(r'3 stars\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'\b1 star\.')), findsNothing);
    });

    testWidgets('does not double-announce the star titles', (tester) async {
      await _pump3D(tester, [_star]);
      // Without ExcludeSemantics the per-star TextPainter output would be
      // concatenated onto the curated label, which is exactly the defect that
      // made every SOS tile and tool card announce twice.
      expect(find.bySemanticsLabel('Test star'), findsNothing);
    });

    testWidgets('a rotate drag changes yaw, so the view is not frozen',
        (tester) async {
      await _pump3D(tester, [_star, _star2, _star3]);

      final before = _yaw(tester);
      expect(before, 0.0);

      await tester.drag(find.byType(CustomPaint).last, const Offset(120, 40));
      await tester.pump();

      expect(_yaw(tester), isNot(before),
          reason: 'a drag must change yaw or the sky sits frozen under the '
              'finger — the same failure mode as shouldRepaint ignoring pan');
    });

    testWidgets('shouldRepaint reports a yaw change', (tester) async {
      await _pump3D(tester, [_star, _star2]);
      final p = _painter(tester);
      final turned = Constellation3DPainter(
        nodes: [_star, _star2],
        yaw: 0.9,
        pitch: p.pitch,
        centerColor: p.centerColor,
        linkColor: p.linkColor,
        starColor: p.starColor,
        labelColor: p.labelColor,
      );
      expect(p.shouldRepaint(turned), isTrue);
    });

    // The zoom slider is declared outside the `_is3DView` conditional, so it is
    // on screen in 3D too. It used to be ignored here — the painter hard-
    // defaulted zoom to 1.0 — which made a visible, draggable control do
    // nothing in this mode.
    testWidgets('honours the zoom handed down from the 2D slider',
        (tester) async {
      await _pump3D(tester, [_star, _star2], zoom: 5.0);
      expect(_painter(tester).zoom, greaterThan(1.0),
          reason: 'a zoomed-in 2D view must not silently reset when the user '
              'switches to 3D');
    });

    testWidgets('carries the 2D pan across so framing is not lost',
        (tester) async {
      await _pump3D(tester, [_star, _star2], pan: const Offset(40, -25));
      expect(_painter(tester).pan, const Offset(40, -25));
    });

    testWidgets('shouldRepaint reports a pan change', (tester) async {
      await _pump3D(tester, [_star, _star2]);
      final p = _painter(tester);
      final moved = Constellation3DPainter(
        nodes: [_star, _star2],
        yaw: p.yaw,
        pitch: p.pitch,
        centerColor: p.centerColor,
        linkColor: p.linkColor,
        starColor: p.starColor,
        labelColor: p.labelColor,
        pan: const Offset(12, 34),
      );
      // `pan` was absent from the comparison, so panning produced a painter
      // Flutter believed was identical — no repaint, stale star positions.
      expect(p.shouldRepaint(moved), isTrue);
    });

    testWidgets('shouldRepaint reports a zoom change', (tester) async {
      await _pump3D(tester, [_star, _star2]);
      final p = _painter(tester);
      final zoomed = Constellation3DPainter(
        nodes: [_star, _star2],
        yaw: p.yaw,
        pitch: p.pitch,
        centerColor: p.centerColor,
        linkColor: p.linkColor,
        starColor: p.starColor,
        labelColor: p.labelColor,
        zoom: p.zoom + 0.5,
      );
      expect(p.shouldRepaint(zoomed), isTrue);
    });

    group('zoom mapping', () {
      // The 2D slider runs 1.0-10.0. Feeding that straight into a projection
      // whose perspective term is already ~0.5 would throw every star hundreds
      // of pixels off-screen, so the value is remapped. These pin the ends and
      // monotonicity; the endpoints are what keep stars reachable.
      test('1.0x 2D maps to just under 1x in 3D', () {
        expect(zoomFor3D(1.0), closeTo(0.85, 1e-9));
      });

      test('10x 2D maps to the 2.6 ceiling, never past it', () {
        expect(zoomFor3D(10.0), closeTo(2.6, 1e-9));
      });

      test('values beyond the slider range are clamped, not extrapolated', () {
        expect(zoomFor3D(-5.0), 0.85);
        expect(zoomFor3D(99.0), 2.6);
      });

      test('is monotonic across the whole slider range', () {
        var previous = zoomFor3D(1.0);
        for (var z = 1.0; z <= 10.0; z += 0.25) {
          final current = zoomFor3D(z);
          expect(current, greaterThanOrEqualTo(previous),
              reason: 'mapping must not go backwards at zoom $z');
          previous = current;
        }
      });
    });
  });
}

Future<void> _pump3D(
  WidgetTester tester,
  List<ConstellationNode3D> nodes, {
  double zoom = 1.0,
  Offset pan = Offset.zero,
}) async {
  tester.view.physicalSize = const Size(411, 921) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme:
        AppColors.themeDataFor(const ThemePreference(), Brightness.dark),
    home: Scaffold(
      body: RecoveryConstellation3DWidget(nodes: nodes, zoom: zoom, pan: pan),
    ),
  ));
  await tester.pump();
}

/// Reads yaw back off the painter the widget is currently using.
Constellation3DPainter _painter(WidgetTester tester) =>
    (tester.widget(find.byType(CustomPaint).last) as CustomPaint).painter!
        as Constellation3DPainter;

double _yaw(WidgetTester tester) => _painter(tester).yaw;

// Not const: ConstellationNode3D has no const constructor because DateTime does
// not, so nothing holding a ConstellationNode3D can be const either.
ConstellationNode3D _make(String id, String title, double x, double y) =>
    ConstellationNode3D(
      id: id,
      title: title,
      category: 'milestone',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1750000000000),
      x: x,
      y: y,
      z: 0.0,
    );

final _star = _make('n1', 'Test star', 0.2, 0.1);
final _star2 = _make('n2', 'Second star', -0.25, 0.15);
final _star3 = _make('n3', 'Third star', 0.05, -0.3);
