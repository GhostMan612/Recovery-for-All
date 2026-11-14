// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/screens/meeting_map_screen.dart';
import 'package:recovery_for_all/widgets/footprint_trail.dart';

void main() {
  group('FootprintTrail', () {
    testWidgets('renders one footprint per step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: FootprintTrail())),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('footprint-$i')), findsOneWidget);
      }
    });

    testWidgets('prints pulse in sequence while animating', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: FootprintTrail())),
        ),
      );

      double opacityOf(int index) => tester
          .widget<Opacity>(find.byKey(ValueKey('footprint-opacity-$index')))
          .opacity;

      final first = opacityOf(0);
      // A quarter-cycle later the travelling wave has moved on: at least
      // one print must have changed brightness, and all stay in range.
      await tester.pump(const Duration(milliseconds: 450));
      final later = opacityOf(0);
      expect(first, isNot(later));
      for (var i = 0; i < 5; i++) {
        expect(opacityOf(i), inInclusiveRange(0.3, 1.0));
      }
    });

    testWidgets('renders static full-opacity prints with reduced motion',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: Center(child: FootprintTrail())),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(
          tester
              .widget<Opacity>(find.byKey(ValueKey('footprint-opacity-$i')))
              .opacity,
          1.0,
        );
      }
    });

    testWidgets('MeetingMapScreen loading view shows the footprint trail',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MeetingMapScreen(),
          ),
        ),
      );

      // Allow the initial loading frame to render.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FootprintTrail), findsOneWidget);

      // Drain the GPS timeout timer before the test ends.
      await tester.pump(const Duration(seconds: 21));
    });
  });
}
