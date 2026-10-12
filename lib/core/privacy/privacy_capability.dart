// lib/core/privacy/privacy_capability.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Distinct network capabilities governed by independent user consent.
enum PrivacyCapability {
  remoteWeather,
  cloudSync,
  circleShare,
  directoryRefresh,
  onlineTiles,
  externalNavigation;

  PrivacyDisclosure get disclosure => PrivacyCapabilityState.disclosures[this]!;
}

/// Explicit tri-state consent states.
/// Invariant: Only [granted] authorizes optional outbound network activity.
enum ConsentState {
  unknown,
  granted,
  denied;

  bool get isGranted => this == ConsentState.granted;
  bool get isDenied => this == ConsentState.denied;
  bool get isUnknown => this == ConsentState.unknown;
}

/// Structured disclosure explaining data transmission for a capability.
class PrivacyDisclosure {
  final String title;
  final String description;
  final String transmittedData;
  final String recipient;
  final String fallback;

  const PrivacyDisclosure({
    required this.title,
    required this.description,
    required this.transmittedData,
    required this.recipient,
    required this.fallback,
  });
}

/// Immutable snapshot of privacy capability authorization state.
@immutable
class PrivacyCapabilityState {
  final Map<PrivacyCapability, ConsentState> consents;

  const PrivacyCapabilityState([
    this.consents = const <PrivacyCapability, ConsentState>{},
  ]);

  /// Default baseline fails closed: all capabilities unknown.
  factory PrivacyCapabilityState.defaults() {
    return const PrivacyCapabilityState();
  }

  /// Retrieves the recorded consent state for [capability].
  /// Defaults to [ConsentState.unknown] if never set.
  ConsentState getConsent(PrivacyCapability capability) {
    return consents[capability] ?? ConsentState.unknown;
  }

  /// Checks if network operations for [capability] are authorized.
  /// Strictly fails closed: returns true ONLY if state is explicitly [ConsentState.granted].
  bool isGranted(PrivacyCapability capability) {
    return getConsent(capability) == ConsentState.granted;
  }

  /// Returns a copy of this state with [capability] set to [state].
  PrivacyCapabilityState withConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) {
    final next = Map<PrivacyCapability, ConsentState>.from(consents);
    next[capability] = state;
    return PrivacyCapabilityState(next);
  }

  /// Structured disclosure metadata for user consent prompts.
  static const Map<PrivacyCapability, PrivacyDisclosure> disclosures = {
    PrivacyCapability.remoteWeather: PrivacyDisclosure(
      title: 'Local Weather Conditions',
      description:
          'Fetches current weather and temperature for meeting locations from Open-Meteo.',
      transmittedData: 'Approximate latitude and longitude coordinates',
      recipient: 'Open-Meteo API (open-meteo.com)',
      fallback: 'Map shows meeting times and directions without weather chips.',
    ),
    PrivacyCapability.cloudSync: PrivacyDisclosure(
      title: 'Cloud Synchronization',
      description:
          'Enables encrypted backup and multi-device synchronization for recovery journals and progress.',
      transmittedData: 'Encrypted recovery journals, milestones, and settings',
      recipient: 'Firebase Cloud Firestore / Authentication',
      fallback: 'All recovery data remains securely stored on this device only.',
    ),
    PrivacyCapability.circleShare: PrivacyDisclosure(
      title: 'Recovery Circle Community Sharing',
      description:
          'Allows sharing encouragement, stories, and reactions with the Recovery Circle peer feed.',
      transmittedData: 'Chosen alias, post text, and peer reactions',
      recipient: 'Recovery Circle Firestore collection',
      fallback: 'Community feed remains visible locally without publishing outwards.',
    ),
    PrivacyCapability.directoryRefresh: PrivacyDisclosure(
      title: 'Meeting Directory Updates',
      description:
          'Downloads up-to-date meeting schedules and formats from recovery intergroups.',
      transmittedData: 'Approximate search coordinates and feed query parameters',
      recipient: 'Local fellowship servers (Code for Recovery / BMLT)',
      fallback: 'Bundled and previously cached meeting directory remains available offline.',
    ),
    PrivacyCapability.onlineTiles: PrivacyDisclosure(
      title: 'Online Map Detail Tiles',
      description:
          'Downloads street map and satellite imagery for viewing meeting locations.',
      transmittedData: 'Tile coordinates (zoom, x, y)',
      recipient: 'OpenStreetMap / Esri tile servers',
      fallback: 'Previously cached offline tiles and meeting address lists remain usable.',
    ),
    PrivacyCapability.externalNavigation: PrivacyDisclosure(
      title: 'External Navigation Handoff',
      description:
          'Opens external mapping applications (Google Maps, Apple Maps) for turn-by-turn driving directions.',
      transmittedData: 'Destination meeting latitude, longitude, and street address',
      recipient: 'System default map application',
      fallback: 'Meeting addresses and cross streets are displayed on screen for manual entry.',
    ),
  };
}

/// Central authority for capability authorization and persisted consent.
///
/// Concurrency and Security Model:
/// - Authoritative in-memory state: [_effectiveConsents] governs [isGranted] immediately.
/// - Immediate revocation: Denial updates memory synchronously before persistence starts.
/// - Concurrency lock: All disk persistence is sequentially queued through [_lock].
/// - Request revisions: Monotonically increasing per-capability counters discard completions
///   from superseded requests, ensuring older async grants never overwrite newer denials.
class PrivacyCapabilityService {
  PrivacyCapabilityService._();

  static const String keyPrefix = 'privacy_consent_v1_';

  static final List<void Function(PrivacyCapability, ConsentState)>
      onConsentChangedCallbacks = [];

  static Future<void> _lock = Future.value();

  static final Map<PrivacyCapability, int> _capabilityRevisions = {};
  static final Map<PrivacyCapability, ConsentState> _effectiveConsents = {};
  static final Set<PrivacyCapability> _explicitlyModified = {};

  @visibleForTesting
  static Future<bool> Function(PrivacyCapability, ConsentState)?
      persistenceOverrideForTesting;

  @visibleForTesting
  static void resetForTesting() {
    _capabilityRevisions.clear();
    _effectiveConsents.clear();
    _explicitlyModified.clear();
    onConsentChangedCallbacks.clear();
    _lock = Future.value();
    persistenceOverrideForTesting = null;
  }

  /// Loads persisted consent from storage into [PrivacyCapabilityState].
  /// Preserves session-level modifications made prior to hydration completion.
  static Future<PrivacyCapabilityState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <PrivacyCapability, ConsentState>{};
      for (final cap in PrivacyCapability.values) {
        if (_explicitlyModified.contains(cap) && _effectiveConsents.containsKey(cap)) {
          map[cap] = _effectiveConsents[cap]!;
          continue;
        }
        final val = prefs.getString('$keyPrefix${cap.name}');
        final state = val == ConsentState.granted.name
            ? ConsentState.granted
            : (val == ConsentState.denied.name ? ConsentState.denied : ConsentState.unknown);
        map[cap] = state;
        _effectiveConsents[cap] = state;
      }
      return PrivacyCapabilityState(map);
    } catch (_) {
      return const PrivacyCapabilityState();
    }
  }

  /// Evaluates whether [capability] is authorized.
  /// Consults the authoritative in-memory state first, then persisted storage.
  /// Fails closed: returns false on absent, corrupted, unknown, or denied state.
  static Future<bool> isGranted(PrivacyCapability capability) async {
    if (_effectiveConsents.containsKey(capability)) {
      return _effectiveConsents[capability] == ConsentState.granted;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_effectiveConsents.containsKey(capability)) {
        return _effectiveConsents[capability] == ConsentState.granted;
      }
      final val = prefs.getString('$keyPrefix${capability.name}');
      final state = val == ConsentState.granted.name
          ? ConsentState.granted
          : (val == ConsentState.denied.name ? ConsentState.denied : ConsentState.unknown);
      if (!_effectiveConsents.containsKey(capability)) {
        _effectiveConsents[capability] = state;
      }
      return _effectiveConsents[capability] == ConsentState.granted;
    } catch (_) {
      return false;
    }
  }

  /// Fast synchronous check of effective authorization in memory.
  /// Fails closed if not explicitly granted.
  static bool isGrantedSync(PrivacyCapability capability) {
    return _effectiveConsents[capability] == ConsentState.granted;
  }

  /// Retrieves effective [ConsentState] for [capability].
  static Future<ConsentState> getConsent(PrivacyCapability capability) async {
    if (_effectiveConsents.containsKey(capability)) {
      return _effectiveConsents[capability]!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_effectiveConsents.containsKey(capability)) {
        return _effectiveConsents[capability]!;
      }
      final val = prefs.getString('$keyPrefix${capability.name}');
      final state = val == ConsentState.granted.name
          ? ConsentState.granted
          : (val == ConsentState.denied.name ? ConsentState.denied : ConsentState.unknown);
      if (!_effectiveConsents.containsKey(capability)) {
        _effectiveConsents[capability] = state;
      }
      return _effectiveConsents[capability]!;
    } catch (_) {
      return ConsentState.unknown;
    }
  }

  /// Sets consent for [capability] and persists the decision.
  ///
  /// Concurrency contract:
  /// - Serialized through [_lock] to ensure sequential persistence.
  /// - Monotonically increasing revision numbers ensure completions from
  ///   superseded requests never overwrite newer intent or emit stale callbacks.
  ///
  /// Security invariants:
  /// - Revocation synchronously updates [_effectiveConsents] and fires callbacks,
  ///   immediately blocking outbound requests before persistence starts.
  /// - Grants only become effective after persistence succeeds.
  ///
  /// Unresolved security acceptance issue (failed revocation on restart):
  /// - If persistence fails during revocation, session-level denial is retained
  ///   in memory and this method returns false. However, because underlying storage
  ///   was not updated, durable denial cannot be guaranteed across app restarts.
  static Future<bool> setConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) async {
    final int revision = (_capabilityRevisions[capability] ?? 0) + 1;
    _capabilityRevisions[capability] = revision;
    _explicitlyModified.add(capability);

    // Synchronous immediate revocation blocks calls before persistence starts
    if (!state.isGranted) {
      _effectiveConsents[capability] = state;
      for (final cb in List.of(onConsentChangedCallbacks)) {
        try {
          cb(capability, state);
        } catch (_) {}
      }
    }

    final completer = Completer<bool>();
    _lock = _lock.then((_) async {
      try {
        final bool ok;
        if (persistenceOverrideForTesting != null) {
          ok = await persistenceOverrideForTesting!(capability, state);
        } else {
          final prefs = await SharedPreferences.getInstance();
          ok = await prefs.setString('$keyPrefix${capability.name}', state.name);
        }

        // Discard completions superseded by a newer request
        if (_capabilityRevisions[capability] != revision) {
          debugPrint(
            '[privacy] Request revision $revision for ${capability.name} superseded by revision ${_capabilityRevisions[capability]}',
          );
          completer.complete(false);
          return;
        }

        if (!ok) {
          _effectiveConsents[capability] = ConsentState.denied;
          completer.complete(false);
          return;
        }

        _effectiveConsents[capability] = state;

        if (state.isGranted) {
          for (final cb in List.of(onConsentChangedCallbacks)) {
            try {
              cb(capability, state);
            } catch (_) {}
          }
        }
        completer.complete(true);
      } catch (e) {
        debugPrint('[privacy] persistence failed for ${capability.name}: $e');
        if (_capabilityRevisions[capability] == revision) {
          _effectiveConsents[capability] = ConsentState.denied;
        }
        completer.complete(false);
      }
    });
    return completer.future;
  }

  static Future<bool> saveConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) =>
      setConsent(capability, state);
}

final privacyCapabilityProvider =
    NotifierProvider<PrivacyCapabilityNotifier, PrivacyCapabilityState>(
  PrivacyCapabilityNotifier.new,
);

/// Observable Riverpod provider managing privacy capability authorization.
class PrivacyCapabilityNotifier extends Notifier<PrivacyCapabilityState> {
  int _revision = 0;

  @override
  PrivacyCapabilityState build() {
    _hydrateFromStorage();
    return PrivacyCapabilityState(Map.from(PrivacyCapabilityService._effectiveConsents));
  }

  Future<void> _hydrateFromStorage() async {
    final revisionAtStart = _revision;
    final loaded = await PrivacyCapabilityService.loadState();
    if (_revision == revisionAtStart) {
      state = loaded;
    }
  }

  /// Updates consent with immediate in-memory revocation and serialized storage.
  /// Stale completions from superseded operations are ignored.
  Future<bool> setConsent(
    PrivacyCapability capability,
    ConsentState consent,
  ) async {
    final myRevision = ++_revision;
    if (!consent.isGranted) {
      state = state.withConsent(capability, consent);
    }

    final success = await PrivacyCapabilityService.setConsent(capability, consent);

    if (_revision != myRevision) {
      return false;
    }

    if (consent.isGranted) {
      if (success) {
        state = state.withConsent(capability, consent);
      } else {
        state = state.withConsent(capability, ConsentState.denied);
      }
    } else if (!success) {
      state = state.withConsent(capability, ConsentState.denied);
    }

    return success;
  }

  Future<bool> grant(PrivacyCapability capability) async {
    return setConsent(capability, ConsentState.granted);
  }

  Future<bool> deny(PrivacyCapability capability) async {
    return setConsent(capability, ConsentState.denied);
  }

  Future<bool> revoke(PrivacyCapability capability) async {
    return setConsent(capability, ConsentState.denied);
  }
}
