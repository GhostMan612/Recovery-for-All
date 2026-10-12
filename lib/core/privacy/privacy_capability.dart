// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/privacy/privacy_capability.dart
//
// WO-P0-PRIVACY — Fail-closed Network Capability Architecture.
// Defines explicit privacy capabilities and consent state machine:
//  1. Default system state is unknown -> denies all optional network requests.
//  2. Only explicit, affirmative user grant authorizes network traffic.
//  3. Revocation immediately tears down pending and active network streams.
//  4. SOS and local recovery coping tools never require network consent.
//  5. Capabilities are independent; granting one does not grant another.

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

  /// Clear, unvarnished disclosure metadata for user consent prompts.
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

/// Standalone service for querying and updating privacy capability consent.
/// Usable by background services and non-widget layers.
class PrivacyCapabilityService {
  PrivacyCapabilityService._();

  static const String keyPrefix = 'privacy_consent_v1_';

  static final List<void Function(PrivacyCapability, ConsentState)>
      onConsentChangedCallbacks = [];

  static Future<void> _lock = Future.value();

  @visibleForTesting
  static Future<bool> Function(PrivacyCapability, ConsentState)?
      persistenceOverrideForTesting;

  /// Evaluates and loads all persisted consents into [PrivacyCapabilityState].
  static Future<PrivacyCapabilityState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <PrivacyCapability, ConsentState>{};
      for (final cap in PrivacyCapability.values) {
        final val = prefs.getString('$keyPrefix${cap.name}');
        if (val == ConsentState.granted.name) {
          map[cap] = ConsentState.granted;
        } else if (val == ConsentState.denied.name) {
          map[cap] = ConsentState.denied;
        } else {
          map[cap] = ConsentState.unknown;
        }
      }
      return PrivacyCapabilityState(map);
    } catch (_) {
      return const PrivacyCapabilityState();
    }
  }

  /// Asynchronously evaluates whether [capability] is granted from [SharedPreferences].
  /// Fails closed: returns false if absent, corrupted, unknown, or denied.
  static Future<bool> isGranted(PrivacyCapability capability) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString('$keyPrefix${capability.name}');
      return val == ConsentState.granted.name;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the persisted [ConsentState] for [capability].
  static Future<ConsentState> getConsent(PrivacyCapability capability) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString('$keyPrefix${capability.name}');
      if (val == ConsentState.granted.name) return ConsentState.granted;
      if (val == ConsentState.denied.name) return ConsentState.denied;
      return ConsentState.unknown;
    } catch (_) {
      return ConsentState.unknown;
    }
  }

  /// Sets consent in [SharedPreferences] and notifies registered callbacks.
  /// Serialized through a lock to eliminate persistence concurrency races.
  /// Fails closed: returns false if persistence throws or fails.
  static Future<bool> setConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) async {
    final completer = Completer<bool>();
    _lock = _lock.then((_) async {
      try {
        if (persistenceOverrideForTesting != null) {
          final ok = await persistenceOverrideForTesting!(capability, state);
          if (!ok) {
            completer.complete(false);
            return;
          }
        } else {
          final prefs = await SharedPreferences.getInstance();
          final ok = await prefs.setString('$keyPrefix${capability.name}', state.name);
          if (!ok) {
            completer.complete(false);
            return;
          }
        }
        for (final cb in List.of(onConsentChangedCallbacks)) {
          try {
            cb(capability, state);
          } catch (_) {}
        }
        completer.complete(true);
      } catch (e) {
        debugPrint('[privacy] persistence failed for ${capability.name}: $e');
        completer.complete(false);
      }
    });
    return completer.future;
  }

  /// Alias for setConsent for round-trip persistence operations.
  static Future<bool> saveConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) =>
      setConsent(capability, state);
}

/// Global provider managing privacy capability authorization across the app.
final privacyCapabilityProvider =
    NotifierProvider<PrivacyCapabilityNotifier, PrivacyCapabilityState>(
  PrivacyCapabilityNotifier.new,
);

class PrivacyCapabilityNotifier extends Notifier<PrivacyCapabilityState> {
  @override
  PrivacyCapabilityState build() {
    _hydrateFromStorage();
    return PrivacyCapabilityState.defaults();
  }

  Future<void> _hydrateFromStorage() async {
    final loaded = await PrivacyCapabilityService.loadState();
    if (state != loaded) {
      state = loaded;
    }
  }

  /// Updates consent with immediate fail-closed in-memory revocation
  /// and serialized persistent storage.
  /// Grants are only committed to UI state after storage succeeds.
  Future<bool> setConsent(
    PrivacyCapability capability,
    ConsentState consent,
  ) async {
    if (!consent.isGranted) {
      state = state.withConsent(capability, consent);
    }

    final success = await PrivacyCapabilityService.setConsent(capability, consent);

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
