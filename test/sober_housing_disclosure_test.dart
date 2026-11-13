// test/sober_housing_disclosure_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/screens/sober_housing_locator.dart';

void main() {
  testWidgets('unverified directory status is disclosed before choosing housing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SoberHousingLocatorScreen(),
    ));

    expect(find.textContaining('historical, unverified directory references'),
        findsOneWidget);
    expect(find.textContaining('historical directory entries'), findsOneWidget);
    expect(find.text('Reported guidelines (verify):'), findsWidgets);
  });

  testWidgets('directions require explicit user-confirmed address',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SoberHousingLocatorScreen(),
    ));

    final directions =
        find.widgetWithText(OutlinedButton, 'Directions').first;
    await tester.ensureVisible(directions);
    await tester.tap(directions);
    await tester.pumpAndSettle();

    expect(find.text('Confirm housing destination'), findsOneWidget);
    expect(find.textContaining('Have you independently confirmed this address?'),
        findsOneWidget);

    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm housing destination'), findsNothing);
    // The test intentionally does not launch an external mapping application.
  });
}
