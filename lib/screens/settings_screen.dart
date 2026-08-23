// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
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
  final _safetyPlanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;

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
    await widget.database.getProfile('active_user_profile');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
            ],
          ),
        ),
      ),
    );
  }
}