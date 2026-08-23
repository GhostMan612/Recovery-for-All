// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/main.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_navigator.dart';
import 'database/recovery_database.dart';
import 'screens/splash_screen.dart';
import 'services/community_feed_service.dart';
import 'services/gentle_reminder_service.dart';
import 'services/sos_notification_service.dart';
import 'services/recovery_pet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Firebase (Recovery Circle cloud sync) — activates only when
  // android/app/google-services.json exists; local-only otherwise.
  try {
    await Firebase.initializeApp();
    CommunityFeedService.remoteReady = true;
  } catch (_) {
    CommunityFeedService.remoteReady = false;
  }

  // 1. Initialize the modern notification bridge
  await SosNotificationService.initialize();
  await GentleReminderService.initialize();
  unawaited(GentleReminderService.rescheduleIfEnabled());
  
  // 2. Safely retrieve user preferences and restore SOS state if active
  final sosSettings = await SosNotificationService.getStoredSettings();
  if (sosSettings.enabled) {
    await SosNotificationService.startPersistentSos(
      sponsorPhone: sosSettings.sponsor,
      customHelpPhone: sosSettings.custom,
      safetyPlan: sosSettings.safetyPlan,
    );
  }

  // 3. Mount the local-first database
  final database = RecoveryDatabase();
  RecoveryPetService.bindDatabase(database);

  runApp(
    ProviderScope(
      child: RecoveryCompanionApp(database: database),
    ),
  );
}

class RecoveryCompanionApp extends StatelessWidget {
  final RecoveryDatabase database;

  const RecoveryCompanionApp({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Private Recovery Coach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF38BDF8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      home: SplashScreen(database: database),
    );
  }
}