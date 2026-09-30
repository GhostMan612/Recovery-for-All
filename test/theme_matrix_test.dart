// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// test/theme_matrix_test.dart
//
// Phase 15. The existing dashboard tests loop `Brightness.values`, but always
// with the DEFAULT palette and always at the default 800x600 test surface.
// That leaves the two axes Phase 15 actually cares about unverified: the
// 3 palettes x 2 brightness matrix, and whether the cards survive the form
// factors and text scales a real phone actually produces.
//
// No goldens. These surfaces are animated, Lottie-backed and device-dependent,
// so a pixel baseline would be brittle and would fail for reasons that have
// nothing to do with the design system. Instead this asserts the two things
// that are objectively checkable: the schemes really are distinct where the
// engine promises they are, and nothing overflows at any supported size.
//
// Overflow is not asserted by inspecting a flag. A RenderFlex overflow is
// reported as a FlutterError, which the test binding records and rethrows, so
// `tester.takeException()` being null IS the overflow assertion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recovery_for_all/core/theme/app_colors.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';
import 'package:recovery_for_all/widgets/dashboard_cards.dart';
import 'package:recovery_for_all/widgets/dashboard_sections.dart';

/// The overflow-prone half of the dashboard: the fixed-aspect grid, the pinned
/// SOS rows, and the two full-width link rows.
Widget _surfaceUnderTest() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PledgeCard(pledged: false, onPledge: _noop),
      const SizedBox(height: 12),
      ToolGrid(
        title: 'Your Toolbox',
        editing: false,
        hidden: const {},
        onRestore: (_) {},
        onToggleEditing: () {},
        children: const [
          ToolCard(
            label: 'Meeting Finder',
            subtitle: 'Live and upcoming near you',
            icon: Icons.groups_outlined,
            onTap: _noop,
          ),
          ToolCard(
            label: 'Daily Reflection',
            subtitle: 'A few honest lines',
            icon: Icons.edit_note_outlined,
            onTap: _noop,
          ),
          ToolCard(
            label: '7th Tradition',
            subtitle: 'Contribute to the pot',
            icon: Icons.savings_outlined,
            onTap: _noop,
          ),
          ToolCard(
            label: 'Wellness Check-In',
            subtitle: 'Six dimensions',
            icon: Icons.favorite_outline,
            onTap: _noop,
          ),
        ],
      ),
      const SizedBox(height: 12),
      const SosTile(
        icon: Icons.phone_in_talk,
        color: Color(0xFFDC2626),
        title: 'Call 988',
        subtitle: 'Suicide & Crisis Lifeline · 24/7',
        onTap: _noop,
      ),
      const SosTile(
        icon: Icons.person_pin_circle,
        color: Color(0xFF2563EB),
        title: 'Call Sponsor',
        subtitle: 'Add in Settings',
        enabled: false,
        onTap: _noop,
      ),
      const SizedBox(height: 12),
      const SupportLinkRow(
        icon: Icons.qr_code_scanner,
        title: 'Fellowship Handshake',
        subtitle: 'QR connect, offline, private',
        onTap: _noop,
      ),
      const SizedBox(height: 12),
      CompanionSection(
        pet: _pet(),
        onTap: _noop,
        onCheckIn: _noop,
        onWalk: _noop,
        onOpen: _noop,
      ),
      const SizedBox(height: 12),
      SkyCrown(nodes: const [], skyName: 'Recovery for All', onTap: _noop),
    ],
  );
}

Future<void> _pumpAt(
  WidgetTester tester, {
  required AppTheme palette,
  required Brightness brightness,
  Size size = const Size(411, 731),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final theme =
      AppColors.themeDataFor(ThemePreference(palette: palette), brightness);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(child: _surfaceUnderTest()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Phase 15 theme matrix: 3 palettes x 2 brightness', () {
    testWidgets('every combination renders the dashboard surface cleanly',
        (tester) async {
      for (final palette in AppTheme.values) {
        for (final brightness in Brightness.values) {
          await _pumpAt(tester, palette: palette, brightness: brightness);
          expect(tester.takeException(), isNull,
              reason: '$palette / $brightness must render without overflow');
          expect(find.byType(ToolCard), findsNWidgets(4));
        }
      }
    });

    test('the three palettes are genuinely distinct in dark mode', () {
      // Guards `paletteFor` against silently ignoring its argument, which is
      // the failure this whole matrix exists to catch. Only asserted for dark,
      // where the engine copies each palette's own bgDeep into `surface`.
      final surfaces = AppTheme.values
          .map((p) => AppColors.schemeFor(
              AppColors.paletteFor(p), Brightness.dark).surface)
          .toList();
      expect(surfaces.toSet().length, AppTheme.values.length,
          reason: 'dark surfaces: $surfaces');
    });

    test('light and dark are different schemes for every palette', () {
      for (final p in AppTheme.values) {
        final light = AppColors.schemeFor(AppColors.paletteFor(p), Brightness.light);
        final dark = AppColors.schemeFor(AppColors.paletteFor(p), Brightness.dark);
        expect(light.surface, isNot(dark.surface),
            reason: '${p.name} must not render identically in both brightnesses');
      }
    });

    test('deepForest is distinguishable from the other two palettes', () {
      // Accent is the one token that survives into BOTH brightnesses.
      final accents = {
        for (final p in AppTheme.values)
          p: AppColors.paletteFor(p).accent,
      };
      expect(accents[AppTheme.deepForest],
          isNot(accents[AppTheme.midnightSlate]));
      expect(accents[AppTheme.deepForest], isNot(accents[AppTheme.oledPitch]));
    });

    // Documented limitation, asserted so it cannot regress silently: light
    // mode is generated from the seed accent, and midnightSlate and oledPitch
    // share one, so those two are indistinguishable while light. This is a
    // property of the palettes as designed, not a bug, but it was only
    // discoverable by running the matrix.
    test('KNOWN: midnightSlate and oledPitch are identical in light mode', () {
      final a = AppColors.schemeFor(
          AppColors.paletteFor(AppTheme.midnightSlate), Brightness.light);
      final b = AppColors.schemeFor(
          AppColors.paletteFor(AppTheme.oledPitch), Brightness.light);
      expect(a.surface, b.surface);
      expect(a.primary, b.primary);
    });

    test('system mode follows the platform brightness in both directions', () {
      const system = ThemePreference(mode: AppThemeMode.system);
      expect(system.resolve(Brightness.light), Brightness.light);
      expect(system.resolve(Brightness.dark), Brightness.dark);

      // An explicit mode must ignore the platform entirely.
      expect(const ThemePreference(mode: AppThemeMode.dark).resolve(Brightness.light),
          Brightness.dark);
      expect(const ThemePreference(mode: AppThemeMode.light).resolve(Brightness.dark),
          Brightness.light);
    });
  });

  group('Phase 13 form factors and text scales', () {
    const sizes = <String, Size>{
      'small 320x568': Size(320, 568),
      'normal 411x731': Size(411, 731),
      'large 480x1000': Size(480, 1000),
      'landscape 731x411': Size(731, 411),
    };

    for (final entry in sizes.entries) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('${entry.key} at ${scale}x text', (tester) async {
          await _pumpAt(
            tester,
            palette: AppTheme.midnightSlate,
            brightness: Brightness.dark,
            size: entry.value,
            textScale: scale,
          );
          expect(tester.takeException(), isNull,
              reason: 'overflow at ${entry.key} / ${scale}x');
          // The grid must still be laid out, not silently dropped.
          expect(find.byType(ToolCard), findsNWidgets(4));
        });
      }
    }
  });
}

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

void _noop() {}
