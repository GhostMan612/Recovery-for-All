// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/resources/resource_request.dart';
import 'package:recovery_for_all/screens/resource_viewer/resource_web_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class _FakeWebViewController extends Fake implements WebViewController {
  Uri? loadedUri;
  JavaScriptMode? configuredJavaScriptMode;
  NavigationDelegate? navigationDelegate;
  int reloadCount = 0;
  bool hasBack = false;
  bool hasForward = false;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    configuredJavaScriptMode = javaScriptMode;
  }

  @override
  Future<void> setNavigationDelegate(NavigationDelegate delegate) async {
    navigationDelegate = delegate;
  }

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    loadedUri = uri;
  }

  @override
  Future<bool> canGoBack() async => hasBack;

  @override
  Future<bool> canGoForward() async => hasForward;

  @override
  Future<void> goBack() async {
    hasBack = false;
  }

  @override
  Future<void> goForward() async {
    hasForward = false;
  }

  @override
  Future<void> reload() async {
    reloadCount++;
  }
}

void main() {
  setUpAll(AndroidWebViewPlatform.registerWith);

  testWidgets('loads with JavaScript disabled and displays the live host',
      (tester) async {
    final controller = _FakeWebViewController();
    final request = ResourceRequest(
      uri: Uri.parse('https://www.aa.org/the-twelve-steps'),
      title: 'Twelve Steps',
      sourceId: 'test-resource',
      kind: ResourceKind.web,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceWebScreen(
          request: request,
          controllerBuilder: (_) async => controller,
          webViewBuilder: (_) => const Text('Fake website content'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.loadedUri, request.uri);
    expect(controller.configuredJavaScriptMode, JavaScriptMode.disabled);
    expect(controller.navigationDelegate, isNotNull);
    expect(find.text('www.aa.org'), findsOneWidget);
    expect(find.text('Fake website content'), findsOneWidget);
  });

  testWidgets('reload and browser escape are explicit user actions',
      (tester) async {
    final controller = _FakeWebViewController();
    final escapedTo = <Uri>[];
    final request = ResourceRequest(
      uri: Uri.parse('https://www.aa.org/the-twelve-steps'),
      title: 'Twelve Steps',
      sourceId: 'test-resource',
      kind: ResourceKind.web,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceWebScreen(
          request: request,
          controllerBuilder: (_) async => controller,
          webViewBuilder: (_) => const Text('Fake website content'),
          onOpenExternal: (uri) async => escapedTo.add(uri),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reload'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open in browser'));
    await tester.pumpAndSettle();

    expect(controller.reloadCount, 1);
    expect(escapedTo, [request.uri]);
  });

  testWidgets('controller startup failure shows a retryable error state',
      (tester) async {
    final request = ResourceRequest(
      uri: Uri.parse('https://www.aa.org/the-twelve-steps'),
      title: 'Twelve Steps',
      sourceId: 'test-resource',
      kind: ResourceKind.web,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceWebScreen(
          request: request,
          controllerBuilder: (_) async => throw StateError('startup failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page unavailable'), findsOneWidget);
    expect(find.text('This page could not be loaded. Check your connection.'),
        findsOneWidget);
  });
}
