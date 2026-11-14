# media/game-art/craving_wraith_generator.py
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

"""
Blender 3D Procedural Generator & Sprite Atlas Baker for Craving Wraith.
Generates the original stylized low-poly 3D mesh, ethereal materials,
animation actions, and renders a 16-frame transparent 4x4 sprite atlas (1024x1024).

Usage:
  blender --background --python media/game-art/craving_wraith_generator.py
"""

import bpy
import math
import os
import sys

def hex_to_rgba(hex_str, alpha=1.0):
    hex_str = hex_str.lstrip('#')
    r = int(hex_str[0:2], 16) / 255.0
    g = int(hex_str[2:4], 16) / 255.0
    b = int(hex_str[4:6], 16) / 255.0
    def to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (to_linear(r), to_linear(g), to_linear(b), alpha)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in bpy.data.collections:
        bpy.data.collections.remove(c)
    scene = bpy.context.scene
    col = bpy.data.collections.new("CravingWraithCollection")
    scene.collection.children.link(col)
    return col

def make_ethereal_material(name, hex_color, alpha=0.88, emission_hex=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.blend_method = 'BLEND' if hasattr(mat, 'blend_method') else 'HASHED'
    nodes = mat.node_tree.nodes
    nodes.clear()

    node_bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    node_bsdf.inputs['Base Color'].default_value = hex_to_rgba(hex_color)
    node_bsdf.inputs['Roughness'].default_value = 0.4
    if 'Alpha' in node_bsdf.inputs:
        node_bsdf.inputs['Alpha'].default_value = alpha

    if emission_hex and emission_strength > 0:
        if 'Emission Color' in node_bsdf.inputs:
            node_bsdf.inputs['Emission Color'].default_value = hex_to_rgba(emission_hex)
            node_bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in node_bsdf.inputs:
            node_bsdf.inputs['Emission'].default_value = hex_to_rgba(emission_hex)

    node_output = nodes.new(type='ShaderNodeOutputMaterial')
    mat.node_tree.links.new(node_bsdf.outputs['BSDF'], node_output.inputs['Surface'])
    return mat

def build_craving_wraith_model(collection):
    # Palette: Smoky Slate (#475569), Deep Shadow (#1E293B), Mist Rim (#94A3B8), Soft White Glow (#FFFFFF)
    mat_shroud = make_ethereal_material("Mat_WraithShroud", "#475569", alpha=0.92)
    mat_inner_void = make_ethereal_material("Mat_WraithVoid", "#0F172A", alpha=1.0)
    mat_wisps = make_ethereal_material("Mat_WraithWisps", "#64748B", alpha=0.72)
    mat_eyes = make_ethereal_material("Mat_WraithEyes", "#FFFFFF", alpha=1.0, emission_hex="#FFFFFF", emission_strength=4.5)

    # Hood / Mantle (faceted low-poly cone/pyramid)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.48, depth=0.85, location=(0, 0, 1.45), rotation=(0, 0, math.radians(25)))
    hood = bpy.context.active_object
    hood.name = "Wraith_Hood"
    hood.scale = (1.0, 0.9, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    hood.data.materials.append(mat_shroud)

    # Inner Void of Hood (face darkness)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.24, location=(0, -0.16, 1.35))
    void = bpy.context.active_object
    void.name = "Wraith_Void"
    void.scale = (0.9, 0.6, 1.1)
    bpy.ops.object.transform_apply(scale=True)
    void.data.materials.append(mat_inner_void)

    # Soft glowing white eyes inside the hood void
    for sign, side in [(-1, "L"), (1, "R")]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.038, location=(sign * 0.10, -0.26, 1.38))
        eye = bpy.context.active_object
        eye.name = f"Wraith_Eye_{side}"
        eye.data.materials.append(mat_eyes)

    # Flowing torso / cloak body
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.38, depth=0.80, location=(0, 0.05, 0.85))
    body = bpy.context.active_object
    body.name = "Wraith_Torso"
    body.scale = (1.0, 0.75, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat_shroud)

    # Floating trailing wisps / ribbons (replacing legs, symbolic dissipation)
    wisp_coords = [
        (-0.20, 0.0, 0.35, -15),
        (-0.06, -0.12, 0.28, 5),
        (0.08, 0.10, 0.30, -8),
        (0.22, -0.04, 0.32, 18),
    ]
    for idx, (wx, wy, wz, w_rot) in enumerate(wisp_coords):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.14, depth=0.65, location=(wx, wy, wz), rotation=(math.radians(w_rot), 0, math.radians(idx * 40)))
        wisp = bpy.context.active_object
        wisp.name = f"Wraith_Wisp_{idx}"
        wisp.data.materials.append(mat_wisps)

    # Join into master object
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.context.view_layer.objects.active = hood
    bpy.ops.object.join()
    wraith_char = bpy.context.active_object
    wraith_char.name = "CravingWraith_Character"
    return wraith_char

def setup_camera_and_lighting(scene):
    # Ethereal, moody atmospheric lighting (rim-lit, cool tones)
    light_key_data = bpy.data.lights.new(name="Light_MoonKey", type='SUN')
    light_key_data.energy = 3.2
    light_key_data.color = (0.75, 0.82, 1.0)
    light_key = bpy.data.objects.new("Light_MoonKey", light_key_data)
    light_key.rotation_euler = (math.radians(55), math.radians(-15), math.radians(45))
    scene.collection.objects.link(light_key)

    light_rim_data = bpy.data.lights.new(name="Light_EtherealRim", type='SUN')
    light_rim_data.energy = 5.0
    light_rim_data.color = (0.9, 0.95, 1.0)
    light_rim = bpy.data.objects.new("Light_EtherealRim", light_rim_data)
    light_rim.rotation_euler = (math.radians(-40), math.radians(30), math.radians(-135))
    scene.collection.objects.link(light_rim)

    # Camera setup (Hero front-quarter framing)
    cam_data = bpy.data.cameras.new(name="Camera_Wraith")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 3.0
    cam_obj = bpy.data.objects.new("Camera_Wraith", cam_data)
    cam_obj.location = (1.8, -3.0, 1.8)
    cam_obj.rotation_euler = (math.radians(65), 0, math.radians(30))
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def create_animation_actions(char_obj):
    """
    Creates 3 distinct animation sequences for Craving Wraith:
      Frames 1-8:   Idle (undulating floating levitation + misty tilt)
      Frames 9-12:  Hit  (recoil stagger + pulse)
      Frames 13-16: Fade (peaceful gentle dissipation into mist)
    """
    char_obj.animation_data_create()
    action = bpy.data.actions.new(name="CravingWraith_Actions")
    char_obj.animation_data.action = action

    # Idle: frames 1 to 8 (levitation floating wave)
    for f in range(1, 9):
        t = (f - 1) / 7.0
        float_z = math.sin(t * math.pi * 2) * 0.08
        tilt_x = math.sin(t * math.pi * 2) * 0.04
        waver_y = math.cos(t * math.pi * 2) * 0.03
        char_obj.location = (waver_y, 0, float_z)
        char_obj.rotation_euler = (tilt_x, 0, 0)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

    # Hit: frames 9 to 12 (recoil back + upward stagger)
    for idx, f in enumerate(range(9, 13)):
        t = idx / 3.0
        recoil_y = math.sin(t * math.pi) * 0.16
        recoil_z = math.sin(t * math.pi) * 0.06
        char_obj.location = (0, recoil_y, recoil_z)
        char_obj.rotation_euler = (math.sin(t * math.pi) * -0.12, 0, 0)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

    # Fade / Dissipation: frames 13 to 16 (dissolving gracefully upward)
    for idx, f in enumerate(range(13, 17)):
        t = idx / 3.0
        lift_z = t * 0.22
        scale_fade = max(0.2, 1.0 - t * 0.65)
        char_obj.location = (0, 0, lift_z)
        char_obj.scale = (scale_fade, scale_fade, scale_fade)
        char_obj.rotation_euler = (0, 0, t * 0.20)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="scale", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

def render_and_pack_atlas(output_dir, atlas_filename="craving_wraith_v1.png"):
    """
    Renders 16 frames and composites them into a 4x4 1024x1024 sprite atlas.
    """
    scene = bpy.context.scene
    temp_frames = []
    os.makedirs(output_dir, exist_ok=True)

    print("Rendering 16 animation frames for Craving Wraith...")
    for frame_idx in range(1, 17):
        scene.frame_set(frame_idx)
        frame_path = os.path.join(output_dir, f"_temp_wraith_{frame_idx:02d}.png")
        scene.render.filepath = frame_path
        bpy.ops.render.render(write_still=True)
        temp_frames.append(frame_path)

    atlas_path = os.path.join(output_dir, atlas_filename)
    try:
        from PIL import Image
        atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        for i, fpath in enumerate(temp_frames):
            row = i // 4
            col = i % 4
            im = Image.open(fpath)
            atlas.paste(im, (col * 256, row * 256))
            im.close()
            os.remove(fpath)
        atlas.save(atlas_path, "PNG", optimize=True)
        print(f"SUCCESS: Baked Craving Wraith 1024x1024 16-frame atlas to {atlas_path}")
    except ImportError:
        print("PIL not available in Blender Python. Individual frames saved. Atlas stitching requires Pillow.")

def main():
    col = clear_scene()
    char = build_craving_wraith_model(col)
    setup_camera_and_lighting(bpy.context.scene)
    create_animation_actions(char)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    blend_path = os.path.join(script_dir, "craving_wraith_v1.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"SUCCESS: Saved Craving Wraith master model to {blend_path}")

    repo_root = os.path.dirname(os.path.dirname(script_dir))
    sprite_dir = os.path.join(repo_root, "assets", "game", "sprites")
    render_and_pack_atlas(sprite_dir, "craving_wraith_v1.png")

if __name__ == "__main__":
    main()
