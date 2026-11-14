# assets/game/sprites/README.md
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

# Recovery for All — 2D Sprite Atlas Manifest (G-01 Pilot)

## 1. Ownership, Provenance & Licensing
- **Author / Ownership**: Glenn Lee Clark IV · Recovery for All.
- **Originality**: 100% original, stylized low-poly character designs created exclusively for the Recovery for All project.
- **Licensing**: Repository-owned asset suite. Free of third-party copyrighted game characters, commercial asset packs, or unverified licenses.
- **Tone & Ethics**: Compassionate, non-violent, non-stigmatizing fantasy aesthetic. The companion fosters warmth and safety; the Trial enemy represents an internal coping hurdle rather than an adversary to punish.

---

## 2. Technical Specifications & Budgets
| Parameter | Value | Rationale |
|---|---|---|
| Atlas Resolution | 1024 × 1024 px | Native power-of-two texture dimensions for mobile GPU caches |
| Grid Layout | 4 rows × 4 columns (16 cells) | Compact layout for 3 distinct states per character |
| Cell Resolution | 256 × 256 px | Crisp display at 64dp thumbnail up to 240dp stage scale |
| Format | Transparent 32-bit RGBA PNG | Clean alpha channel; no square background halos |
| Compressed Size Budget | ≤ 1.5 MB per atlas | Fast mobile asset loading without app bloat |
| Decoded RAM Budget | ≤ 4.0 MB per atlas (1024×1024×4 bytes) | Safe for Android devices with ≤ 3.0 GB RAM |
| Fallback Mode | Reduced-motion pins Frame 0 | Zero CPU/GPU ticker load when reduced-motion is enabled |

---

## 3. Frame Map: Ember Kit (`ember_kit_v1.png`)
The primary fox/canine recovery companion.

```
Grid Index (0-based, row-major):
[ 0] [ 1] [ 2] [ 3]   <- Idle (Frames 0..3)
[ 4] [ 5] [ 6] [ 7]   <- Idle (Frames 4..7)
[ 8] [ 9] [10] [11]   <- Joy  (Frames 8..11)
[12] [13] [14] [15]   <- Rest (Frames 12..15)
```

- **Idle (Frames 0–7)**: 8 frames. Gentle breathing cycle, tail sway, alert ear micro-movements.
  - Duration: 125 ms / frame (1000 ms full loop).
- **Joy (Frames 8–11)**: 4 frames. Cheerful bounce, perked ears, tail wag on reward / victory.
  - Duration: 100 ms / frame (400 ms one-shot).
- **Rest (Frames 12–15)**: 4 frames. Peaceful curled resting posture for quiet reflection.
  - Duration: 250 ms / frame (1000 ms gentle breathing cycle).
- **Reduced Motion / Static Pose**: Frame 0.

---

## 4. Frame Map: Craving Wraith (`craving_wraith_v1.png`)
The symbolic shadow Trial monster representing restless cravings.

```
Grid Index (0-based, row-major):
[ 0] [ 1] [ 2] [ 3]   <- Idle (Frames 0..3)
[ 4] [ 5] [ 6] [ 7]   <- Idle (Frames 4..7)
[ 8] [ 9] [10] [11]   <- Hit  (Frames 8..11)
[12] [13] [14] [15]   <- Fade (Frames 12..15)
```

- **Idle (Frames 0–7)**: 8 frames. Floating ethereal levitation, undulating misty wisps.
  - Duration: 150 ms / frame (1200 ms full loop).
- **Hit (Frames 8–11)**: 4 frames. Recoil flinch, shock wave dissipation on coping skill strike.
  - Duration: 80 ms / frame (320 ms one-shot).
- **Fade (Frames 12–15)**: 4 frames. Graceful dissipation into mist upon resolution (compassionate victory).
  - Duration: 150 ms / frame (600 ms one-shot).
- **Reduced Motion / Static Pose**: Frame 0.

---

## 5. Export Reproducibility
Source scripts are located in `media/game-art/`:
- `media/game-art/ember_kit_generator.py`
- `media/game-art/craving_wraith_generator.py`

Requires Blender 3.6+ and Pillow for stitching (`python -m pip install Pillow`).

Run via Blender CLI:
```bash
blender --background --python media/game-art/ember_kit_generator.py
blender --background --python media/game-art/craving_wraith_generator.py
```
This builds the 3D meshes, assigns Principled BSDF materials, creates the action timelines, renders the 16 transparent PNGs at 256×256, and stitches them into the final 1024×1024 sprite atlas.
