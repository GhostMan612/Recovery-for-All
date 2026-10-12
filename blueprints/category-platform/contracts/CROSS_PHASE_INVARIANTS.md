# Cross-Phase Invariants (normative targets)

These become tests as each work order is implemented; existing `RULES.md` / `AGENTS.md` invariants remain in force. Never weaken an earlier test to make a later feature green without explicitly approving the behavior change.

| ID | Invariant / failure that must be impossible |
|---|---|
| CP-01 | Personal coping, journal, SOS and emergency access do not require RPG, login, feed or network. |
| CP-02 | Every reward-bearing event has a stable `eventId`, registered `actionType`, payload version, event creation time, and provenance; unrecognized types fail closed. |
| CP-03 | One stable `eventId` creates at most one reward receipt across XP, Sparks, battles, quests, raids, constellation, retries, currency types, or policy versions, even after 100 retries, double taps, app termination, or reconciliation. Policy version is audit metadata, never an idempotency-key component; corrections use a separately identified compensating event. |
| CP-04 | The original domain action and its reward/event journal commit in one transaction or use explicitly recoverable outbox/saga state; no silent half-credit. |
| CP-05 | Raid damage and victory projections are idempotent per triggering event and raid instance; a projection cannot issue a second underlying XP/Sparks reward or route one event to competing reward ledgers. |
| CP-06 | Attestation is not GPS proof, sobriety proof, meeting attendance proof or independent identity proof. |
| CP-07 | No XP/Sparks bonuses for relapse/confession severity, share volume, reaction count, or mandatory disclosure. |
| CP-08 | Companion never dies, shames, locks coping support or punishes absence/relapse. |
| CP-09 | Game opt-out retains full meeting navigation, journaling, Circle/sponsor (if consented) and SOS. |
| CP-10 | Synthetic meeting fixtures carry a visible `SAMPLE` flag and are never routed/rewarded as real attendance. |
| CP-11 | Meeting identifiers are source-scoped; schedule timezone/service-day semantics and data age are explicit. |
| CP-12 | Weather/radar/stale transit is never represented as a current observation after freshness expiry. |
| CP-13 | Prepared-offline routing is distinguishable from merely caching map imagery; first-run-offline cannot fabricate a route. |
| CP-14 | Precise coordinates are not published with Circle posts, activity proofs or game achievements. |
| CP-15 | Location-aware external requests require documented, enforceable consent; external routing fallbacks are explicit. |
| CP-16 | Remote Circle writes require trusted ownership controls and immutable author attribution, tested with two identities. |
| CP-17 | Remote moderation role cannot be granted by a client-local preference or self-issued claim. |
| CP-18 | One actor's reaction/quest contribution is unique per allowed actor-target pair, across reconnect/reinstall. |
| CP-19 | A local draft is never labeled published; a requested delete is never labeled deleted remotely before acknowledgement. |
| CP-20 | Blocking/reporting do not expose report identities or precise location to other members. |
| CP-21 | No private text, exact location, tokens, or unredacted trip history enters default logs/analytics. |
| CP-22 | All schema changes are coordinated through one Drift migration plan across Phase 0–4; they preserve existing encrypted data and pass populated v1→current and current→next chain tests. |
| CP-23 | Accessibility: screen readers, 200% text, reduced motion, contrast, and touch sizes are verified on actual views. |
| CP-24 | Cloud being unreachable cannot affect core local app startup, user-data integrity or emergency affordances. |

Each phase `ACCEPTANCE_AND_TESTS.md` names its subset. Phase 4 requires all applicable CP invariants signed off with test IDs/device evidence.
