// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// tools/validate_tutorials.dart
//
// Build-time route validator for Companion Guide tutorials.
// Asserts that every tutorial's routeId exists in the app's
// navigation structure. Called by generate_code_package.py.
//
// Exit code: 0 = all routes valid, 1 = missing routes found.

import 'dart:io';

import 'package:recovery_for_all/services/companion_guide_service.dart';

void main() {
  final registry = CompanionTutorialRegistry.allTutorials;

  // Screen class names that exist in the codebase (from dashboard_screen.dart)
  // This list must be kept in sync with actual screens.
  final validScreens = <String>{
    // Universal
    'JournalScreen',
    'GratitudeEntryScreen',
    'SobrietyCounterScreen',
    'MeetingMapScreen',
    // Path-specific
    'WellbrietyCirclesScreen',
    // Library tools
    'WellnessCheckInScreen',
    'WeeklyGoalsScreen',
    'StepsViewerScreen',
    'DailyMotivationScreen',
    'PetHomeScreen',
    'CommunityFeedScreen',
    'ChatbotScreen',
    'CopingToolScreen',
    'DailyReflectionScreen',
    'GroundingScreen',
    'ConstellationScreen',
    'ConstellationCanvas3D',
    'SoberHousingLocator',
    'AvatarDresserScreen',
    'SettingsScreen',
    'CommunityResourcesScreen',
    'NativeResourcesScreen',
    'LiteratureLibraryScreen',
    'SponsorManagerWidget',
  };

  // Map tutorial routeIds to actual screen class names
  final routeToScreen = <String, String>{
    'journal': 'JournalScreen',
    'gratitude': 'GratitudeEntryScreen',
    'counters': 'SobrietyCounterScreen',
    'meetings': 'MeetingMapScreen',
    'wellbriety': 'WellbrietyCirclesScreen',
    'wellness': 'WellnessCheckInScreen',
    'goals': 'WeeklyGoalsScreen',
    'steps': 'StepsViewerScreen',
    'motivation': 'DailyMotivationScreen',
    'pet': 'PetHomeScreen',
    'feed': 'CommunityFeedScreen',
    'coach': 'ChatbotScreen',
    'constellation': 'ConstellationScreen',
    'sponsor': 'SponsorManagerWidget',
    'settings': 'SettingsScreen',
    'literature': 'LiteratureLibraryScreen',
    'resources': 'CommunityResourcesScreen',
    'native': 'NativeResourcesScreen',
    'dresser': 'AvatarDresserScreen',
    'coping': 'CopingToolScreen',
    'reflection': 'DailyReflectionScreen',
    'grounding': 'GroundingScreen',
    'housing': 'SoberHousingLocator',
    'constellation3d': 'ConstellationCanvas3D',
  };

  var hasErrors = false;

  for (final tutorial in registry) {
    if (tutorial.routeId != null) {
      final expectedScreen = routeToScreen[tutorial.routeId!];
      if (expectedScreen == null) {
        stderr.writeln('ERROR: Tutorial "${tutorial.id}" has unknown routeId "${tutorial.routeId}"');
        hasErrors = true;
      } else if (!validScreens.contains(expectedScreen)) {
        stderr.writeln('ERROR: Tutorial "${tutorial.id}" references screen "$expectedScreen" which does not exist');
        hasErrors = true;
      } else {
        stdout.writeln('OK: Tutorial "${tutorial.id}" -> $expectedScreen');
      }
    }
  }

  // Also check that tutorials with requiredPathways have valid pathway names
  final validPathways = <String>{
    '12-Step (AA/NA)',
    'Recovery Dharma',
    'Wellbriety',
    'Celebrate Recovery',
    'LifeRing',
    'Women for Sobriety',
    'SMART Recovery',
    'InTheRooms',
  };

  for (final tutorial in registry) {
    for (final pathway in tutorial.requiredPathways) {
      if (!validPathways.contains(pathway)) {
        stderr.writeln('WARNING: Tutorial "${tutorial.id}" references unknown pathway "$pathway"');
      }
    }
  }

  if (hasErrors) {
    stderr.writeln('\nVALIDATION FAILED: One or more tutorials reference missing routes.');
    exit(1);
  } else {
    stdout.writeln('\nVALIDATION PASSED: All tutorial routes are valid.');
    exit(0);
  }
}