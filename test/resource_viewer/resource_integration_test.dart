// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/resources/resource_request.dart';
import 'package:recovery_for_all/core/resources/resource_router.dart';
import 'package:recovery_for_all/screens/resource_viewer/resource_pdf_screen.dart';
import 'package:recovery_for_all/screens/steps_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'AA chapter actions route through the scoped reader and return to the same step state',
      (tester) async {
    final opened = <ResourceRequest>[];
    // Resolved lazily inside the loop: at this point the tree is still empty, so
    // capturing a Navigator state here would throw "No element".
    NavigatorState? readerNavigator;
    final steps = <(int, String)>[
      (1, 'Honesty'),
      (2, 'Hope'),
      (6, 'Willingness'),
      (11, 'Spirituality'),
      (12, 'Service'),
    ];

    // `scrollUntilVisible` defaults its scrollable to `find.byType(Scrollable)`
    // and then calls widget(finder) on it, which throws "Too many elements" as
    // soon as the tree holds more than one Scrollable -- which this screen does
    // (the list, plus one inside every open step panel). Name the steps list
    // explicitly instead.
    Finder stepsList() => find
        .descendant(
          of: find.byType(StepsViewerScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceRouterScope(
          onOpen: (context, request) async {
            opened.add(request);
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Fake in-app PDF reader')),
                ),
              ),
            );
          },
          child: const StepsViewerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final (number, title) in steps) {
      // The tile header title is unique even with a panel open: the expanded
      // body does not repeat `step.title`. Verified by measurement -- adding a
      // defensive "collapse first" tap on `ExpansionTile.first` is what
      // actually introduced "Too many elements", because the list is
      // virtualized and that finder did not resolve to a single tile the way
      // `find.text(title)` does. `scrollUntilVisible` calls widget(finder)
      // internally and throws on more than one match.
      final header = find.text(title);
      expect(header, findsOneWidget,
          reason: 'step $number ($title) must have exactly one tile header');
      await tester.scrollUntilVisible(header, 180, scrollable: stepsList());
      await tester.tap(header);
      await tester.pumpAndSettle();

      // Anchor on the unique per-step label rather than the shared title, and use
      // `ensureVisible` rather than `scrollUntilVisible`: the drag loop can park
      // the target off-screen or behind the app bar, which makes the following
      // tap hit nothing even though the finder resolves.
      final readerAction = find.text('Read Step $number — AA chapter (PDF)');
      await tester.scrollUntilVisible(readerAction, 120, scrollable: stepsList());
      await tester.ensureVisible(readerAction);
      await tester.pumpAndSettle();
      expect(readerAction, findsOneWidget);

      await tester.tap(readerAction, warnIfMissed: false);
      await tester.pumpAndSettle();
      // The FIRST Navigator is the one that owns the pushed route. `.last` is the
      // root, and popping it tears the whole tree down.
      readerNavigator = tester.state<NavigatorState>(find.byType(Navigator).first);

      expect(opened, hasLength(number == 1 ? 1 : opened.length));
      expect(opened.last.uri, ResourceRequest.aaStep(number).uri);
      expect(opened.last.title, ResourceRequest.aaStep(number).title);
      expect(opened.last.sourceId, ResourceRequest.aaStep(number).sourceId);
      expect(find.text('Fake in-app PDF reader'), findsOneWidget);

      // Pop through the captured navigator. `tester.pageBack()` searches for a
      // BackButton/BackButtonIcon and throws "Too many elements" here because
      // both the steps screen and the pushed route expose one; popping directly
      // is what the test actually means to assert anyway.
      readerNavigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Fake in-app PDF reader'), findsNothing,
          reason: 'the reader must be dismissed');

      await tester.scrollUntilVisible(readerAction, 120, scrollable: stepsList());
      await tester.ensureVisible(readerAction);
      await tester.pumpAndSettle();
      expect(readerAction, findsOneWidget,
          reason: 'the same step panel must still be open on return');
    }

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('steps_completed_v1'), isNull);
  });

  testWidgets('a local workbook reader never deletes its caller-owned file',
      (tester) async {
    // Synchronous temp I/O, deliberately. Under `testWidgets` the binding runs
    // in a fake-async zone, and an `await`ed real file operation (createTemp /
    // writeAsBytes) never sees its completion delivered, so the test hangs to
    // its 10-minute limit. Sync I/O is unaffected and is the reliable form here.
    final directory = Directory.systemTemp.createTempSync('rfa_workbook_');
    final workbook =
        File('${directory.path}${Platform.pathSeparator}guide.pdf');
    workbook.writeAsBytesSync(const <int>[0x25, 0x50, 0x44, 0x46]);
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    final reader = ResourcePdfScreen.local(
      path: workbook.path,
      title: 'Counselor guide',
      documentBuilder: (_) => const Center(child: Text('Fake local PDF')),
    );
    expect(reader.localPath, workbook.path);
    expect(reader.request, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => reader),
              ),
              child: const Text('Open workbook'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open workbook'));
    await tester.pumpAndSettle();
    expect(find.text('Fake local PDF'), findsOneWidget);

    // Direct navigator pop, as above: pageBack's BackButton finder is ambiguous
    // with more than one route in the tree, and `find.byType(Navigator).last`
    // is the root navigator, which would tear down the whole tree.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Fake local PDF'), findsNothing);
    expect(workbook.existsSync(), isTrue);
  });
}
