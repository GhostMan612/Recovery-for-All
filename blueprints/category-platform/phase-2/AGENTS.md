# Phase 2 Agent Scope

Follow RFA `RULES.md`, `AGENTS.md`, `SESSION_HANDOFF.md`, Phase 0 privacy gate, and Metro `docs/SDK_INTEGRATION.md` from the active `master` branch. **Read Metro only; do not edit, publish to remote, or rewrite it** within RFA work orders.

Start with isolated SDK feasibility: check Gradle tooling, Flutter channel, artifacts and minSdk. Use a locally published versioned Maven artifact, not unpublished GitHub branch source. Keep alternative `no Atlas` path so RFA still boots and the old map can show meeting data.

All network actions must be consented and auditable. No hidden remote OTP call. No SAMPLE meeting treated as real. No claim that a tilepack gives offline routing. Verify result bounds, malformed native payloads, no GPS leakage and human-device transit behavior. Do not silently add app permission or raise minSdk without explicit owner approval.
