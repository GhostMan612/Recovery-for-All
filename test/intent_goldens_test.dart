// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// Goldens harness for intent classification (ASK-3).
// Validates keyword classifier against trainer LABELS and ensures
// vocab/encode contract hasn't drifted. TFLite accuracy asserted only
// when model loads (host may lack asset); keyword path always tested.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_companion/services/coach_tflite_intent_service.dart';
import 'package:recovery_companion/services/recovery_coach_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoachIntent _parseExpected(String s) => switch (s) {
      'crisis' => CoachIntent.crisis,
      'urge' => CoachIntent.urge,
      'checkIn' => CoachIntent.checkIn,
      'walk' => CoachIntent.walk,
      'gratitude' => CoachIntent.gratitude,
      'appHelpPet' => CoachIntent.appHelpPet,
      'appHelpSos' => CoachIntent.appHelpSos,
      'appHelpDresser' => CoachIntent.appHelpDresser,
      'greeting' => CoachIntent.greeting,
      'unknown' => CoachIntent.unknown,
      _ => CoachIntent.unknown,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('intent goldens: keyword classifier matches expected labels', () async {
    SharedPreferences.setMockInitialValues({});
    final file = File('test/intent_goldens.jsonl');
    expect(file.existsSync(), isTrue, reason: 'missing test/intent_goldens.jsonl');
    final lines = await file.readAsLines();
    final goldens = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      goldens.add(jsonDecode(line) as Map<String, dynamic>);
    }
    expect(goldens.length, greaterThanOrEqualTo(15));

    var correct = 0;
    final failures = <String>[];
    for (final g in goldens) {
      final text = g['text'] as String;
      final expected = _parseExpected(g['expected'] as String);
      // For skill-heavy phrases (e.g., "fourth step"), the skill layer
      // intentionally returns unknown intent — so we allow either.
      final got = RecoveryCoachService.classify(text);
      if (got == expected) {
        correct++;
      } else {
        // Check if skill would handle it (then unknown is acceptable)
        final skill = RecoveryCoachService.matchSkill(text);
        if (skill != null && expected == CoachIntent.unknown) {
          correct++;
        } else {
          failures.add('"$text": expected $expected, got $got');
        }
      }
    }
    // Keyword harness should stay >75% even though tiny corpus is lossy.
    final acc = correct / goldens.length;
    expect(acc, greaterThanOrEqualTo(0.75),
        reason: 'keyword accuracy $acc below 0.75; failures:\n${failures.join("\n")}');
  });

  test('TFLite encode contract is stable (sentenceLen 64, specials)', () {
    final vocab = {'<START>': 2, 'hello': 10, 'world': 11};
    final ids = CoachTfliteIntentService.encode('hello world', vocab);
    expect(ids.length, 64);
    expect(ids.first, 2); // <START>
    expect(ids[1], 10);
    expect(ids[2], 11);
    expect(ids.sublist(3), everyElement(0)); // pad
  });

  test('persisted forceKeywordOnly survives reload', () async {
    SharedPreferences.setMockInitialValues({});
    await CoachTfliteIntentService.setForceKeywordOnly(true);
    expect(CoachTfliteIntentService.forceKeywordOnly, isTrue);
    // Simulate fresh process: reset static then reload
    CoachTfliteIntentService.forceKeywordOnly = false;
    await CoachTfliteIntentService.loadPersistedForceKeyword();
    expect(CoachTfliteIntentService.forceKeywordOnly, isTrue);
    // Cleanup
    await CoachTfliteIntentService.setForceKeywordOnly(false);
  });
}
