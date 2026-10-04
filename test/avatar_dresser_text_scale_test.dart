// ============================================================
// As Above, So Below. As Within, So Without.
// ============================================================

// Multi-scale text audit for the avatar dresser grid (lessons-learned L14).
//
// WHY THIS EXISTS. `AvatarDresserScreen`'s cosmetic grid is a
// `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3,
// childAspectRatio: 0.85)`. Each cell is a fixed-size box holding a fixed 34dp
// painted icon plus TWO text lines — the item label (11px, up to 2 lines) and a
// status line (12px). A fixed cell with scaled text inside it is precisely the
// shape that clips, and it shipped unexamined.
//
// THE TRAP THAT WOULD HAVE HIDDEN IT: the default widget-test surface is
// 800dp WIDE. That makes each grid cell 252dp and leaves ~130dp of slack, so a
// test written without pinning a screen size PASSES while the real phone
// overflows. Every test below pins a 360x640dp surface. If you extend this file,
// keep that — a wide default surface makes the whole group decorative.
//
// MEASURED, not assumed: on a 360dp phone the cell is ~105dp wide and ~123.5dp
// tall (105 / 0.85), leaving ~107.5dp inside its padding. Content at 2x is
// 34 + 6 + 2*label lines + 4 + status, which measured 119.5dp — a 12px overflow
// at 2.0x and 14px at 1.5x. Both were real RenderFlex overflows, reported by the
// framework, fixed in avatar_dresser_screen.dart.

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/screens/avatar_dresser_screen.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 360dp wide — the width the arithmetic above assumes, and narrow enough that
/// a clipping bug cannot hide. 640dp tall is a small-but-real phone height.
const Size _phone = Size(360, 640);

RecoveryPet _testPet({int sparks = 120, String name = 'Ash'}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return RecoveryPetService.petFromRow(RecoveryPetRow(
    id: 'active_pet',
    name: name,
    speciesOrStyle: 'wolf',
    energy: 80,
    bond: 40,
    mood: 'content',
    sparks: sparks,
    unlockedItems: '[]',
    equippedOutfit: '[]',
    lastFedAt: now,
    createdAt: now,
    equippedSlotsJson: '[]',
    pathLevel: 1,
    pathXp: 0,
  ));
}

/// Pumps the dresser at [scale] on a phone-sized surface and returns every
/// framework error raised.
///
/// Errors are collected through `FlutterError.onError` rather than
/// `tester.takeException()` on purpose: `takeException()` collapses a layout
/// failure to a single summary line and discards the part that says WHICH
/// RenderFlex broke, which is the only part worth reading. `FlutterErrorDetails`
/// carries the full report, including the creator chain.
///
/// Restores `onError` in a `finally` so a pump failure cannot leave the binding
/// permanently deaf for the rest of the suite.
Future<List<String>> _pumpAt(
  WidgetTester tester,
  double scale, {
  RecoveryPet? pet,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final errors = <FlutterErrorDetails>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: AvatarDresserScreen(initialPet: pet ?? _testPet()),
        ),
      ),
    );
    // NOT pumpAndSettle: `AvatarVisualLayer` runs a continuous animation, so
    // there is no settled frame and pumpAndSettle only times out. Two bounded
    // pumps are enough — layout, and therefore any overflow, happens on the
    // first frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    FlutterError.onError = priorOnError;
  }

  return errors.map((e) {
    final full = e.toString();
    return full.length > 1200 ? '${full.substring(0, 1200)}\n…truncated' : full;
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  RecoveryDatabase? previousDb;

  setUp(() async {
    db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
    previousDb = RecoveryPetService.database;
    RecoveryPetService.bindDatabase(db);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    RecoveryPetService.bindDatabase(previousDb);
    try {
      await db.close();
    } on Object {
      // Already closed by a test body.
    }
  });

  group('avatar dresser grid holds its content at every text scale', () {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at ${scale}x on a 360dp phone', (tester) async {
        final errors = await _pumpAt(tester, scale);
        expect(errors, isEmpty,
            reason: 'the cosmetic grid clipped at ${scale}x. A fixed '
                'childAspectRatio cannot fit scaled text; see L14.\n'
                '${errors.join('\n---\n')}');
      });
    }

    testWidgets('a very long pet name does not overflow the header at 2x',
        (tester) async {
      // Realistic Spark count on purpose. The header Row lays the readout out at
      // INTRINSIC width BEFORE the Expanded title gets any space, so a long name
      // is what pushes into it — but a six-digit Spark total is a DIFFERENT
      // stress (one the grid's status lines share too), and mixing them would
      // mean a failure could not be attributed to either.
      final errors = await _pumpAt(tester, 2.0,
          pet: _testPet(name: 'Bartholomew the Unyielding'));
      expect(errors, isEmpty,
          reason: 'a long pet name must not overflow the header at 2x.\n'
              '${errors.join('\n---\n')}');
    });

    testWidgets('a large Spark count does not overflow a grid cell at 2x',
        (tester) async {
      // A cell has a fixed height, so a status line that wraps without bound
      // eventually pushes out of it. `${item.cost}✦` is short for every current
      // cosmetic, but it is a number formatted from data, so a wide value must
      // ellipsize rather than wrap.
      final errors = await _pumpAt(tester, 2.0, pet: _testPet(sparks: 999999));
      expect(errors, isEmpty,
          reason: 'a big Spark total is data, not layout: the status line must '
              'clamp to one line rather than wrap out of its cell.\n'
              '${errors.join('\n---\n')}');
    });

    testWidgets('the Spark readout is still rendered at 2x', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final priorOnError = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: AvatarDresserScreen(initialPet: _testPet(sparks: 12345)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = priorOnError;
      }

      // The Spark count is the user's progress. If a layout change ever made it
      // vanish to make room for a title, that is not a cosmetic regression.
      expect(find.textContaining('12345'), findsWidgets);
      expect(find.text('Avatar dresser'), findsOneWidget);
    });
  });
}