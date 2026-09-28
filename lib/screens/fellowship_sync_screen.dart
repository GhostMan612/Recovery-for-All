// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

class FellowshipSyncScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const FellowshipSyncScreen({super.key, required this.database});

  @override
  State<FellowshipSyncScreen> createState() => _FellowshipSyncScreenState();
}

class _FellowshipSyncScreenState extends State<FellowshipSyncScreen> {
  String _alias = 'Anonymous';
  String _payload = '';
  bool _isProcessing = false;
  DateTime _payloadTime = DateTime.now();
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _loadAlias();
    _scannerController = MobileScannerController();
  }

  Future<void> _loadAlias() async {
    try {
      final profile = await widget.database.getProfile('active_user_profile');
      final alias = profile?.anonymousUsername?.trim();
      final resolved = (alias == null || alias.isEmpty) ? 'Anonymous' : alias;
      final now = DateTime.now();
      final payload = jsonEncode({'alias': resolved, 'ts': now.millisecondsSinceEpoch});
      if (!mounted) return;
      setState(() {
        _alias = resolved;
        _payload = payload;
        _payloadTime = now;
      });
    } catch (_) {
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _payload = jsonEncode({'alias': 'Anonymous', 'ts': now.millisecondsSinceEpoch});
        _payloadTime = now;
      });
    }
  }

  void _refreshPayload() {
    final now = DateTime.now();
    setState(() {
      _payload = jsonEncode({'alias': _alias, 'ts': now.millisecondsSinceEpoch});
      _payloadTime = now;
    });
  }

  Future<void> _handleScanned(String raw) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final peerAlias = decoded['alias']?.toString().trim();
      if (peerAlias == null || peerAlias.isEmpty) {
        throw const FormatException('missing alias');
      }
      if (peerAlias == _alias) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('You cannot sync with yourself.')),
        );
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cutoff = nowMs - const Duration(hours: 24).inMilliseconds;
      final recent = await widget.database.getRecentFellowshipSyncsForPeer(peerAlias, cutoff);
      if (recent.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Already synced with $peerAlias in the last 24 hours.')),
        );
        return;
      }
      final pet = await RecoveryPetService.ensureHatched();
      final withXp = pet.copyWith(pathXp: pet.pathXp + 50);
      final updated = RecoveryPetService.evaluateLevel(withXp);
      await RecoveryPetService.save(updated);
      final sync = FellowshipSync(
        id: 'sync_${DateTime.now().microsecondsSinceEpoch}_${peerAlias.hashCode.abs()}',
        peerAlias: peerAlias,
        timestamp: nowMs,
        xpAwarded: 50,
      );
      await widget.database.addFellowshipSync(sync);
      await widget.database.addPetEvent(PetEventRow(
        id: 'pet_event_${nowMs}_${peerAlias.hashCode.abs()}',
        petId: RecoveryPetService.defaultPetId,
        eventType: 'fellowship_sync',
        sparksDelta: 0,
        timestamp: nowMs,
        metaJson: jsonEncode({'peerAlias': peerAlias, 'xp': 50}),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Text('Fellowship Buff Acquired! Connected with $peerAlias +50 XP'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Invalid fellowship code.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          title: Text('Fellowship Handshake', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_rounded), text: 'My Code'),
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Scan Peer'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyCodeTab(),
            _buildScanTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_alias, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Anonymous • offline • no PII', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh code',
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                  onPressed: _refreshPayload,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1.2)),
            child: _payload.isEmpty
                ? SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)))
                : QrImageView(
                    data: _payload,
                    version: QrVersions.auto,
                    size: 260,
                    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Theme.of(context).colorScheme.surface),
                    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Theme.of(context).colorScheme.surface),
                    backgroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Refreshed ${_payloadTime.hour.toString().padLeft(2, '0')}:${_payloadTime.minute.toString().padLeft(2, '0')} • tap refresh to rotate', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.tertiary, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Privacy-safe. Shares only your alias + timestamp. No location, no contact.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final b in barcodes) {
              final raw = b.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _handleScanned(raw);
                break;
              }
            }
          },
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.handshake_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Align peer QR inside frame. Awards +50 XP • 24h cooldown per peer.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, height: 1.3))),
                if (_isProcessing) SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),

      ],
    );
  }
}
