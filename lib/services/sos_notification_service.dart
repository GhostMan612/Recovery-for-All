// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Persistent SOS notification with:
/// - Foreground service (specialUse)
/// - Isolate-safe contact storage (SharedPreferences)
/// - Payload + prefs dual-read for background actions
/// - Auto-republish on dismiss (Android 14+)
/// - Restore-on-launch for post-boot recovery
class SosNotificationService {
  static const String channelKey = 'sos_persistent';
  static const int notificationId = 988001;

  static const String actionCallSponsor = 'CALL_SPONSOR';
  static const String actionTextSponsor = 'TEXT_SPONSOR';
  static const String actionCall988 = 'CALL_988';
  static const String actionCustomHelp = 'CUSTOM_HELP';

  // Isolate-safe preference keys (readable from background action isolate)
  static const String prefSponsor = 'sos_sponsor_phone';
  static const String prefCustom = 'sos_custom_help_phone';
  static const String prefEnabled = 'sos_enabled';

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

  /// Persist contacts in isolate-safe storage + optional DB mirror handled by caller.
  static Future<void> saveContacts({
    required String? sponsorPhone,
    required String? customHelpPhone,
    bool enabled = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefSponsor, sponsorPhone?.trim() ?? '');
    await prefs.setString(prefCustom, customHelpPhone?.trim() ?? '');
    await prefs.setBool(prefEnabled, enabled);
  }

  /// Load contacts from isolate-safe storage.
  /// Always call [SharedPreferences.reload] when reading from a background isolate.
  static Future<({String? sponsor, String? custom, bool enabled})> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // critical for background isolate cache coherence
    final sponsor = prefs.getString(prefSponsor);
    final custom = prefs.getString(prefCustom);
    final enabled = prefs.getBool(prefEnabled) ?? true;
    return (
      sponsor: (sponsor != null && sponsor.isNotEmpty) ? sponsor : null,
      custom: (custom != null && custom.isNotEmpty) ? custom : null,
      enabled: enabled,
    );
  }

  /// Request notification permission (Android 13+).
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
  static Future<void> startPersistentSos({
    String? sponsorPhone,
    String? customHelpPhone,
  }) async {
    // Prefer explicit args; fall back to isolate-safe storage
    final stored = await loadContacts();
    final sponsor = (sponsorPhone != null && sponsorPhone.trim().isNotEmpty)
        ? sponsorPhone.trim()
        : stored.sponsor;
    final custom = (customHelpPhone != null && customHelpPhone.trim().isNotEmpty)
        ? customHelpPhone.trim()
        : stored.custom;

    await saveContacts(
      sponsorPhone: sponsor,
      customHelpPhone: custom,
      enabled: true,
    );

    final allowed = await requestPermission();
    if (!allowed) return;

    final hasSponsor = sponsor != null && sponsor.isNotEmpty;
    final hasCustom = custom != null && custom.isNotEmpty;

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
        'sponsorPhone': sponsor ?? '',
        'customHelpPhone': custom ?? '',
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

  /// Restore SOS after cold start / reboot if user left it enabled.
  /// Call from main() after initialize().
  static Future<void> restoreIfEnabled() async {
    final stored = await loadContacts();
    if (!stored.enabled) return;

    // Always restore at least 988 button; contacts optional
    await startPersistentSos(
      sponsorPhone: stored.sponsor,
      customHelpPhone: stored.custom,
    );
  }

  /// Stop the SOS notification + foreground service.
  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, false);

    await AndroidForegroundService.stopForeground(notificationId);
    await AwesomeNotifications().cancel(notificationId);
  }

  // ---------------------------------------------------------------------------
  // Background isolate entry points
  // ---------------------------------------------------------------------------

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    final payload = action.payload ?? {};

    // Dual-read: payload first, then isolate-safe prefs
    String? sponsor = payload['sponsorPhone']?.trim();
    String? custom = payload['customHelpPhone']?.trim();

    if ((sponsor == null || sponsor.isEmpty) ||
        (custom == null || custom.isEmpty)) {
      final stored = await loadContacts();
      sponsor = (sponsor != null && sponsor.isNotEmpty) ? sponsor : stored.sponsor;
      custom = (custom != null && custom.isNotEmpty) ? custom : stored.custom;
    }

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

  /// Android 14+ allows dismissing ongoing notifications.
  /// Republish from isolate-safe storage so static memory is not required.
  @pragma('vm:entry-point')
  static Future<void> _onDismissReceived(ReceivedAction action) async {
    if (action.id != notificationId) return;

    final stored = await loadContacts();
    if (!stored.enabled) return;

    await Future.delayed(const Duration(milliseconds: 400));
    await startPersistentSos(
      sponsorPhone: stored.sponsor,
      customHelpPhone: stored.custom,
    );
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
