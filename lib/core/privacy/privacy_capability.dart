// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/privacy/privacy_capability.dart
//
// WO-P0-PRIVACY — Privacy capability domain contract and policy enforcement.
//
// Local-first doctrine:
//  1. Being signed in anonymously to Firebase is not user consent.
//  2. Device runtime permissions (e.g. Android GPS) do not equal consent
//     to transmit data to external providers.
//  3. Fail-closed: Unknown, denied, or unreadable states deny outbound network calls.
//  4. SOS and local recovery coping tools never require network consent.
//  5. Capabilities are independent; granting one does not grant another.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The distinct external network capabilities governed by user consent.
enum PrivacyCapability {
  cloudSync, // Firebase authentication & cloud synchronization
  circleShare, // Publishing posts / reactions to Recovery Circle
  directoryRefresh, // Fetching remote 12-step meeting directories
  remoteWeather, // Sending location coordinates to Open-Meteo
  onlineTiles, // Downloading map tiles over the network
  externalNavigation, // Exporting destination coordinates to external navigation apps
}

extension PrivacyCapabilityX on PrivacyCapability {
  CapabilityDisclosure get disclosure => capabilityDisclosures[this]!;
}

/// The state of user consent for a given capability.
enum ConsentState {
  unknown,
  denied,
  granted;

  bool get isGranted => this == ConsentState.granted;
}

/// Descriptive metadata for transparent user disclosure.
class CapabilityDisclosure {
  final String title;
  final String description;
  final String recipient;
  final String dataShared;
  final String offlineFallback;

  const CapabilityDisclosure({
    required this.title,
    required this.description,
    required this.recipient,
    required this.dataShared,
    required this.offlineFallback,
  });

  String get transmittedData => dataShared;
  String get fallback => offlineFallback;
}

const Map<PrivacyCapability, CapabilityDisclosure> capabilityDisclosures = {
  PrivacyCapability.cloudSync: CapabilityDisclosure(
    title: 'Cloud Account & Sync',
    description: 'Enables anonymous cloud authentication to connect with Recovery Circle and remote sponsor alerts.',
    recipient: 'Google Firebase (Cloud Firestore & Auth)',
    dataShared: 'Anonymous Firebase user ID and app session tokens',
    offlineFallback: 'App runs 100% offline. All journal entries, pets, streaks, and recovery data remain encrypted on-device.',
  ),
  PrivacyCapability.circleShare: CapabilityDisclosure(
    title: 'Recovery Circle Sharing',
    description: 'Allows sharing milestone reflections, stories, and peer encouragement with the Recovery Circle.',
    recipient: 'Google Firebase (Community Feeds)',
    dataShared: 'Chosen alias, post text, recovery shapes, and reaction counts',
    offlineFallback: 'Posts remain local drafts on your device only.',
  ),
  PrivacyCapability.directoryRefresh: CapabilityDisclosure(
    title: 'Meeting Directory Updates',
    description: 'Downloads current 12-step meeting schedules from public intergroup directories (AA, NA, BMLT).',
    recipient: 'Public meeting directory servers (AA Minnesota, BMLT)',
    dataShared: 'Network request and IP address (no personal info or GPS)',
    offlineFallback: 'Uses previously cached directory and curated Minnesota pathway meetings.',
  ),
  PrivacyCapability.remoteWeather: CapabilityDisclosure(
    title: 'Live Weather Forecast',
    description: 'Fetches temperature and conditions for your current area to display on the meeting map.',
    recipient: 'Open-Meteo API (api.open-meteo.com)',
    dataShared: 'Latitude and longitude coordinates for current map center',
    offlineFallback: 'Weather chip is hidden; meeting map and local listings function normally.',
  ),
  PrivacyCapability.onlineTiles: CapabilityDisclosure(
    title: 'Online Map Imagery',
    description: 'Downloads dynamic map tiles as you pan and zoom the meeting finder.',
    recipient: 'OpenStreetMap and ArcGIS map servers',
    dataShared: 'Tile coordinates and IP address (no personal user ID)',
    offlineFallback: 'Uses downloaded offline tile packs or previously cached areas.',
  ),
  PrivacyCapability.externalNavigation: CapabilityDisclosure(
    title: 'External Navigation Handoff',
    description: 'Opens Google Maps or other navigation apps with meeting coordinates for driving or walking directions.',
    recipient: 'External map app (e.g., Google Maps)',
    dataShared: 'Destination coordinates and street address',
    offlineFallback: 'Meeting address remains visible on-screen for manual entry.',
  ),
};

/// Immutable container of capability consent decisions.
@immutable
class PrivacyCapabilityState {
  final Map<PrivacyCapability, ConsentState> consents;

  const PrivacyCapabilityState([Map<PrivacyCapability, ConsentState>? consents])
      : consents = consents ?? const {};

  factory PrivacyCapabilityState.defaults() => const PrivacyCapabilityState();

  static Map<PrivacyCapability, CapabilityDisclosure> get disclosures =>
      capabilityDisclosures;

  ConsentState getConsent(PrivacyCapability capability) {
    return consents[capability] ?? ConsentState.unknown;
  }

  bool isGranted(PrivacyCapability capability) {
    return getConsent(capability).isGranted;
  }

  PrivacyCapabilityState withConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) {
    final updated = Map<PrivacyCapability, ConsentState>.from(consents);
    updated[capability] = state;
    return PrivacyCapabilityState(updated);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyCapabilityState &&
          mapEquals(other.consents, consents);

  @override
  int get hashCode => consents.hashCode;
}

/// Standalone service for querying and updating privacy capability consent.
/// Usable by background services and non-widget layers.
class PrivacyCapabilityService {
  PrivacyCapabilityService._();

  static const String keyPrefix = 'privacy_consent_v1_';

  static final List<void Function(PrivacyCapability, ConsentState)>
      onConsentChangedCallbacks = [];

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
  static Future<void> setConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$keyPrefix${capability.name}', state.name);
    for (final cb in List.of(onConsentChangedCallbacks)) {
      try {
        cb(capability, state);
      } catch (_) {}
    }
  }

  /// Alias for setConsent for round-trip persistence operations.
  static Future<void> saveConsent(
    PrivacyCapability capability,
    ConsentState state,
  ) =>
      setConsent(capability, state);
}

/// Riverpod Notifier for observable privacy capability state across the app.
class PrivacyCapabilityNotifier extends Notifier<PrivacyCapabilityState> {
  static const String keyPrefix = PrivacyCapabilityService.keyPrefix;

  @override
  PrivacyCapabilityState build() {
    _loadFromPrefs();
    return const PrivacyCapabilityState();
  }

  Future<void> _loadFromPrefs() async {
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
    if (ref.mounted) {
      state = PrivacyCapabilityState(map);
    }
  }

  Future<void> setConsent(
    PrivacyCapability capability,
    ConsentState consent,
  ) async {
    state = state.withConsent(capability, consent);
    await PrivacyCapabilityService.setConsent(capability, consent);
  }

  Future<void> grant(PrivacyCapability capability) async {
    await setConsent(capability, ConsentState.granted);
  }

  Future<void> deny(PrivacyCapability capability) async {
    await setConsent(capability, ConsentState.denied);
  }

  Future<void> revoke(PrivacyCapability capability) async {
    await setConsent(capability, ConsentState.denied);
  }
}

final privacyCapabilityProvider =
    NotifierProvider<PrivacyCapabilityNotifier, PrivacyCapabilityState>(
  PrivacyCapabilityNotifier.new,
);
