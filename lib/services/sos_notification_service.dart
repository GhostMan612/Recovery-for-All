// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_navigator.dart';
import '../screens/grounding_screen.dart';

/// Persistent SOS notification hardened for crisis use.
class SosNotificationService {
  static const String channelKey = 'sos_persistent';
  static const int notificationId = 988001;

  static const String actionCallSponsor = 'CALL_SPONSOR';
  static const String actionTextSponsor = 'TEXT_SPONSOR';
  static const String actionCall988 = 'CALL_988';
  static const String actionText988 = 'TEXT_988';
  static const String actionCustomHelp = 'CUSTOM_HELP';
  static const String actionGround = 'GROUND';

  static const String prefSponsor = 'sos_sponsor_phone';
  static const String prefCustom = 'sos_custom_help_phone';
  static const String prefEnabled = 'sos_enabled';
  static const String prefSafetyPlan = 'sos_safety_plan';
  static const String prefSponsorsJson = 'sos_sponsors_json';
  static const String prefLockScreenPublic = 'sos_lock_screen_public';

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: 'SOS Recovery Controls',
          channelDescription: 'Persistent one-tap crisis help buttons',
          importance: NotificationImportance.High,
          defaultPrivacy: NotificationPrivacy.Public,
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

  static Future<void> saveContacts({
    required String? sponsorPhone,
    required String? customHelpPhone,
    bool enabled = true,
    String? safetyPlan,
    bool? lockScreenPublic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefSponsor, sponsorPhone?.trim() ?? '');
    await prefs.setString(prefCustom, customHelpPhone?.trim() ?? '');
    await prefs.setBool(prefEnabled, enabled);
    if (safetyPlan != null) {
      await prefs.setString(prefSafetyPlan, safetyPlan.trim());
    }
    if (lockScreenPublic != null) {
      await prefs.setBool(prefLockScreenPublic, lockScreenPublic);
    }
  }

  static Future<void> saveSponsorsJson(String jsonList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefSponsorsJson, jsonList);
  }

  static Future<List<Map<String, dynamic>>> loadSponsors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(prefSponsorsJson);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Primary sponsor = first entry in multi-sponsor list, else single pref.
  static Future<String?> resolvePrimarySponsorPhone() async {
    final sponsors = await loadSponsors();
    if (sponsors.isNotEmpty) {
      final phone = (sponsors.first['phone'] as String?)?.trim();
      if (phone != null && phone.isNotEmpty) return phone;
    }
    final stored = await loadContacts();
    return stored.sponsor;
  }

  static Future<
      ({
        String? sponsor,
        String? custom,
        bool enabled,
        String safetyPlan,
        bool lockScreenPublic,
      })> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final sponsor = prefs.getString(prefSponsor);
    final custom = prefs.getString(prefCustom);
    final enabled = prefs.getBool(prefEnabled) ?? true;
    final plan = prefs.getString(prefSafetyPlan) ?? '';
    final lockPublic = prefs.getBool(prefLockScreenPublic) ?? true;
    return (
      sponsor: (sponsor != null && sponsor.isNotEmpty) ? sponsor : null,
      custom: (custom != null && custom.isNotEmpty) ? custom : null,
      enabled: enabled,
      safetyPlan: plan,
      lockScreenPublic: lockPublic,
    );
  }

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

  static Future<void> startPersistentSos({
    String? sponsorPhone,
    String? customHelpPhone,
    String? safetyPlan,
  }) async {
    final stored = await loadContacts();
    final primary = await resolvePrimarySponsorPhone();

    final sponsor = (sponsorPhone != null && sponsorPhone.trim().isNotEmpty)
        ? sponsorPhone.trim()
        : (primary ?? stored.sponsor);
    final custom = (customHelpPhone != null && customHelpPhone.trim().isNotEmpty)
        ? customHelpPhone.trim()
        : stored.custom;
    final plan = (safetyPlan != null && safetyPlan.trim().isNotEmpty)
        ? safetyPlan.trim()
        : stored.safetyPlan;

    await saveContacts(
      sponsorPhone: sponsor,
      customHelpPhone: custom,
      enabled: true,
      safetyPlan: plan,
      lockScreenPublic: stored.lockScreenPublic,
    );

    final allowed = await requestPermission();
    if (!allowed) return;

    final hasSponsor = sponsor != null && sponsor.isNotEmpty;
    final hasCustom = custom != null && custom.isNotEmpty;

    final body = plan.isNotEmpty
        ? plan.length > 120
            ? '${plan.substring(0, 117)}...'
            : plan
        : 'Call / text help · Ground for 60s';

    final content = NotificationContent(
      id: notificationId,
      channelKey: channelKey,
      title: 'Recovery SOS',
      body: body,
      category: NotificationCategory.Service,
      notificationLayout: plan.isNotEmpty
          ? NotificationLayout.BigText
          : NotificationLayout.Default,
      locked: true,
      autoDismissible: false,
      displayOnForeground: true,
      displayOnBackground: true,
      wakeUpScreen: false,
      privacy: stored.lockScreenPublic
          ? NotificationPrivacy.Public
          : NotificationPrivacy.Private,
      payload: {
        'sponsorPhone': sponsor ?? '',
        'customHelpPhone': custom ?? '',
        'safetyPlan': plan,
      },
    );

    // Android reliably surfaces ~3 actions; prioritize crisis paths.
    final buttons = <NotificationActionButton>[
      NotificationActionButton(
        key: actionCall988,
        label: 'Call 988',
        actionType: ActionType.SilentAction,
        autoDismissible: false,
        color: Colors.redAccent,
      ),
      NotificationActionButton(
        key: actionText988,
        label: 'Text 988',
        actionType: ActionType.SilentAction,
        autoDismissible: false,
        color: Colors.redAccent,
      ),
      if (hasSponsor)
        NotificationActionButton(
          key: actionCallSponsor,
          label: 'Sponsor',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        )
      else if (hasCustom)
        NotificationActionButton(
          key: actionCustomHelp,
          label: 'Other Help',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        )
      else
        NotificationActionButton(
          key: actionGround,
          label: 'Ground',
          actionType: ActionType.Default,
          autoDismissible: false,
        ),
    ];

    // If sponsor present, still allow Ground from notification tap path via payload flag
    // Extra silent actions beyond 3 may be collapsed on some OEMs.
    if (hasSponsor || hasCustom) {
      buttons.add(
        NotificationActionButton(
          key: actionGround,
          label: 'Ground',
          actionType: ActionType.Default,
          autoDismissible: false,
        ),
      );
    }
    if (hasSponsor) {
      buttons.add(
        NotificationActionButton(
          key: actionTextSponsor,
          label: 'Text Sponsor',
          actionType: ActionType.SilentAction,
          autoDismissible: false,
        ),
      );
    }

    await AndroidForegroundService.startAndroidForegroundService(
      foregroundStartMode: ForegroundStartMode.stick,
      foregroundServiceType: ForegroundServiceType.specialUse,
      content: content,
      actionButtons: buttons,
    );
  }

  static Future<void> restoreIfEnabled() async {
    final stored = await loadContacts();
    if (!stored.enabled) return;
    await startPersistentSos(
      sponsorPhone: stored.sponsor,
      customHelpPhone: stored.custom,
      safetyPlan: stored.safetyPlan,
    );
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, false);
    await AndroidForegroundService.stopForeground(notificationId);
    await AwesomeNotifications().cancel(notificationId);
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    final payload = action.payload ?? {};

    String? sponsor = payload['sponsorPhone']?.trim();
    String? custom = payload['customHelpPhone']?.trim();

    if ((sponsor == null || sponsor.isEmpty) ||
        (custom == null || custom.isEmpty)) {
      final primary = await resolvePrimarySponsorPhone();
      final stored = await loadContacts();
      sponsor =
          (sponsor != null && sponsor.isNotEmpty) ? sponsor : (primary ?? stored.sponsor);
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
      case actionText988:
        await _launchSms('988');
        break;
      case actionCustomHelp:
        if (custom != null && custom.isNotEmpty) {
          await _launchTel(custom);
        }
        break;
      case actionGround:
        _openGrounding();
        break;
      default:
        // Notification body tap → grounding as safe default
        if (action.actionType == ActionType.Default) {
          _openGrounding();
        }
        break;
    }
  }

  static void _openGrounding() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => const GroundingScreen()),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _onDismissReceived(ReceivedAction action) async {
    if (action.id != notificationId) return;
    final stored = await loadContacts();
    if (!stored.enabled) return;
    await Future.delayed(const Duration(milliseconds: 400));
    await startPersistentSos(
      sponsorPhone: stored.sponsor,
      customHelpPhone: stored.custom,
      safetyPlan: stored.safetyPlan,
    );
  }

  /// Prefer ACTION_DIAL (tel:) — works without CALL_PHONE permission.
  /// Falls back to sms: for text actions.
  static Future<void> _launchTel(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      // Fallback: try without canLaunch gate (some OEMs lie)
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Last resort: open dialer with number in scheme form
      try {
        await launchUrl(Uri.parse('tel:$cleaned'));
      } catch (_) {}
    }
  }

  static Future<void> _launchSms(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'sms', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse('sms:$cleaned'));
      } catch (_) {}
    }
  }
}
