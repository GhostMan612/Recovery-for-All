---
description: Run the verification gates (analyze + test)
---
Run the project verification gates in order:

1. `flutter pub get`
2. `flutter analyze` — must report **No issues found** (the archived
   `Recovery-for-All-main/` copy is excluded; if errors appear only from
   that path, the exclude regressed — fix `analysis_options.yaml`)
3. `flutter test` — all tests must pass

Filter output to failures only (token conservation). Report a compact
summary: analyze status, test count, and any failures with file:line.
NEVER run `flutter build` anything — the human builds in Android Studio.
