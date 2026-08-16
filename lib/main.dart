// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_navigator.dart';
import 'database/recovery_database.dart';
import 'screens/splash_screen.dart';
import 'services/sos_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SosNotificationService.initialize();
  await SosNotificationService.restoreIfEnabled();

  final database = RecoveryDatabase();

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
