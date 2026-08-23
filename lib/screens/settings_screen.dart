// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/meeting_finder_service.dart';
import '../services/sos_notification_service.dart';

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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await widget.database.getProfile('active_user_profile');
    final moderator = await CommunityFeedService.isModerator();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isModerator = moderator;
      });
    }
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
      return (39.7392, -104.9903); // neutral fallback center
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