# Circle Identity, Moderation and Abuse Model

## Threat actors

A curious peer, malicious anonymous account, device owner after reinstall, member who spoofs local SharedPreferences, replaying client, compromised device, abusive reply author, and service operator with access to Firebase-side content. The UI alias does not prove identity and the operator may see metadata even when peers do not.

## Rules of authority

- Remote writes are allowed by authenticated server identity **plus** owner-specific access controls; an anonymous auth UID alone is not universal authorization.
- A server-issued moderator role is enforced by backend rules with auditable authorization. `SharedPreferences` 'moderator mode' may control local UI only and must **never** authorize remote moderation.
- Reactions and quest contributions use immutable actor-bound documents or equivalent trusted dedup. Aggregate counts are derived or server-maintained, not client-incremented without authorization.
- For small private Circles, membership/invitations and removal use cryptographic or server identity binding; never rely solely on alias strings or self-declared codes.
- Transport encryption does not imply end-to-end encryption. A properly vetted E2EE design would require group key lifecycle, device loss, moderation compatibility, consent and recovery; leave as explicit future option.
- Moderation policy has a human staffing/abuse response plan, appeals process, expected response times honestly described, data retention and legal review where needed. Otherwise do not promise real-time safety.

## Community safety defaults

- No public sobriety duration, face/photo requirement, full name, city-specific check-in, meeting attendance map or precise location.
- No leaderboard or public 'neediest/most sober' ranking. Chronological/opt-in sorting only, preserve existing no-score ethos.
- Never compensate or pressure members to describe crisis or relapse details. Support resources pinned to crises where appropriate; no automated medical advice.
- Block/mute/report from any post and membership view; reporting not treated as a game quest.
- Users can remove local drafts, revoke consent, and request remote deletion with clear pending/outcome states. Account deletion behavior and retained moderator audit log disclosed.

## Required red team

Actor A/B moderator tests for create/update/delete/status, alias impersonation, owner switch, replay, blocked user, outbox while logged out, precise location in schema and logs, malformed Unicode/lengths, 100 reactions, corrupted timestamps, mass-report abuse, moderation privilege elevation. Conduct cross-device tests before public beta.
