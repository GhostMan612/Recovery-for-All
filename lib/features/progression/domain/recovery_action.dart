// lib/features/progression/domain/recovery_action.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math';

/// Canonical action types supported by Category Platform Phase 1.
/// Matches contracts/recovery_action_v1.schema.json.
enum RecoveryActionType {
  checkIn('check_in'),
  journal('journal'),
  gratitude('gratitude'),
  grounding('grounding'),
  meetingSelfReport('meeting_self_report'),
  meetingPeerAttestation('meeting_peer_attestation'),
  walkVerified('walk_verified'),
  questCompleted('quest_completed'),
  battleCompleted('battle_completed'),
  supportIntention('support_intention');

  final String wireName;
  const RecoveryActionType(this.wireName);

  static RecoveryActionType? fromWireName(String name) {
    for (final val in RecoveryActionType.values) {
      if (val.wireName == name) return val;
    }
    return null;
  }
}

/// Provenance / origin of the action.
enum ActionOrigin {
  localUi('local_ui'),
  localImport('local_import'),
  verifiedSensor('verified_sensor'),
  peerAttestation('peer_attestation'),
  legacyAdapter('legacy_adapter');

  final String wireName;
  const ActionOrigin(this.wireName);

  static ActionOrigin? fromWireName(String name) {
    for (final val in ActionOrigin.values) {
      if (val.wireName == name) return val;
    }
    return null;
  }
}

/// Level of verification associated with the action.
enum ProofTier {
  selfReported('self_reported'),
  locallyObserved('locally_observed'),
  cryptographicallyAttested('cryptographically_attested');

  final String wireName;
  const ProofTier(this.wireName);

  static ProofTier? fromWireName(String name) {
    for (final val in ProofTier.values) {
      if (val.wireName == name) return val;
    }
    return null;
  }
}

/// Immutable metadata sanitized of PHI, PII, precise location, and sensitive text.
class RedactedActionMeta {
  final String? intentId;
  final String? sourceRefHash;

  const RedactedActionMeta({
    this.intentId,
    this.sourceRefHash,
  });

  Map<String, dynamic> toJson() => {
        if (intentId != null) 'intentId': intentId,
        if (sourceRefHash != null) 'sourceRefHash': sourceRefHash,
      };

  factory RedactedActionMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RedactedActionMeta();
    return RedactedActionMeta(
      intentId: json['intentId'] as String?,
      sourceRefHash: json['sourceRefHash'] as String?,
    );
  }
}

/// Canonical local RecoveryAction event model.
/// Immutable domain event representing user recovery activity.
class RecoveryAction {
  final int schemaVersion;
  final String eventId;
  final RecoveryActionType actionType;
  final int createdAtUtcMs;
  final ActionOrigin origin;
  final ProofTier proofTier;
  final bool synthetic;
  final RedactedActionMeta redactedMeta;

  const RecoveryAction({
    this.schemaVersion = 1,
    required this.eventId,
    required this.actionType,
    required this.createdAtUtcMs,
    this.origin = ActionOrigin.localUi,
    this.proofTier = ProofTier.selfReported,
    this.synthetic = false,
    this.redactedMeta = const RedactedActionMeta(),
  });

  /// Mint a unique, deterministic-format UUID v4 for new user actions.
  static String generateEventId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'eventId': eventId,
        'actionType': actionType.wireName,
        'createdAtUtcMs': createdAtUtcMs,
        'origin': origin.wireName,
        'proofTier': proofTier.wireName,
        'synthetic': synthetic,
        'redactedMeta': redactedMeta.toJson(),
      };

  factory RecoveryAction.fromJson(Map<String, dynamic> json) {
    final typeName = json['actionType'] as String;
    final type = RecoveryActionType.fromWireName(typeName);
    if (type == null) {
      throw ArgumentError('Unsupported actionType: $typeName');
    }
    final originName = json['origin'] as String? ?? 'local_ui';
    final origin = ActionOrigin.fromWireName(originName) ?? ActionOrigin.localUi;
    final tierName = json['proofTier'] as String? ?? 'self_reported';
    final tier = ProofTier.fromWireName(tierName) ?? ProofTier.selfReported;

    return RecoveryAction(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      eventId: json['eventId'] as String,
      actionType: type,
      createdAtUtcMs: json['createdAtUtcMs'] as int,
      origin: origin,
      proofTier: tier,
      synthetic: json['synthetic'] as bool? ?? false,
      redactedMeta: RedactedActionMeta.fromJson(
        json['redactedMeta'] as Map<String, dynamic>?,
      ),
    );
  }
}
