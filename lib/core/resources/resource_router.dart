// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../screens/resource_viewer/resource_pdf_screen.dart';
import '../../screens/resource_viewer/resource_web_screen.dart';
import 'resource_policy.dart';
import 'resource_request.dart';

/// Opens a resource request inside the app where that is safe, and hands off to
/// the OS only when a person asked for it.
///
/// Every URL decision comes from [ResourcePolicy]; this class owns navigation
/// and nothing else. Screens never implement their own scheme or origin rules,
/// which is what keeps a redirect in one place able to refuse a destination.
class ResourceRouter {
  const ResourceRouter._();

  /// Opens [request], producing exactly one navigation or one OS action.
  ///
  /// [onExternalApproval] exists so a host test can observe an approval without
  /// a platform channel. When omitted, the default shows a confirmation dialog
  /// naming the destination host before anything leaves the app.
  static Future<void> open(
    BuildContext context,
    ResourceRequest request, {
    ResourcePolicy? policyOverride,
    Future<bool> Function(BuildContext context, Uri uri)? onExternalApproval,
    Future<bool> Function(Uri uri)? launchUri,
  }) async {
    final activePolicy = policyOverride ?? ResourcePolicy.defaultPolicy;
    final decision = activePolicy.classify(request);

    // Safety and consent are decided BEFORE anything else, including a test scope.
    // The scope overrides *in-app navigation only*. If an override could observe
    // a `file://` URL or an unapproved host, the policy would be advisory rather
    // than binding, and consent would belong to a test seam instead of a person.
    if (decision.route == ResourceRoute.blocked) {
      await _explain(context, decision);
      return;
    }
    if (decision.route == ResourceRoute.requiresExternalApproval) {
      final approved =
          await _confirm(context, decision.uri, onExternalApproval);
      if (approved && context.mounted) {
        await _launchSystem(context, decision.uri, launchUri);
      }
      return;
    }

    // Both remaining in-app routes may be intercepted by an installed scope.
    final scope = ResourceRouterScope.maybeOf(context);
    final override = scope?.onOpen;
    if (override != null) {
      await override(context, request);
      return;
    }

    switch (decision.route) {
      case ResourceRoute.pdf:
        final navigator = Navigator.of(context);
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ResourcePdfScreen(
              request: request,
              onOpenResource: (next) => ResourceRouter.open(
                navigator.context,
                next,
                policyOverride: activePolicy,
                launchUri: launchUri,
              ),
              onOpenExternal: (uri) => _handoff(
                navigator.context,
                uri,
                onExternalApproval,
                launchUri,
              ),
            ),
          ),
        );
      case ResourceRoute.web:
        final navigator = Navigator.of(context);
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ResourceWebScreen(
              request: request,
              policy: activePolicy,
              onOpenResource: (next) => ResourceRouter.open(
                navigator.context,
                next,
                policyOverride: activePolicy,
                launchUri: launchUri,
              ),
              onOpenExternal: (uri) => _handoff(
                navigator.context,
                uri,
                onExternalApproval,
                launchUri,
              ),
            ),
          ),
        );
      case ResourceRoute.system:
        await _launchSystem(context, request.uri, launchUri);
      case ResourceRoute.blocked:
      case ResourceRoute.requiresExternalApproval:
        // Both handled above, before the scope lookup. Reached only if a future
        // route is added without a decision above; fail closed rather than
        // navigating or launching anything.
        await _explain(context, decision);
    }
  }

  /// Confirms before any document leaves the app, naming the real destination.
  ///
  /// A failed in-app load never falls through to this on its own: the caller
  /// must have asked, or the reader's explicit browser button must have been
  /// tapped. That is the difference between an escape hatch and a silent
  /// fallback to Chrome.
  static Future<bool> _confirm(
    BuildContext context,
    Uri uri,
    Future<bool> Function(BuildContext context, Uri uri)? onExternalApproval,
  ) async {
    if (onExternalApproval != null) return onExternalApproval(context, uri);
    if (!context.mounted) return false;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Recovery for All?'),
        content: Text(
          'This link goes to ${uri.host}, which is not an approved in-app '
          'source. It will open in your browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open externally'),
          ),
        ],
      ),
    );
    return choice ?? false;
  }

  /// Performs exactly one OS launch for an approved handoff.
  ///
  /// This is the only place an in-app reader may reach the OS, and it is always
  /// reached from an explicit control. A failed load never calls it.
  static Future<void> _handoff(
    BuildContext context,
    Uri uri,
    Future<bool> Function(BuildContext context, Uri uri)? onExternalApproval,
    Future<bool> Function(Uri uri)? launchUri,
  ) async {
    final approved = await _confirm(context, uri, onExternalApproval);
    if (approved && context.mounted) {
      await _launchSystem(context, uri, launchUri);
    }
  }

  static Future<void> _launchSystem(
    BuildContext context,
    Uri uri,
    Future<bool> Function(Uri uri)? launchUri,
  ) async {
    if (!context.mounted) return;
    try {
      final launched = await (launchUri?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (launched || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No app on this device can open that link.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No app on this device can open that link.'),
        ),
      );
    }
  }

  static Future<void> _explain(
    BuildContext context,
    ResourceDecision decision,
  ) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(decision.reason)),
    );
  }
}

/// Lets a host override routing without a platform channel.
///
/// Production code has no scope installed, so the default screen pushes apply.
/// A widget test installs one to observe the navigation decision directly,
/// which is what proves "exactly one internal navigation" without a WebView or
/// a PDF plugin.
class ResourceRouterScope extends InheritedWidget {
  final Future<void> Function(BuildContext context, ResourceRequest request)?
      onOpen;

  const ResourceRouterScope({
    super.key,
    required this.onOpen,
    required super.child,
  });

  static ResourceRouterScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResourceRouterScope>();

  @override
  bool updateShouldNotify(ResourceRouterScope oldWidget) =>
      oldWidget.onOpen != onOpen;
}