// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/resources/resource_policy.dart';
import '../../core/resources/resource_request.dart';
import '../../widgets/app_primitives.dart';
import 'resource_toolbar.dart';

/// In-app reader for approved HTML recovery resources.
///
/// Scope honesty, stated plainly because it is easy to overclaim: a page here is
/// still an external website. Its server and any embedded third parties receive
/// the device's IP address and user agent. Keeping the browser closed does not
/// make the site private, and this screen does not claim to block trackers.
class ResourceWebScreen extends StatefulWidget {
  final ResourceRequest request;
  final ResourcePolicy? policy;
  final Future<void> Function(ResourceRequest request)? onOpenResource;
  final Future<void> Function(Uri uri)? onOpenExternal;

  /// Lets host tests run this screen without a platform WebView.
  final Widget Function(WebViewController controller)? webViewBuilder;
  final Future<WebViewController> Function(Uri uri)? controllerBuilder;

  const ResourceWebScreen({
    super.key,
    required this.request,
    this.policy,
    this.onOpenResource,
    this.onOpenExternal,
    this.webViewBuilder,
    this.controllerBuilder,
  });

  @override
  State<ResourceWebScreen> createState() => _ResourceWebScreenState();
}

class _ResourceWebScreenState extends State<ResourceWebScreen> {
  WebViewController? _controller;
  Uri? _currentUri;
  double _progress = 0;
  String _host = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUri = widget.request.uri;
    _host = widget.request.uri.host;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _controller = null;
      _currentUri = widget.request.uri;
      _error = null;
      _progress = 0;
    });

    try {
      final controller = widget.controllerBuilder == null
          ? WebViewController()
          : await widget.controllerBuilder!(widget.request.uri);
      if (!mounted) return;

      // JavaScript stays disabled. No site in the scoped registry needs it, and
      // turning it on is a per-site decision that would require a documented
      // exception plus tests (risk RV-13), not a default.
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value / 100);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            final uri = Uri.tryParse(url);
            setState(() {
              _progress = 0;
              _error = null;
              _currentUri = uri ?? _currentUri;
              _host = uri?.host ?? '';
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            final uri = Uri.tryParse(url);
            setState(() {
              _progress = 0;
              _currentUri = uri ?? _currentUri;
              _host = uri?.host ?? _host;
            });
            await _refreshNavState();
          },
          onWebResourceError: (error) {
            // Subresource errors are noisy and often benign; only a main-frame
            // failure is worth telling the user about. The flag is nullable on
            // this platform type, and absent means "unknown", so treat it as a
            // main-frame failure rather than silently swallowing it.
            if (!mounted || error.isForMainFrame == false) return;
            final description = error.description;
            setState(() => _error = description.trim().isEmpty
                ? 'This page could not be loaded.'
                : description);
          },
          onHttpError: (error) {
            // A 404/403 that still renders an HTML body must read as an error
            // rather than a successfully loaded page.
            if (!mounted) return;
            final status = error.response?.statusCode;
            if (status != null && status >= 400) {
              setState(() => _error =
                  'The site returned an error (HTTP $status).');
            }
          },
          onNavigationRequest: _decide,
        ),
      );
      await controller.loadRequest(widget.request.uri);
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = controller;
        _host = widget.request.uri.host;
      });
      await _refreshNavState();
    } catch (error) {
      debugPrint('Resource WebView startup failed: $error');
      if (!mounted) return;
      setState(() => _error = 'This page could not be loaded. Check your connection.');
    }
  }

  /// Re-routes every navigation, including in-page link clicks, through policy.
  NavigationDecision _decide(NavigationRequest navigation) {
    final parsed = Uri.tryParse(navigation.url);
    if (parsed == null) {
      _reportBlocked();
      return NavigationDecision.prevent;
    }
    // Subframe requests are page-internal (ads, images, trackers). They are not
    // a user navigation and must not be blocked by route policy.
    if (!navigation.isMainFrame) return NavigationDecision.navigate;

    final activePolicy = widget.policy ?? ResourcePolicy.defaultPolicy;
    final decision = activePolicy.classify(
      ResourceRequest(uri: parsed, title: 'Document', sourceId: 'web-nav'),
      currentUri: _currentUri,
    );
    switch (decision.route) {
      case ResourceRoute.web:
        return NavigationDecision.navigate;
      case ResourceRoute.pdf:
        // Android WebView does not reliably render PDFs, so hand a PDF to the
        // native reader rather than navigating into a blank frame.
        _openPdf(parsed);
        return NavigationDecision.prevent;
      case ResourceRoute.blocked:
        _reportBlocked();
        return NavigationDecision.prevent;
      case ResourceRoute.requiresExternalApproval:
        _reportBlocked(externalUri: parsed);
        return NavigationDecision.prevent;
      case ResourceRoute.system:
        _reportBlocked(systemUri: parsed);
        return NavigationDecision.prevent;
    }
  }

  void _openPdf(Uri uri) {
    final handler = widget.onOpenResource;
    if (!mounted) return;
    if (handler == null) {
      _reportBlocked(externalUri: uri);
      return;
    }
    unawaited(_openPdfRoute(handler, uri));
  }

  Future<void> _openPdfRoute(
    Future<void> Function(ResourceRequest request) handler,
    Uri uri,
  ) async {
    try {
      await handler(ResourceRequest(
        uri: uri,
        title: 'Document',
        sourceId: 'web-pdf-link',
        kind: ResourceKind.pdf,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This PDF could not be opened.');
      }
    }
  }

  void _reportBlocked({Uri? externalUri, Uri? systemUri}) {
    if (!mounted) return;
    final externalHandler = widget.onOpenExternal;
    final resourceHandler = widget.onOpenResource;
    final action = externalUri != null && externalHandler != null
        ? SnackBarAction(
            label: 'Review',
            onPressed: () => unawaited(externalHandler(externalUri)),
          )
        : systemUri != null && resourceHandler != null
            ? SnackBarAction(
                label: 'Continue',
                onPressed: () => unawaited(resourceHandler(ResourceRequest(
                  uri: systemUri,
                  title: 'Device link',
                  sourceId: 'web-system-link',
                ))),
              )
            : null;
    final message = externalUri != null
        ? 'This link goes to ${externalUri.host}, outside the approved in-app sources.'
        : systemUri != null
            ? 'This link needs your phone or mail app.'
            : 'That link was not opened.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  Future<void> _refreshNavState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    } catch (_) {
      // A controller torn down mid-navigation needs no nav-state update.
    }
  }

  /// Web history first, route pop second, so back inside a page does not
  /// discard the recovery screen underneath.
  Future<void> _handleBack() async {
    final controller = _controller;
    try {
      if (controller != null && await controller.canGoBack()) {
        await controller.goBack();
        if (mounted) await _refreshNavState();
        return;
      }
    } catch (_) {
      // If the native history controller is unavailable, back closes the
      // reader rather than trapping the user on a non-responsive page.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reload() async {
    try {
      await _controller?.reload();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This page could not be reloaded.');
      }
    }
  }

  Future<void> _navigateHistory({required bool forward}) async {
    try {
      if (forward) {
        await _controller?.goForward();
      } else {
        await _controller?.goBack();
      }
      await _refreshNavState();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Page navigation is temporarily unavailable.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.request.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
                onPressed: _controller == null ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(ResourceViewerToolbar.height),
            child: ResourceViewerToolbar(
              host: _host.isEmpty ? widget.request.uri.host : _host,
              onOpenExternal: widget.onOpenExternal == null
                  ? null
                  : () => widget.onOpenExternal!(
                        _currentUri ?? widget.request.uri,
                      ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_progress > 0 && _progress < 1)
                LinearProgressIndicator(
                  value: _progress,
                  semanticsLabel: 'Page loading progress',
                ),
              Expanded(
                child: _error != null
                    ? SingleChildScrollView(
                        child: AppErrorState(
                          title: 'Page unavailable',
                          message: _error!,
                          onRetry: _load,
                        ),
                      )
                    : (_controller == null
                        ? const SingleChildScrollView(
                            child: AppLoadingState(message: 'Opening page…'),
                          )
                        : widget.webViewBuilder?.call(_controller!) ??
                            WebViewWidget(controller: _controller!)),
              ),
              _NavBar(
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onBack: () => _navigateHistory(forward: false),
                onForward: () => _navigateHistory(forward: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _NavBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: canGoBack ? onBack : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Forward',
              onPressed: canGoForward ? onForward : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}