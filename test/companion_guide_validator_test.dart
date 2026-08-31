// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// test/companion_guide_validator_test.dart
//
// Build-time route validator for Companion Guide tutorials.
// Runs as a Flutter test so platform code compiles correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/services/companion_guide_service.dart';

void main() {
  group('CompanionTutorial route validation', () {
    test('all tutorials have valid routeIds that map to existing screens', () {
      final registry = CompanionTutorialRegistry.allTutorials;

      final validScreens = <String>{
        'JournalScreen',
        'GratitudeEntryScreen',
        'SobrietyCounterScreen',
        'MeetingMapScreen',
        'WellbrietyCirclesScreen',
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

      final routeToScreen = <String, String>{
        'welcome': 'SplashScreen', // Welcome shows on first launch, not a navigable screen
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

      for (final tutorial in registry) {
        if (tutorial.routeId != null) {
          final expectedScreen = routeToScreen[tutorial.routeId!];
          expect(expectedScreen, isNotNull,
              reason: 'Tutorial "${tutorial.id}" has unknown routeId "${tutorial.routeId}"');
          expect(validScreens, contains(expectedScreen),
              reason: 'Tutorial "${tutorial.id}" references screen "$expectedScreen" which does not exist');
        }
      }
    });

    test('all tutorials have valid requiredPathways', () {
      final registry = CompanionTutorialRegistry.allTutorials;

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
          expect(validPathways, contains(pathway),
              reason: 'Tutorial "${tutorial.id}" references unknown pathway "$pathway"');
        }
      }
    });
  });
}