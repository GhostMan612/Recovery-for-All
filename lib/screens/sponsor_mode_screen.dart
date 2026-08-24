// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../services/sponsor_link_service.dart';

/// Sponsor Mode — for mentors who use the app and sign off their sponsees'
/// step work. Shows this device's pairing code and signs incoming bundles.
class SponsorModeScreen extends StatefulWidget {
  const SponsorModeScreen({super.key});

  @override
  State<SponsorModeScreen> createState() => _SponsorModeScreenState();
}

class _SponsorModeScreenState extends State<SponsorModeScreen> {
  SponsorIdentity? _identity;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final identity = await SponsorLinkService.ensureIdentity();
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _loaded = true;
    });
  }

  Future<void> _reviewBundle() async {
    final controller = TextEditingController();
    final bundle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title:
            const Text('Review step work', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the bundle your sponsee shared (it arrives as a '
              'RC-BUNDLE block).',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Review', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (bundle == null || bundle.isEmpty) return;

    // Extract the JSON payload from the RC-BUNDLE wrapper if present.
    final jsonStart = bundle.indexOf('{');
    final jsonEnd = bundle.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd <= jsonStart) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bundle found in that text.')),
      );
      return;
    }
    final payload = bundle.substring(jsonStart, jsonEnd + 1);

    String stepTitle = 'this step';
    var stepNumber = 0;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      stepNumber = json['step'] as int? ?? 0;
      stepTitle = json['title'] as String? ?? 'this step';
    } catch (_) {}

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sign & confirm', style: TextStyle(color: Colors.white)),
        content: Text(
          'Sign off Step $stepNumber — "$stepTitle"?\n\n'
          'This produces a signed confirmation your sponsee pastes back '
          'into their app.',
          style: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final code = await SponsorLinkService.signBundle(payload);
      await Clipboard.setData(ClipboardData(
          text: 'RC-SIGNOFF\n$code\nRC-END\n'
              '(paste this into Recovery Companion → Twelve Steps → Redeem sign-off)'));
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
              'Signed confirmation copied — send it back to your sponsee.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signing failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Sponsor Mode',
            style: TextStyle(color: Colors.white)),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Pairing Code',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(
                        identity?.pairingCode ?? '———',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sponsees enter this code under '
                        'Settings → My Sponsor. Then they share step-work '
                        'bundles with you here for signing.',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: identity?.pairingCode ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Pairing code copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_all_outlined, size: 16),
                        label: const Text('Copy code', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review a step-work bundle',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _reviewBundle,
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'How it works: your sponsee finishes a step worksheet, '
                    'copies the bundle, and sends it to you (any messenger). '
                    'You paste it here, sign it, and send the signed code '
                    'back. Their app verifies it against your pairing code '
                    'and marks the step sponsor-confirmed. Everything runs '
                    'on-device — no server, no accounts.',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }
}
