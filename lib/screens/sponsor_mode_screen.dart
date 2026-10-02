// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title:
            Text('Review step work', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste the bundle your sponsee shared (it arrives as a '
              'RC-BUNDLE block).',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('Review', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Sign & confirm', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Sign off Step $stepNumber — "$stepTitle"?\n\n'
          'This produces a signed confirmation your sponsee pastes back '
          'into their app.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Sign it', style: TextStyle(color: Theme.of(context).colorScheme.onTertiary)),
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
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.tertiary,
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

  Stream<List<Map<String, dynamic>>> _pendingBundles() {
    final code = _identity?.pairingCode ?? '';
    if (code.isEmpty) return const Stream.empty();
    return SponsorLinkService.watchPendingBundles(code);
  }

  Future<void> _signBundle(String docId, String bundleJson) async {
    if (bundleJson.isEmpty) return;
    final ok = await SponsorLinkService.signBundleViaCloud(
        bundleDocId: docId, bundleJson: bundleJson);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            ok ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
        content: Text(ok
            ? 'Signed and sent back to sponsee.'
            : 'Signing failed — try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('Sponsor Mode',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: !_loaded
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Pairing Code',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(
                        identity?.pairingCode ?? '———',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sponsees enter this code under '
                        'Settings → My Sponsor. Then they share step-work '
                        'bundles with you here for signing.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      // onTertiary, not Colors.white. M3 tertiary is a LIGHT
                      // tone in light mode, so a hardcoded white label is
                      // effectively invisible there.
                      //
                      // This call site is why invariant 9 used to be stated as
                      // "paired on one physical line": the two properties are on
                      // adjacent lines here, so the old regex missed it. The
                      // gate now scans whole call expressions instead.
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review a step-work bundle',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _reviewBundle,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Pending Sign-Offs (Live)',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _pendingBundles(),
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return Text('No pending bundles.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12));
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${item['sponseeAlias'] ?? 'Sponsee'} · Step ${item['step']}',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                    child: const Text('Sign & Send',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    onPressed: () => _signBundle(
                                        item['id'] as String,
                                        item['bundle'] as String? ?? ''),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'How it works: your sponsee finishes a step worksheet, '
                    'copies the bundle, and sends it to you (any messenger). '
                    'You paste it here, sign it, and send the signed code '
                    'back. Their app verifies it against your pairing code '
                    'and marks the step sponsor-confirmed. Everything runs '
                    'on-device — no server, no accounts.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }
}
