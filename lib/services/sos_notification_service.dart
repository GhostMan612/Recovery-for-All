// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SosNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String prefSponsor = 'sos_sponsor_phone';
  static const String prefCustom = 'sos_custom_help_phone';
  static const String prefEnabled = 'sos_enabled';
  static const String prefSafetyPlan = 'sos_safety_plan';
  static const String prefLockScreenPublic = 'sos_lock_screen_public';

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
  }

  static Future<({String? custom, bool enabled, bool lockScreenPublic, String safetyPlan, String? sponsor})> getStoredSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sponsor = prefs.getString(prefSponsor);
    return (
      custom: prefs.getString(prefCustom),
      enabled: prefs.getBool(prefEnabled) ?? true,
      lockScreenPublic: prefs.getBool(prefLockScreenPublic) ?? true,
      safetyPlan: prefs.getString(prefSafetyPlan) ?? '',
      sponsor: (sponsor != null && sponsor.isNotEmpty) ? sponsor : null,
    );
  }

  static Future<void> startPersistentSos({
    String? sponsorPhone,
    String? customHelpPhone,
    String safetyPlan = '',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sos_persistent',
      'SOS Persistent Help',
      channelDescription: 'Always-on SOS lifeline',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id: 988001,
      title: 'SOS Recovery Lifeline',
      body: 'Tap for immediate support options.',
      notificationDetails: details,
    );
  }

  static Future<void> launchTel(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse('tel:$cleaned'));
      }
    } catch (_) {}
  }

  static Future<void> launchSms(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'sms', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse('sms:$cleaned'));
      }
    } catch (_) {}
  }
}