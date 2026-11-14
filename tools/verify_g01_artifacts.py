# tools/verify_g01_artifacts.py
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

import os
from PIL import Image

artifacts = [
    "media/game-art/ember_kit_v1.blend",
    "media/game-art/craving_wraith_v1.blend",
    "assets/game/sprites/ember_kit_v1.png",
    "assets/game/sprites/craving_wraith_v1.png",
]

print("=== G-01 ARTIFACT VERIFICATION ===")
all_pass = True
for p in artifacts:
    if not os.path.exists(p):
        print(f"FAIL: {p} does not exist.")
        all_pass = False
        continue
    sz = os.path.getsize(p)
    print(f"FILE: {p} ({sz:,} bytes / {sz/1024:.1f} KB)")
    if p.endswith(".png"):
        im = Image.open(p)
        w, h = im.size
        mode = im.mode
        extrema = im.getextrema()
        # Alpha channel is the 4th channel
        alpha_min = extrema[3][0]
        alpha_max = extrema[3][1]
        print(f"  Dimensions: {w}x{h} px")
        print(f"  Mode: {mode}")
        print(f"  Alpha Range: min={alpha_min}, max={alpha_max} (has transparency: {alpha_min == 0})")
        if w != 1024 or h != 1024:
            print(f"  FAIL: Expected 1024x1024, got {w}x{h}")
            all_pass = False
        if mode != "RGBA":
            print(f"  FAIL: Expected RGBA mode, got {mode}")
            all_pass = False
        if alpha_min != 0:
            print("  FAIL: Expected transparent pixels (alpha min == 0)")
            all_pass = False

if all_pass:
    print("SUCCESS: All G-01 artifacts verified.")
else:
    print("FAILURE in G-01 verification.")
