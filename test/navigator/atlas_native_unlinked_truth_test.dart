// test/navigator/atlas_native_unlinked_truth_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unlinked Android Atlas channel does not claim a request was cancelled',
      () {
    // GitHub's Flutter host CI does not execute Kotlin code. This source
    // contract prevents the native fallback from silently regressing until
    // a linked SDK / Android JVM device test harness exists.
    final native = File(
      'android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasChannelAdapter.kt',
    ).readAsStringSync();
    final cancelHandler = RegExp(
      r'"cancelRequest"\s*->\s*\{([\s\S]*?)\n\s*\}',
    ).firstMatch(native);
    expect(cancelHandler, isNotNull);
    final block = cancelHandler!.group(1)!;
    expect(block, contains('"cancelRequested" to false'));
    expect(block, isNot(contains('"cancelRequested" to true')));
    expect(native, contains('"SDK_NOT_INSTALLED"'));
  });
}
