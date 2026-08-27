// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/services/companion_guide_service.dart
//
// Self-healing companion guide service.
// Provides onboarding/tutorial overlay using the pet avatar,
// with tutorials generated from live app registry + self-healing
// validation at build/test time.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanionGuideService {
  CompanionGuideService._();

  static final CompanionGuideService _instance = CompanionGuideService._();
  static CompanionGuideService get instance => _instance;

  // Tutorial eligibility stream for the overlay
  final StreamController<List<CompanionTutorial>> _eligibleController =
      StreamController<List<CompanionTutorial>>.broadcast();
  Stream<List<CompanionTutorial>> get eligibleTutorials => _eligibleController.stream;

  // Initialize the eligible tutorials stream based on user pathways
  Future<void> initialize(List<String> userPathways) async {
    final tutorials = CompanionTutorialRegistry.getAll(userPathways: userPathways);
    _eligibleController.add(tutorials);
  }

  // Get next eligible tutorial that hasn't been completed/dismissed
  Future<CompanionTutorial?> getNextEligibleTutorial(Set<String> userPathways) async {
    final completed = (await _getCompletedTutorials()).toSet();
    final dismissed = (await _getDismissedTutorials()).toSet();

    final tutorials = CompanionTutorialRegistry.getAll(userPathways: await _getUserPathways())
        .where((t) => !completed.contains(t.id) && !dismissed.contains(t.id))
        .toList();

    if (tutorials.isEmpty) return null;

    // Sort by priority (welcome first, then by id)
    tutorials.sort((a, b) {
      if (a.id == 'welcome') return -1;
      if (b.id == 'welcome') return 1;
      return a.id.compareTo(b.id);
    });

    return tutorials.firstOrNull;
  }

  static Future<List<String>> _getCompletedTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('companion_guide_completed_v1');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> _getDismissedTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('companion_guide_dismissed_v1');
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<List<String>> _getUserPathways() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_user_profile');
    if (raw == null) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final paths = map['activePaths'] as List?;
      return paths?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> markCompleted(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = await _getCompletedTutorials();
    if (!completed.contains(tutorialId)) {
      completed.add(tutorialId);
      await prefs.setString('companion_guide_completed_v1', jsonEncode(completed));
    }
  }

  Future<void> dismissTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = await _getDismissedTutorials();
    dismissed.add(tutorialId);
    await prefs.setString('companion_guide_dismissed_v1', jsonEncode(dismissed.toList()));
  }

  Future<void> resetAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('companion_guide_completed_v1');
    await prefs.remove('companion_guide_dismissed_v1');
  }
}

class CompanionTutorial {
  const CompanionTutorial({
    required this.id,
    required this.title,
    required this.steps,
    this.routeId,
    this.requiredPathways = const [],
    this.priority = 0,
  });

  final String id;
  final String title;
  final List<CompanionTutorialStep> steps;
  final String? routeId;
  final List<String> requiredPathways;
  final int priority;
}

class CompanionTutorialStep {
  const CompanionTutorialStep({
    required this.text,
    this.highlightWidgetKey,
    this.action,
    this.duration = const Duration(milliseconds: 3000),
    this.widgetPredicate, // For self-healing: widget finder predicate
  });

  final String text;
  final GlobalKey? highlightWidgetKey;
  final VoidCallback? action;
  final Duration duration;
  final bool Function(BuildContext)? widgetPredicate;
}

// Registry of all tutorials - generated/updated alongside feature work
class CompanionTutorialRegistry {
  static final List<CompanionTutorial> _tutorials = [
    CompanionTutorial(
      id: 'welcome',
      title: 'Welcome to Recovery for All',
      priority: 100,
      // No routeId - welcome tutorial doesn't navigate to a specific screen
      steps: [
        CompanionTutorialStep(
          text: 'Welcome! Your companion is here to walk this path with you.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Your pet reflects your journey — it never judges, only supports.',
          duration: Duration(seconds: 5),
        ),
        CompanionTutorialStep(
          text: 'Tap the pet to open its home. Try a check-in or a walk!',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'check_in',
      title: 'Daily Check-In',
      priority: 90,
      routeId: 'coping',
      steps: [
        CompanionTutorialStep(
          text: 'Daily check-ins ground you in the present moment.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Tap the heart icon. Pick a mood. Earn Sparks.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'meetings',
      title: 'Finding Meetings',
      priority: 80,
      routeId: 'meetings',
      steps: [
        CompanionTutorialStep(
          text: 'The Meeting Finder shows rooms near you — AA, NA, Dharma, and more.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Adjust the radius. Filter by fellowship. Save favorites.',
          duration: Duration(seconds: 5),
        ),
      ],
      requiredPathways: ['12-Step (AA/NA)', 'Recovery Dharma', 'Wellbriety'],
    ),
    CompanionTutorial(
      id: 'journal',
      title: 'Encrypted Journal',
      priority: 85,
      routeId: 'journal',
      steps: [
        CompanionTutorialStep(
          text: 'Your journal is encrypted on-device. Only your PIN unlocks it.',
          duration: Duration(seconds: 5),
        ),
        CompanionTutorialStep(
          text: 'Write freely. PIN locks it when you leave.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'pet',
      title: 'Your Companion',
      priority: 85,
      routeId: 'pet',
      steps: [
        CompanionTutorialStep(
          text: 'Your companion grows with you — Sparks, Bond, Mood, Energy.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Sparks buy outfits in the Dresser. Bond deepens with care.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Resting means "I\'m here when you are" — never abandoned.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'trials',
      title: 'Trials of the Path',
      priority: 75,
      routeId: 'coping',
      steps: [
        CompanionTutorialStep(
          text: 'Face urge monsters using real coping skills as abilities.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Focus powers your moves. +1 each turn. Spend wisely.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Lose a battle? Your companion learns — never punished.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'constellation',
      title: 'Your Constellation',
      priority: 70,
      routeId: 'constellation',
      steps: [
        CompanionTutorialStep(
          text: 'Every milestone adds a star. Milestones, steps, goals = stars.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Tap a star to remember. Share your shape with your circle.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'sponsor',
      title: 'Sponsor Linking',
      priority: 65,
      routeId: 'sponsor',
      steps: [
        CompanionTutorialStep(
          text: 'Link with your sponsor via a pairing code. Share step work securely.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Sponsor signs off — you both see the milestone.',
          duration: Duration(seconds: 4),
        ),
      ],
      requiredPathways: ['12-Step (AA/NA)'],
    ),
    CompanionTutorial(
      id: 'settings',
      title: 'Settings & Safety',
      priority: 60,
      routeId: 'settings',
      steps: [
        CompanionTutorialStep(
          text: 'SOS sheet has 988, sponsor call, and meeting finder — one tap.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Biometric lock, journal PIN, reminders — all in Settings.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'wellness',
      title: 'Wellness Wheel',
      priority: 70,
      routeId: 'wellness',
      steps: [
        CompanionTutorialStep(
          text: 'Six dimensions: Spiritual, Intellectual, Emotional, Physical, Social, Occupational.',
          duration: Duration(seconds: 5),
        ),
        CompanionTutorialStep(
          text: 'Track daily. Watch patterns. Share with sponsor if you choose.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'goals',
      title: 'Weekly Goals',
      priority: 70,
      routeId: 'goals',
      steps: [
        CompanionTutorialStep(
          text: 'Set small weekly promises. Check them off. Build trust with yourself.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Goals reset each Monday. Streaks build confidence.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'gratitude',
      title: 'Gratitude Practice',
      priority: 80,
      routeId: 'gratitude',
      steps: [
        CompanionTutorialStep(
          text: 'Three good things, daily. Small moments build resilience.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Streak builds. Science says it rewires attention toward hope.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'literature',
      title: 'Literature Library',
      priority: 75,
      routeId: 'literature',
      steps: [
        CompanionTutorialStep(
          text: 'Curated readings — Big Book, NA Basic Text, Dharma talks, Wellbriety.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Filter by pathway. Download for offline. No tracking.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'resources',
      title: 'Community Resources',
      priority: 70,
      routeId: 'resources',
      steps: [
        CompanionTutorialStep(
          text: 'Hotlines, treatment locators, sober housing, legal aid — offline first.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Filter by pathway. Tap to call or open maps.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'dresser',
      title: 'Avatar Dresser',
      priority: 65,
      routeId: 'dresser',
      steps: [
        CompanionTutorialStep(
          text: 'Sparks buy outfits. Your companion wears your victories.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Seasonal items return yearly. Milestone outfits stay forever.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'coping',
      title: 'Coping Tools',
      priority: 75,
      routeId: 'coping',
      steps: [
        CompanionTutorialStep(
          text: 'Urge surfing, box breathing, 5-4-3-2-1 grounding, HALT check.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Tap any tool. No setup. Works offline.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'reflection',
      title: 'Daily Reflection',
      priority: 70,
      routeId: 'reflection',
      steps: [
        CompanionTutorialStep(
          text: 'One prompt. One moment. Private by default.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Streak tracks consistency, not perfection.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'grounding',
      title: 'Grounding Exercises',
      priority: 70,
      routeId: 'grounding',
      steps: [
        CompanionTutorialStep(
          text: '5-4-3-2-1 senses. Box breathing. Body scan. Always available.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Haptic cues guide you. Eyes open or closed.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'constellation3d',
      title: '3D Constellation',
      priority: 60,
      routeId: 'constellation3d',
      steps: [
        CompanionTutorialStep(
          text: 'Your milestones as stars in 3D. Pinch to zoom, drag to orbit.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Each star holds a memory. Share the view with your circle.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    CompanionTutorial(
      id: 'housing',
      title: 'Sober Housing Locator',
      priority: 65,
      routeId: 'housing',
      steps: [
        CompanionTutorialStep(
          text: 'Find certified sober living near you. Filter by path.',
          duration: Duration(seconds: 4),
        ),
        CompanionTutorialStep(
          text: 'Call or map directions. Works offline with cached data.',
          duration: Duration(seconds: 4),
        ),
      ],
    ),
  ];

  static List<CompanionTutorial> getAll({required List<String> userPathways}) {
    return _tutorials.where((t) {
      if (t.requiredPathways.isEmpty) return true;
      return t.requiredPathways.any((p) => userPathways.contains(p));
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  static CompanionTutorial? getById(String id) {
    try {
      return _tutorials.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // Exposed for build-time validation (tools/validate_tutorials.dart)
  static List<CompanionTutorial> get allTutorials => _tutorials;
}

extension on List<CompanionTutorial> {
  CompanionTutorial? get firstOrNull => isEmpty ? null : first;
}