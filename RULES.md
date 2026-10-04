# RULES.md — Recovery for All Operating Law
> **CANONICAL RULESET.** Every session MUST read this file before doing any work.
> If any other document contradicts this file, THIS FILE WINS.

---

## 1. ABSOLUTE RULES (never violated, no exceptions)

### 1.1 External directories are READ-ONLY
Never create, modify, move, or delete ANYTHING under these paths:
```
C:\pathfinder_god
C:\Sovereign Nodes
C:\sovereign_mantle
C:\sovereign_tagger_2
C:\sovereign_tagger_bak
```
- Any folder matching `sovereign_tagger*` is READ-ONLY regardless of name or state.
- Reading and copying FROM them into `C:\Recovery for All` is allowed and encouraged — Sovereign Mantle is a goldmine for advanced patterns (LandSectorView, HybridTileScheme, TilePack, etc.).
- `sovereign_tagger_2` may be renamed back to `sovereign_tagger` at any time by the user — treat both names as read-only permanently.
- The ONLY writable work area is `C:\Recovery for All`.
- When in doubt: copy out, edit inside.

### 1.2 Secrets and commercial data never enter the repo
- Never commit: `.env`, API keys, keystores (`*.keystore`, `debug.keystore`), `local.properties`.
- `android/app/google-services.json` is gitignored — it stays on the user's machine only.
- Commercial or licensed content (AA literature beyond public-domain step text, Coyhis Publishing meditations) is LINKED, never reproduced.

### 1.3 Git discipline
- **Stage by explicit path only.** `git add -A` / `git add .` are FORBIDDEN.
- Commits happen as part of an approved session workflow; never force-push, rebase public history, or delete branches unless explicitly asked.
- Commit messages: analyze/test status only; NEVER claim build success (the human builds in Android Studio).

### 1.4 Synthetic data only
- Never include real person names, real addresses, or personal data in committed source code or tests. Use `SAMPLE` prefix for fictional meeting/housing entries.
- Recovery meeting data from live feeds (aaMinnesota, BMLT) is fetched at runtime, not committed.
- `android/app/google-services.json` is gitignored — it exists on disk for the build to read, never in history.

### 1.5 Build boundary
- **Builds are PRE-AUTHORIZED.** On 2026-09-30 the user granted **standing
  permission** to build binaries without asking again: `flutter build apk
  --debug`, `flutter build appbundle --release`, and signed release bundles
  using `android/key.properties` + `upload-keystore.jks`. Do not re-request
  build authorization. The `flutter pub get` → `flutter analyze` → `flutter
  test` sequence remains the **end-of-plan** gate batch; see SHELL DISCIPLINE
  below for when it runs. Builds still happen only in the end-of-plan batch —
  authorization to build is not permission to build mid-plan. Release signing
  keys are never committed; `build/` is gitignored.
- **Cadence, not permission:** `flutter pub get`, `flutter analyze` (must be "No issues found"), and `flutter test` are the end-of-plan gates. They run **once, batched, after the whole plan is finished** — not between steps, not to "just check" an edit. `AGENTS.md` "SHELL DISCIPLINE" is binding and has the intent→tool routing table. This clause previously said only that these are "your gates", which read as licence to run them per-feature; §1.7 below is the cadence.

### 1.6 Nothing outside the project without approval
Do not install software, modify system settings, or write to new locations outside `C:\Recovery for All` without asking the user first.
- Approved exception: `C:\venv-hub` / `.venv-tf` Python environments (installing packages INTO them is allowed).

---

## 1A. CONTEXT & OUTPUT DISCIPLINE (from CLAUDE.md)

- Filter all terminal output; pipe for failures only (`Select-String "error|fail"`), never ingest passing noise.
- No massive file reads — probe large JSON/data files with short Python scripts instead.
- **No testing mid-plan, at all — not even targeted.** This line previously read
  "Targeted verification only during development; full test suite reserved for
  staged-commit verification," and it was the last surviving licence for the
  habit that caused L21's four regressions: a single surviving "permitted"
  clause is enough to reopen it. There is no cheap version of running a gate;
  see `AGENTS.md` SHELL DISCIPLINE and `CLAUDE.md` §1.
- Spawn subagents for deep exploration when available; return summaries, not raw dumps.
- Proactively compact context after each verified+committed phase.

---

## 2. PROJECT CONVENTIONS

1. **Full code only** — no partial snippets, no TODO stubs.
2. **Genesis header** every `.dart` file must carry:
   ```
   // ============================================================
   // As Above, So Below. As Within, So Without.
   // The Future Dictates the Past and the Past is Always Present.
   // ============================================================
   ```
3. **Minnesota-first doctrine**: fallbacks center Twin Cities; MN feeds first; other states are additive. The meeting finder, resources, and sober housing all reflect this.
4. **Tailoring doctrine**: onboarding choices drive the dashboard, meeting fellowships, and downloads. Never show the user everything — show what they chose.
5. **No emoji in the avatar composite** — the companion is painted via `AvatarPainter` (procedural vector). Emoji survive only as dresser grid thumbnails and minor glyphs. Full custom art destination: see `blueprints/avatar-art-spec.md`.
6. **Safety pipeline is untouchable**: guardrail → crisis keywords → model (GGUF, output re-checked) → TFLite intent → scripted skills → keyword fallback → unknown redirect. Never reorder. Never let a model suppress a crisis path — a crisis-worded or empty model reply is discarded so the scripted coach still answers.
7. **Pet never dies, never gets sad, never guilts.** Low activity = resting. Return after absence = welcomed. Loss in minigames = "learned something" +Bond, no punishment.
8. **Cosmetics only**: Sparks buy outfits/species/auras. Never gate safety, meetings list, or crisis tools behind currency.

---

## 3. TECHNICAL LAWS (learned the hard way)

| Law | Rule |
|-----|------|
| PowerShell UTF-8 | NEVER round-trip source files through `Get-Content | Set-Content` without `-Encoding UTF8` — ANSI decode mangles emoji/·/— into mojibake. Use the file tools or Python with `io.open(..., encoding='utf-8', newline='\n')`. Console showing `Ã°Å¸` is display-only; verify with strict Python read. |
| Drift schema | Currently **v13** (v10 `fellowship_syncs`, v11 `active_raids`, v12 seven `@TableIndex` annotations, v13 the fellowship attestation columns `peerKeyB64`/`attested`/`role` + `idx_sync_key_ts`). Schema edit = bump `schemaVersion` AND add `if (from < N)` migration block, then `dart run build_runner build --delete-conflicting-outputs`. Never edit `recovery_database.g.dart` by hand. v9 added `equippedSlotsJson/pathLevel/pathXp` (R28); v12's block is the index template, v13's is the nullable-column template. |
| SQLCipher | Uses `sqlcipher_flutter_libs 0.6.8` + `sqlite3 ^2.9.4` (pinned). The `sqlite3mc` native-assets experiment and `sqlcipher_flutter_libs 0.7.0+eol` (empty shell) are DEAD ENDS — do not revisit. sqlite3 3.x line ships cipher natively = future migration path. |
| TensorFlow | System Python is 3.14 → no TF wheels. Coach-model training uses `.venv-tf` (Python 3.12 via uv): `python -m uv venv .venv-tf --python 3.12` → `uv pip install --python .venv-tf numpy tensorflow-cpu`. Model artifacts in `assets/models/` ARE committed. |
| Analyzer scope | `analysis_options.yaml` excludes `Recovery-for-All-main/` (archived upstream, gitignored and currently absent — the exclude is a harmless no-op) and platform dirs. `flutter analyze` must stay at zero issues. Don't loosen excludes. |
| Prefs keys | `meeting_search_radius_miles_v1` (`lib/core/meeting_radius_logic.dart`) is load-bearing — it is what stops the dashboard meeting card falling back to statewide results. It is in `verify_invariants.py`'s `REQUIRED_KEYS`; if you rename it, rename it there in the same commit. |
| Code package | `blueprints/recovery_all_code.md` is generated by `tools/generate_code_package.py`. Never hand-edit. Regenerate after code changes. |
| flutter_map v8 | Uses `latlong2 ^0.9.1` (pinned for marker_cluster compat). `TileLayer` requires named params in v22+ FLN. Stacked layers = multiple `TileLayer` children in `FlutterMap`. |
| FLN 22 | `initialize()`, `show()`, `zonedSchedule()` all use NAMED parameters. `uiLocalNotificationDateInterpretation` REMOVED. `desugar_jdk_libs` must be ≥ 2.1.5. |
| TFLite | Model is 14–24KB INT8, trained via `tools/train_coach_intent.py` in `.venv-tf`. Masked-mean pooling required (pad tokens must not dilute). Float token IDs in, cast to int32 inside graph. |
| Firebase | `google-services.json` is gitignored. Gradle plugin activates conditionally (only when file exists). `Firebase.initializeApp()` guarded with try/catch + 8s timeout. |
| Snackbars | Global theme in `main.dart` — white text on dark bg, floating, rounded. Never override with invisible colors. |
| Emojis | NO new emoji features. Custom art is the destination (`blueprints/avatar-art-spec.md`). Emoji only as temporary dresser thumbnails. |

---

## 4. WORKFLOW LAW

### 4.1 Cold start (every session, in order)
1. Read `AGENTS.md`
2. Read THIS file (`RULES.md`)
3. Read `blueprints/roadmap-v2.md` → current tier
4. Check `blueprints/SPRINT_PLAN.md` status block for latest state (historical; gitignored)

### 4.2 Session end (every session)
1. Finish the entire plan first. No shell ran during it (§1.5, `AGENTS.md` SHELL DISCIPLINE).
2. **Then**, in one batched shell block: `flutter analyze` + `flutter test` + `python tools/verify_no_hardcoded_colors.py` + `python tools/verify_invariants.py`
3. Run `python tools/generate_code_package.py`
4. Tick relevant `blueprints/*.md` checklists
5. Device checklist, if the plan called for one — also batched into the same end pass
6. Commit code by explicit path with a descriptive message

### 4.3 Verification law
No feature is *reported done* until `flutter analyze` reports zero issues AND `flutter test` passes — and those two numbers are collected **once, at the end**, not per feature. Evidence before status flips; the evidence is a single end-of-plan run, and a run is only meaningful if it is the one that closes the plan. Mid-plan runs produce stale signal that must then be re-derived, and they are what turns a three-day plan into a three-day wait.

### 4.4 Scope law
Big ideas go into `blueprints/roadmap-v2.md` with phased plans first. Ship vertical slices; never let polish precede a working build.

### 4.5 Reference law
Sovereign Mantle directories are REFERENCE ONLY. Read their code for patterns and inspiration, but every line written for Recovery for All must be authored in this repo, tailored to this project's needs. Credit the source in comments where a pattern is directly inspired.
