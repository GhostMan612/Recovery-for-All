// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_primitives.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/feedback_service.dart';
import '../services/gguf_model_service.dart';
import '../services/gentle_reminder_service.dart';
import '../services/journal_crypto_service.dart';
import '../services/resource_link_health.dart';
import '../services/meeting_finder_service.dart';
import '../services/data_export_service.dart';
import '../services/sponsor_link_service.dart';
import 'seventh_tradition_screen.dart';
import '../services/sos_notification_service.dart';
import 'sponsor_mode_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final RecoveryDatabase database;

  const SettingsScreen({super.key, required this.database});

  /// Public so the dashboard shell can hold a GlobalKey and call
  /// `refreshState()` when this screen is selected as a persistent tab.
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _sponsorController = TextEditingController();
  final _customHelpController = TextEditingController();
  final _safetyPlanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  List<String> _meetingSources = [];
  bool _refreshingMeetings = false;
  String? _lastMeetingRefresh;
  bool _isModerator = false;
  bool _reminderEnabled = false;
  int _reminderMinutes = 8 * 60;
  bool _biometricEnabled = false;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _ggufSupported = false;
  bool _ggufEnabled = false;
  String? _ggufSelectedModel;
  Set<String> _ggufDownloaded = {};
  bool _ggufDownloading = false;
  double _ggufProgress = 0;
  final TextEditingController _sponsorAliasController = TextEditingController();
  final TextEditingController _sponsorCodeController = TextEditingController();
  SponsorIdentity? _registeredSponsor;

  final MeetingFinderService _meetingFinder = MeetingFinderService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMeetingSources();
  }

  /// Re-reads persisted state.
  ///
  /// Phase 9: this screen became a persistent tab inside an `IndexedStack`, so
  /// it is constructed once and never rebuilt. Loading only in `initState`
  /// meant every toggle showed whatever was true when the app launched, and
  /// `_biometricEnabled` could contradict what `SplashScreen` actually
  /// enforces (it reads Drift directly, not from here). The shell calls this
  /// when the Profile destination is selected, so arriving at the tab always
  /// shows current state.
  void refreshState() {
    if (!mounted) return;
    _loadProfile();
  }

  @override
  void dispose() {
    _sponsorController.dispose();
    _customHelpController.dispose();
    _safetyPlanController.dispose();
    _sponsorAliasController.dispose();
    _sponsorCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final moderator = await CommunityFeedService.isModerator();
    final reminderEnabled = await GentleReminderService.getEnabled();
    final reminderMinutes = await GentleReminderService.getMinutesOfDay();
    final sound = await FeedbackService.soundEnabled();
    final haptics = await FeedbackService.hapticsEnabled();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isModerator = moderator;
        _reminderEnabled = reminderEnabled;
        _reminderMinutes = reminderMinutes;
        _biometricEnabled = profile?.biometricLockEnabled ?? false;
        _soundEnabled = sound;
        _hapticsEnabled = haptics;
      });
    }
    final sponsor = await SponsorLinkService.registeredSponsor();
    if (mounted) setState(() => _registeredSponsor = sponsor);
    await _loadGgufState();
  }

  Future<void> _loadGgufState() async {
    final service = GgufModelService();
    await service.detectDeviceTier();
    final supported = service.isSupported;
    final enabled = await service.isEnabled();
    final selected = await service.getSelectedModelId();
    final downloaded = await service.getDownloadedModels();
    if (!mounted) return;
    setState(() {
      _ggufSupported = supported;
      _ggufEnabled = enabled && supported;
      _ggufSelectedModel = selected;
      _ggufDownloaded = downloaded;
    });
  }

  Future<void> _toggleGguf(bool value) async {
    final service = GgufModelService();
    await service.setEnabled(value);
    // R24: toggling in Settings clears persistent chat dismissal
    if (value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gguf_download_dismissed_v1');
    }
    if (!mounted) return;
    setState(() => _ggufEnabled = value);
  }

  Future<void> _downloadGgufModel(GgufModelInfo model) async {
    final service = GgufModelService();
    setState(() => _ggufDownloading = true);
    final ok = await service.downloadModel(model, onProgress: (d, tot) {
      if (mounted) setState(() => _ggufProgress = tot > 0 ? d / tot : 0);
    });
    if (!mounted) return;
    setState(() => _ggufDownloading = false);
    if (ok) {
      await service.setSelectedModelId(model.id);
      // Clear chat dismissal so offline AI prompt respects new download
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gguf_download_dismissed_v1');
      if (!mounted) return;
      setState(() {
        _ggufSelectedModel = model.id;
        _ggufDownloaded.add(model.id);
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? '${model.name} ready for offline use.'
              : 'Download failed: ${GgufModelService.lastDownloadError ?? 'unknown error'}')),
    );
  }

  Future<void> _toggleReminder(bool value) async {
    final granted =
        await GentleReminderService.setSchedule(
      enabled: value,
      minutesOfDay: _reminderMinutes,
    );
    if (!mounted) return;
    setState(() => _reminderEnabled = granted ? value : false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(granted
            ? (value
                ? 'Daily invitation set for ${GentleReminderService.formatMinutes(_reminderMinutes)}'
                : 'Reminder turned off')
            : 'Notification permission was denied'),
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderMinutes ~/ 60, minute: _reminderMinutes % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() => _reminderMinutes = minutes);
    if (_reminderEnabled) {
      await GentleReminderService.setSchedule(enabled: true, minutesOfDay: minutes);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text('Invitation set for ${GentleReminderService.formatMinutes(minutes)}'),
      ),
    );
  }

  Future<void> _toggleBiometric(bool want) async {
    if (!want) {
      final profile = await widget.database.getProfile('active_user_profile');
      if (profile != null) {
        await widget.database.saveProfile(
          profile.copyWith(biometricLockEnabled: false),
        );
      }
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      return;
    }

    // Confirm the device can actually do it before saving the flag.
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Confirm to enable biometric unlock',
        biometricOnly: true,
      );
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not confirmed — lock stays off')),
        );
        return;
      }
      final profile = await widget.database.getProfile('active_user_profile');
      if (profile != null) {
        await widget.database.saveProfile(
          profile.copyWith(biometricLockEnabled: true),
        );
      }
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No biometrics enrolled on this device')),
      );
    }
  }

  Future<void> _verifyResourceLinks() async {
    final urls = ResourceLinkHealth.allRegistryUrls();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checking ${urls.length} links…')));
    final service = ResourceLinkHealth.instance;
    final (checked, broken) = await service.verifyAll(urls, null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(broken == 0
            ? 'All $checked links are alive.'
            : '$broken of $checked links look down — affected entries are '
                'dimmed in the Library and Community screens (details '
                'still readable).')));
  }

  Future<void> _resetDashboardLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_tool_order_v1');
    await prefs.remove('dashboard_library_order_v1');
    await prefs.remove('dashboard_hidden_tools_v1');
    await prefs.remove('dashboard_hidden_library_v1');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard layout reset — reopen to see.')));
  }

  Future<void> _changeJournalPin() async {
    final scheme = Theme.of(context).colorScheme;
    final current = await _promptPinText('Enter your current journal PIN');
    if (current == null || !mounted) return;
    final ok = await JournalCryptoService.verifyPin(current);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('That PIN did not match — nothing changed'),
          backgroundColor: scheme.error));
      return;
    }
    if (!mounted) return;
    final next =
        await _promptPinText('Choose your new ${JournalCryptoService.pinLength}-digit PIN');
    if (next == null || !mounted) return;
    final confirm =
        await _promptPinText('Confirm the new PIN');
    if (confirm == null || !mounted) return;
    if (confirm != next) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('The two new PINs did not match — nothing changed'),
          backgroundColor: scheme.error));
      return;
    }
    try {
      await JournalCryptoService.setPin(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal PIN updated')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PIN must be exactly 6 digits'),
          backgroundColor: scheme.error));
    }
  }

  Future<String?> _promptPinText(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text(title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: JournalCryptoService.pinLength,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 20, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text('Continue',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _linkSponsor() async {
    final identity = await SponsorLinkService.registerSponsor(
      _sponsorAliasController.text,
      _sponsorCodeController.text,
    );
    if (!mounted) return;
    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid pairing code — check with your sponsor.')),
      );
      return;
    }
    setState(() => _registeredSponsor = identity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text('Linked to ${identity.alias} — sign-offs are now verifiable.'),
      ),
    );
  }

  Future<void> _loadMeetingSources() async {
    final sources = await _meetingFinder.getSources();
    final last = await _meetingFinder.lastRefreshed();
    if (!mounted) return;
    setState(() {
      _meetingSources = sources;
      _lastMeetingRefresh = last == null
          ? null
          : MaterialLocalizations.of(context).formatFullDate(last);
    });
  }

  Future<(double, double)> _currentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 8));
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (44.9778, -93.2650); // Minnesota-first fallback (Twin Cities)
    }
  }

  Future<void> _refreshMeetingDirectory() async {
    setState(() => _refreshingMeetings = true);
    final (lat, lng) = await _currentLocation();
    var count = 0;
    var failed = false;
    try {
      final meetings = await _meetingFinder.refresh(lat: lat, lng: lng);
      count = meetings.length;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _refreshingMeetings = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(
          failed
              ? 'Refresh failed — the cached directory still works offline.'
              : 'Directory refreshed · $count meetings cached for offline use',
        ),
      ),
    );
    _loadMeetingSources();
  }

  Future<void> _addSource() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Add Meeting Feed', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'https://yourarea.org/meetings.json',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feed URL must start with http(s)://')),
      );
      return;
    }
    final updated = [..._meetingSources, url];
    await _meetingFinder.setSources(updated);
    setState(() => _meetingSources = updated);
  }

  Future<void> _removeSource(String url) async {
    final updated = [..._meetingSources]..remove(url);
    await _meetingFinder.setSources(updated);
    setState(() => _meetingSources = updated);
  }

  String _shortenUrl(String url) {
    final withoutScheme = url.replaceFirst(RegExp(r'^https?://'), '');
    return withoutScheme.length > 60
        ? '${withoutScheme.substring(0, 60)}…'
        : withoutScheme;
  }

  InputDecoration _fieldDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
      ],
      decoration: _fieldDecoration(label: label, hint: hint).copyWith(
        prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.outline),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final digits = value.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 7) return 'Enter a valid phone number';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                            const AppSectionHeader(
                title: 'System Permissions',
              ),
              ListTile(
                title: Text('Battery Optimization', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Disable for reliable background SOS', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.primary),
                onTap: () async {
                  await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                },
              ),
              ListTile(
                title: Text('General App Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                trailing: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                onTap: () async {
                  await AppSettings.openAppSettings();
                },
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'Appearance',
              ),
              Text('Choose a palette — saved to theme_preference_v1', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final current = ref.watch(themeProvider).palette;
                Widget chip(AppTheme t, String label) => ChoiceChip(
                      label: Text(label, style: TextStyle(color: current == t ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                      selected: current == t,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      avatar: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.paletteFor(t).bgDeep, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)))),
                      onSelected: (sel) {
                        if (sel) {
                          ref.read(themeProvider.notifier).setPalette(t);
                        }
                      },
                    );
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  chip(AppTheme.midnightSlate, 'Midnight Slate'),
                  chip(AppTheme.deepForest, 'Deep Forest'),
                  chip(AppTheme.oledPitch, 'OLED Pitch'),
                ]);
              }),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text('Community moderator mode',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Review flagged circle posts before they return to the feed',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                value: _isModerator,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) async {
                  await CommunityFeedService.setModerator(value);
                  setState(() => _isModerator = value);
                },
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'Gentle Reminder',
              ),
              Text(
                'One invitational nudge a day. No streaks, no guilt — '
                'just an open door at a time you choose.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              SwitchListTile(
                title: Text('Daily invitation',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(GentleReminderService.formatMinutes(_reminderMinutes),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                value: _reminderEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: _toggleReminder,
              ),
              ListTile(
                enabled: _reminderEnabled,
                leading:
                    Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                title: Text('Invitation time',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                trailing: Text(
                  GentleReminderService.formatMinutes(_reminderMinutes),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                onTap: _reminderEnabled ? _pickReminderTime : null,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text('Biometric app lock',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Require fingerprint/face when opening the app',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                value: _biometricEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: _toggleBiometric,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.key, color: Theme.of(context).colorScheme.primary),
                title:
                    Text('Journal PIN',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Change the privacy wall on your private journal',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                onTap: _changeJournalPin,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.fact_check_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: Text('Verify resource links now',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Check every literature & community link for link rot',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                onTap: _verifyResourceLinks,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.dashboard_customize_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: Text('Reset dashboard layout',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Restore tile order and show hidden tiles',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                onTap: _resetDashboardLayout,
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'My Sponsor',
              ),
              if (_registeredSponsor != null) ...[
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_outlined,
                      color: Theme.of(context).colorScheme.tertiary),
                  title: Text(_registeredSponsor!.alias,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  subtitle: Text('Pairing ${_registeredSponsor!.pairingCode}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                        label: const Text('Sponsor Mode'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SponsorModeScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerSoft,
                          side: BorderSide(color: AppColors.dangerSoft.withValues(alpha: 0.4)),
                        ),
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Unlink'),
                        onPressed: () async {
                          await SponsorLinkService.unregisterSponsor();
                          if (!mounted) return;
                          setState(() => _registeredSponsor = null);
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Enter the pairing code from your sponsor\'s app '
                  '(Sponsor Mode). Enables verified 12-step sign-offs.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sponsorAliasController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: _fieldDecoration(label: 'Sponsor alias', hint: 'e.g. Mike D.'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sponsorCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, letterSpacing: 1.5),
                  decoration: _fieldDecoration(label: 'Pairing code', hint: 'ABCD12EF-QX'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                        ),
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Link sponsor'),
                        onPressed: _linkSponsor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.tertiary,
                          side: BorderSide(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                        label: const Text('I am a sponsor'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SponsorModeScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text('Feedback', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: Text('Sound effects',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Reward chimes for Sparks, milestones, and stars',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                value: _soundEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) async {
                  await FeedbackService.setSound(value);
                  setState(() => _soundEnabled = value);
                },
              ),
              SwitchListTile(
                title: Text('Haptics',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    'Vibration feedback on rewards and key actions',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                value: _hapticsEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) async {
                  await FeedbackService.setHaptics(value);
                  setState(() => _hapticsEnabled = value);
                  if (value) await FeedbackService.selection();
                },
              ),
              const SizedBox(height: 24),
              if (_ggufSupported) ...[
                                const AppSectionHeader(
                  title: 'Deeper Chat (Optional)',
                ),
                Text(
                  'Download a small AI model for richer coach replies. '
                  'Runs entirely on your device. Your scripted coach remains '
                  'the default and safety features never change.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Enable deeper chat',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  value: _ggufEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: _toggleGguf,
                ),
                if (_ggufEnabled)
                  for (final model in GgufModelService.catalog)
                    if (model.minTier.index <= GgufModelService().deviceTier.index)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _ggufDownloaded.contains(model.id)
                              ? Icons.check_circle
                              : Icons.download_outlined,
                          color: _ggufDownloaded.contains(model.id)
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        title: Text(model.name,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                        subtitle: Text(
                            '${model.description}\n${model.fileSizeMb} · ${model.quantization}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.3)),
                        trailing: _ggufDownloading && _ggufSelectedModel == model.id
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : _ggufDownloaded.contains(model.id)
                                ? IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Theme.of(context).colorScheme.error, size: 20),
                                    onPressed: () async {
                                      await GgufModelService().deleteModel(model.id);
                                      final downloaded =
                                          await GgufModelService().getDownloadedModels();
                                      if (!mounted) return;
                                      setState(() => _ggufDownloaded = downloaded);
                                    },
                                  )
                                : IconButton(
                                    icon: Icon(Icons.download,
                                        color: Theme.of(context).colorScheme.primary, size: 20),
                                    onPressed: () => _downloadGgufModel(model),
                                  ),
                        onTap: () {
                          if (_ggufDownloaded.contains(model.id)) {
                            GgufModelService().setSelectedModelId(model.id);
                            setState(() => _ggufSelectedModel = model.id);
                          }
                        },
                      ),
                if (_ggufDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: _ggufProgress,
                      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'Export Data',
              ),
              Text(
                'Share your recovery data with a therapist, counselor, or healthcare provider.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.table_view, size: 18),
                      label: const Text('Export CSV'),
                      onPressed: () async {
                        try {
                          await DataExportService(widget.database).shareCsv();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Summary'),
                      onPressed: () async {
                        try {
                          await DataExportService(widget.database).shareSummary();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'SOS Contacts',
              ),
              _buildPhoneField(
                controller: _sponsorController,
                label: 'Sponsor Phone',
                hint: 'e.g. 555-0123',
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  if (_sponsorController.text.isNotEmpty) {
                    SosNotificationService.launchTel(_sponsorController.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Test Call Sponsor'),
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'Meeting Directory',
              ),
              Text(
                'Open feeds following the Meeting Guide spec (AA intergroups, BMLT for NA). '
                'Downloaded meetings are cached and work fully offline.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (_lastMeetingRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Last refreshed: $_lastMeetingRefresh',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
                ),
              ..._meetingSources.map(
                (url) => ListTile(
                  dense: true,
                  leading: Icon(Icons.rss_feed, color: Theme.of(context).colorScheme.primary, size: 20),
                  title: Text(_shortenUrl(url),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Remove feed',
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error, size: 20),
                    onPressed: () => _removeSource(url),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.add_link, size: 18),
                      label: const Text('Add Feed'),
                      onPressed: _addSource,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      icon: _refreshingMeetings
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface))
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed:
                          _refreshingMeetings ? null : _refreshMeetingDirectory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/code4recovery/spec'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.menu_book_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Feed format spec (Code for Recovery) — works with AA intergroups and BMLT',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(Icons.open_in_new,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 7th Tradition & Support
                            const AppSectionHeader(
                title: '7th Tradition & Support',
              ),
              Text(
                'Every fellowship is self-supporting. Links open in your browser — '
                'Recovery for All does not process payments or collect financial data.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.pink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volunteer_activism_outlined,
                      color: AppColors.pink, size: 22),
                ),
                title: Text('7th Tradition & Support',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Fellowship donations, literature stores, and app upkeep',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SeventhTraditionScreen()),
                ),
              ),
              const SizedBox(height: 24),
                            const AppSectionHeader(
                title: 'Legal',
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Privacy Policy',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Offline-first, no analytics, no tracking',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                onTap: () => launchUrl(Uri.parse('https://github.com/GhostMan612/Recovery-for-All/blob/main/PRIVACY_POLICY.md'), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Terms of Service',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('EULA — not medical advice',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                onTap: () => launchUrl(Uri.parse('https://github.com/GhostMan612/Recovery-for-All/blob/main/TERMS.md'), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.article_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Open Source Licenses',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Flutter, Drift, SQLCipher, llama.cpp, etc.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                onTap: () => showLicensePage(context: context, applicationName: 'Recovery for All', applicationVersion: '1.0.0+1', applicationLegalese: '© 2024–2026 Recovery for All — Proprietary. Third-party licenses as listed.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.security_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Security Policy',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Report vulnerabilities privately',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                onTap: () => launchUrl(Uri.parse('https://github.com/GhostMan612/Recovery-for-All/blob/main/SECURITY.md'), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }
}