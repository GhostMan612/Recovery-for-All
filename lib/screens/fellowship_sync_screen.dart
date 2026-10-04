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
import '../services/fellowship_attestation_service.dart';
import '../services/xp_engine_service.dart';

/// Where this device is in the three-leg signed exchange.
///
/// The exchange is legible to the two people in the room, which is the whole
/// point: A cannot be rewarded until B has signed a nonce that only a scan of
/// A's own live code could have revealed, and B cannot be rewarded until A has
/// signed a nonce that only B could have revealed. See
/// `fellowship_attestation_service.dart` for the protocol and for what it
/// deliberately does NOT prove.
enum ExchangeStage {
  /// Nothing generated yet. The first build moves straight to [offering].
  idle,

  /// We published a challenge and are waiting for the peer's answer.
  offering,

  /// We answered a peer's challenge and are waiting for their confirmation.
  answered,

  /// Both sides verified; nothing further is needed.
  complete,
}

class FellowshipSyncScreen extends StatefulWidget {
  final RecoveryDatabase database;

  /// Called after a handshake is recorded, so the caller can refresh whatever
  /// snapshot it is showing.
  ///
  /// Exists because the dashboard's pet state is a ONE-SHOT snapshot in a plain
  /// `Notifier`, not a stream — the screen is pushed on top of an `IndexedStack`
  /// shell, so returning to it does not rebuild it. Without this callback the
  /// XP was written to the database and never appeared anywhere.
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

  /// This device's public key fingerprint, shown so two people in a room can
  /// confirm they are looking at each other's real code.
  String _myFingerprint = '????';

  String _payload = '';
  ExchangeStage _stage = ExchangeStage.idle;

  /// The nonce this device issued for the current pairing.
  String _myNonce = '';

  /// The nonce the peer issued, learned when we scanned their offer and needed
  /// again to echo it back in our answer.
  String _lastPeerNonce = '';

  String _peerAlias = '';
  String _peerFingerprint = '';

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
  /// sites — so a completed handshake left no trace the user could ever see.
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

  /// REMOVED: `_humanAge`, which formatted a code's age for the expiry
  /// snackbar. Expiry is now decided by `FellowshipAttestationService.verify`
  /// against `maxAge`, and a boolean result carries one message per reason —
  /// so a formatter for "11 minutes / 3 hours / 2 days" had no caller, and
  /// keeping it would have been a second place where expiry is described.

  Future<void> _loadAlias() async {
    String resolved = 'Anonymous';
    try {
      final profile = await widget.database.getProfile('active_user_profile');
      final alias = profile?.anonymousUsername?.trim();
      if (alias != null && alias.isNotEmpty) resolved = alias;
    } catch (_) {
      // A user who skipped the alias question still needs to be able to connect,
      // so a profile failure falls back rather than blocking the screen.
    }

    final keyB64 = await _safePublicKey();
    if (!mounted) return;
    setState(() {
      _alias = resolved;
      _myFingerprint = keyB64 == null
          ? '????'
          : FellowshipAttestationService.shortFingerprint(keyB64);
    });
    await _beginExchange();
  }

  /// The public key, or null when secure storage is unavailable.
  ///
  /// Key generation can legitimately fail on a device whose keystore is locked
  /// or corrupt. The screen still renders and explains why the code is not
  /// signed, rather than throwing out of `initState` and leaving a blank page.
  Future<String?> _safePublicKey() async {
    try {
      return await FellowshipAttestationService.publicKeyB64();
    } catch (e) {
      debugPrint('[fellowship] identity unavailable: $e');
      return null;
    }
  }

  /// Starts a fresh exchange: a new nonce and a signed [AttestationRole.offer].
  Future<void> _beginExchange() async {
    final nonce = FellowshipAttestationService.newNonce();
    final payload = await _sign(AttestationRole.offer, nonce);
    if (!mounted) return;
    setState(() {
      _myNonce = nonce;
      _lastPeerNonce = '';
      _peerAlias = '';
      _peerFingerprint = '';
      _stage = ExchangeStage.offering;
      _payload = payload;
      _payloadTime = DateTime.now();
    });
  }

  /// Signs a payload, returning an empty string if this device has no identity.
  Future<String> _sign(AttestationRole role, String nonce,
      {String echo = ''}) async {
    try {
      final signed = await FellowshipAttestationService.sign(
        role: role,
        alias: _alias,
        nonce: nonce,
        echo: echo,
      );
      return signed.encode();
    } catch (e) {
      debugPrint('[fellowship] could not sign a $role payload: $e');
      return '';
    }
  }

  /// Regenerates the current step's code without changing roles.
  ///
  /// Rotating the nonce invalidates the peer's in-flight answer, which is the
  /// point: a refresh is also a "start over".
  void _refreshPayload() {
    switch (_stage) {
      case ExchangeStage.idle:
      case ExchangeStage.complete:
        unawaited(_beginExchange());
        return;
      case ExchangeStage.offering:
      case ExchangeStage.answered:
        // Re-sign the SAME nonce: the peer may be mid-scan, and changing it
        // would invalidate a code that is already on their screen for no reason.
        unawaited(_resignCurrent());
        return;
    }
  }

  Future<void> _resignCurrent() async {
    final role = _stage == ExchangeStage.offering
        ? AttestationRole.offer
        : AttestationRole.answer;
    final payload =
        await _sign(role, _myNonce, echo: _stage == ExchangeStage.answered ? _lastPeerNonce : '');
    if (!mounted) return;
    setState(() {
      _payload = payload;
      _payloadTime = DateTime.now();
    });
  }

  /// Which role we are willing to accept next, or null when the exchange is done.
  AttestationRole? get _expectedRole => switch (_stage) {
        ExchangeStage.offering => AttestationRole.answer,
        ExchangeStage.answered => AttestationRole.confirm,
        ExchangeStage.idle || ExchangeStage.complete => null,
      };

  Future<void> _handleScanned(String raw) async {
    if (_isProcessing) return;

    // Stop the camera the moment a code is accepted. `MobileScannerController`
    // defaults to `DetectionSpeed.normal`, a CONTINUOUS stream that re-fires
    // `onDetect` on every frame the code is in view. An earlier build only ever
    // disposed the controller, so while the peer's QR stayed on screen the
    // handler re-ran continuously, the cooldown tripped, and "Already synced"
    // spam replaced the success message within a second — to a tester that reads
    // as "it did nothing".
    //
    // awaited so the frame that delivered this detection is consumed before the
    // camera halts. Safe on a null controller: the field is only null before
    // `initState` finishes assigning it.
    await _scannerController?.stop();

    setState(() => _isProcessing = true);
    try {
      final expected = _expectedRole;
      if (expected == null) {
        _toast('This pairing is already complete. Tap refresh to start a new one.');
        return;
      }
      if (_payload.isEmpty) {
        _toast('This device could not create a signing identity, so codes '
            'cannot be exchanged right now.');
        return;
      }

      // ---- VERIFY FIRST. Nothing below this line runs on an unverified code.
      //
      // The XP grant, the database row and the history all sit AFTER this
      // check, and that ordering is the security property: a payload that does
      // not carry a valid signature over BOTH nonces never reaches the reward
      // path. `tools/verify_invariants.py` invariant 13 fails the build if the
      // grant is ever hoisted above this line.
      final result = await FellowshipAttestationService.verify(
        raw,
        requiredRole: expected,
        expectedNonce: _myNonce,
      );

      if (!result.verified) {
        _toast(result.message);
        unawaited(_scannerController?.start());
        return;
      }

      final peer = result.payload!;
      final safeAlias = FellowshipAttestationService.sanitizeAlias(peer.alias);
      if (safeAlias.isEmpty || safeAlias == _alias) {
        _toast('That code has no usable name, or it is your own.');
        unawaited(_scannerController?.start());
        return;
      }

      _lastPeerNonce = peer.nonce;

      if (expected == AttestationRole.answer) {
        // We are the INVITER. The peer signed a nonce that only a scan of our
        // own live offer could have revealed, so their presence is proven. We
        // now hand back a confirmation so THEY can prove the same about us.
        await _completeHandshake(peerAlias: safeAlias, peerKey: peer.publicKeyB64, role: 'inviter');

        final confirm = await _sign(
          AttestationRole.confirm,
          _myNonce,
          echo: peer.nonce,
        );
        if (!mounted) return;
        setState(() {
          _peerAlias = safeAlias;
          _peerFingerprint =
              FellowshipAttestationService.shortFingerprint(peer.publicKeyB64);
          _payload = confirm;
          _payloadTime = DateTime.now();
          _stage = ExchangeStage.complete;
        });
        return;
      }

      // We are the INVITEE and the peer confirmed our answer: both nonces are
      // now signed by both keys, so our own presence is proven too.
      await _completeHandshake(peerAlias: safeAlias, peerKey: peer.publicKeyB64, role: 'invitee');
      if (!mounted) return;
      setState(() {
        _peerAlias = safeAlias;
        _peerFingerprint =
            FellowshipAttestationService.shortFingerprint(peer.publicKeyB64);
        _stage = ExchangeStage.complete;
        _payload = '';
      });
    } catch (e) {
      if (!mounted) return;
      // Distinguish a malformed code from an internal failure. One catch-all
      // turned a database write error into "Invalid fellowship code", which
      // sends the user (and the next bug report) looking at the wrong thing.
      final malformed = e is FormatException;
      _toast(malformed ? 'That is not a fellowship code.' : 'Could not save the handshake: $e');
      unawaited(_scannerController?.start());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Records the handshake and grants the reward — the ONLY reward path.
  ///
  /// Reached only from [FellowshipAttestationService.verify] returning
  /// `verified == true`, so by construction the peer has signed both nonces.
  Future<void> _completeHandshake({
    required String peerAlias,
    required String peerKey,
    required String role,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Cooldown, checked on the peer's PUBLIC KEY first.
    //
    // The old check keyed on the alias, which the peer chooses: "BrightOak"
    // became "BrightOak2" and the 24-hour limit did not apply at all. The key
    // cannot be renamed. The alias lookup is still applied as well, so a
    // handshake recorded by an older build (no key on file) still blocks a
    // second one today.
    final cutoff = nowMs - const Duration(hours: 24).inMilliseconds;
    final byKey = await widget.database
        .getRecentFellowshipSyncsForPeerKey(peerKey, cutoff);
    if (byKey.isNotEmpty) {
      _toast('Already connected with ${byKey.first.peerAlias} in the last '
          '24 hours.');
      return;
    }
    final byAlias =
        await widget.database.getRecentFellowshipSyncsForPeer(peerAlias, cutoff);
    if (byAlias.isNotEmpty) {
      _toast('Already connected with $peerAlias in the last 24 hours.');
      return;
    }

    // The XP grant goes through XpEngineService, not a raw `save()`. The
    // handshake used to do two untransacted writes from a snapshot read outside
    // them, so a process death mid-handshake granted XP with no audit event, a
    // concurrent reward overwrote the other outright, and — because it never
    // touched RaidService — fellowship work was the one action that never
    // struck the boss.
    final xp = XpEngineService.xpFor('fellowship_sync') ?? 50;
    final grant = await XpEngineService.grantXp(
      widget.database,
      xp,
      actionType: 'fellowship_sync',
      metaJson: jsonEncode({
        'peerAlias': peerAlias,
        'xp': xp,
        'attested': true,
        'role': role,
      }),
    );

    await widget.database.addFellowshipSync(FellowshipSync(
      // Keyed on the timestamp ALONE. An earlier id mixed in
      // `peerAlias.hashCode()`, which is not a secret, and `addFellowshipSync`
      // is `insertOnConflictUpdate` — so a colliding id silently overwrote an
      // earlier, unrelated sync row.
      id: 'sync_${DateTime.now().microsecondsSinceEpoch}',
      peerAlias: peerAlias,
      timestamp: nowMs,
      xpAwarded: xp,
      peerKeyB64: peerKey,
      attested: 1,
      role: role,
    ));

    if (!mounted) return;
    // The dashboard reads pet state from a one-shot snapshot held by a plain
    // `Notifier`, and the nav shell is an `IndexedStack`, so returning here
    // does not rebuild it and the XP bar kept showing the pre-handshake value
    // until a process restart.
    widget.onSynced?.call();

    // Re-read from the database rather than trusting local state: the grant is
    // transactional, so what the history shows is exactly what was stored.
    await _loadHistory();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(
          grant.leveled == true
              ? 'Fellowship Buff! $peerAlias · +$xp XP · verified handshake · LEVEL UP to Lv ${grant.level}'
              : 'Fellowship Buff! Connected with $peerAlias · +$xp XP · verified',
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  /// One line telling each person what to do next.
  String get _instruction => switch (_stage) {
        ExchangeStage.idle => 'Setting up a secure code…',
        ExchangeStage.offering =>
          'Step 1 of 3 — have your peer scan this, then scan their reply.',
        ExchangeStage.answered =>
          'Step 2 of 3 — now scan the confirmation on their screen.',
        ExchangeStage.complete =>
          'Done — both sides verified. Nothing more to scan.',
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          title: Text('Fellowship Handshake',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600)),
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
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_alias,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('You · $_myFingerprint',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12)),
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
          const SizedBox(height: 12),
          Text(
            _instruction,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.3),
          ),
          if (_peerAlias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Peer: $_peerAlias · $_peerFingerprint',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.2)),
            child: _payload.isEmpty
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _stage == ExchangeStage.idle
                        ? CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary)
                        : Text(
                            'This device could not create a signing identity, '
                            'so it cannot issue a verifiable code. Handshakes '
                            'require one, so nothing can be awarded until it '
                            'works — no unverified fallback is offered, because '
                            'that would silently drop the guarantee.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                                height: 1.4),
                          ),
                  )
                // A QR code is opaque to a screen reader. Expose the pairing as
                // text a person can read out, but NOT the raw payload: it is now
                // a signature blob, and announcing several hundred base64
                // characters is useless to a listener. Alias plus the key
                // fingerprint is the part two people need to compare.
                : Semantics(
                    label: _payload.isEmpty
                        ? 'No code to show.'
                        : 'Your pairing code. You are $_alias, key $_myFingerprint'
                            '${_peerAlias.isEmpty ? '' : ', peer $_peerAlias'}.',
                    child: QrImageView(
                      data: _payload,
                      version: QrVersions.auto,
                      size: 240,
                      eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Theme.of(context).colorScheme.surface),
                      dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Theme.of(context).colorScheme.surface),
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Refreshed ${_payloadTime.hour.toString().padLeft(2, '0')}:'
              '${_payloadTime.minute.toString().padLeft(2, '0')} · tap refresh to rotate',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Expires ${FellowshipAttestationService.maxAge.inMinutes} minutes after it is generated',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
          _buildHistory(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    color: Theme.of(context).colorScheme.tertiary, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                  'Privacy-safe. Shares only your alias, a one-time code, and a '
                  'public key. No location, no contact.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The record of who you have connected with.
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
            Icon(Icons.groups_outlined,
                color: Theme.of(context).colorScheme.outline, size: 18),
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
              Icon(Icons.handshake_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 18),
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
                  Icon(
                      sync.attested == 1
                          ? Icons.verified_outlined
                          : Icons.check_circle_outline,
                      size: 14,
                      color: sync.attested == 1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline),
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
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    final expected = _expectedRole;
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
            decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.handshake_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expected == null
                        ? 'This pairing is complete. Switch to My Code and tap refresh to begin another.'
                        : 'Scanning for a ${expected.wire} code. '
                            'Awards +50 XP once both signatures check out · '
                            '24h cooldown per peer key.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.3),
                  ),
                ),
                if (_isProcessing)
                  SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}