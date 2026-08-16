// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

class SafetyAssessment {
  final bool isCrisisTriggered;
  final String matchedPattern;
  final String recommendedResource;

  const SafetyAssessment({
    required this.isCrisisTriggered,
    required this.matchedPattern,
    required this.recommendedResource,
  });
}

class SafetyGuardrailService {
  static final List<RegExp> _crisisPatterns = [
    RegExp(r'\b(suicide|suicidal|suicides)\b', caseSensitive: false),
    RegExp(r'\b(kill\s+myself|ending\s+my\s+life|end\s+my\s+life|want\s+to\s+die|wish\s+i\s+were\s+dead)\b', caseSensitive: false),
    RegExp(r'\b(hurt\s+myself|cutting\s+myself|self-harm|harming\s+myself|slashing\s+wrists)\b', caseSensitive: false),
    RegExp(r'\b(overdose|take\s+all\s+my\s+pills|swallow\s+pills|lethal\s+dose)\b', caseSensitive: false),
    RegExp(r'\b(hanging\s+myself|jump\s+off\s+a\s+bridge|shoot\s+myself|carbon\s+monoxide)\b', caseSensitive: false),
    RegExp(r'\b(better\s+off\s+dead|no\s+reason\s+to\s+live|don\x27t\s+want\s+to\s+be\s+here\s+anymore)\b', caseSensitive: false),
  ];

  static SafetyAssessment assessInput(String input) {
    final String cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      return const SafetyAssessment(
        isCrisisTriggered: false,
        matchedPattern: '',
        recommendedResource: '',
      );
    }

    for (final pattern in _crisisPatterns) {
      final Match? match = pattern.firstMatch(cleanInput);
      if (match != null) {
        return SafetyAssessment(
          isCrisisTriggered: true,
          matchedPattern: match.group(0) ?? 'Explicit Crisis Phrase',
          recommendedResource: '988 Suicide & Crisis Lifeline',
        );
      }
    }

    return const SafetyAssessment(
      isCrisisTriggered: false,
      matchedPattern: '',
      recommendedResource: '',
    );
  }
}
