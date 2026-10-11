# Verification Matrix — Category Platform

**Evidence statuses:** `[ ]` not run; `[x]` run with logs/checkpoint link. Current items are NOT executed. File review is not a passing test.

## Privacy and Circle acceptance

- [ ] Airplane mode, no app account: private journal, coping exercises and companion are functional.
- [ ] Network disabled: compose Circle post as local draft; UI clearly states no peer has received it.
- [ ] Network enabled and opt-in: exactly one post is delivered (no replay duplicates) with visible state.
- [ ] Original author deletes remote post: another client cannot view it after settled sync; retained cached copy policy explained.
- [ ] Malicious client attempts to change another user's Circle text, author, status or counts without rules: rejected.
- [ ] User toggles `SharedPreferences` local moderator flag: **cannot** gain authority over shared remote records.
- [ ] User posts 50 rapid reactions: one accepted per defined actor/post/reaction policy; no unlimited amplification.
- [ ] User blocks peer: blocked content/actions obey policy on all online devices.
- [ ] Review captured outbound requests: exact coordinates are never transmitted without the chosen capability/consent; privacy policy lists network recipients.
- [ ] If Firebase used: emulator-driven rules tests and App Check/abuse design; privacy policy reflects actual identifiers and data deletion procedure.

## Game integrity and compassion

- [ ] Same action event replayed 100 times grants XP/Sparks once.
- [ ] Two concurrent actions grant both entitlements and append audit rows exactly once.
- [ ] Active raid processed once per event; no doubled boss damage or victory credit.
- [ ] Quest, pet outfit, journal entry, star memories and Path XP survive full kill/restart/offline.
- [ ] Database migration from previous schema preserves all user progress and notes.
- [ ] Missed day, relapse disclosure, failed battle: no shaming, negative streak pressure, companion death or loss of access to support.
- [ ] Accessibility-equivalent quest can be completed without walking/standing/tapping fast.
- [ ] No real-money purchases, mandatory daily task, RNG reward wager or social comparison of sober days.
- [ ] User turns off game surface: meeting search, tools and Circle still work.

## Meeting + travel

- [ ] Cached real meeting has source, timestamp, local date/time and timezone; synthetic SAMPLE entries excluded from routes.
- [ ] GTFS calendar/calendar_dates and service-day times past midnight handled correctly on date transitions.
- [ ] Prepared airplane mode: selected meeting -> one valid local route with correct departure/arrival and walk+transit steps.
- [ ] Fresh airplane-mode install: honestly reports unavailable meeting/routing data; no fake route or online call.
- [ ] User rejects location: can search a city manually; no unrequested external coordinate request.
- [ ] Weather feed unavailable: routes remain usable and overlay disappears with timestamped warning.
- [ ] Live transit stale: label as *scheduled/last updated*, never current vehicle or guaranteed transfer.
- [ ] Missed/canceled transfer: candidate re-ranking includes explanation, accessible alternative and no false certainty.
- [ ] Offline map package missing: meaningful textual directions and offline capability message, not a blank map assumed usable.
- [ ] Destination route shown in Flutter's existing map; no unexpected switch to browser.
- [ ] Direct API provider call and attribution, caching rights, user agent requirements verified.

## Device and workflow

- [ ] Existing `flutter analyze` and `flutter test` pass; preserved regression suites (`schema_migration`, `pet_economy`, `meeting_finder`, `community_feed`, `gguf_services`, `fellowship_attestation`).
- [ ] Metro SDK published by explicit local build; sample host/portability tests and Kotlin tests pass (no cross-repo writes).
- [ ] Real Android device E2E with offline transition and background/foreground lifecycle.
- [ ] Large text 200%, screen readers and reduce-motion paths for battle, map and Circle.
- [ ] Memory pressure test on 3GB device; app stays responsive with downloaded region and large GTFS feed.
- [ ] Source evidence, target commit, input fixtures, command output and verdict retained in local verification report.

## Measurement guide (pilot)

Use opt-in, minimal personal data, aggregate analysis where possible. Favor **task completion, autonomy and user experience**, not screen-time maximization.

- Meeting find-to-saved-itinerary completion rate; route uncertainty comprehension.
- Prepared-offline success rate and cached data staleness honesty.
- Number of double grants/duplicate posts/reaction abuse incidents = zero.
- Time to access a coping tool / emergency resource.
- Voluntary use vs game opt-out rates; perceived guilt/pressure measure.
- Circle report resolution and deletion success; users who successfully find support.
- No unsupported clinical efficacy claim from these engineering measurements.
