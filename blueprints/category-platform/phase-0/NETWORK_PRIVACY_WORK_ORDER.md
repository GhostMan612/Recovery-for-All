# WO-P0-PRIVACY — Implement explicit network capability controls

**Existing limitation:** on Firebase-enabled installs `main.dart` initializes Firebase and signs in anonymously on boot. `meeting_map_screen.dart::_loadWeather()` can call Open-Meteo with a location fix on map load. External Google Maps intents carry the destination. Changing only `PRIVACY_POLICY.md` cannot prevent any request.

## Implementation slices

1. **Domain contract:** central capability decisions for private-only, remote weather, directory refresh, online tiles, external navigation and Circle sharing. Define 'consent unknown/denied/granted' separately from Android runtime location permission. Explicit default decision must be approved by owner due to changes to existing app behavior.
2. **Persistence and privacy UI:** store capability choices locally in protected app settings; make revocation immediate. Explain destination/provider, precision and tradeoffs before opt-in; provide a pathway to use a manual city and cached listings without GPS. Never gate SOS or core coping tools on consent.
3. **Map request gating:** guard `meeting_map_screen.dart::_loadWeather()` **before** `http.get` and map startup; do not call location-aware weather until policy permits. Avoid assuming a generic map `Position` is permission to send exact GPS to weather service; provide a null/disabled chip. Show freshness and provider attribution.
4. **Cloud initialization:** decouple optional Firebase readiness from automatic sign-in. In `main.dart` do not begin anonymous auth unless the user has chosen a connected mode (or the owner intentionally retains opt-in-independent startup and updates policy accordingly). Circle must present honest local state even when remote is not connected.
5. **External directions:** show an explicit handoff message, no background navigation launch; make URL requests only from a user action, preserving native Atlas offline future seam.
6. **Cache hygiene:** documented TTL, offline tile provider terms, last GPS fix deletion and no accidental analytics/debug location logging. Preserve current reliable offline meeting cache after a denied request.
7. **Negative tests:** mock clients assert zero requests for denied capabilities on boot, map entry, refresh, lifecycle pause/resume and process restart; logging and secure-store inspections use fictional coordinates/aliases.

## Dependencies and owner decisions

- Current behavior may rely on cloud sign-in immediately after startup; consent gating can change community functionality. Present migration behavior and owner choice before modifying live code.
- Check Google Play privacy/Data Safety classification against observed Firebase initialization and provider requests with counsel as needed; do not simply declare 'data collected: none' for connected users.
- Preserve `AGENTS.md` build discipline and authorization boundaries; run Flutter gates only at phase completion.

## Acceptance

Zero unauthorized location-bearing weather/route requests in negative network tests; precise GPS never enters shared Circle payload; offline personal tools unaffected; privacy settings describe real data flows; external handoff user-initiated and obvious.
