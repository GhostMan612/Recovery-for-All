// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Synchronous thermal gate for low-end devices.
///
/// Parses `/proc/meminfo` on Android to detect total RAM < 3.0 GB.
/// Result is stored as a synchronous static boolean `isLowEnd` so UI
/// can drop Lottie tickers without awaiting a Future on every frame.
///
/// Must be awaited once at boot via [initialize] (see `lib/main.dart`).
class HardwareTierService {
  /// True if total RAM < 3.0 GB → animations and heavy models are gated.
  static bool isLowEnd = false;

  /// Resolved total RAM in GB (0 if unknown / host test).
  static double totalRamGb = 0;

  static bool _initialized = false;

  /// Parse total RAM from `/proc/meminfo` (kB → GB). Returns 0 on failure.
  static double _parseMeminfoGb(String contents) {
    final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(contents);
    if (match == null) return 0;
    final kb = int.tryParse(match.group(1)!) ?? 0;
    if (kb <= 0) return 0;
    return kb / (1024 * 1024);
  }

  /// Initialize the synchronous hardware tier flag. Safe to call multiple
  /// times; second call is a no-op. Never throws.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid) {
        final contents = await File('/proc/meminfo').readAsString();
        totalRamGb = _parseMeminfoGb(contents);
        isLowEnd = totalRamGb > 0 && totalRamGb < 3.0;
      } else {
        // Host tests / non-Android dev machines: treat as not low-end
        // so Lotties and GGUF still verify in CI.
        totalRamGb = 0;
        isLowEnd = false;
      }
    } catch (_) {
      // /proc/meminfo inaccessible (host tests, permissions) → graceful fallback
      totalRamGb = 0;
      isLowEnd = false;
    }
    _initialized = true;
    debugPrint('[hardware] totalRamGb=${totalRamGb.toStringAsFixed(2)} isLowEnd=$isLowEnd');
  }

  /// Test-only reset. Do not use in production.
  @visibleForTesting
  static void debugReset() {
    isLowEnd = false;
    totalRamGb = 0;
    _initialized = false;
  }

  /// Test-only synchronous injector for unit tests.
  @visibleForTesting
  static void debugSetMeminfo(String contents) {
    totalRamGb = _parseMeminfoGb(contents);
    isLowEnd = totalRamGb > 0 && totalRamGb < 3.0;
    _initialized = true;
  }
}
