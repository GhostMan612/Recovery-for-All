// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/feedback_service.dart';
import '../services/gguf_model_service.dart';
import '../services/gentle_reminder_service.dart';
import '../services/journal_crypto_service.dart';
import '../services/meeting_finder_service.dart';
import '../services/data_export_service.dart';
import '../services/sponsor_link_service.dart';
import '../services/sos_notification_service.dart';
import 'sponsor_mode_screen.dart';

class SettingsScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
              : 'Download failed — try again later.')),
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
        backgroundColor: const Color(0xFF1E293B),
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
        backgroundColor: const Color(0xFF1E293B),
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

  Future<void> _changeJournalPin() async {
    final current = await _promptPinText('Enter your current journal PIN');
    if (current == null || !mounted) return;
    final ok = await JournalCryptoService.verifyPin(current);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That PIN did not match — nothing changed'),
          backgroundColor: Color(0xFFEF4444)));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The two new PINs did not match — nothing changed'),
          backgroundColor: Color(0xFFEF4444)));
      return;
    }
    try {
      await JournalCryptoService.setPin(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal PIN updated')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN must be exactly 6 digits'),
          backgroundColor: Color(0xFFEF4444)));
    }
  }

  Future<String?> _promptPinText(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: JournalCryptoService.pinLength,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Continue',
                style: TextStyle(color: Color(0xFF38BDF8))),
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
        backgroundColor: const Color(0xFF1E293B),
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
        backgroundColor: const Color(0xFF1E293B),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Meeting Feed', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://yourarea.org/meetings.json',
            hintStyle: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
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
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      hintStyle: const TextStyle(color: Color(0xFF475569)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
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
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
      ],
      decoration: _fieldDecoration(label: label, hint: hint).copyWith(
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
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
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('System Permissions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Battery Optimization', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Disable for reliable background SOS', style: TextStyle(color: Color(0xFF94A3B8))),
                trailing: const Icon(Icons.open_in_new, color: Color(0xFF38BDF8)),
                onTap: () async {
                  await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                },
              ),
              ListTile(
                title: const Text('General App Settings', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.settings, color: Color(0xFF38BDF8)),
                onTap: () async {
                  await AppSettings.openAppSettings();
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Community moderator mode',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Review flagged circle posts before they return to the feed',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: _isModerator,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: (value) async {
                  await CommunityFeedService.setModerator(value);
                  setState(() => _isModerator = value);
                },
              ),
              const SizedBox(height: 24),
              const Text('Gentle Reminder', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'One invitational nudge a day. No streaks, no guilt — '
                'just an open door at a time you choose.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              SwitchListTile(
                title: const Text('Daily invitation',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(GentleReminderService.formatMinutes(_reminderMinutes),
                    style: const TextStyle(color: Color(0xFF94A3B8))),
                value: _reminderEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: _toggleReminder,
              ),
              ListTile(
                enabled: _reminderEnabled,
                leading:
                    const Icon(Icons.schedule, color: Color(0xFF38BDF8)),
                title: const Text('Invitation time',
                    style: TextStyle(color: Colors.white)),
                trailing: Text(
                  GentleReminderService.formatMinutes(_reminderMinutes),
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                onTap: _reminderEnabled ? _pickReminderTime : null,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Biometric app lock',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Require fingerprint/face when opening the app',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: _biometricEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: _toggleBiometric,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key, color: Color(0xFF38BDF8)),
                title:
                    const Text('Journal PIN',
                        style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Change the privacy wall on your private journal',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                onTap: _changeJournalPin,
              ),
              const SizedBox(height: 24),
              const Text('My Sponsor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (_registeredSponsor != null) ...[
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_outlined,
                      color: Color(0xFF34D399)),
                  title: Text(_registeredSponsor!.alias,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Pairing ${_registeredSponsor!.pairingCode}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
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
                          foregroundColor: const Color(0xFFF87171),
                          side: BorderSide(color: const Color(0xFFF87171).withValues(alpha: 0.4)),
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
                const Text(
                  'Enter the pairing code from your sponsor\'s app '
                  '(Sponsor Mode). Enables verified 12-step sign-offs.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sponsorAliasController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration(label: 'Sponsor alias', hint: 'e.g. Mike D.'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sponsorCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
                  decoration: _fieldDecoration(label: 'Pairing code', hint: 'ABCD12EF-QX'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.white,
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
                          foregroundColor: const Color(0xFF34D399),
                          side: BorderSide(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
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
              const Text('Feedback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('Sound effects',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Reward chimes for Sparks, milestones, and stars',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: _soundEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: (value) async {
                  await FeedbackService.setSound(value);
                  setState(() => _soundEnabled = value);
                },
              ),
              SwitchListTile(
                title: const Text('Haptics',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Vibration feedback on rewards and key actions',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: _hapticsEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: (value) async {
                  await FeedbackService.setHaptics(value);
                  setState(() => _hapticsEnabled = value);
                  if (value) await FeedbackService.selection();
                },
              ),
              const SizedBox(height: 24),
              if (_ggufSupported) ...[
                const Text('Deeper Chat (Optional)',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Download a small AI model for richer coach replies. '
                  'Runs entirely on your device. Your scripted coach remains '
                  'the default and safety features never change.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable deeper chat',
                      style: TextStyle(color: Colors.white)),
                  value: _ggufEnabled,
                  activeThumbColor: const Color(0xFF38BDF8),
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
                              ? const Color(0xFF34D399)
                              : const Color(0xFF38BDF8),
                          size: 22,
                        ),
                        title: Text(model.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                            '${model.description}\n${model.fileSizeMb} · ${model.quantization}',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                height: 1.3)),
                        trailing: _ggufDownloading && _ggufSelectedModel == model.id
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : _ggufDownloaded.contains(model.id)
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Color(0xFFEF4444), size: 20),
                                    onPressed: () async {
                                      await GgufModelService().deleteModel(model.id);
                                      final downloaded =
                                          await GgufModelService().getDownloadedModels();
                                      if (!mounted) return;
                                      setState(() => _ggufDownloaded = downloaded);
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.download,
                                        color: Color(0xFF38BDF8), size: 20),
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
                      backgroundColor: const Color(0xFF334155),
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 24),
              const Text('Export Data', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Share your recovery data with a therapist, counselor, or healthcare provider.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
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
                        foregroundColor: const Color(0xFF38BDF8),
                        side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
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
              const Text('SOS Contacts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
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
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF38BDF8),
                ),
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Test Call Sponsor'),
              ),
              const SizedBox(height: 24),
              const Text('Meeting Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Open feeds following the Meeting Guide spec (AA intergroups, BMLT for NA). '
                'Downloaded meetings are cached and work fully offline.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (_lastMeetingRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Last refreshed: $_lastMeetingRefresh',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ),
              ..._meetingSources.map(
                (url) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.rss_feed, color: Color(0xFF38BDF8), size: 20),
                  title: Text(_shortenUrl(url),
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Remove feed',
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFEF4444), size: 20),
                    onPressed: () => _removeSource(url),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
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
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.white,
                      ),
                      icon: _refreshingMeetings
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Feed format spec (Code for Recovery) — works with AA intergroups and BMLT',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}