// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/resources/resource_policy.dart';
import 'package:recovery_for_all/core/resources/resource_request.dart';
import 'package:recovery_for_all/core/resources/resource_router.dart';
import 'package:recovery_for_all/screens/resource_viewer/resource_pdf_screen.dart';

/// Proves the router's central promise: an approved request produces exactly one
/// internal navigation, and a rejected one produces none.
void main() {
  ResourceRequest requestFor(String url,
          {ResourceKind kind = ResourceKind.auto}) =>
      ResourceRequest(uri: Uri.parse(url), title: 'T', sourceId: 't', kind: kind);

  Future<void> pumpWithScope(
    WidgetTester tester,
    List<ResourceRequest> opened, {
    Future<void> Function(BuildContext, ResourceRequest)? onOpen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceRouterScope(
          onOpen: (context, request) async {
            opened.add(request);
            if (onOpen != null) return onOpen(context, request);
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('in-app reader')),
                ),
              ),
            );
          },
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ResourceRouter.open(context, requestFor(
                    'https://www.aa.org/sites/default/files/2022-01/en_step1.pdf')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an approved pdf request opens exactly one internal route',
      (tester) async {
    final opened = <ResourceRequest>[];
    await pumpWithScope(tester, opened);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1),
        reason: 'no double navigation, and no external launch');
    expect(find.text('in-app reader'), findsOneWidget);
  });

  testWidgets('a blocked request never reaches the internal reader',
      (tester) async {
    final opened = <ResourceRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceRouterScope(
          onOpen: (context, request) async => opened.add(request),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    ResourceRouter.open(context, requestFor('file:///etc/passwd')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty,
        reason: 'a blocked URL must not navigate anywhere');
  });

  testWidgets('an approved phone action launches exactly once after a tap',
      (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ResourceRouter.open(
                context,
                requestFor('tel:+19555550123'),
                launchUri: (uri) async {
                  launched.add(uri);
                  return true;
                },
              ),
              child: const Text('call'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('call'));
    await tester.pumpAndSettle();

    expect(launched, [Uri.parse('tel:+19555550123')]);
  });

  testWidgets('a failed OS launch is reported instead of silently ignored',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ResourceRouter.open(
                context,
                requestFor('tel:+19555550123'),
                launchUri: (_) async => false,
              ),
              child: const Text('call'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('call'));
    await tester.pumpAndSettle();

    expect(find.text('No app on this device can open that link.'), findsOneWidget);
  });

  testWidgets(
      'an unapproved origin is never handed to the internal reader',
      (tester) async {
    final opened = <ResourceRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceRouterScope(
          onOpen: (context, request) async => opened.add(request),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ResourceRouter.open(
                  context,
                  requestFor('https://aa.org.evil.example/x'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // An unapproved origin needs consent before it can leave the app. With no
    // approval handler installed the default dialog is required, so the read
    // must not have been treated as a trusted in-app resource.
    expect(opened, isEmpty,
        reason: 'a lookalike host must never receive a trusted in-app route');
  });

  test('policy classification is exhaustive over the route enum', () {
    final policy = ResourcePolicy.defaultPolicy;
    final routes = <ResourceRoute>{};
    for (final url in [
      'https://www.aa.org/a.pdf',
      'https://www.aa.org/page',
      'tel:+19555550123',
      'https://unknown.example/x',
      'http://www.aa.org/a',
    ]) {
      routes.add(policy.classify(requestFor(url, kind: ResourceKind.auto)).route);
    }
    expect(routes, containsAll(<ResourceRoute>[
      ResourceRoute.pdf,
      ResourceRoute.web,
      ResourceRoute.system,
      ResourceRoute.requiresExternalApproval,
      ResourceRoute.blocked,
    ]));
  });

  test('ResourcePdfScreen exposes a local mode that owns nothing', () {
    final screen = ResourcePdfScreen.local(path: '/tmp/x.pdf', title: 'Workbook');
    expect(screen.localPath, '/tmp/x.pdf');
    expect(screen.request, isNull);
  });
}