# Agent Handoff — Phase 2

Start with `WO-2A` only: consume *already-built local* Atlas SDK and prove MethodChannel fixture; no map UI rewrite, no network permission changes, no changes in Metro repo. If new Atlas SDK API required, stop and record an upstream issue/proposal instead of patching its internals from RFA.

**Required report:** source branch+SHA; exact SDK Maven artifact/dependency versions and license; ABI/minSdk matrix; methods/error schema used; who provides GTFS and whether routing actually works; exact network logs by opt-in mode; synthetic fixture tests; RFA regression tests; Android Studio/device status; owner decisions for external OTP and offline map package terms.

Then implement 2B (destination integrity) and 2C (user-facing navigation) under separate diffs with acceptance matrix evidence. Legacy meeting finder must function if Atlas is disabled.
