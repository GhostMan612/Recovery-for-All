# WO-2C — Route, Weather and Arrival-Oriented Meeting UX

## User experience

Meeting detail → **Get there** (primary) → selectable origin (GPS only by consent, or text/point) → choose arrival target (e.g., 10–15 minute buffer, customizable) → cards for transit and walk options → route drawn in the existing Flutter map → read-only itinerary saved on device → warnings/status and one-tap alternative meeting. The action “I went” remains separate from “I planned a route.”

## Files

- **NEW** `lib/features/navigator/application/meeting_journey_planner.dart`: resolve meeting occurrence, invoke AtlasBridge and cancel by request ID, rank options by *arrives before meeting*, walk burden, transfer uncertainty and accessibility preference, never fake a successful plan.
- **NEW** `lib/features/navigator/domain/journey_preview.dart`: typed native DTO, fresh/stale/unknown, speed/walk/time limits, accessible route summary.
- **NEW** `lib/features/navigator/ui/journey_sheet.dart`, `journey_option_card.dart`, `transfer_details.dart`: route cards, accessible status, saved offline plan and explicit external fallback.
- `lib/screens/meeting_map_screen.dart`: wire CTA and selected route geometry; replace one-click `Google Maps` direction launch as the default with in-app planner when available, while retaining **explicit** external fallback.
- `lib/services/map_tile_cache.dart`: show separate availability for map tiles; never promise basemap from GTFS snapshot.
- Use Metro `TransferConfidenceScorer` outputs through the Atlas bridge, but expose `SCHEDULED_UNKNOWN` as uncertainty, not 'guaranteed connection'.
- Weather: use current RFA Open-Meteo chip for existing map status; integrate weather exposure **only** after provider, consent and distinct timestamps. Metro weather adapters include NWS alerts/RainViewer radar, neither automatically supplies hyperlocal minute-by-minute walking-leg forecasts.

## Helpful differentiators with bounded claims

- **Meeting reachability**: not just distance; whether a schedule-based journey can arrive before meeting start, including route duration, transit service date and transfer margin.
- **Weather-informed preparation**: rain, hot/cold, wind if the selected provider supplies it, explicit source/time and suggestions (coat, water, alternative route), not medical predictions.
- **Accessibility-first**: accessible stop/vehicle metadata only when provided; unknown availability presented as unknown; adjustable maximum walk distance and transfer count.
- **Offline itinerary**: locally available GTFS snapshot and saved plan with warnings about static vs live; latest weather remains dated, never quietly live.
- **Alternative meeting**: explain why original is currently impractical; nearby authentic source meeting or virtual listing, no implied superiority among fellowships.

## Navigation integrity

- Never auto-open external maps in a workflow labeled in-app; ask explicitly.
- If the user selected a synthetic meeting or destination is invalid, disable `Get there` and show why.
- No hidden third-party location upload from low-level tile/radar/route APIs; invoke `PrivacyCapabilityController` at the network adapter boundary, not just in the UI.
- No rewards for viewing routes repeatedly; a one-time *prepare* quest can credit an action if policy explicitly permits it, never 'attendance'.

## Gate

A rider can complete a mocked but structurally real trip flow in airplane mode using cached fixture GTFS and tile data, understand stale timetable/forecast limits, and return to meeting details. A second test on current live sources validates a real meeting time and route without claiming clinical/attendance proof. External routing fallback shows consent before network use.
