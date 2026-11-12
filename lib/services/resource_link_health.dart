// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/resource_link_health.dart
//
// Link-rot prevention at runtime (resource-system.md §3–4):
//   * Cached health per URL: {ok: bool, at: epochMs}, TTL 30 days.
//   * Silent staggered refresh of expired entries on screen open
//     (capped per pass — never hammer).
//   * Explicit full verification from Settings ("tap of a button").
//   * Offline / transport failure NEVER marks a link broken — absence
//     of evidence stays absence. Only an explicit bad status flags it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/resources/resource_policy.dart';
import '../data/recovery_literature.dart';
import '../data/recovery_resources.dart';

class LinkHealth {
  final bool? ok;
  final int checkedAtMs;

  const LinkHealth({required this.ok, required this.checkedAtMs});
}

class ResourceLinkHealth {
  ResourceLinkHealth._();

  static final ResourceLinkHealth instance = ResourceLinkHealth._();

  static const String _key = 'resource_link_health_v1';
  static const Duration ttl = Duration(days: 30);
  static const int _maxChecksPerPass = 20;
  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, LinkHealth> _cache = {};
  static bool _loaded = false;
  static bool _busy = false;

  static Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        // Parse per entry. The old `decoded.map(... as bool?)` threw on the
        // FIRST entry with an unexpected type, and the catch wiped the whole
        // cache — so one hand-edited or older-schema value made every link
        // report "never checked" and triggered a full re-verify.
        final parsed = <String, LinkHealth>{};
        decoded.forEach((url, v) {
          try {
            if (v is! Map) return;
            final ok = v['ok'];
            final at = v['at'];
            parsed[url] = LinkHealth(
              ok: ok is bool ? ok : null,
              checkedAtMs: at is int ? at : 0,
            );
          } catch (_) {
            // Skip only the malformed entry.
          }
        });
        _cache = parsed;
      } catch (_) {
        _cache = {};
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final e in _cache.entries)
          e.key: {'ok': e.value.ok, 'at': e.value.checkedAtMs},
      }),
    );
  }

  /// Cached status (no network). [LinkHealth.ok] == null ⇒ never checked.
  Future<LinkHealth> statusFor(String url) async {
    await _load();
    return _cache[url] ??
        const LinkHealth(ok: null, checkedAtMs: 0);
  }

  /// Newest successful-check timestamp across the cache (for the footer
  /// chip). Returns null when nothing has ever been checked.
  Future<int?> lastVerifiedAt() async {
    await _load();
    int? newest;
    for (final h in _cache.values) {
      if (newest == null || h.checkedAtMs > newest) newest = h.checkedAtMs;
    }
    return newest;
  }

  /// One explicit health check. Never follow redirects, transmit to an
  /// insecure URL or download the response body merely to inspect status.
  ///
  /// null means unknown, including a redirected resource: a redirect's
  /// destination must be reviewed separately, not silently fetched.
  /// [client] supports deterministic host tests without real network calls.
  Future<bool?> checkUrl(String url, {http.Client? client}) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        ResourcePolicy.defaultPolicy.unsafeHttpsReason(uri) != null) {
      return null;
    }

    final activeClient = client ?? http.Client();

    Future<int?> getStatus(String method) async {
      try {
        final request = http.Request(method, uri)
          ..followRedirects = false
          ..maxRedirects = 0;
        request.headers.addAll({
          'User-Agent': 'RecoveryForAll link checker',
          'Accept': '*/*',
          if (method == 'GET') 'Range': 'bytes=0-1023',
        });
        final response =
            await activeClient.send(request).timeout(_timeout);
        // A Range header can be ignored by the server. Do not buffer a
        // potentially multi-GB response just to determine its HTTP status.
        final subscription = response.stream.listen((_) {});
        await subscription.cancel();
        return response.statusCode;
      } catch (_) {
        return null;
      }
    }

    try {
      final head = await getStatus('HEAD');
      if (head == null || (head >= 300 && head < 400)) return null;
      if ((head >= 200 && head < 300) || head == 429) return true;
      if (head == 405 || head == 501 || head >= 400) {
        final get = await getStatus('GET');
        if (get == null || (get >= 300 && get < 400)) return null;
        return (get >= 200 && get < 300) || get == 429;
      }
      return null;
    } finally {
      if (client == null) activeClient.close();
    }
  }

  /// Refresh expired entries (screen-open pass). Returns how many were
  /// actually re-checked this pass.
  /// Gap G: already async (non-blocking) + staggered 250ms + 20 cap;
  /// true `compute()` Isolate is WRONG for http (async + SharedPreferences
  /// not sendable) — HTTP is I/O-bound, not CPU. Keep async, HEAD-first.
  Future<int> ensureFresh(List<String> urls) async {
    if (_busy) return 0;
    _busy = true;
    try {
      await _load();
      final now = DateTime.now().millisecondsSinceEpoch;
      final stale = urls
          .where((u) =>
              !_cache.containsKey(u) ||
              now - (_cache[u]?.checkedAtMs ?? 0) > ttl.inMilliseconds)
          .take(_maxChecksPerPass)
          .toList();
      var checked = 0;
      for (final url in stale) {
        final verdict = await checkUrl(url);
        if (verdict != null) {
          _cache[url] = LinkHealth(
              ok: verdict, checkedAtMs: DateTime.now().millisecondsSinceEpoch);
          checked++;
          // Persist incrementally so navigation away keeps progress.
          await _persist();
        }
        // Stagger — be a polite guest.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return checked;
    } finally {
      _busy = false;
    }
  }

  /// Full verification (Settings button). Reports progress per link.
  /// Returns (checkedCount, brokenCount).
  Future<(int, int)> verifyAll(
      List<String> urls,
      void Function(int done, int total)? onProgress) async {
    if (_busy) return (0, 0);
    _busy = true;
    try {
      await _load();
      var done = 0;
      var broken = 0;
      for (final url in urls) {
        final verdict = await checkUrl(url);
        if (verdict != null) {
          _cache[url] = LinkHealth(
              ok: verdict, checkedAtMs: DateTime.now().millisecondsSinceEpoch);
          if (!verdict) broken++;
        }
        done++;
        onProgress?.call(done, urls.length);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await _persist();
      debugPrint('[link-health] verified $done, broken $broken');
      return (done, broken);
    } finally {
      _busy = false;
    }
  }

  /// Convenience: collect every URL from both registries.
  static List<String> allRegistryUrls() => [
        for (final (_, links) in RecoveryLiterature.sections)
          for (final l in links) l.url,
        for (final s in RecoveryResources.sections)
          for (final l in s.links) l.url,
      ];
}
