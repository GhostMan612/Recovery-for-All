// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

// Ensures every hand-authored aura animation parses as a valid Lottie
// composition on the host — catches malformed bodymovin JSON at CI time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = [
    'assets/lottie/aura_warm.json',
    'assets/lottie/aura_calm_blue.json',
    'assets/lottie/aura_starfield.json',
    'assets/lottie/aura_ember.json',
  ];

  for (final path in assets) {
    test('parses $path', () async {
      final data = await rootBundle.load(path);
      final composition = await LottieComposition.fromByteData(data);
      expect(composition.duration.inMilliseconds, greaterThan(0));
    });
  }
}
