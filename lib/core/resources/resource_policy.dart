// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import '../../data/recovery_literature.dart';
import '../../data/recovery_resources.dart';
import 'aa_step_resources.dart';
import 'resource_request.dart';

enum ResourceRoute { pdf, web, system, requiresExternalApproval, blocked }

/// The exhaustive, side-effect-free result of routing a resource request.
class ResourceDecision {
  final ResourceRoute route;
  final Uri uri;
  final String reason;

  const ResourceDecision({
    required this.route,
    required this.uri,
    required this.reason,
  });

  bool get opensInApp => route == ResourceRoute.pdf || route == ResourceRoute.web;
}

/// Central HTTPS/origin policy for resource viewing and PDF acquisition.
///
/// This class intentionally performs no networking. Trusted origins are a
/// fixed registry. The PDF acquirer preflights hostname resolution on each
/// redirect hop, but the HTTP client may resolve again when connecting, so
/// DNS rebinding remains possible; WebView DNS is not checked here.
class ResourcePolicy {
  static const int maximumUriLength = 2048;

  final Set<_ResourceOrigin> _trustedOrigins;

  ResourcePolicy({Iterable<Uri>? allowedOrigins})
      : _trustedOrigins = _buildTrustedOrigins(allowedOrigins);

  static final ResourcePolicy defaultPolicy = ResourcePolicy();

  /// Classifies an initial request, or a proposed navigation/redirect from
  /// [currentUri]. Unknown but structurally safe HTTPS destinations require an
  /// explicit external handoff rather than automatic embedded navigation.
  ResourceDecision classify(ResourceRequest request, {Uri? currentUri}) {
    final uri = request.uri;
    if (_isSystemScheme(uri)) {
      final invalidReason = _invalidSystemReason(uri);
      if (invalidReason != null) {
        return ResourceDecision(
          route: ResourceRoute.blocked,
          uri: uri,
          reason: invalidReason,
        );
      }
      return ResourceDecision(
        route: ResourceRoute.system,
        uri: uri,
        reason: 'This action needs your device\'s phone or mail app.',
      );
    }

    final unsafeReason = unsafeHttpsReason(uri);
    if (unsafeReason != null) {
      return ResourceDecision(
        route: ResourceRoute.blocked,
        uri: uri,
        reason: unsafeReason,
      );
    }

    if (!isTrustedOrigin(uri)) {
      return ResourceDecision(
        route: ResourceRoute.requiresExternalApproval,
        uri: uri,
        reason: 'This website is not an approved in-app resource source.',
      );
    }

    if (currentUri != null) {
      final currentUnsafeReason = unsafeHttpsReason(currentUri);
      if (currentUnsafeReason != null || !isTrustedOrigin(currentUri)) {
        return ResourceDecision(
          route: ResourceRoute.blocked,
          uri: uri,
          reason: 'The current document source is not approved for redirects.',
        );
      }
      if (!allowsAutomaticRedirect(
        originalUri: request.uri,
        currentUri: currentUri,
        nextUri: uri,
      )) {
        return ResourceDecision(
          route: ResourceRoute.requiresExternalApproval,
          uri: uri,
          reason: 'This link leaves the approved document source.',
        );
      }
    }

    return ResourceDecision(
      route: _routeFor(request, uri),
      uri: uri,
      reason: 'Approved in-app resource source.',
    );
  }

  /// Rejects only structural URL threats. It deliberately does not claim a
  /// hostname is public; the acquirer resolves and validates DNS per hop.
  String? unsafeHttpsReason(Uri uri) {
    if (uri.toString().length > maximumUriLength) {
      return 'This link is too long to open safely.';
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return 'Only secure HTTPS website links can open in the app.';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Links with embedded account details cannot open in the app.';
    }
    if (uri.host.isEmpty || uri.host.contains('%')) {
      return 'This website address is not valid.';
    }
    if (uri.hasPort && uri.port != 443) {
      return 'This website uses an unsupported network port.';
    }

    final host = uri.host.toLowerCase();
    if (_isIpLiteral(host)) {
      return 'Direct IP-address links cannot open in the app.';
    }
    if (_isLocalHostName(host)) {
      return 'Local network links cannot open in the app.';
    }
    return null;
  }

  bool isTrustedOrigin(Uri uri) {
    if (unsafeHttpsReason(uri) != null) return false;
    return _trustedOrigins.contains(_ResourceOrigin.fromUri(uri));
  }

  /// Permits a redirect only when it remains on the original/current exact
  /// HTTPS origin. AA's apex and www hosts are the one audited alias pair.
  bool allowsAutomaticRedirect({
    required Uri originalUri,
    required Uri currentUri,
    required Uri nextUri,
  }) {
    if (unsafeHttpsReason(originalUri) != null ||
        unsafeHttpsReason(currentUri) != null ||
        unsafeHttpsReason(nextUri) != null ||
        !isTrustedOrigin(originalUri) ||
        !isTrustedOrigin(currentUri) ||
        !isTrustedOrigin(nextUri)) {
      return false;
    }
    return _sameOriginOrAaAlias(nextUri, originalUri) ||
        _sameOriginOrAaAlias(nextUri, currentUri);
  }

  static ResourceRoute _routeFor(ResourceRequest request, Uri uri) {
    return switch (request.kind) {
      ResourceKind.pdf => ResourceRoute.pdf,
      ResourceKind.web => ResourceRoute.web,
      ResourceKind.auto => uri.path.toLowerCase().endsWith('.pdf')
          ? ResourceRoute.pdf
          : ResourceRoute.web,
    };
  }

  static bool _isSystemScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'tel' || scheme == 'sms' || scheme == 'mailto';
  }

  static String? _invalidSystemReason(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (uri.toString().length > maximumUriLength ||
        uri.userInfo.isNotEmpty ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.trim().isEmpty) {
      return 'This system link is not valid.';
    }
    if (scheme == 'tel' || scheme == 'sms') {
      if (!RegExp(r'^\+?[0-9(). ,;*#-]{3,40}$').hasMatch(uri.path)) {
        return 'This phone link is not valid.';
      }
    } else {
      final address = uri.path;
      if (!RegExp(r'^[^\s@<>]+@[^\s@<>.]+(?:\.[^\s@<>.]+)+$')
          .hasMatch(address)) {
        return 'This mail link is not valid.';
      }
    }
    return null;
  }

  static Set<_ResourceOrigin> _buildTrustedOrigins(
    Iterable<Uri>? allowedOrigins,
  ) {
    final origins = <_ResourceOrigin>{};
    final inputs = allowedOrigins ?? _registeredResourceUris();
    for (final uri in inputs) {
      if (uri.scheme.toLowerCase() != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty ||
          (uri.hasPort && uri.port != 443)) {
        continue;
      }
      origins.add(_ResourceOrigin.fromUri(uri));
    }
    for (final host in AaStepResources.officialHosts) {
      origins.add(_ResourceOrigin('https', host, 443));
    }
    return origins;
  }

  static Iterable<Uri> _registeredResourceUris() sync* {
    for (final url in RecoveryLiterature.allUrls) {
      final uri = Uri.tryParse(url);
      if (uri != null) yield uri;
    }
    for (final url in RecoveryResources.allUrls) {
      final uri = Uri.tryParse(url);
      if (uri != null) yield uri;
    }
  }

  static bool _sameOriginOrAaAlias(Uri first, Uri second) {
    final firstOrigin = _ResourceOrigin.fromUri(first);
    final secondOrigin = _ResourceOrigin.fromUri(second);
    if (firstOrigin == secondOrigin) return true;
    return firstOrigin.scheme == 'https' &&
        secondOrigin.scheme == 'https' &&
        firstOrigin.port == 443 &&
        secondOrigin.port == 443 &&
        AaStepResources.officialHosts.contains(firstOrigin.host) &&
        AaStepResources.officialHosts.contains(secondOrigin.host);
  }

  static bool _isLocalHostName(String host) {
    return host == 'localhost' ||
        host == 'local' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local');
  }

  static bool _isIpLiteral(String host) {
    if (host.contains(':')) return true;
    if (RegExp(r'^\d+$').hasMatch(host)) return true;
    final segments = host.split('.');
    if (segments.length != 4 || segments.any((segment) => segment.isEmpty)) {
      return false;
    }
    return segments.every((segment) {
      final value = int.tryParse(segment);
      return value != null && value >= 0 && value <= 255;
    });
  }
}

class _ResourceOrigin {
  final String scheme;
  final String host;
  final int port;

  const _ResourceOrigin(this.scheme, this.host, this.port);

  factory _ResourceOrigin.fromUri(Uri uri) {
    final defaultPort = uri.scheme.toLowerCase() == 'https' ? 443 : uri.port;
    return _ResourceOrigin(
      uri.scheme.toLowerCase(),
      uri.host.toLowerCase(),
      uri.hasPort ? uri.port : defaultPort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ResourceOrigin &&
        other.scheme == scheme &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(scheme, host, port);
}
