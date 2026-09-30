---
description: Commit changed files by explicit path with gates
---
You are committing changes for the user. Steps:

1. Run `git status --short` and show the user what changed.
2. Ask which files to stage if ambiguous — NEVER `git add .` or `-A`.
3. Stage only the explicitly agreed paths.
4. If the end-of-plan gate batch has not been run yet in this session, run it
   now as part of this command: `flutter analyze` and `flutter test` (filtered
   to failures). Do not assume a previous mid-plan run is still valid — the
   result goes stale with the next edit. See `AGENTS.md` "SHELL DISCIPLINE".
5. Commit with a concise imperative message. The message may state
   analyze/test status but must NEVER claim build success.

Arguments (optional): $ARGUMENTS — explicit paths to stage.
