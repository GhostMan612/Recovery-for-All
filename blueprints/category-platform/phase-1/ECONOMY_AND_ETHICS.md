# RPG Economy, Balancing and Human-Centered Rewards

## Current baseline to retain until tested

`RecoveryPetService` currently uses Sparks earn cap 150/day for ordinary sources, walk cap 2/day, cap-exempt meeting/milestones per existing design; Path Level uses XP and gear score. `XpEngineService` uses registered action amounts and a legacy fallback. Any proposed rebalance must start from characterization tests and owner signoff—not a blind rewrite.

## Proposed economy

- **XP:** transparent lifetime progression, nonspendable. **Sparks:** strictly cosmetic spendable currency. **Bond:** relationship/engagement visual, not a shame meter. **Energy/Mood:** gentle representation, never death, lockout or coercive decay.
- **Core event classes:** coping tool, private reflection, routine action, verified walk, *self-reported* meeting, supported meeting attestation, paid-for-nothing peer kindness. Distinguish evidence tier in metadata, not public display.
- **No gambling:** no lootboxes, random reward amount for sensitive actions, cash-to-currency, limited-time shame/urgency. Cosmetic unlocks have published fixed costs.
- **Daily cap:** once-per-day quest bonus, defined per-event and per-day limits, no evasion through backdated data, repeated shares or timezone shifts. Case-insensitive/normalized action type only if defined in schema.
- **Gameplay accessibility:** no physical-movement advantage that prevents disabled users from equivalent progress. Equivalent nontravel alternatives for offline, mobility, rural, or transit-poor users.
- **Meaningful player agency:** selectable themes/pathway, avatar identity, optional quest narrative and positive completion options; never rank members by sobriety time.

## Proposed instrumentation (local only)

Collect opt-in local diagnostics that report whether an action completed and resulting receipt count, not private text, medical markers or location. For testing, synthetic event history. Never silently enable telemetry/cloud analytics.

## Balance QA

Model 30-day synthetic cases: daily average, very active, episodic, no movement, offline-only, skipped week, low literacy, game disabled, multiple duplicate retries. Compare rewards/caps and *pressure* UX against user-study observations. Do not claim clinical benefit from retention or XP earned.
