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

/// Immutable snapshot of privacy capability authorization and preference state.
///
/// WO-P0-PRIVACY-DURABILITY:
/// - [sessionAuthorizations]: Evaluates effective outbound network permission for the current process.
/// - [persistedPreferences]: Stores durable user preferences loaded from disk.
/// - Invariant: Persisted preferences alone NEVER authorize network requests on a cold restart.
@immutable
class PrivacyCapabilityState {
  final Map<PrivacyCapability, ConsentState> sessionAuthorizations;
  final Map<PrivacyCapability, ConsentState> persistedPreferences;

  const PrivacyCapabilityState([
    this.sessionAuthorizations = const <PrivacyCapability, ConsentState>{},
    this.persistedPreferences = const <PrivacyCapability, ConsentState>{},
  ]);

  Map<PrivacyCapability, ConsentState> get consents => sessionAuthorizations;

  /// Default baseline fails closed: all capabilities session-denied.
  factory PrivacyCapabilityState.defaults() {
    return const PrivacyCapabilityState();
  }

  /// Checks if network operations for [capability] are authorized for the current session.
  /// Strictly fails closed: returns true ONLY if session authorization is explicitly [ConsentState.granted].
  bool isGranted(PrivacyCapability capability) {
    return sessionAuthorizations[capability] == ConsentState.granted;
  }

  /// Effective session authorization for [capability].
  /// Fails closed: defaults to [ConsentState.denied] if not explicitly authorized for the session.
  ConsentState getConsent(PrivacyCapability capability) {
    return sessionAuthorizations[capability] ?? ConsentState.denied;
  }

  /// Retrieves the durable stored preference for [capability] (what the user previously chose).
  ConsentState getPersistedPreference(PrivacyCapability capability) {
    return persistedPreferences[capability] ?? ConsentState.unknown;
  }

  /// Returns a copy of this state with session authorization updated for [capability].
  PrivacyCapabilityState withSessionAuthorization(
    PrivacyCapability capability,
    ConsentState state,
  ) {
    final nextSession = Map<PrivacyCapability, ConsentState>.from(sessionAuthorizations);
    nextSession[capability] = state;
    return PrivacyCapabilityState(nextSession, persistedPreferences);
  }

  /// Returns a copy of this state with both session authorization and persisted preference updated.
  PrivacyCapabilityState withConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) {
    final nextSession = Map<PrivacyCapability, ConsentState>.from(sessionAuthorizations);
    final nextPrefs = Map<PrivacyCapability, ConsentState>.from(persistedPreferences);
    nextSession[capability] = state;
    nextPrefs[capability] = state;
    return PrivacyCapabilityState(nextSession, nextPrefs);
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
/// Concurrency and Security Model (WO-P0-PRIVACY-DURABILITY):
/// - In-memory session authorization: [_sessionAuthorizations] governs [isGranted].
///   Initializes to denied on every fresh application launch. Persisted grants
///   never automatically authorize network operations across cold restarts.
/// - Persistent preferences: [_persistedPreferences] records durable choices without
///   granting network authority independently.
/// - Explicit user authorization workflow: Fresh session grants MUST originate from
///   an explicit user consent action through [setConsent]. No silent or generic shortcuts exist.
/// - Immediate revocation: Denial updates memory synchronously before persistence starts.
/// - Concurrency lock: All disk persistence is sequentially queued through [_lock].
/// - Request revisions: Monotonically increasing per-capability counters discard completions
///   from superseded requests, ensuring older async grants never overwrite newer denials.
/// - Accurate preference reporting: Failed writes do not overwrite [_persistedPreferences].
///   A failed revocation remains session-denied while accurately reporting storage failure.
/// - Complete restart safety: Even if disk write fails during revocation, a subsequent
///   cold restart still initializes session authorization to denied, preventing leaks.
class PrivacyCapabilityService {
  PrivacyCapabilityService._();

  static const String keyPrefix = 'privacy_consent_v1_';

  static final List<void Function(PrivacyCapability, ConsentState)>
      onConsentChangedCallbacks = [];

  static Future<void> _lock = Future.value();

  static final Map<PrivacyCapability, int> _capabilityRevisions = {};
  static final Map<PrivacyCapability, ConsentState> _sessionAuthorizations = {};
  static final Map<PrivacyCapability, ConsentState> _persistedPreferences = {};

  @visibleForTesting
  static Future<bool> Function(PrivacyCapability, ConsentState)?
      persistenceOverrideForTesting;

  @visibleForTesting
  static void resetForTesting() {
    _capabilityRevisions.clear();
    _sessionAuthorizations.clear();
    _persistedPreferences.clear();
    onConsentChangedCallbacks.clear();
    _lock = Future.value();
    persistenceOverrideForTesting = null;
  }

  /// Ensures privacy service initialization completes.
  /// Hydrates persisted preferences from storage while ensuring all
  /// session authorizations remain denied until explicitly authorized by the user.
  static Future<PrivacyCapabilityState> initialize() async {
    return loadState();
  }

  /// Loads persisted consent from storage into [PrivacyCapabilityState].
  /// Populates [_persistedPreferences] from disk while keeping [_sessionAuthorizations]
  /// restricted to decisions explicitly made in the current process session.
  static Future<PrivacyCapabilityState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final cap in PrivacyCapability.values) {
        final val = prefs.getString('$keyPrefix${cap.name}');
        final state = val == ConsentState.granted.name
            ? ConsentState.granted
            : (val == ConsentState.denied.name ? ConsentState.denied : ConsentState.unknown);
        _persistedPreferences[cap] = state;
      }
      return PrivacyCapabilityState(
        Map.from(_sessionAuthorizations),
        Map.from(_persistedPreferences),
      );
    } catch (_) {
      return PrivacyCapabilityState(
        Map.from(_sessionAuthorizations),
        const {},
      );
    }
  }

  /// Evaluates whether optional network activity for [capability] is authorized.
  /// Governed exclusively by current process session authorization.
  /// Fails closed: returns false on cold start, denied, unknown, or corrupted state.
  static Future<bool> isGranted(PrivacyCapability capability) async {
    return _sessionAuthorizations[capability] == ConsentState.granted;
  }

  /// Fast synchronous check of session authorization in memory.
  /// Fails closed if not explicitly granted in the current application session.
  static bool isGrantedSync(PrivacyCapability capability) {
    return _sessionAuthorizations[capability] == ConsentState.granted;
  }

  /// Retrieves effective session [ConsentState] for [capability].
  static Future<ConsentState> getConsent(PrivacyCapability capability) async {
    return _sessionAuthorizations[capability] ?? ConsentState.denied;
  }

  /// Fast synchronous check of effective session [ConsentState].
  static ConsentState getConsentSync(PrivacyCapability capability) {
    return _sessionAuthorizations[capability] ?? ConsentState.denied;
  }

  /// Retrieves the durable stored preference for [capability].
  static Future<ConsentState> getPersistedPreference(PrivacyCapability capability) async {
    if (_persistedPreferences.containsKey(capability)) {
      return _persistedPreferences[capability]!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString('$keyPrefix${capability.name}');
      final state = val == ConsentState.granted.name
          ? ConsentState.granted
          : (val == ConsentState.denied.name ? ConsentState.denied : ConsentState.unknown);
      _persistedPreferences[capability] = state;
      return state;
    } catch (_) {
      return ConsentState.unknown;
    }
  }

  /// Sets consent for [capability], updates session authorization, and persists the decision.
  ///
  /// Concurrency contract:
  /// - Serialized through [_lock] to ensure sequential persistence.
  /// - Monotonically increasing revision numbers ensure completions from
  ///   superseded requests never overwrite newer intent or emit stale callbacks.
  ///
  /// Security invariants:
  /// - Revocation synchronously updates [_sessionAuthorizations] to [ConsentState.denied],
  ///   immediately firing callbacks and blocking outbound requests before persistence starts.
  /// - Grants only become effective in session authorization after persistence succeeds.
  /// - Failed persistence is reported by returning false, not silently treated as success.
  /// - Failed revocation writes do NOT overwrite [_persistedPreferences]; session authorization
  ///   remains strictly denied, while storage failure is accurately reported.
  /// - On subsequent cold restart, all session authorizations initialize to denied,
  ///   guaranteeing failed writes cannot leak access across restarts.
  static Future<bool> setConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) async {
    final int revision = (_capabilityRevisions[capability] ?? 0) + 1;
    _capabilityRevisions[capability] = revision;

    // Synchronous immediate revocation blocks calls before persistence starts
    if (!state.isGranted) {
      _sessionAuthorizations[capability] = state;
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
          // Persistence failed: session authorization fails closed / remains denied.
          // Do not represent failed write as saved in _persistedPreferences.
          _sessionAuthorizations[capability] = ConsentState.denied;
          completer.complete(false);
          return;
        }

        // Persistence succeeded: both session authorization and persisted preferences are updated.
        _sessionAuthorizations[capability] = state;
        _persistedPreferences[capability] = state;

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
          // Persistence threw: session authorization fails closed / remains denied.
          // Do not represent failed write as saved in _persistedPreferences.
          _sessionAuthorizations[capability] = ConsentState.denied;
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

/// Observable Riverpod provider managing privacy capability authorization and preferences.
class PrivacyCapabilityNotifier extends Notifier<PrivacyCapabilityState> {
  int _revision = 0;

  @override
  PrivacyCapabilityState build() {
    _hydrateFromStorage();
    return PrivacyCapabilityState(
      Map.from(PrivacyCapabilityService._sessionAuthorizations),
      Map.from(PrivacyCapabilityService._persistedPreferences),
    );
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
    // Synchronous immediate revocation blocks network operations immediately
    if (!consent.isGranted) {
      state = state.withSessionAuthorization(capability, ConsentState.denied);
    }

    final success = await PrivacyCapabilityService.setConsent(capability, consent);

    if (_revision != myRevision) {
      return false;
    }

    if (success) {
      // Storage write succeeded: durably update both session authorization and persisted preferences
      state = state.withConsent(capability, consent);
    } else {
      // Storage write failed: session authorization remains strictly denied,
      // but persisted preference is not claimed as saved.
      state = state.withSessionAuthorization(capability, ConsentState.denied);
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
