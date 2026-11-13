// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

/// Presentation-layer formatter for decrypted journal entries.
///
/// Decrypted records may be plain user text or structured JSON payloads
/// produced by specialized logging features (such as the 3-field Gratitude tool).
///
/// Under strict data preservation rules:
/// - Stored database bytes and encrypted records are NEVER altered.
/// - Plain-text entries continue rendering unchanged.
/// - Recognized JSON structures are rendered into human-readable text.
/// - Malformed or unknown JSON formats fail safely back to the raw decrypted text.
class JournalPresentationFormatter {
  JournalPresentationFormatter._();

  /// Formats raw decrypted journal content for UI display.
  static String format(String rawDecrypted) {
    if (rawDecrypted.isEmpty) return rawDecrypted;

    final trimmed = rawDecrypted.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return rawDecrypted;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return _formatMap(decoded, rawDecrypted);
      } else if (decoded is List) {
        return _formatList(decoded, rawDecrypted);
      }
    } catch (_) {
      // Malformed or partial JSON fails safely back to raw text
    }

    return rawDecrypted;
  }

  static String _formatMap(Map<String, dynamic> map, String fallback) {
    // 1. Gratitude structure: wentWell, person, asset
    final hasGratitudeKeys =
        map.containsKey('wentWell') ||
        map.containsKey('person') ||
        map.containsKey('asset');

    if (hasGratitudeKeys) {
      final lines = <String>[];
      final wentWell = map['wentWell']?.toString().trim();
      if (wentWell != null && wentWell.isNotEmpty) {
        lines.add('What went well: $wentWell');
      }
      final person = map['person']?.toString().trim();
      if (person != null && person.isNotEmpty) {
        lines.add('Grateful for: $person');
      }
      final asset = map['asset']?.toString().trim();
      if (asset != null && asset.isNotEmpty) {
        lines.add('Strength or asset: $asset');
      }
      if (lines.isNotEmpty) {
        return lines.join('\n\n');
      }
    }

    // 2. Generic single-field wrapper (e.g. text, content, reflection, body, entry, note, message)
    for (final key in const [
      'reflection',
      'text',
      'content',
      'body',
      'entry',
      'note',
      'message',
    ]) {
      final val = map[key];
      if (val is String && val.trim().isNotEmpty) {
        final prompt = map['prompt']?.toString().trim();
        if (prompt != null && prompt.isNotEmpty) {
          return '$prompt\n\n${val.trim()}';
        }
        return val.trim();
      }
    }

    // 3. Unknown or unhandled map: fail safely without altering rawDecrypted
    return fallback;
  }

  static String _formatList(List list, String fallback) {
    if (list.every((e) => e is String)) {
      return list.map((e) => e.toString().trim()).join('\n');
    }
    return fallback;
  }
}
