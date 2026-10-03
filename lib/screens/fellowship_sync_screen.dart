// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../database/recovery_database.dart';
import '../services/xp_engine_service.dart';

class FellowshipSyncScreen extends StatefulWidget {
  final RecoveryDatabase database;

  /// Called after a handshake is recorded, so the caller can refresh whatever
  /// snapshot it is showing.
  ///
  /// Exists because the dashboard's pet state is a ONE-SHOT snapshot in a plain
  /// `Notifier`, not a stream — the screen is pushed on top of an `IndexedStack`
  /// shell, so returning to it does not rebuild it. Without this callback the
  /// +50 XP was written to the database and never appeared anywhere, which is
  /// exactly what a tester reported as "it doesn't do anything".
  final VoidCallback? onSynced;

  const FellowshipSyncScreen({
    super.key,
    required this.database,
    this.onSynced,
  });

  @override
  State<FellowshipSyncScreen> createState() => _FellowshipSyncScreenState();
}

class _FellowshipSyncScreenState extends State<FellowshipSyncScreen> {
  String _alias = 'Anonymous';
  String _payload = '';
  bool _isProcessing = false;
  DateTime _payloadTime = DateTime.now();
  MobileScannerController? _scannerController;
  int _syncCount = 0;
  List<FellowshipSync> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadAlias();
    _loadHistory();
    _scannerController = MobileScannerController();
  }

  /// Handshakes recorded on this device.
  ///
  /// Backs the visible outcome of the feature. `getAllFellowshipSyncs()` was
  /// dead code — the one method that could have shown a peer list had no call
  /// sites — so a completed handshake left no trace the user could ever see
  /// again, which is the other half of "it doesn't do anything".
  Future<void> _loadHistory() async {
    try {
      final rows = await widget.database.getAllFellowshipSyncs();
      if (!mounted) return;
      // Newest first — this is a history, not a set.
      rows.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _history = rows;
        _syncCount = rows.length;
      });
    } catch (e) {
      debugPrint('[fellowship] history load failed: $e');
    }
  }

  /// Human-readable age for the code-expiry message.
  static String _humanAge(int ms) {
    if (ms < const Duration(minutes: 1).inMilliseconds) return 'under a minute';
    if (ms < const Duration(hours: 1).inMilliseconds) {
      return '${ms ~/ const Duration(minutes: 1).inMilliseconds} minutes';
    }
    if (ms < const Duration(days: 1).inMilliseconds) {
      return '${ms ~/ const Duration(hours: 1).inMilliseconds} hours';
    }
    return '${ms ~/ const Duration(days: 1).inMilliseconds} days';
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

    // Stop the camera the moment a code is accepted. `MobileScannerController`
    // defaults to `DetectionSpeed.normal`, which is a CONTINUOUS stream — it
    // re-fires `onDetect` on every frame the code is in view. The screen only
    // ever disposed the controller, so while the peer's QR stayed on screen the
    // handler re-ran continuously, the 24h cooldown then tripped, and the user
    // watched "Already synced with X in the last 24 hours." spam replace the
    // success message they had just been shown. To a tester that reads as
    // "it did nothing" — the success was on screen for well under a second.
    // await on the stop so the frame that delivered this detection has already
    // been consumed before the camera halts. Safe on a null controller: the
    // field is only null before `initState` finishes assigning it.
    await _scannerController?.stop();

    setState(() => _isProcessing = true);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('not an object');
      }
      final peerAlias = decoded['alias']?.toString().trim();
      if (peerAlias == null || peerAlias.isEmpty) {
        throw const FormatException('missing alias');
      }
      // The peer chooses this string. Unbounded it is written to the database,
      // into `metaJson`, and interpolated into a SnackBar — so cap the length
      // and strip control characters before it is stored or displayed.
      if (peerAlias.length > 40) {
        throw const FormatException('alias too long');
      }
      final safeAlias = peerAlias.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
      if (safeAlias.isEmpty) {
        throw const FormatException('alias has no visible characters');
      }

      // `ts` was written into the payload from the start and read by nothing,
      // so a screenshot of "My Code" from a year ago still completed a
      // handshake. The card even said "tap refresh to rotate", which implied an
      // expiry that did not exist. Ten minutes is long enough to hand a phone
      // across a table and short enough that a photographed code is dead.
      final ts = (decoded['ts'] as num?)?.toInt();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (ts == null) {
        throw const FormatException('missing ts');
      }
      final ageMs = nowMs - ts;
      if (ageMs.abs() > const Duration(minutes: 10).inMilliseconds) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: Text(
              ageMs > 0
                  ? 'That code is ${_humanAge(ageMs)} old — ask them to refresh it.'
                  : 'That code is from the future. Check your device clock.',
            ),
          ),
        );
        return;
      }

      if (safeAlias == _alias) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('You cannot sync with yourself.')),
        );
        return;
      }
      final cutoff = nowMs - const Duration(hours: 24).inMilliseconds;
      final recent = await widget.database.getRecentFellowshipSyncsForPeer(safeAlias, cutoff);
      if (recent.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Already synced with $safeAlias in the last 24 hours.')),
        );
        return;
      }

      // The XP grant goes through XpEngineService, not a raw `save()`. The
      // handshake was doing two untransacted writes from a snapshot read outside
      // them, so a process death mid-handshake granted XP with no audit event,
      // a concurrent reward overwrote the other outright, and — because it
      // never touched RaidService — fellowship work was the one action that
      // never struck the boss.
      final grant = await XpEngineService.grantXp(
        widget.database,
        XpEngineService.xpFor('fellowship_sync') ?? 50,
        actionType: 'fellowship_sync',
        metaJson: jsonEncode({'peerAlias': safeAlias, 'xp': 50}),
      );

      await widget.database.addFellowshipSync(FellowshipSync(
        // Keyed on the timestamp ALONE. The old id mixed in
        // `peerAlias.hashCode()`, which is not a secret, and `addFellowshipSync`
        // is `insertOnConflictUpdate` — so a colliding id silently overwrote an
        // earlier, unrelated sync row.
        id: 'sync_${DateTime.now().microsecondsSinceEpoch}',
        peerAlias: safeAlias,
        timestamp: nowMs,
        xpAwarded: 50,
      ));

      if (!mounted) return;
      if (!mounted) return;
      // The dashboard reads pet state from a one-shot snapshot held by a plain
      // `Notifier`, and the nav shell is an `IndexedStack`, so returning here
      // does not rebuild it and the XP bar kept showing the pre-handshake value
      // until a process restart. That is the direct cause of "it doesn't do
      // anything, even after doing the handshake" — the reward was real, in the
      // database, and invisible.
      widget.onSynced?.call();

      // Re-read from the database rather than trusting local state: the grant is
      // transactional, so what the history shows is exactly what was stored.
      await _loadHistory();
      if (!mounted) return;

      // Report the REAL level. An earlier draft of this message shipped the
      // literal text "LEVEL UP to Lv ..." — an ellipsis where a number belongs,
      // which is worse than saying nothing because it looks like a rendering
      // bug rather than an unfinished feature.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Text(
            grant.leveled == true
                ? 'Fellowship Buff! $safeAlias · +50 XP · LEVEL UP to Lv ${grant.level}'
                : 'Fellowship Buff! Connected with $safeAlias · +50 XP',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Distinguish a malformed code from an internal failure. One catch-all
      // turned a database write error into "Invalid fellowship code", which
      // sends the user (and the next bug report) looking at the wrong thing.
      final malformed = e is FormatException;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Text(
            malformed
                ? 'That is not a fellowship code.'
                : 'Could not save the handshake: $e',
          ),
        ),
      );
      // Put the camera back so the user can retry without leaving the tab.
      unawaited(_scannerController?.start());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
                // A QR code is opaque to a screen reader. Expose the pairing
                // payload as text, otherwise a blind user cannot read their
                // own code to their sponsor.
                : Semantics(
                    label: 'Your pairing code. '
                        'Sponsor code ${_payload.replaceAll('|', ' ')}',
                    child: QrImageView(
                      data: _payload,
                      version: QrVersions.auto,
                      size: 260,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Theme.of(context).colorScheme.surface),
                      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Theme.of(context).colorScheme.surface),
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Refreshed ${_payloadTime.hour.toString().padLeft(2, '0')}:${_payloadTime.minute.toString().padLeft(2, '0')}'
              ' • tap refresh to rotate',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              // Now truthful. Before this, the code carried no expiry at all, so
              // "rotate" implied a security property the implementation did not
              // have and a photographed code stayed valid indefinitely.
              'Expires 10 minutes after it is generated',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
          _buildHistory(),
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

  /// The record of who you have connected with.
  ///
  /// The feature's missing observable outcome. `getAllFellowshipSyncs()` existed
  /// from the day the table was created and had **zero call sites**, and the
  /// pet event it wrote rendered in the memory wall as the generic "Kin
  /// remembers a moment of care." — so after a handshake the peer's alias, the
  /// XP, and the fact that it happened were all written and then thrown away.
  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_outlined, color: Theme.of(context).colorScheme.outline, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No handshakes yet. Scan a peer in the same room to be '
                'connected with them — it stays on this device.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final totalXp = _history.fold<int>(0, (sum, s) => sum + s.xpAwarded);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '$_syncCount handshake${_syncCount == 1 ? '' : 's'} · +$totalXp XP',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bounded so a long history cannot grow the page without limit —
          // `fellowship_syncs` is never pruned, and an unbounded list in a
          // single-child scroll view is a perf cliff.
          for (final sync in _history.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sync.peerAlias,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '+${sync.xpAwarded} XP',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          if (_history.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${_history.length - 8} older',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline, fontSize: 11),
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
                Expanded(child: Text('Align a peer QR in frame to be connected. Awards +50 XP • 24h cooldown per peer.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, height: 1.3))),
                if (_isProcessing) SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),

      ],
    );
  }
}
