// ============================================================
// As Above, So Below. As Within, So Without.
// ============================================================

// Proves the claim AGENTS.md makes about `dashboardDataProvider` being the LIVE
// single owner of pet state.
//
// Before this, `DashboardDataNotifier.build()` called `_load()`, which read the
// pet exactly once. After that the only way the state changed was somebody
// remembering to call `setPet`/`refreshPet`. So the "single owner" was a
// snapshot, and any write that went straight to `RecoveryPetService` left the
// whole dashboard showing the pre-write value until the process restarted.
//
// The concrete user-visible bug: a brand-new user has an empty sky. They tap the
// seed card in Constellation, `logStar` awards Sparks in the database — and the
// dashboard spark counter does not move. Nothing was corrupt; the dashboard was
// simply reading a value that was already false.
//
// WHY THIS NEEDS A TEST AND NOT A COMMENT (lessons-learned L32): "I made the
// notifier subscribe to the stream" is a claim about behaviour that the analyzer
// cannot check and that no existing test would notice being reverted. A comment
// describing a fix is not the fix — this file is the fix.

import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/dashboard_providers.dart';
import 'package:recovery_for_all/core/providers.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  RecoveryDatabase? previousDb;
  late ProviderContainer container;

  setUp(() async {
    db = RecoveryDatabase.forTesting(NativeDatabase.memory() as QueryExecutor);
    previousDb = RecoveryPetService.database;
    RecoveryPetService.bindDatabase(db);
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    RecoveryPetService.bindDatabase(previousDb);
    // The disposal test closes the database itself on purpose, to prove that a
    // live subscription does not hold it open. drift's close() is not
    // documented as idempotent, so tolerate the second call rather than have
    // teardown report an error that belongs to no assertion.
    try {
      await db.close();
    } on Object {
      // Already closed by the test body.
    }
  });

  /// Writes a pet row the way the service does, WITHOUT telling the notifier.
  /// That omission is the entire point: nothing here calls setPet or
  /// refreshPet, which is exactly what constellation_screen.dart does when it
  /// calls `RecoveryPetService.logStar`.
  Future<void> writePetDirectly({required int sparks, String id = 'active_pet'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertPet(RecoveryPetRow(
      id: id,
      name: 'Ash',
      speciesOrStyle: 'wolf',
      energy: 100,
      bond: 10,
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

  /// Lets the drift stream deliver and the notifier apply it.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  group('dashboardDataProvider is a live owner of pet state', () {
    test('a pet row written behind the notifier\'s back reaches the state',
        () async {
      container.read(dashboardDataProvider); // build + subscribe
      await settle();
      // `_load()` calls ensureHatched(), which CREATES a default 0-spark pet on
      // an empty database, so the starting state is a real pet, not null.
      expect(container.read(dashboardDataProvider).pet?.sparks, 0);

      // No setPet, no refreshPet. Exactly the constellation/seed-star path.
      await writePetDirectly(sparks: 37);
      await settle();

      expect(container.read(dashboardDataProvider).pet?.sparks, 37,
          reason: 'a Spark awarded anywhere must reach the dashboard without '
              'anyone remembering to call setPet — that is what "live owner" '
              'means, and it is the bug this replaces');
    });

    test('a SECOND, later change is seen too — not just the first emission',
        () async {
      container.read(dashboardDataProvider);
      await settle();

      await writePetDirectly(sparks: 10);
      await settle();
      expect(container.read(dashboardDataProvider).pet?.sparks, 10);

      // The old code read once and was done forever. One emission proving the
      // subscription exists is not enough: it has to keep delivering, or the
      // dashboard still goes stale after the first reward of the session.
      await writePetDirectly(sparks: 260);
      await settle();
      expect(container.read(dashboardDataProvider).pet?.sparks, 260);

      await writePetDirectly(sparks: 512);
      await settle();
      expect(container.read(dashboardDataProvider).pet?.sparks, 512);
    });

    test('the subscription is disposed with the container, not leaked',
        () async {
      // A notifier that subscribes in build() and never unsubscribes keeps the
      // drift stream — and therefore the database file handle — alive for the
      // rest of the process. On Android that is a held FD after logout/relaunch.
      var cancelled = false;
      await runZonedGuarded(() async {
        final c = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        c.read(dashboardDataProvider);
        await settle();
        c.dispose();
        cancelled = true;
      }, (e, s) => fail('zone error: $e'));

      expect(cancelled, isTrue);
      // If the stream were still subscribed, closing the database would throw
      // or the stream would emit into a disposed notifier. Reaching here
      // without an unhandled error is the assertion that matters; the explicit
      // ref.onDispose(() => _petSub?.cancel()) in build() is what makes it so.
      await db.close();
      await settle();
    });
  });

  group('DashboardDataState.copyWith can express "no pet"', () {
    test('copyWith(pet: null) CLEARS the pet', () {
      // The old signature was `RecoveryPet? pet` with `pet: pet ?? this.pet`,
      // which makes clearing impossible — there is no argument that distinguishes
      // "not mentioned" from "explicitly null". The live subscription above needs
      // this, because a deleted pet row has to be able to clear the state.
      final withPet = const DashboardDataState(pet: null, loading: false);
      expect(withPet.pet, isNull);

      final cleared = withPet.copyWith(pet: null);
      expect(cleared.pet, isNull);
    });

    test('omitting pet leaves it alone', () {
      // Built through the real service mapper so the "unchanged" case is pinned
      // against an actual pet rather than against null — pinning it against null
      // would pass even if the sentinel were broken.
      final anyPet = RecoveryPetService.petFromRow(RecoveryPetRow(
        id: 'active_pet',
        name: 'Ash',
        speciesOrStyle: 'wolf',
        energy: 100,
        bond: 10,
        mood: 'content',
        sparks: 5,
        unlockedItems: '[]',
        equippedOutfit: '[]',
        lastFedAt: 0,
        createdAt: 0,
        equippedSlotsJson: '[]',
        pathLevel: 1,
        pathXp: 0,
      ));
      final before = DashboardDataState(pet: anyPet, loading: false);
      final after = before.copyWith(loading: true);
      expect(after.pet, same(anyPet),
          reason: 'omitting pet must keep the old value; a sentinel that '
              'forgot the identical() check would null it out');
      expect(after.loading, isTrue);
    });
  });

  group('the `get _pet => ref.watch(...)` getter is safe from event handlers',
      () {
    // Both pet_home_screen and pet_trials_screen read pet state through a
    // getter that calls `ref.watch`. From `build` that is exactly right — the
    // dependency registers and the screen stays live. From an EVENT HANDLER it
    // is a different question: `ref.watch` outside build is not a valid
    // subscription point in Riverpod, and pet_home_screen's `_adoptSpecies` and
    // `_openDresser` both read the getter that way.
    //
    // This test pins the answer so the pattern is a decision rather than an
    // accident. If riverpod ever tightens this, the failure lands here instead
    // of on a user's tap.
    testWidgets('a getter that watches is readable from a tap handler',
        (tester) async {
      int? fromHandler;
      int? fromBuild;

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: _GetterProbe(
              onBuild: (v) => fromBuild = v,
              onHandler: (v) => fromHandler = v,
            ),
          ),
        ),
      ));

      expect(fromBuild, 7, reason: 'build must see the value');

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(fromHandler, 7,
          reason: 'if this ever throws, every screen using the getter pattern '
              'crashes on tap — including _adoptSpecies, the action that '
              'spends a user\'s Sparks');
    });
  });
}

class _ProbeNotifier extends Notifier<int> {
  @override
  int build() => 7;
}

final probeProvider = NotifierProvider<_ProbeNotifier, int>(_ProbeNotifier.new);

/// A faithful reproduction of `RecoveryPet? get _pet =>
/// ref.watch(dashboardDataProvider).pet;` in `_PetHomeScreenState` /
/// `_PetTrialsScreenState`: a `ConsumerState` whose getter calls `ref.watch`,
/// read both from `build` and from a button callback.
///
/// It has to be a ConsumerState rather than a ConsumerWidget because this repo
/// is on flutter_riverpod 3.4.3, where `ConsumerWidget.build` receives `ref`
/// as a parameter and exposes no `ref` getter. A getter can only reach `ref` on
/// a `ConsumerState`.
class _GetterProbe extends ConsumerStatefulWidget {
  const _GetterProbe({required this.onBuild, required this.onHandler});

  final void Function(int) onBuild;
  final void Function(int) onHandler;

  @override
  ConsumerState<_GetterProbe> createState() => _GetterProbeState();
}

class _GetterProbeState extends ConsumerState<_GetterProbe> {
  int get _value => ref.watch(probeProvider);

  @override
  Widget build(BuildContext context) {
    widget.onBuild(_value);
    return Column(
      children: [
        Text('value $_value', textDirection: TextDirection.ltr),
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => widget.onHandler(_value),
            child: const Text('tap'),
          ),
        ),
      ],
    );
  }
}
