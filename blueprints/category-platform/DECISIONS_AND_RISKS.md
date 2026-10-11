# Decisions, Threats and Risk Register

**Do not let agents decide these silently.** Recommendations are provided for efficient work; user remains owner of substantive tradeoffs.

| Decision | Recommended default | Reason / blocking gate |
|---|---|---|
| Product identity | “Recovery Adventure Network” **working category label**, not registered trademark claim | Clear distinction from conventional tracker, subject to branding review |
| Release focus | RPG -> Navigator -> Circle on top of Phase-0 trust gates | Biggest differentiated user loop with security first |
| Metro source | Pin `Metro-IntelliTrip/master` at `a7d77e4`; leave `main` alone | SDK lives on master; main currently only README |
| SDK integration | Local Maven artifacts + Kotlin `MethodChannel` bridge and Flutter rendering | Matches Metro published SDK design; separate repos and renderer ownership |
| Web routing | Local static planner by default; explicit consent before remote fallback | Offline usefulness plus minimal coordinate disclosure |
| Weather | Explicit optional capability; show source/timestamp; never gate access to meeting | Forecast/radar requires network and is uncertain |
| Circle transport | Local draft/cache + Firestore only after trusted moderation and delete semantics | Current remote design is not moderation-complete |
| Local Circle support | Local contacts and drafts first; no claim of offline P2P | Mesh delivery is separate R&D and currently absent |
| Game loop | Nonpunitive personal development; one ledger | Protects users, avoids dupes, improves testability |
| Paid game mechanics | None, including random rewards for money | Matches free-for-all mission and avoids coercion |
| External cultural programs | Link to official directories, respect each program's governance | Avoid presenting White Bison/other fellowships as owned services |
| License | Stop public “proprietary exclusive” claims until legal review of committed MIT license | Published license conveys broad rights; cannot silently revoke for past recipients |

## Risk register

| Risk | Priority | Owner domain | Mitigation / acceptance |
|---|---|---|---|
| Remote Circle harm/abuse; fake moderation | P0 | Circle, Security | Server-enforced permissions, abuse reporting, hard gates and emulator tests |
| Misleading deletion/privacy promises | P0 | Data, Privacy | Cross-device delete test, accurate disclosure, request-level telemetry in local testing (redacted) |
| License contradiction and public patent disclosure | P0 | Governance/IP | Owner/counsel review, source/license timeline, independent prior-art chart |
| Remote fallback leaks location/route | P0 | Navigator | Explicit user choice + offline local preference; exact privacy flow matrix |
| Too many reward writers / stale state | P1 | Game engine | One idempotent ledger and schema migration/rollback tests |
| Synthetic meetings mistaken for real | P1 | Navigator | Demo-only labeling and routing prohibition |
| Stale transit service and weather | P1 | Navigator | Provenance and freshness on every result/overlay |
| Storage-heavy offline maps and GTFS | P1 | Performance | Region prefetch, quotas, content validation, licit tile packs, eviction policy |
| Unsupported older Android phones | P1 | SDK integration | MinSdk audit; document device floor before adding Kotlin SDK |
| Social reward coercion / shame | P1 | UX/clinical | Plain-language safety review and non-gamified opt-out; no sober day rankings |
| No independent impact evidence | P2 | Product evaluation | Usability pilot; no claims of relapse reduction without appropriate study |

## Escalation criteria

Stop before implementation and request an owner decision if an agent would need to: change `LICENSE` or copyright holder; raise minSdk; delete/migrate existing user data; rewrite Firebase security rules without emulator tests; add analytics or change privacy defaults; introduce new recurring costs/cloud providers; touch Metro code from the Recovery for All worktree; replace the established Flutter map; or materially change rehabilitation guidance/clinical claims.
