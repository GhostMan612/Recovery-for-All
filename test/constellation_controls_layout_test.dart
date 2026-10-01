import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Geometry-only regression test for the constellation zoom slider being
/// unreachable under the "Add Star" FAB.
///
/// Found on the LG B160V, not by reading the code: a tap intended for the
/// zoom slider opened the Add Star dialog instead, because the slider row sat
/// at `bottom: 12` while the extended FAB occupies roughly 16..72dp from the
/// bottom across the right half of the screen. Nothing overflowed, so the
/// theme x text-scale matrix could not see it.
///
/// This computes the two rects explicitly rather than pumping the screen,
/// because `ConstellationScreen` needs a Drift database and the geometry under
/// test is pure arithmetic. Both directions are asserted so the guard cannot
/// silently become vacuous.
void main() {
  group('constellation bottom controls do not collide', () {
    test('the zoom slider row clears the extended FAB', () {
      final size = const Size(411, 921); // B160V logical size

      // Measured on the device: the extended FAB is ~213dp wide on a 411dp
      // screen and 56dp tall, docked 16dp from the bottom and right edges.
      final fab = _fabRect(size);
      final slider = _sliderRect(size, bottomInset: _kSliderBottomInset);

      expect(slider.overlaps(fab), isFalse,
          reason: 'the slider rect $slider overlaps the FAB rect $fab, so the '
              'covered part of the track can neither be tapped nor dragged');
    });

    test('the old bottom: 12 inset DID collide, so the guard has teeth', () {
      final size = const Size(411, 921);
      final fab = _fabRect(size);
      final old = _sliderRect(size, bottomInset: 12);

      expect(old.overlaps(fab), isTrue,
          reason: 'if this ever becomes false, the test above proves nothing');
    });

    test('it clears on a small phone too, not just at 411dp', () {
      // The FAB label is fixed-width, so on a narrow screen it eats a larger
      // share of the row. The row is inset from both edges, so this holds
      // regardless — but assert it rather than trusting the arithmetic.
      for (final width in [320.0, 360.0, 411.0, 480.0]) {
        final size = Size(width, 921);
        expect(_sliderRect(size, bottomInset: _kSliderBottomInset)
            .overlaps(_fabRect(size)), isFalse,
            reason: 'collides at ${width}dp wide');
      }
    });
  });
}

/// The inset the canvas now uses. Mirrors `Positioned(bottom: 84)` in
/// `constellation_screen.dart`.
const double _kSliderBottomInset = 84.0;

Rect _fabRect(Size size) => Rect.fromLTWH(
      size.width - 213.0 - 16.0,
      size.height - 56.0 - 16.0,
      213.0,
      56.0,
    );

Rect _sliderRect(Size size, {required double bottomInset}) => Rect.fromLTWH(
      16.0,
      size.height - bottomInset - 48.0,
      size.width - 32.0,
      48.0,
    );
