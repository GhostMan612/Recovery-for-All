// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/recovery_coach_service.dart

import 'recovery_pet_service.dart';

enum CoachIntent {
  crisis,
  urge,
  checkIn,
  walk,
  gratitude,
  appHelpPet,
  appHelpSos,
  appHelpDresser,
  greeting,
  unknown,
}

enum CoachActionType {
  none,
  openSos,
  openDresser,
  openSettings,
  suggestCheckIn,
  suggestWalk,
  logGrounding,
  openSteps,
  openWorksheets,
  openMeetings,
}

class CoachReply {
  final CoachIntent intent;
  final String message;
  final CoachActionType action;
  final String? actionLabel;
  final bool isCrisis;

  const CoachReply({
    required this.intent,
    required this.message,
    this.action = CoachActionType.none,
    this.actionLabel,
    this.isCrisis = false,
  });
}

class RecoveryCoachService {
  static const List<String> _crisisTokens = [
    'kill myself',
    'killing myself',
    'want to die',
    'wanna die',
    'suicide',
    'end my life',
    'end it all',
    'hurt myself',
    'self harm',
    'self-harm',
    'no reason to live',
  ];

  static const Map<CoachIntent, List<String>> _intentTokens = {
    CoachIntent.urge: [
      'urge',
      'craving',
      'crave',
      'trigger',
      'triggered',
      'relapse',
      'using',
      'slip',
      'tempted',
      'temptation',
    ],
    CoachIntent.checkIn: [
      'check in',
      'check-in',
      'mood',
      'how am i',
      'feeling',
      'feel today',
    ],
    CoachIntent.walk: [
      'walk',
      'walking',
      'steps',
      'move',
      'movement',
      'exercise',
      'went outside',
    ],
    CoachIntent.gratitude: [
      'gratitude',
      'grateful',
      'thankful',
      'appreciate',
      'blessing',
    ],
    CoachIntent.appHelpPet: [
      'pet',
      'companion',
      'sparks',
      'avatar',
      'outfit',
      'energy',
      'bond',
      'kin',
    ],
    CoachIntent.appHelpSos: [
      'sos',
      '988',
      'sponsor',
      'crisis line',
      'emergency',
      'notification',
      'help number',
    ],
    CoachIntent.appHelpDresser: [
      'dresser',
      'clothes',
      'customize',
      'cosmetic',
      'unlock',
      'seasonal',
    ],
    CoachIntent.greeting: [
      'hello',
      'hi ',
      'hey',
      'good morning',
      'good night',
      'good evening',
    ],
  };

  static CoachIntent classify(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return CoachIntent.unknown;

    for (final token in _crisisTokens) {
      if (text.contains(token)) return CoachIntent.crisis;
    }

    CoachIntent best = CoachIntent.unknown;
    var bestScore = 0;
    _intentTokens.forEach((intent, tokens) {
      var score = 0;
      for (final token in tokens) {
        if (text.contains(token)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = intent;
      }
    });
    return best;
  }

  /// R8 — skills layer: richer guided replies for deeper topics, matched
  /// by keywords BEFORE the generic intent classifier. The TFLite model
  /// keeps its 10-label contract; skills are keyword-driven by design.
  static const List<({List<String> keys, CoachReply reply})> _skills = [
    (
      keys: ['fourth step', 'step work', 'stepwork', 'inventory', 'making amends', 'fifth step', 'step 4', 'step 5'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Step work is the deep water — and you do not swim it alone. '
            'Start with one column at a time, write rough, and share it '
            'with your sponsor before you polish it. The worksheets in the '
            'Twelve Steps reader will hold your answers on this device.',
        action: CoachActionType.openSteps,
        actionLabel: 'Open the Twelve Steps',
      ),
    ),
    (
      keys: ['talk to my sponsor', 'sponsor conversation', 'tell my sponsor', 'ask my sponsor'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Keep it simple and honest: what happened, what you did, and '
            'one question you have. Sponsors respect directness more than '
            'perfect wording. When they confirm your step, redeem their '
            'sign-off code right in the reader.',
        action: CoachActionType.openSteps,
        actionLabel: 'Open sign-offs',
      ),
    ),
    (
      keys: ['first meeting', 'what happens at a meeting', 'meeting etiquette', 'new to meetings', 'never been to a meeting'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Meetings are simpler than they look: sit anywhere, say your '
            'first name only if you want, and "pass" is a complete '
            'sentence. Nobody will call on you as a newcomer unless your '
            'hand is up. Listen for the similarities, not the differences.',
        action: CoachActionType.openMeetings,
        actionLabel: 'Find a meeting',
      ),
    ),
    (
      keys: ['got my chip', 'my anniversary', 'celebrate', 'medallion', 'birthday tonight'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'That is real progress and it deserves to be marked. Tell your '
            'home group — they will want to celebrate with you. And your '
            'companion agrees.',
        action: CoachActionType.none,
      ),
    ),
    (
      keys: ['using dream', 'dream about using', 'drinking dream', 'relapse dream'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Using dreams are common in recovery — they are your mind '
            'processing, not a prophecy or a failure. Waking up sober is '
            'the win. Note it in your journal if it shook you.',
        action: CoachActionType.none,
      ),
    ),
  ];

  /// Returns the matching skill reply, or null.
  static CoachReply? matchSkill(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final skill in _skills) {
      for (final key in skill.keys) {
        if (text.contains(key)) return skill.reply;
      }
    }
    return null;
  }

  static Future<CoachReply> reply(String userMessage) async {
    final intent = classify(userMessage);
    return replyFromIntent(intent);
  }

  static Future<CoachReply> replyFromIntent(CoachIntent intent) async {
    switch (intent) {
      case CoachIntent.crisis:
        return const CoachReply(
          intent: CoachIntent.crisis,
          isCrisis: true,
          message:
              'You are not alone. If you are in immediate danger, call emergency services. '
              'In the US you can call or text 988 (Suicide & Crisis Lifeline). '
              'Use SOS in this app to reach your sponsor or help numbers you saved. '
              'I am a scripted coach, not a crisis counselor — please reach a human now.',
          action: CoachActionType.openSos,
          actionLabel: 'Open SOS',
        );
      case CoachIntent.urge:
        return const CoachReply(
          intent: CoachIntent.urge,
          message:
              'Urges rise and fall. Try: name the feeling, slow exhale for 60 seconds, '
              'change rooms, drink water, text a safe person. '
              'You can log grounding to feed your companion without judgment.',
          action: CoachActionType.logGrounding,
          actionLabel: 'Log grounding',
        );
      case CoachIntent.checkIn:
        return const CoachReply(
          intent: CoachIntent.checkIn,
          message:
              'A short mood check-in helps your companion and keeps a gentle record of today. '
              'No perfect answers — honest is enough.',
          action: CoachActionType.suggestCheckIn,
          actionLabel: 'Check in',
        );
      case CoachIntent.walk:
        return const CoachReply(
          intent: CoachIntent.walk,
          message:
              'Movement counts even when it is small. A short walk can feed your companion Sparks. '
              'Log it when you are ready — no step counter required.',
          action: CoachActionType.suggestWalk,
          actionLabel: 'Log walk',
        );
      case CoachIntent.gratitude:
        return const CoachReply(
          intent: CoachIntent.gratitude,
          message:
              'One specific gratitude is enough: a person, a moment, a quiet win. '
              'Journal or Reflections can hold it offline on this device.',
          action: CoachActionType.none,
        );
      case CoachIntent.appHelpPet:
        return const CoachReply(
          intent: CoachIntent.appHelpPet,
          message:
              'Your Path Companion gains Sparks from check-ins, walks, journal, and grounding. '
              'Energy and bond grow with care; low energy means resting, never punishment. '
              'Tap the companion card to open the avatar dresser.',
          action: CoachActionType.openDresser,
          actionLabel: 'Open dresser',
        );
      case CoachIntent.appHelpSos:
        return const CoachReply(
          intent: CoachIntent.appHelpSos,
          message:
              'SOS lives in Settings and as a persistent Android notification when contacts are saved. '
              'Add sponsor and custom help numbers there. 988 is always available in the US.',
          action: CoachActionType.openSettings,
          actionLabel: 'Open settings',
        );
      case CoachIntent.appHelpDresser:
        return const CoachReply(
          intent: CoachIntent.appHelpDresser,
          message:
              'The dresser has slots: body, skin, face, hair, top, bottom, shoes, headwear, jewelry, accessory, aura. '
              'Free items unlock at hatch. Others need Sparks and bond. Seasonal items appear only in their window.',
          action: CoachActionType.openDresser,
          actionLabel: 'Open dresser',
        );
      case CoachIntent.greeting:
        return const CoachReply(
          intent: CoachIntent.greeting,
          message:
              'Hello. I am the in-app recovery coach — offline scripts for this app, not a therapist. '
              'Ask about your companion, urges, SOS, or say check-in / walk when you want a nudge.',
          action: CoachActionType.none,
        );
      case CoachIntent.unknown:
        return const CoachReply(
          intent: CoachIntent.unknown,
          message:
              'I can help with: companion & Sparks, dresser, urges/grounding, check-in, walk, SOS/988. '
              'For clinical or emergency needs, contact a professional or 988.',
          action: CoachActionType.none,
        );
    }
  }

  static Future<void> runAction(CoachActionType action) async {
    switch (action) {
      case CoachActionType.logGrounding:
        await RecoveryPetService.logGrounding();
        break;
      case CoachActionType.suggestWalk:
      case CoachActionType.openSteps:
      case CoachActionType.openWorksheets:
      case CoachActionType.openMeetings:
      case CoachActionType.suggestCheckIn:
      case CoachActionType.openSos:
      case CoachActionType.openDresser:
      case CoachActionType.openSettings:
      case CoachActionType.none:
        break;
    }
  }

  static List<String> quickPrompts() {
    return const [
      'How does the pet work?',
      'I have an urge',
      'Check in',
      'Log a walk',
      'SOS and sponsor',
      'Avatar dresser',
    ];
  }
}
