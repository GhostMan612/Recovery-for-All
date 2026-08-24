---
description: Commit changed files by explicit path with gates
---
You are committing changes for the user. Steps:

1. Run `git status --short` and show the user what changed.
2. Ask which files to stage if ambiguous — NEVER `git add .` or `-A`.
3. Stage only the explicitly agreed paths.
4. Run `flutter analyze` and `flutter test` (filtered to failures).
5. Commit with a concise imperative message. The message may state
   analyze/test status but must NEVER claim build success.

Arguments (optional): $ARGUMENTS — explicit paths to stage.
