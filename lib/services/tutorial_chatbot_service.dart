// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/services/tutorial_chatbot_service.dart
//
// Full-app tutorial chatbot — answers questions about any feature,
// guides onboarding, uses the recovery pet as its avatar.
// Separate from RecoveryCoachService (which is recovery support).
// This is onboarding/feature help; coach is recovery support.

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TutorialChatbotService {
  TutorialChatbotService._();

  static final TutorialChatbotService _instance = TutorialChatbotService._();
  static TutorialChatbotService get instance => _instance;

  static const String _keyChatHistory = 'tutorial_chatbot_history_v1';
  static const String _keySeenWelcome = 'tutorial_chatbot_welcome_v1';
  static const int _maxHistoryLength = 50;

  final StreamController<List<TutorialChatMessage>> _messagesController =
      StreamController<List<TutorialChatMessage>>.broadcast();
  Stream<List<TutorialChatMessage>> get messagesStream => _messagesController.stream;

  List<TutorialChatMessage> _messages = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyChatHistory);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _messages = list.map((e) => TutorialChatMessage.fromJson(e)).toList();
        _messagesController.add(_messages);
      } catch (_) {
        _messages = [];
      }
    }

    // Show welcome if first time
    final seenWelcome = prefs.getBool(_keySeenWelcome) ?? false;
    if (!seenWelcome) {
      await prefs.setBool(_keySeenWelcome, true);
      _addBotMessage(
        'Welcome! I\'m your tutorial guide. Ask me anything about the app — '
        'meetings, journal, pet, constellations, settings, anything. '
        'I\'ll show you how it works.',
      );
    }
  }

  void _addBotMessage(String text) {
    _messages.add(TutorialChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    if (_messages.length > _maxHistoryLength) {
      _messages = _messages.sublist(_messages.length - _maxHistoryLength);
    }
    _messagesController.add(_messages);
    _persist();
  }

  void _addUserMessage(String text) {
    _messages.add(TutorialChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    if (_messages.length > _maxHistoryLength) {
      _messages = _messages.sublist(_messages.length - _maxHistoryLength);
    }
    _messagesController.add(_messages);
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChatHistory, jsonEncode(_messages.map((m) => m.toJson()).toList()));
  }

  /// Process user message and generate response
  Future<void> sendMessage(String text) async {
    _addUserMessage(text);

    // Simple keyword-based responses (can be enhanced with ML later)
    final response = _generateResponse(text.toLowerCase());
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate thinking
    _addBotMessage(response);
  }

  String _generateResponse(String input) {
    // Feature-specific responses
    if (input.contains('meeting') || input.contains('aa') || input.contains('na') || input.contains('find room')) {
      return 'The Meeting Finder shows rooms near you — AA, NA, Dharma, LifeRing, WFS, CR, SMART, and more. '
          'Tap the map pin on the dashboard, or go to Path tab → Meeting Finder. '
          'You can filter by fellowship, adjust radius, and save favorites.';
    }
    if (input.contains('journal') || input.contains('diary') || input.contains('write')) {
      return 'Your Encrypted Journal is PIN-protected — only you can read it. '
          'Tap the lock icon on the dashboard, or Library tab → Private Journal. '
          'Write freely; it locks automatically when you leave.';
    }
    if (input.contains('pet') || input.contains('companion') || input.contains('kin')) {
      return 'Your companion grows with you — Sparks, Bond, Mood, Energy. '
          'Tap the pet on the dashboard to open Pet Home. '
          'Check in, take walks, do quests to earn Sparks. '
          'Sparks buy outfits in the Dresser. Resting means "I\'m here when you are" — never abandoned.';
    }
    if (input.contains('constellation') || input.contains('star') || input.contains('sky')) {
      return 'Every milestone adds a star to your constellation — day chips, step work, goals, meetings. '
          'Tap a star to remember. Pinch to zoom, drag to orbit in 3D. '
          'Dashboard has the crown; tap it for the full screen.';
    }
    if (input.contains('counter') || input.contains('day one') || input.contains('sober') || input.contains('chip')) {
      return 'Your Day One counter tracks from any date you set. '
          'Milestone chips (24h, 30d, 90d, 1yr, etc.) auto-award Sparks and constellation stars. '
          'Tap the timer icon on the dashboard.';
    }
    if (input.contains('gratitude') || input.contains('thankful') || input.contains('three good')) {
      return 'Gratitude: three good things daily. Small moments build resilience. '
          'Streak tracks consistency, not perfection. '
          'Tap the heart-with-hands icon on the dashboard.';
    }
    if (input.contains('wellness') || input.contains('wheel') || input.contains('dimension')) {
      return 'Wellness Wheel: six dimensions — Spiritual, Intellectual, Emotional, Physical, Social, Occupational. '
          'Track daily, watch patterns, share with sponsor if you choose. '
          'Library tab → Wellness Check-In.';
    }
    if (input.contains('goal') || input.contains('weekly') || input.contains('promise')) {
      return 'Weekly Goals: set small promises, check them off, build trust with yourself. '
          'Goals reset each Monday. Streaks build confidence. '
          'Library tab → Weekly Goals.';
    }
    if (input.contains('trial') || input.contains('battle') || input.contains('monster') || input.contains('urge')) {
      return 'Trials of the Path: face urge monsters using real coping skills as abilities. '
          'Focus powers your moves (+1 each turn). Lose a battle? Your companion learns — never punished. '
          'Path tab → Trials of the Path.';
    }
    if (input.contains('coach') || input.contains('help') || input.contains('support') || input.contains('talk')) {
      return 'Recovery Coach: offline guidance, always here. Scripted skills + optional GGUF deeper chat. '
          'Tap the chat icon on the dashboard, or Library tab → Recovery Coach.';
    }
    if (input.contains('setting') || input.contains('pin') || input.contains('lock') || input.contains('biometric')) {
      return 'Settings: biometric lock, journal PIN, reminders, SOS sheet (988, sponsor, meeting finder), '
          'data export, link health verification, Reset Layout for dashboard. '
          'Gear icon top-right or Library tab → Settings.';
    }
    if (input.contains('feed') || input.contains('circle') || input.contains('community') || input.contains('share')) {
      return 'Recovery Circle: share shapes, not numbers. Alias-only, no sober-time numbers. '
          'Reactions: Strength, Proud, Respect. Crisis language blocked, relapse flagged with support. '
          'Path tab → Recovery Circle.';
    }
    if (input.contains('literature') || input.contains('book') || input.contains('read') || input.contains('big book')) {
      return 'Literature Library: curated readings — Big Book, NA Basic Text, Dharma talks, Wellbriety, SMART manual. '
          'Filter by pathway, download for offline, no tracking. '
          'Library tab → Literature Library.';
    }
    if (input.contains('resource') || input.contains('hotline') || input.contains('treatment') || input.contains('housing')) {
      return 'Community Resources: hotlines, treatment locators, sober housing, legal aid — offline first. '
          'Filter by pathway. Tap to call or open maps. '
          'Library tab → Community Resources.';
    }
    if (input.contains('sponsor') || input.contains('step work') || input.contains('sign off')) {
      return 'Sponsor Linking: pair via code, share step work securely. Sponsor signs off — you both see the milestone. '
          'Path tab → Sponsor (12-Step pathways).';
    }
    if (input.contains('dresser') || input.contains('outfit') || input.contains('cosmetic')) {
      return 'Avatar Dresser: Sparks buy outfits. Your companion wears your victories. '
          'Seasonal items return yearly. Milestone outfits stay forever. '
          'Pet Home → Dresser.';
    }
    if (input.contains('coping') || input.contains('grounding') || input.contains('breath') || input.contains('urge surf')) {
      return 'Coping Tools: urge surfing, box breathing, 5-4-3-2-1 grounding, HALT check. '
          'Tap any tool. No setup. Works offline. '
          'Library tab → Coping Tools.';
    }
    if (input.contains('reflection') || input.contains('prompt') || input.contains('daily reflection')) {
      return 'Daily Reflection: one prompt, one moment, private by default. '
          'Streak tracks consistency, not perfection. '
          'Library tab → Daily Reflection.';
    }
    if (input.contains('hello') || input.contains('hi') || input.contains('hey')) {
      return 'Hello! How can I help you today? Ask me about any feature — meetings, journal, pet, constellations, trials, coach, anything.';
    }
    if (input.contains('thank') || input.contains('thanks')) {
      return 'You\'re welcome! Remember — your companion is always here when you need it. Just ask.';
    }

    // Default: suggest categories
    return 'I can help with:\n'
        '• Meetings (AA, NA, Dharma, LifeRing, WFS, CR, SMART)\n'
        '• Encrypted Journal\n'
        '• Your Companion (pet, Sparks, outfits)\n'
        '• Constellations & milestones\n'
        '• Day One counter & chips\n'
        '• Gratitude practice\n'
        '• Wellness Wheel\n'
        '• Weekly Goals\n'
        '• Trials of the Path (urge monsters)\n'
        '• Recovery Coach\n'
        '• Literature Library\n'
        '• Community Resources\n'
        '• Sponsor linking\n'
        '• Settings & safety\n'
        'Just ask!';
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    _messages.clear();
    _messagesController.add(_messages);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyChatHistory);
  }

  void dispose() {
    _messagesController.close();
  }
}

class TutorialChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  TutorialChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory TutorialChatMessage.fromJson(Map<String, dynamic> json) => TutorialChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      );
}