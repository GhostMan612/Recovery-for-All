# media/game-art/README.md
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

# Recovery for All — 3D Character Art Source Pipeline (G-01 Pilot)

## Overview
This directory contains the authoritative 3D procedural generator scripts and master scene definitions for:
1. **Ember Kit** (`ember_kit_generator.py` -> `ember_kit_v1.blend`) — The flagship canine/fox recovery companion.
2. **Craving Wraith** (`craving_wraith_generator.py` -> `craving_wraith_v1.blend`) — The symbolic Trial monster representing temptation and craving.

## Visual Design & Technical Standards
- **Aesthetic**: Stylized soft low-poly fantasy, clean silhouette contrast, faceted shading, non-violent and non-stigmatizing.
- **Palette**:
  - **Ember Kit**: Amber Orange (`#F59E0B`), Deep Burnt Orange (`#C2410C`), Cream Belly/Muzzle (`#FDE68A`), Dark Eyes (`#0F172A`).
  - **Craving Wraith**: Smoky Slate (`#475569`), Shadow Shroud (`#1E293B`), Translucent Wisps (`#64748B`), Glowing White Eyes (`#FFFFFF`).
- **Rendering Target**: Orthographic hero camera, transparent RGBA film, 256x256 cell rendering packed into a 1024x1024 4x4 atlas (16 frames).

## Execution / Reproducibility
Requirements: Blender 3.6+ (4.x supported) and Pillow for frame stitching
(`python -m pip install Pillow`).

To generate the 3D `.blend` files and bake the sprite atlases directly using Blender:

```bash
# Generate Ember Kit 3D model and 16-frame sprite atlas:
blender --background --python media/game-art/ember_kit_generator.py

# Generate Craving Wraith 3D model and 16-frame sprite atlas:
blender --background --python media/game-art/craving_wraith_generator.py
```

Generated sprite sheets are placed directly into `assets/game/sprites/`.
