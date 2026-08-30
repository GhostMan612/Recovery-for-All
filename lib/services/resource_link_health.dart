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
        _cache = decoded.map((url, v) => MapEntry(
              url,
              LinkHealth(
                ok: v['ok'] as bool?,
                checkedAtMs: v['at'] as int? ?? 0,
              ),
            ));
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

  /// Single live check. Returns true/false on a definitive HTTP answer,
  /// null when we simply could not reach the internet (inconclusive).
  /// ASK-6: HEAD first (bandwidth), fallback to GET Range on 405.
  Future<bool?> checkUrl(String url) async {
    // Try HEAD first (saves bandwidth); many CDNs/servers reject HEAD with 405.
    Future<http.Response> doHead() => http
        .head(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (RecoveryForAll link checker)',
          'Accept': '*/*',
        })
        .timeout(_timeout)
        .catchError((_) => http.Response('', 0));
    Future<http.Response> doGet() => http
        .get(Uri.parse(url), headers: {
          'Range': 'bytes=0-1023',
          'User-Agent': 'Mozilla/5.0 (RecoveryForAll link checker)',
          'Accept': '*/*',
        })
        .timeout(_timeout)
        .catchError((_) => http.Response('', 0));

    try {
      var resp = await doHead();
      if (resp.statusCode == 405 || resp.statusCode == 501) {
        resp = await doGet();
      } else if (resp.statusCode == 0) {
        // Transport failure on HEAD (offline/DNS) — don't try GET
        return null;
      } else if (resp.statusCode >= 200 && resp.statusCode < 400) {
        return true;
      } else if (resp.statusCode == 429) {
        return true; // rate-limited means EXISTS
      } else if (resp.statusCode >= 400) {
        // 4xx/5xx on HEAD may be HEAD-specific; fallback once to GET
        final getResp = await doGet();
        if (getResp.statusCode == 0) return null;
        return getResp.statusCode >= 200 && getResp.statusCode < 400 ||
            getResp.statusCode == 405 ||
            getResp.statusCode == 429;
      }
      if (resp.statusCode == 0) return null;
      return resp.statusCode >= 200 && resp.statusCode < 400 ||
          resp.statusCode == 405 ||
          resp.statusCode == 429;
    } catch (_) {
      return null;
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
