// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/services/journal_presentation_formatter.dart';

void main() {
  group('JournalPresentationFormatter Tests', () {
    test('renders plain text unchanged', () {
      const plain = 'Today was a calm day in recovery. Went for a walk.';
      expect(JournalPresentationFormatter.format(plain), equals(plain));
    });

    test('renders multi-line plain text unchanged', () {
      const multi =
          'Morning reflection.\nAttended noon meeting.\nFelt grounded.';
      expect(JournalPresentationFormatter.format(multi), equals(multi));
    });

    test('formats structured gratitude entries into readable sections', () {
      final payload = jsonEncode({
        'wentWell': 'Made my bed and meditated for 10 minutes.',
        'person': 'My sponsor for taking my call.',
        'asset': 'Patience and willingness to listen.',
      });

      final result = JournalPresentationFormatter.format(payload);
      expect(
        result,
        contains('What went well: Made my bed and meditated for 10 minutes.'),
      );
      expect(result, contains("Grateful for: My sponsor for taking my call."));
      expect(
        result,
        contains('Strength or asset: Patience and willingness to listen.'),
      );
      expect(result.contains('{'), isFalse);
      expect(result.contains('}'), isFalse);
    });

    test('formats gratitude entries with partial non-empty fields', () {
      final payload = jsonEncode({
        'wentWell': 'Stayed sober through a difficult afternoon.',
        'person': '',
        'asset': 'Resilience',
      });

      final result = JournalPresentationFormatter.format(payload);
      expect(
        result,
        contains('What went well: Stayed sober through a difficult afternoon.'),
      );
      expect(result, contains('Strength or asset: Resilience'));
      expect(result.contains('Grateful for:'), isFalse);
    });

    test('formats single-field text/reflection wrapper JSON', () {
      final payload = jsonEncode({
        'reflection': 'I reached out to a fellow when cravings spiked.',
      });

      final result = JournalPresentationFormatter.format(payload);
      expect(result, equals('I reached out to a fellow when cravings spiked.'));
    });

    test('formats text wrapper with prompt header', () {
      final payload = jsonEncode({
        'prompt': 'What gave you hope today?',
        'reflection': 'Hearing someone celebrate 10 years of sobriety.',
      });

      final result = JournalPresentationFormatter.format(payload);
      expect(
        result,
        equals(
          'What gave you hope today?\n\nHearing someone celebrate 10 years of sobriety.',
        ),
      );
    });

    test('fails safely on malformed JSON without modifying or throwing', () {
      const malformed = '{"wentWell": "broken json string';
      expect(JournalPresentationFormatter.format(malformed), equals(malformed));
    });

    test(
      'fails safely on unrecognized JSON object without altering contents',
      () {
        final unknown = jsonEncode({
          'unknown_field': 42,
          'nested_data': {'a': 1},
        });
        expect(JournalPresentationFormatter.format(unknown), equals(unknown));
      },
    );

    test('handles empty or blank string safely', () {
      expect(JournalPresentationFormatter.format(''), equals(''));
      expect(JournalPresentationFormatter.format('   '), equals('   '));
    });
  });
}
