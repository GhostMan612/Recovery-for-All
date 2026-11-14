# tools/stitch_atlases.py
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

"""
Stitches 16 rendered 256x256 frames into a 4x4 1024x1024 RGBA sprite atlas.
Requires Pillow (`python -m pip install Pillow`).
"""

import os
import sys

SPRITE_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets",
    "game",
    "sprites",
)


def stitch_with_pil():
    from PIL import Image

    for prefix, out_name in [
        ("ember", "ember_kit_v1.png"),
        ("wraith", "craving_wraith_v1.png"),
    ]:
        atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        temp_files = []
        for i in range(1, 17):
            fpath = os.path.join(SPRITE_DIR, f"_temp_{prefix}_{i:02d}.png")
            if not os.path.exists(fpath):
                print(f"Warning: {fpath} does not exist.")
                continue
            im = Image.open(fpath)
            row = (i - 1) // 4
            col = (i - 1) % 4
            atlas.paste(im, (col * 256, row * 256))
            im.close()
            temp_files.append(fpath)

        out_path = os.path.join(SPRITE_DIR, out_name)
        atlas.save(out_path, "PNG", optimize=True)
        size_kb = os.path.getsize(out_path) / 1024.0
        print(f"STITCHED: {out_name} ({size_kb:.1f} KB, 1024x1024 RGBA)")

        # Clean up temp frames
        for f in temp_files:
            try:
                os.remove(f)
            except OSError:
                pass


def main():
    try:
        stitch_with_pil()
    except ImportError:
        print("Pillow is required: python -m pip install Pillow")
        sys.exit(1)


if __name__ == "__main__":
    main()
