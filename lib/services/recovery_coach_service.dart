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
    (
      keys: ['panic attack', 'having a panic', 'cant breathe', "can't breathe", 'hyperventilating', 'racing heart'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Panic is your body sounding a false alarm — it will pass. '
            'Try: name 5 things you see, 4 you can touch, 3 you hear, '
            '2 you smell, 1 you taste. Then slow exhale for a count of 6. '
            'You are safe right now.',
        action: CoachActionType.logGrounding,
        actionLabel: 'Log grounding',
      ),
    ),
    (
      keys: ['feeling lonely', 'so alone', 'isolated', 'no one understands', 'nobody cares', 'all alone'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Loneliness lies. It says nobody cares — but you opened this '
            'app, which means part of you knows that is not true. Reach out '
            'to one person: a meeting, your sponsor, or the Recovery Circle. '
            'Connection is the antidote.',
        action: CoachActionType.openMeetings,
        actionLabel: 'Find a meeting',
      ),
    ),
    (
      keys: ['cant sleep', "can't sleep", 'insomnia', 'up all night', 'racing thoughts at night', 'tired of being tired'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Sleepless nights are rough in recovery — the mind runs. '
            'Try: no screens 30 min before bed, write tomorrows worries '
            'in your journal to park them, and slow breathing. If it '
            'persists more than a week, mention it to a doctor.',
        action: CoachActionType.suggestCheckIn,
        actionLabel: 'Check in',
      ),
    ),
    (
      keys: ['they offered me a drink', 'offered me drugs', 'someone offered', 'peer pressure', 'pressuring me to', 'just try it'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'You do not owe anyone an explanation. "No thanks" is a '
            'complete sentence. If they push, leave — your recovery is '
            'worth more than their comfort. Play the tape forward: how '
            'will you feel tomorrow?',
        action: CoachActionType.none,
      ),
    ),
    (
      keys: ['so bored', 'bored out of my mind', 'nothing to do', 'empty inside', 'feeling empty', 'meaningless'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Boredom and emptiness are often the space where using used to '
            'be. That space is real — and it is yours to fill. Try: a '
            'walk (Sparks for you and your companion), a worksheet, or '
            'one small thing you used to enjoy before addiction took it.',
        action: CoachActionType.suggestWalk,
        actionLabel: 'Log a walk',
      ),
    ),
    (
      keys: ['so angry', 'furious', 'rage', 'pissed off', 'want to punch', 'seething'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Anger is valid — it is what you do with it that matters. '
            'Before you act: cold water on your face, 10 slow breaths, '
            'or walk away. Write it in your journal first. React sober '
            'and you will not regret it tomorrow.',
        action: CoachActionType.logGrounding,
        actionLabel: 'Log grounding',
      ),
    ),
    (
      keys: ['medicine wheel', 'wellbriety teaching', 'four directions', 'grandfather teachings', 'sacred hoop', 'red road'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'The Medicine Wheel teaches balance across all dimensions: '
            'spiritual (East), emotional (South), physical (West), and '
            'mental (North). Check your Wellness Wheel — which quadrant '
            'needs attention today? Wellbriety Circles can help you walk '
            'this path with others.',
        action: CoachActionType.openDresser,
        actionLabel: 'Open companion',
      ),
    ),
    (
      keys: ['cba', 'cost benefit', 'smart tool', 'abc tool', 'smart recovery worksheet', 'dispute'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'SMART Recovery uses evidence-based CBT tools. The Cost-Benefit '
            'Analysis worksheet in your app walks you through it: short-term '
            'benefits vs costs, long-term benefits vs costs. Write rough '
            'and honest — nobody sees it but you.',
        action: CoachActionType.openWorksheets,
        actionLabel: 'Open worksheets',
      ),
    ),
    (
      keys: ['meditation practice', 'mindfulness meditation', 'sangha', 'dharma practice', 'buddhist recovery'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Recovery Dharma teaches that suffering comes from craving — '
            'and that meditation is the path to freedom from it. Start '
            'with 5 minutes: focus on your breath, notice when the mind '
            'wanders, return. The Meditation Timer can hold the space.',
        action: CoachActionType.suggestCheckIn,
        actionLabel: 'Check in',
      ),
    ),
    (
      keys: ['lifering', 'life ring', 'secular recovery group', '3-s philosophy', 'how was your week meeting'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'LifeRing is secular recovery built on three S\'s: Sobriety, '
            'Secularity, and Self-Direction. Meetings ask "How was your '
            'week?" — crosstalk welcome, you craft your own recovery plan. '
            'Their online calendar has meetings every day; the link lives '
            'in your Literature Library.',
      ),
    ),
    (
      keys: ['women for sobriety', 'new life program', 'thirteen statements', 'wfs acceptance'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Women for Sobriety\'s New Life Program centers thirteen '
            'acceptance statements — self-worth, emotional growth, and '
            'reaching out to other women. Statement one says it all: "I '
            'have a life-threatening problem that once had me." The '
            'Literature Library links their site and conference calls.',
      ),
    ),
    (
      keys: ['celebrate recovery', 'eight principles', 'beatitudes recovery', 'cr step study'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Celebrate Recovery is a Christ-centered program for hurts, '
            'habits, and hangups of every kind — eight principles from '
            'the Beatitudes, with step studies in small groups. Their '
            'group finder link is in Community Support under Faith-Based.',
      ),
    ),
    (
      keys: ['grateful for', 'gratitude practice', 'counting blessings', 'thankful for'],
      reply: CoachReply(
        intent: CoachIntent.unknown,
        message:
            'Gratitude rewires the brain away from craving. One specific '
            'thing is enough: a person, a moment, a quiet win. Write it '
            'in your journal or gratitude entry — it feeds your companion '
            'and your path.',
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
