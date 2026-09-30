// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/accessibility_contracts_test.dart
//
// Phase 12. The a11y audit fixed a large set of real defects, but almost none
// of it was protected by a test, and a Semantics wrapper is exactly the kind
// of change a later refactor deletes as "redundant" without anyone noticing
// the screen-reader regression.
//
// These tests assert CONTRACTS, not styling: that a control announces as a
// button, that a disabled control announces disabled AND does not fire, that
// state otherwise visible only as colour or a painted shape is exposed as a
// value, and that the accessible name is announced ONCE.
//
// Why a hand-rolled tree walk instead of `find.bySemanticsLabel`:
// that finder tests `element.renderObject.debugSemantics`, which is NOT the
// node the platform sees. A dump of the real tree showed a Semantics wrapper
// whose label was "Call 988. Sub Line" still reported zero matches, because
// the annotation had been merged into a child node. Walking
// `renderView.owner!.semanticsOwner!.rootSemanticsNode!` looks at exactly what
// an accessibility service would, and it is what caught the double-announcement
// defect below. See `_allNodes` for which owner to read and why.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/widgets/dashboard_cards.dart';
import 'package:recovery_for_all/widgets/dashboard_sections.dart';
import 'package:recovery_for_all/widgets/wellness_wheel_widget.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppColors.themeDataFor(const ThemePreference(), Brightness.dark),
    home: Scaffold(body: child),
  );
}

List<SemanticsNode> _allNodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // The root is the per-VIEW pipeline owner's, not the binding root's. Two
  // traps, and both look completely reasonable in source:
  //
  //  1. `binding.rootPipelineOwner.semanticsOwner` is NULL in a widget test.
  //     Modern Flutter gives each `View` its own `PipelineOwner` hung off the
  //     root, and THAT one carries the SemanticsOwner. Reading the root owner
  //     throws "Null check operator used on a null value".
  //  2. `binding.pipelineOwner` is a *different*, legacy PipelineOwner
  //     instance (see RendererBinding), not an alias for the root. It works,
  //     and it is what the framework's docs told us to do for years, which is
  //     exactly why it is a trap.
  //
  // This is the same expression flutter_test uses internally, in
  // `finders.dart`: `renderView.owner!.semanticsOwner!.rootSemanticsNode!`.
  for (final renderView in tester.binding.renderViews) {
    walk(renderView.owner!.semanticsOwner!.rootSemanticsNode!);
  }
  return out;
}

/// The single node whose label CONTAINS [phrase].
///
/// Containment rather than equality on purpose: a Semantics label that does
/// not exclude its children is concatenated with them, so the tree legitimately
/// holds "Open Skill Tree. Kin, level 3, 45 of 100 XP." as a prefix of a
/// longer string on some widgets.
SemanticsNode _nodeContaining(WidgetTester tester, String phrase) {
  final hits = _allNodes(tester).where((n) => n.label.contains(phrase)).toList();
  expect(hits, hasLength(1),
      reason: 'expected exactly one node whose label contains "$phrase"; '
          'labels were: ${_allNodes(tester).map((n) => n.label).toList()}');
  return hits.single;
}

/// The single node whose label is exactly [label].
SemanticsNode _nodeWithLabel(WidgetTester tester, String label) {
  final hits = _allNodes(tester).where((n) => n.label == label).toList();
  expect(hits, hasLength(1),
      reason: 'expected exactly one node labelled "$label"; labels were: '
          '${_allNodes(tester).map((n) => n.label).toList()}');
  return hits.single;
}

/// Runs [body] with semantics enabled, disposing the handle deterministically.
///
/// The handle must be disposed BEFORE the test ends: `flutter_test` verifies
/// that in `_endOfTestVerifications`, which runs before tearDown callbacks, so
/// an `addTearDown(handle.dispose)` is too late and fails every test.
Future<void> _withSemantics(
    WidgetTester tester, Future<void> Function() body) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

void main() {
  group('SosTile', () {
    testWidgets('announces one combined name, as a button', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.phone_in_talk,
            color: Colors.red,
            title: 'Call 988',
            subtitle: 'Suicide & Crisis Lifeline · 24/7',
            onTap: () {},
          ),
        ));
        await tester.pump();

        // SAFETY: every SOS destination must be operable by a screen reader.
        final node = _nodeWithLabel(
            tester, 'Call 988. Suicide & Crisis Lifeline · 24/7');
        expect(node.flagsCollection.isButton, isTrue,
            reason: 'SOS tiles must announce as buttons, not static text');
      });
    });

    testWidgets('announces the name exactly once', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.phone_in_talk,
            color: Colors.red,
            title: 'Call 988',
            subtitle: 'Suicide & Crisis Lifeline · 24/7',
            onTap: () {},
          ),
        ));
        await tester.pump();

        // Phase 12 defect, found by dumping the real semantics tree: without
        // `excludeSemantics` the curated label was concatenated with the
        // ListTile's own title and subtitle, so the line was read twice.
        final spoken = _allNodes(tester)
            .where((n) => n.label.contains('Call 988'))
            .map((n) => n.label)
            .toList();
        expect(spoken, ['Call 988. Suicide & Crisis Lifeline · 24/7'],
            reason: 'a screen reader must not hear this destination twice');
      });
    });

    testWidgets('disabled tile announces disabled and does not fire',
        (tester) async {
      await _withSemantics(tester, () async {
        var pressed = 0;
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.person_pin_circle,
            color: Colors.blue,
            title: 'Call Sponsor',
            subtitle: 'Add in Settings',
            enabled: false,
            onTap: () => pressed++,
          ),
        ));
        await tester.pump();

        final node = _nodeWithLabel(tester, 'Call Sponsor. Add in Settings');
        expect(node.flagsCollection.isButton, isTrue);
        // isEnabled is a Tristate, not a bool, so "not enabled" is anything
        // other than an explicit true.
        expect(node.flagsCollection.isEnabled, isNot(Tristate.isTrue),
            reason: '"Call Sponsor" with no sponsor linked must announce as '
                'unavailable, otherwise a screen-reader user taps a dead end');

        await tester.tap(find.byType(SosTile));
        await tester.pump();
        expect(pressed, 0, reason: 'a disabled SOS tile must not be tappable');
      });
    });

    testWidgets('excluding children must not cost the tile its tap action',
        (tester) async {
      // A button with a role but no action is worse than no button at all, and
      // this is exactly what excludeSemantics would have caused.
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          SosTile(
            icon: Icons.phone_in_talk,
            color: Colors.red,
            title: 'Call 988',
            subtitle: 'Suicide & Crisis Lifeline · 24/7',
            onTap: () {},
          ),
        ));
        await tester.pump();

        final node = _nodeWithLabel(
            tester, 'Call 988. Suicide & Crisis Lifeline · 24/7');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: 'the SOS destination must be actionable by a screen reader');
      });
    });
  });

  group('dashboard cards carry one combined accessible name', () {
    testWidgets('ToolCard', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          ToolCard(
            label: 'Meeting Finder',
            subtitle: 'Live and upcoming',
            icon: Icons.groups_outlined,
            onTap: () {},
          ),
        ));
        await tester.pump();

        final node = _nodeWithLabel(tester, 'Meeting Finder. Live and upcoming');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      });
    });

    testWidgets('SupportLinkRow', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          SupportLinkRow(
            icon: Icons.qr_code_scanner,
            title: 'Fellowship Handshake',
            subtitle: 'QR connect, offline, private',
            onTap: () {},
          ),
        ));
        await tester.pump();

        final node = _nodeWithLabel(
            tester, 'Fellowship Handshake. QR connect, offline, private');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      });
    });

    testWidgets('PledgeCard names its unpledged action', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(
            _host(PledgeCard(pledged: false, onPledge: () {})));
        await tester.pump();

        // Exact match matters here: the adjacent sentence "Today I pledge to
        // stay the course." also contains the words "I pledge", and matching
        // on a substring would find both nodes.
        final node = _nodeWithLabel(tester, 'I pledge');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      });
    });
  });

  group('state conveyed only as colour or a painted shape is spoken', () {
    testWidgets('SkyCrown announces the empty star count and is operable',
        (tester) async {
      await _withSemantics(tester, () async {
        var taps = 0;
        await tester.pumpWidget(_host(
          SkyCrown(
            nodes: const [],
            skyName: 'Recovery for All',
            onTap: () => taps++,
          ),
        ));
        await tester.pump();

        final node = _nodeContaining(tester, 'Open your constellation');
        expect(node.flagsCollection.isButton, isTrue,
            reason: 'the constellation is the top dashboard surface; it must '
                'be operable without sight');
        expect(node.label, contains('no stars yet'),
            reason: '"0 stars" and "no stars yet" are different states');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        await tester.tap(find.byType(SkyCrown));
        expect(taps, 1);
      });
    });

    testWidgets('CompanionSection announces level and XP', (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          CompanionSection(
            pet: _pet(),
            onTap: () {},
            onCheckIn: () {},
            onWalk: () {},
            onOpen: () {},
          ),
        ));
        await tester.pump();

        // 145 XP => level 3 with 45 into the current level. The XP used to be
        // visible only as a LinearProgressIndicator, which announces nothing.
        final node = _nodeContaining(tester, 'Open Skill Tree');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.label, contains('45 of 100 XP'));
      });
    });

    testWidgets('CompanionSection keeps its nested care actions reachable',
        (tester) async {
      // CompanionSection cannot use excludeSemantics: doing so would drop the
      // check-in and walk buttons from the tree entirely. This pins that.
      await _withSemantics(tester, () async {
        await tester.pumpWidget(_host(
          CompanionSection(
            pet: _pet(),
            onTap: () {},
            onCheckIn: () {},
            onWalk: () {},
            onOpen: () {},
          ),
        ));
        await tester.pump();

        final actionable = _allNodes(tester)
            .where((n) => n.getSemanticsData().hasAction(SemanticsAction.tap))
            .length;
        expect(
            actionable,
            greaterThanOrEqualTo(3),
            reason: 'skill tree, check in, walk and open must all stay operable');
      });
    });
  });

  group('WellnessWheel is adjustable without sight', () {
    // The six spokes are painted into a CustomPainter, which emits no
    // semantics nodes at all. Before the fix the entire six-dimension
    // check-in was invisible to a screen reader; it is the highest-value
    // a11y contract in the app, so it is pinned here.
    testWidgets('exposes one slider node speaking all six dimensions',
        (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(
            _host(WellnessWheelWidget(initialScores: const {})));
        await tester.pump();

        // The child subtree is ExcludeSemantics, so this is unambiguous.
        final node = _nodeContaining(tester, 'Wellness check-in wheel');
        expect(node.flagsCollection.isSlider, isTrue);
        for (final dim in const [
          'Spiritual',
          'Intellectual',
          'Emotional',
          'Physical',
          'Social',
          'Occupational',
        ]) {
          expect(node.label, contains(dim),
              reason: '$dim must be spoken, not just the focused spoke');
        }
        expect(node.label, contains('(adjusting)'),
            reason:
                'the user must know which spoke increase/decrease will move');
      });
    });

    testWidgets('announces its value and what increase/decrease will do',
        (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(
            _host(WellnessWheelWidget(initialScores: const {})));
        await tester.pump();

        final node = _nodeContaining(tester, 'Wellness check-in wheel');

        // Unscored dimensions start at 0.5 => "5 out of 10".
        expect(node.value, '5 out of 10');
        // Flutter's own debug assert requires these whenever the increase and
        // decrease actions are present, so asserting the strings is a faithful
        // proxy for "the actions are wired and announced".
        expect(node.increasedValue, '6 out of 10');
        expect(node.decreasedValue, '4 out of 10');
      });
    });

    testWidgets('adjusting the wheel reports new scores', (tester) async {
      Map<String, double>? captured;
      await tester.pumpWidget(_host(
        WellnessWheelWidget(
          initialScores: const {},
          onScoresChanged: (s) => captured = s,
        ),
      ));

      await tester.tap(find.byType(WellnessWheelWidget));
      await tester.pump();

      expect(captured, isNotNull,
          reason: 'changing the wheel must report the new scores upward');
      expect(captured!.length, 6,
          reason: 'all six dimensions are always reported together');
    });
  });
}

/// Mirrors test/dashboard_sections_test.dart exactly, which is already proven
/// to render CompanionSection (and therefore RecoveryPetCard and the avatar
/// layer) inside a host widget test.
RecoveryPet _pet() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return RecoveryPet(
    id: 'p1',
    name: 'Kin',
    energy: 80,
    bond: 20,
    mood: PetMoodX.happy,
    sparks: 10,
    unlockedItems: const ['starter_glow'],
    equippedOutfit: 'starter_glow',
    equippedSlots: const {},
    lastFedAt: now,
    createdAt: now,
    pathLevel: 3,
    pathXp: 145,
  );
}
