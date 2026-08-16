// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/recovery_database.dart';
import '../services/sos_notification_service.dart';
import '../widgets/sponsor_manager_widget.dart';
import 'grounding_screen.dart';

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
  bool _isSaving = false;
  bool _sosEnabled = true;
  bool _lockScreenPublic = true;
  Profile? _profile;
  List<SponsorContact> _sponsors = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _sponsorController.dispose();
    _customHelpController.dispose();
    _safetyPlanController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final stored = await SosNotificationService.loadContacts();
    final sponsorMaps = await SosNotificationService.loadSponsors();

    if (!mounted) return;

    setState(() {
      _profile = profile;
      final sponsor = profile?.sponsorPhone ?? stored.sponsor ?? '';
      final custom = profile?.customHelpPhone ?? stored.custom ?? '';
      _sponsorController.text = sponsor;
      _customHelpController.text = custom;
      _safetyPlanController.text = stored.safetyPlan;
      _sosEnabled = stored.enabled;
      _lockScreenPublic = stored.lockScreenPublic;
      _sponsors = sponsorMaps
          .map(
            (m) => SponsorContact(
              id: (m['id'] as String?) ?? UniqueKey().toString(),
              name: (m['name'] as String?) ?? '',
              phone: (m['phone'] as String?) ?? '',
              pathway: (m['pathway'] as String?) ?? 'Custom',
              notes: (m['notes'] as String?) ?? '',
            ),
          )
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _persistSponsors(List<SponsorContact> contacts) async {
    final jsonList = contacts
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'phone': c.phone,
              'pathway': c.pathway,
              'notes': c.notes,
            })
        .toList();
    await SosNotificationService.saveSponsorsJson(jsonEncode(jsonList));

    if (contacts.isNotEmpty) {
      _sponsorController.text = contacts.first.phone;
    }
  }

  Future<void> _dial(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse('tel:$cleaned'));
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profile == null) return;

    setState(() => _isSaving = true);

    try {
      final sponsor = _sponsorController.text.trim().isEmpty
          ? null
          : _sponsorController.text.trim();
      final custom = _customHelpController.text.trim().isEmpty
          ? null
          : _customHelpController.text.trim();
      final plan = _safetyPlanController.text.trim();

      final updated = Profile(
        id: _profile!.id,
        anonymousUsername: _profile!.anonymousUsername,
        createdAt: _profile!.createdAt,
        biometricLockEnabled: _profile!.biometricLockEnabled,
        selectedGoals: _profile!.selectedGoals,
        activePaths: _profile!.activePaths,
        selectedValues: _profile!.selectedValues,
        sponsorPhone: sponsor,
        customHelpPhone: custom,
      );

      await widget.database.saveProfile(updated);
      await _persistSponsors(_sponsors);

      await SosNotificationService.saveContacts(
        sponsorPhone: sponsor,
        customHelpPhone: custom,
        enabled: _sosEnabled,
        safetyPlan: plan,
        lockScreenPublic: _lockScreenPublic,
      );

      if (_sosEnabled) {
        await SosNotificationService.startPersistentSos(
          sponsorPhone: sponsor,
          customHelpPhone: custom,
          safetyPlan: plan,
        );
      } else {
        await SosNotificationService.stop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS settings saved'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      setState(() {
        _profile = updated;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _toggleSos(bool value) async {
    setState(() => _sosEnabled = value);
    final sponsor = _sponsorController.text.trim().isEmpty
        ? null
        : _sponsorController.text.trim();
    final custom = _customHelpController.text.trim().isEmpty
        ? null
        : _customHelpController.text.trim();

    await SosNotificationService.saveContacts(
      sponsorPhone: sponsor,
      customHelpPhone: custom,
      enabled: value,
      safetyPlan: _safetyPlanController.text.trim(),
      lockScreenPublic: _lockScreenPublic,
    );

    if (value) {
      await SosNotificationService.startPersistentSos(
        sponsorPhone: sponsor,
        customHelpPhone: custom,
        safetyPlan: _safetyPlanController.text.trim(),
      );
    } else {
      await SosNotificationService.stop();
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      await AppSettings.openAppSettings(
        type: AppSettingsType.batteryOptimization,
      );
    } catch (_) {
      await AppSettings.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'SOS & Support Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildSosToggle(),
                      const SizedBox(height: 12),
                      _buildLockScreenToggle(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Safety plan (shown on SOS notification)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _safetyPlanController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        maxLength: 280,
                        decoration: _fieldDecoration(
                          label: 'Short safety plan / reminder',
                          hint: 'e.g. Call Sam. Ice water. Walk around the block.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Primary sponsor (quick dial)'),
                      const SizedBox(height: 8),
                      _buildPhoneField(
                        controller: _sponsorController,
                        label: 'Sponsor phone number',
                        hint: 'e.g. 6125550199',
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Other help contact'),
                      const SizedBox(height: 8),
                      _buildPhoneField(
                        controller: _customHelpController,
                        label: 'Custom help number',
                        hint: 'Friend, hotline, or other support',
                      ),
                      const SizedBox(height: 24),
                      SponsorManagerWidget(
                        initialContacts: _sponsors,
                        onContactsChanged: (list) async {
                          setState(() => _sponsors = list);
                          await _persistSponsors(list);
                        },
                        onCallInitiated: (contact) => _dial(contact.phone),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Device hardening'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openBatterySettings,
                        icon: const Icon(Icons.battery_saver, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Allow unrestricted battery (OEM)',
                          style: TextStyle(color: Color(0xFF38BDF8)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'On Xiaomi / Oppo / Vivo / Samsung, also enable Autostart for this app in system settings so SOS can return after reboot.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GroundingScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.self_improvement, color: Color(0xFF34D399)),
                        label: const Text(
                          'Try 60s grounding now',
                          style: TextStyle(color: Color(0xFF34D399)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Text(
                                'Save & Update SOS Notification',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await SosNotificationService.startPersistentSos(
                            sponsorPhone: _sponsorController.text.trim().isEmpty
                                ? null
                                : _sponsorController.text.trim(),
                            customHelpPhone:
                                _customHelpController.text.trim().isEmpty
                                    ? null
                                    : _customHelpController.text.trim(),
                            safetyPlan: _safetyPlanController.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SOS notification refreshed'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Refresh Notification Now',
                          style: TextStyle(color: Color(0xFF38BDF8)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'SOS shade actions: Call 988, Text 988, Sponsor, Ground. Safety plan text appears on the notification. Contacts are mirrored to isolate-safe storage so actions work if the app was killed.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Persistent SOS notification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'One-tap help in the notification shade',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        value: _sosEnabled,
        activeColor: const Color(0xFF38BDF8),
        onChanged: _toggleSos,
      ),
    );
  }

  Widget _buildLockScreenToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Show on lock screen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Public visibility so crisis buttons are reachable without unlock',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        value: _lockScreenPublic,
        activeColor: const Color(0xFF38BDF8),
        onChanged: (v) => setState(() => _lockScreenPublic = v),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
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
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 7) return 'Enter a valid phone number';
        return null;
      },
    );
  }
}
