// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// SCREEN-WIRING cover for the fellowship handshake.
//
// A tester filed "the QR code fellowship handshake doesn't do anything, even
// after doing the handshake". Four defects stacked behind that one symptom, and
// NONE of them was about the QR code:
//
//   1. The +50 XP was written straight to Drift through a raw `save()`, while
//      the dashboard reads pet state from a ONE-SHOT snapshot in a plain
//      `Notifier` with no stream subscription, and the nav shell is an
//      `IndexedStack` that never rebuilds. The reward was real, persisted, and
//      invisible until a process restart.
//   2. `MobileScannerController` defaults to `DetectionSpeed.normal`, which
//      re-fires `onDetect` every frame. The screen never stopped the scanner, so
//      the success message was overwritten by "Already synced..." within a
//      second — the user saw the failure, never the success.
//   3. The result was recorded and then discarded: `getAllFellowshipSyncs()` had
//      zero call sites, so a completed handshake left no visible trace.
//   4. The exchange was one-directional, and the 24-hour cooldown was keyed on
//      the peer-chosen ALIAS, so renaming defeated the limit and the XP was
//      farmable.
//
// This file covers defects 1-4 AS WIRED IN THE SCREEN. The protocol itself —
// the three signed legs, nonce echo, replay refusal, tamper detection — is
// covered behaviourally in `fellowship_attestation_test.dart`, which drives the
// real service with two independent device identities.
//
// WHY SOURCE INSPECTION FOR THIS LAYER. Every one of these is a statement
// ORDER or a statement IDENTITY inside one method, and none of them is
// observable from outside the widget: an XP grant that happens before the
// signature check still produces exactly the right database rows when every
// input is valid, and a camera that is never stopped still shows the correct
// message the moment the QR leaves frame. Reading the source is the only way to
// see them, and `tools/verify_invariants.py` invariant 13 enforces the most
// important one at the build level too.
//
// Comments are stripped before every scan. Two of these files DESCRIBE the
// removal of the very identifiers being searched for, and a scan that reads its
// own documentation fails on the first run — lessons-learned L32.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _screenPath = 'lib/screens/fellowship_sync_screen.dart';

/// Source with comments removed, so documentation cannot satisfy or trip a
/// scan.
String codeOf(String path) {
  var src = File(path).readAsStringSync();
  src = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  src = src.replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');
  return src;
}

void main() {
  late String src;

  setUpAll(() => src = codeOf(_screenPath));

  /// Body of `_handleScanned`, by brace balance.
  ///
  /// Deliberately not a regex over the whole file: `_completeHandshake` is a
  /// separate method, and the interesting question is whether the VERIFY happens
  /// before the things that follow it inside the scanner path.
  String handlerBody() {
    final start = src.indexOf('Future<void> _handleScanned');
    expect(start, greaterThan(-1),
        reason: '_handleScanned disappeared from $_screenPath');
    var depth = 0;
    var i = src.indexOf('{', start);
    final openAt = i;
    for (; i < src.length; i++) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) return src.substring(openAt, i + 1);
      }
    }
    fail('unbalanced braces in _handleScanned');
  }

  group('defect 4 — the reward is downstream of the verification', () {
    test('the signature check runs before the XP grant', () {
      final body = handlerBody();
      final verifyAt = body.indexOf('FellowshipAttestationService.verify');
      final completeAt = body.indexOf('_completeHandshake');
      expect(verifyAt, greaterThan(-1),
          reason: '_handleScanned no longer verifies anything, so a code with '
              'no signature would be rewarded');
      expect(completeAt, greaterThan(-1));
      expect(verifyAt, lessThan(completeAt),
          reason: 'a handshake is recorded and paid BEFORE its signature is '
              'checked — this is the bug invariant 13 exists to prevent');
    });

    test('the code refuses to continue on an unverified payload', () {
      // `verified == false` must terminate the path, not merely be logged. A
      // version that only recorded the failure would still fall through and
      // award the XP.
      final body = handlerBody();
      expect(body, contains('if (!result.verified)'));
      final guardAt = body.indexOf('if (!result.verified)');
      final returnAt = body.indexOf('return;', guardAt);
      expect(returnAt, greaterThan(guardAt));
      expect(returnAt, lessThan(body.indexOf('_completeHandshake')),
          reason: 'the early return must precede the reward path');
    });

    test('the cooldown is keyed on the peer KEY, not the alias', () {
      // The alias is peer-supplied text. Keying the 24-hour limit on it meant
      // "BrightOak" -> "BrightOak2" reset the limit, so the XP was farmable.
      final body = codeOf('lib/screens/fellowship_sync_screen.dart');
      expect(body, contains('getRecentFellowshipSyncsForPeerKey'),
          reason: 'the cooldown must be keyed on something the peer cannot '
              'rename');
      // The alias lookup is retained deliberately, for legacy rows with no key.
      expect(body, contains('getRecentFellowshipSyncsForPeer'));
    });

    test('the recorded row carries the attestation evidence', () {
      final body = codeOf('lib/screens/fellowship_sync_screen.dart');
      expect(body, contains('peerKeyB64:'));
      expect(body, contains('attested: 1'));
      expect(body, contains("role: role"));
    });

    test('the audit event records that the pairing was attested', () {
      final body = codeOf('lib/screens/fellowship_sync_screen.dart');
      expect(body, contains("'attested': true"));
    });
  });

  group('defect 2 — the scanner is stopped once', () {
    test('the controller is stopped before the payload is processed', () {
      // A continuous detection stream re-fires every frame the code is in
      // view, which is what turned the success message into "Already synced"
      // spam within a second.
      expect(src, contains('await _scannerController?.stop()'));
      final stopAt = src.indexOf('await _scannerController?.stop()');
      final setProcessingAt = src.indexOf('setState(() => _isProcessing = true)');
      expect(stopAt, lessThan(setProcessingAt));
    });

    test('a rejected code puts the camera back so the user can retry', () {
      // Without this, one bad QR in frame ends the session and the user has to
      // leave and re-enter the tab.
      expect(src, contains('unawaited(_scannerController?.start())'));
    });
  });

  group('defect 3 — the outcome is visible', () {
    test('the history is read back and rendered', () {
      expect(src, contains('getAllFellowshipSyncs'));
      expect(src, contains('_buildHistory()'));
      // It used to be read once and sorted; if the sort were dropped the list
      // would render oldest-first and read as broken.
      expect(src, contains('b.timestamp.compareTo(a.timestamp)'));
    });

    test('the dashboard is told to refresh its pet snapshot', () {
      // The reward was real, in the database, and invisible until a process
      // restart, because the nav shell is an IndexedStack that never rebuilds.
      expect(src, contains('widget.onSynced?.call()'));
    });

    test('the history is bounded', () {
      expect(src, contains('_history.take(8)'));
    });
  });

  group('accessibility and privacy of the code surface', () {
    test('the QR is not announced as a signature blob', () {
      // A QR code is opaque to a screen reader, so the payload was exposed as
      // text — which is right — but the payload is now several hundred
      // base64 characters of signature. Announcing that is useless noise.
      expect(src, contains('Semantics('));
      final from = src.indexOf('label: _payload.isEmpty');
      expect(from, greaterThan(-1));
      final block = src.substring(from, src.indexOf('QrImageView'));
      // Only the STRING LITERALS matter. `_payload.isEmpty` in the condition is
      // the right test to write; what must not happen is `_payload` appearing
      // INSIDE an announced string. Checking the whole slice for `_payload`
      // failed on the condition itself, which is why this compares literals.
      final literals = RegExp(r"'([^'\n]*)'").allMatches(block).map((m) => m.group(1)!);
      for (final lit in literals) {
        expect(lit, isNot(contains(r'$_payload')),
            reason: 'announced string interpolates the raw payload: $lit');
      }
      expect(block, contains('_myFingerprint'));
    });

    test('the grid cells are still buttons to a screen reader', () {
      final dresser = codeOf('lib/screens/avatar_dresser_screen.dart');
      expect(dresser, contains('Semantics('));
      expect(dresser, contains('button: true'));
    });
  });

  group('the stage machine is total', () {
    test('every ExchangeStage has a scan instruction and an expected role', () {
      // A switch expression over an enum is exhaustive or it will not compile,
      // so this asserts the INTENT: the scanner must be idle once the exchange
      // is complete, and must expect exactly one role per open stage.
      expect(src, contains('ExchangeStage.offering => AttestationRole.answer'));
      expect(src, contains('ExchangeStage.answered => AttestationRole.confirm'));
      expect(src, contains('ExchangeStage.idle || ExchangeStage.complete => null'));
    });

    test('the three legs are named in the payload', () {
      expect(src, contains('AttestationRole.offer'));
      expect(src, contains('AttestationRole.answer'));
      expect(src, contains('AttestationRole.confirm'));
    });
  });
}