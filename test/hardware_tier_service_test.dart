// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/services/hardware_tier_service.dart';

void main() {
  group('HardwareTierService', () {
    setUp(() => HardwareTierService.debugReset());
    tearDown(() => HardwareTierService.debugReset());

    test('defaults to not low-end when meminfo inaccessible (host CI)', () async {
      // No meminfo file on host → initialize should gracefully fallback to false
      await HardwareTierService.initialize();
      expect(HardwareTierService.isLowEnd, isFalse);
      expect(HardwareTierService.totalRamGb, 0);
    });

    test('detects <3GB as low-end', () {
      // 2.8 GB = 2.8 * 1024*1024 kB
      final kb = (2.8 * 1024 * 1024).round();
      HardwareTierService.debugSetMeminfo('MemTotal:       $kb kB\nMemFree: 123 kB');
      expect(HardwareTierService.isLowEnd, isTrue);
      expect(HardwareTierService.totalRamGb, closeTo(2.8, 0.01));
    });

    test('detects exactly 3GB as not low-end', () {
      final kb = (3.0 * 1024 * 1024).round();
      HardwareTierService.debugSetMeminfo('MemTotal:       $kb kB');
      expect(HardwareTierService.isLowEnd, isFalse);
    });

    test('detects 4GB as not low-end', () {
      final kb = (4 * 1024 * 1024).round();
      HardwareTierService.debugSetMeminfo('MemTotal:       $kb kB');
      expect(HardwareTierService.isLowEnd, isFalse);
      expect(HardwareTierService.totalRamGb, closeTo(4.0, 0.01));
    });

    test('gracefully handles malformed meminfo', () {
      HardwareTierService.debugSetMeminfo('not a meminfo file');
      expect(HardwareTierService.isLowEnd, isFalse);
      expect(HardwareTierService.totalRamGb, 0);
    });

    test('gracefully handles empty meminfo', () {
      HardwareTierService.debugSetMeminfo('');
      expect(HardwareTierService.isLowEnd, isFalse);
    });

    test('initialize is idempotent (second call no-op)', () async {
      final kb = (2 * 1024 * 1024).round();
      HardwareTierService.debugSetMeminfo('MemTotal:       $kb kB');
      expect(HardwareTierService.isLowEnd, isTrue);
      // Second initialize should not flip it back
      await HardwareTierService.initialize();
      expect(HardwareTierService.isLowEnd, isTrue);
    });
  });
}
