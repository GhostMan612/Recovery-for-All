// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/recovery_database.dart';
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
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _sosEnabled = true;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _sponsorController.dispose();
    _customHelpController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final stored = await SosNotificationService.loadContacts();

    if (!mounted) return;

    setState(() {
      _profile = profile;
      // Prefer DB values; fall back to isolate-safe prefs
      final sponsor = profile?.sponsorPhone ?? stored.sponsor ?? '';
      final custom = profile?.customHelpPhone ?? stored.custom ?? '';
      _sponsorController.text = sponsor;
      _customHelpController.text = custom;
      _sosEnabled = stored.enabled;
      _isLoading = false;
    });
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

      // Isolate-safe mirror for background actions / boot restore
      await SosNotificationService.saveContacts(
        sponsorPhone: sponsor,
        customHelpPhone: custom,
        enabled: _sosEnabled,
      );

      if (_sosEnabled) {
        await SosNotificationService.startPersistentSos(
          sponsorPhone: sponsor,
          customHelpPhone: custom,
        );
      } else {
        await SosNotificationService.stop();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS contacts saved'),
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
    );

    if (value) {
      await SosNotificationService.startPersistentSos(
        sponsorPhone: sponsor,
        customHelpPhone: custom,
      );
    } else {
      await SosNotificationService.stop();
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
                      const SizedBox(height: 24),
                      _buildSectionTitle('Primary Sponsor'),
                      const SizedBox(height: 8),
                      _buildPhoneField(
                        controller: _sponsorController,
                        label: 'Sponsor phone number',
                        hint: 'e.g. 6125550199',
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Other Help Contact'),
                      const SizedBox(height: 8),
                      _buildPhoneField(
                        controller: _customHelpController,
                        label: 'Custom help number',
                        hint: 'Friend, hotline, or other support',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '988 Crisis Lifeline is always available from the SOS notification.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
              'These numbers power the persistent SOS notification. Contacts are stored both in your encrypted profile and in isolate-safe local prefs so Call/Text still work if the app process was killed.',
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Keep one-tap help in the notification shade (survives reboot when app next opens)',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        value: _sosEnabled,
        activeColor: const Color(0xFF38BDF8),
        onChanged: _toggleSos,
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
      decoration: InputDecoration(
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
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 7) {
          return 'Enter a valid phone number';
        }
        return null;
      },
    );
  }
}
