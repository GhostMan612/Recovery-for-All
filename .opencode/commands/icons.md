---
description: Regenerate launcher icons (adaptive circle)
---
Run `dart run flutter_launcher_icons` from the repo root.

Source is `assets/images/app_icon_circle.png` (circular, full-bleed
adaptive background + foreground). Confirm it reports "Successfully
generated launcher icons" and that `android/app/src/main/res/mipmap-*/`
files changed. The launcher icon must fill the mask edge-to-edge —
if a square-in-circle appears, the adaptive_icon config in pubspec.yaml
regressed.
