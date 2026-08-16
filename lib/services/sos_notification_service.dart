// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SosNotificationService {
  static const String channelKey = 'sos_persistent';
  static const int notificationId = 988001;

  static const String actionCallSponsor = 'CALL_SPONSOR';
  static const String actionTextSponsor = 'TEXT_SPONSOR';
  static const String actionCall988 = 'CALL_988';
  static const String actionCustomHelp = 'CUSTOM_HELP';

  // Cached numbers so dismiss handler can republish
  static String? _sponsorPhone;
  static String? _customHelpPhone;

  /// Call once at app startup (before runApp).
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: 'SOS Recovery Controls',
          channelDescription: 'Persistent one-tap crisis help buttons',
          importance: NotificationImportance.High,
          defaultPrivacy: NotificationPrivacy.Private,
          playSound: false,
          enableVibration: false,
          locked: true,
          criticalAlerts: true,
          defaultColor: const Color(0xFF38BDF8),
        ),
      ],
      debug: false,
    );

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
      onDismissActionReceivedMethod: _onDismissReceived,
    );
  }

  /// Request notification permission (Android 13+).
  /// Returns true if granted.
  static Future<bool> requestPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) return true;

    return await AwesomeNotifications().requestPermissionToSendNotifications(
      permissions: [
        NotificationPermission.Alert,
        NotificationPermission.Sound,
        NotificationPermission.Badge,
        NotificationPermission.CriticalAlert,
        NotificationPermission.OverrideDnD,
      ],
    );
  }

  /// Start / refresh the persistent SOS notification as a foreground service.
  /// Auto-republishes on dismiss.
  static Future<void> startPersistentSos({
    required String? sponsorPhone,
    required String? customHelpPhone,
  }) async {
    _sponsorPhone = sponsorPhone;
    _customHelpPhone = customHelpPhone;

    final allowed = await requestPermission();
    if (!allowed) return;

    final hasSponsor = sponsorPhone != null && sponsorPhone.trim().isNotEmpty;
    final hasCustom = customHelpPhone != null && customHelpPhone.trim().isNotEmpty;

    final content = NotificationContent(
      id: notificationId,
      channelKey: channelKey,
      title: 'Recovery SOS',
      body: 'One-tap help is ready',
      category: NotificationCategory.Service,
      notificationLayout: NotificationLayout.Default,
      locked: true,
      autoDismissible: false,
      displayOnForeground: true,
      displayOnBackground: true,
      wakeUpScreen: false,
      payload: {
        'sponsorPhone': sponsorPhone ?? '',
        'customHelpPhone': customHelpPhone ?? '',
      },
    );

    final buttons = <NotificationActionButton>[
      if (hasSponsor)
        NotificationActionButton(
          key: actionCallSponsor,
          label: 'Call Sponsor',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        ),
      if (hasSponsor)
        NotificationActionButton(
          key: actionTextSponsor,
          label: 'Text Sponsor',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        ),
      NotificationActionButton(
        key: actionCall988,
        label: 'Call 988',
        actionType: ActionType.SilentAction,
        autoDismissible: false,
        color: Colors.redAccent,
      ),
      if (hasCustom)
        NotificationActionButton(
          key: actionCustomHelp,
          label: 'Other Help',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        ),
    ];

    await AndroidForegroundService.startAndroidForegroundService(
      foregroundStartMode: ForegroundStartMode.stick,
      foregroundServiceType: ForegroundServiceType.specialUse,
      content: content,
      actionButtons: buttons,
    );
  }

  /// Stop the SOS notification + foreground service.
  static Future<void> stop() async {
    await AndroidForegroundService.stopForeground(notificationId);
    await AwesomeNotifications().cancel(notificationId);
    _sponsorPhone = null;
    _customHelpPhone = null;
  }

  // ---------------------------------------------------------------------------
  // Action handlers (must be static + @pragma for background isolate)
  // ---------------------------------------------------------------------------

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    final payload = action.payload ?? {};
    final sponsor = payload['sponsorPhone']?.trim();
    final custom = payload['customHelpPhone']?.trim();

    switch (action.buttonKeyPressed) {
      case actionCallSponsor:
        if (sponsor != null && sponsor.isNotEmpty) {
          await _launchTel(sponsor);
        }
        break;
      case actionTextSponsor:
        if (sponsor != null && sponsor.isNotEmpty) {
          await _launchSms(sponsor);
        }
        break;
      case actionCall988:
        await _launchTel('988');
        break;
      case actionCustomHelp:
        if (custom != null && custom.isNotEmpty) {
          await _launchTel(custom);
        }
        break;
    }
  }

  /// Auto-republish when user dismisses the notification.
  @pragma('vm:entry-point')
  static Future<void> _onDismissReceived(ReceivedAction action) async {
    if (action.id == notificationId) {
      await Future.delayed(const Duration(milliseconds: 400));
      await startPersistentSos(
        sponsorPhone: _sponsorPhone,
        customHelpPhone: _customHelpPhone,
      );
    }
  }

  static Future<void> _launchTel(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _launchSms(String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
