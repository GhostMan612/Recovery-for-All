# media/game-art/ember_kit_generator.py
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

"""
Blender 3D Procedural Generator & Sprite Atlas Baker for Ember Kit.
Generates the original stylized low-poly 3D mesh, armature, materials,
animation actions, and renders a 16-frame transparent 4x4 sprite atlas (1024x1024).

Usage:
  blender --background --python media/game-art/ember_kit_generator.py
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
    # sRGB to linear conversion for Blender
    def to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (to_linear(r), to_linear(g), to_linear(b), alpha)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in bpy.data.collections:
        bpy.data.collections.remove(c)
    scene = bpy.context.scene
    col = bpy.data.collections.new("EmberKitCollection")
    scene.collection.children.link(col)
    return col

def make_material(name, hex_color, roughness=0.6, specular=0.2):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    node_bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    node_bsdf.inputs['Base Color'].default_value = hex_to_rgba(hex_color)
    node_bsdf.inputs['Roughness'].default_value = roughness
    if 'Specular IOR Level' in node_bsdf.inputs:
        node_bsdf.inputs['Specular IOR Level'].default_value = specular
    elif 'Specular' in node_bsdf.inputs:
        node_bsdf.inputs['Specular'].default_value = specular
    node_output = nodes.new(type='ShaderNodeOutputMaterial')
    mat.node_tree.links.new(node_bsdf.outputs['BSDF'], node_output.inputs['Surface'])
    return mat

def build_ember_kit_model(collection):
    mat_base = make_material("Mat_EmberBase", "#F59E0B", roughness=0.55)      # Amber Orange
    mat_shade = make_material("Mat_EmberShade", "#C2410C", roughness=0.6)     # Burnt Orange
    mat_belly = make_material("Mat_EmberBelly", "#FDE68A", roughness=0.7)     # Cream Highlight
    mat_eyes = make_material("Mat_EmberEyes", "#0F172A", roughness=0.1, specular=0.9) # Dark Glint
    mat_catch = make_material("Mat_EmberCatch", "#FFFFFF", roughness=0.0)

    # Torso (rounded low-poly block)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.75))
    torso = bpy.context.active_object
    torso.name = "EmberKit_Torso"
    torso.scale = (0.55, 0.45, 0.50)
    bpy.ops.object.transform_apply(scale=True)
    torso.data.materials.append(mat_base)

    # Belly Patch
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.22, 0.72))
    belly = bpy.context.active_object
    belly.name = "EmberKit_Belly"
    belly.scale = (0.36, 0.08, 0.38)
    bpy.ops.object.transform_apply(scale=True)
    belly.data.materials.append(mat_belly)

    # Head
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.05, 1.35))
    head = bpy.context.active_object
    head.name = "EmberKit_Head"
    head.scale = (0.65, 0.55, 0.52)
    bpy.ops.object.transform_apply(scale=True)
    head.data.materials.append(mat_base)

    # Muzzle / Snout
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.22, depth=0.28, location=(0, -0.42, 1.25), rotation=(math.radians(90), 0, 0))
    muzzle = bpy.context.active_object
    muzzle.name = "EmberKit_Muzzle"
    muzzle.scale = (0.9, 0.8, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    muzzle.data.materials.append(mat_belly)

    # Ears (Fox pointed ears, tilted inward)
    for sign, side in [(-1, "L"), (1, "R")]:
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.18, depth=0.48, location=(sign * 0.24, -0.02, 1.82), rotation=(0, sign * math.radians(-16), 0))
        ear = bpy.context.active_object
        ear.name = f"EmberKit_Ear_{side}"
        ear.data.materials.append(mat_base)

        # Inner ear
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.10, depth=0.34, location=(sign * 0.22, -0.08, 1.80), rotation=(0, sign * math.radians(-16), 0))
        inner_ear = bpy.context.active_object
        inner_ear.name = f"EmberKit_InnerEar_{side}"
        inner_ear.data.materials.append(mat_shade)

    # Eyes
    for sign, side in [(-1, "L"), (1, "R")]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.07, location=(sign * 0.16, -0.32, 1.38))
        eye = bpy.context.active_object
        eye.name = f"EmberKit_Eye_{side}"
        eye.scale = (1.0, 0.4, 1.2)
        bpy.ops.object.transform_apply(scale=True)
        eye.data.materials.append(mat_eyes)

        # Catchlight
        bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.022, location=(sign * 0.145, -0.35, 1.42))
        catch = bpy.context.active_object
        catch.name = f"EmberKit_Catch_{side}"
        catch.data.materials.append(mat_catch)

    # Bushy Fox Tail
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.26, depth=0.65, location=(0, 0.42, 0.95), rotation=(math.radians(-55), 0, 0))
    tail = bpy.context.active_object
    tail.name = "EmberKit_Tail"
    tail.data.materials.append(mat_shade)

    # Paws
    for x_sign, side in [(-1, "L"), (1, "R")]:
        for y_pos, f_or_b in [(-0.16, "F"), (0.16, "B")]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.10, depth=0.45, location=(x_sign * 0.20, y_pos, 0.25))
            paw = bpy.context.active_object
            paw.name = f"EmberKit_Leg_{f_or_b}{side}"
            paw.data.materials.append(mat_shade)

    # Join meshes into one master character
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.join()
    ember_char = bpy.context.active_object
    ember_char.name = "EmberKit_Character"
    return ember_char

def setup_camera_and_lighting(scene):
    # Studio 3-point warm lighting
    light_key_data = bpy.data.lights.new(name="Light_Key", type='SUN')
    light_key_data.energy = 4.0
    light_key_data.color = (1.0, 0.95, 0.85)
    light_key = bpy.data.objects.new("Light_Key", light_key_data)
    light_key.rotation_euler = (math.radians(45), math.radians(20), math.radians(-35))
    scene.collection.objects.link(light_key)

    light_fill_data = bpy.data.lights.new(name="Light_Fill", type='SUN')
    light_fill_data.energy = 1.8
    light_fill_data.color = (0.7, 0.85, 1.0)
    light_fill = bpy.data.objects.new("Light_Fill", light_fill_data)
    light_fill.rotation_euler = (math.radians(50), math.radians(-30), math.radians(130))
    scene.collection.objects.link(light_fill)

    # Camera setup (Hero framing, front-three-quarter isometric angle)
    cam_data = bpy.data.cameras.new(name="Camera_Hero")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 3.2
    cam_obj = bpy.data.objects.new("Camera_Hero", cam_data)
    cam_obj.location = (2.2, -3.2, 2.4)
    cam_obj.rotation_euler = (math.radians(60), 0, math.radians(35))
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    # Render settings: 256x256 per frame, transparent film
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def create_animation_actions(char_obj):
    """
    Creates 3 distinct animation sequences:
      Frames 1-8:   Idle (gentle breathing bob + tail curl)
      Frames 9-12:  Joy  (happy bounce + ear perk)
      Frames 13-16: Rest (peaceful settling/dip)
    """
    char_obj.animation_data_create()
    action = bpy.data.actions.new(name="EmberKit_Actions")
    char_obj.animation_data.action = action

    # Keyframes for 16 frames (1-indexed)
    # Idle: frames 1 to 8
    for f in range(1, 9):
        t = (f - 1) / 7.0
        bob = math.sin(t * math.pi * 2) * 0.04
        rot = math.sin(t * math.pi * 2) * 0.03
        char_obj.location = (0, 0, bob)
        char_obj.rotation_euler = (0, 0, rot)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

    # Joy: frames 9 to 12
    for idx, f in enumerate(range(9, 13)):
        t = idx / 3.0
        jump = math.sin(t * math.pi) * 0.18
        char_obj.location = (0, 0, jump)
        char_obj.rotation_euler = (0, math.sin(t * math.pi * 2) * 0.08, 0)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

    # Rest: frames 13 to 16
    for idx, f in enumerate(range(13, 17)):
        t = idx / 3.0
        settle = -0.06 + math.sin(t * math.pi * 2) * 0.02
        char_obj.location = (0, 0, settle)
        char_obj.rotation_euler = (0.05, 0, 0)
        char_obj.keyframe_insert(data_path="location", frame=f)
        char_obj.keyframe_insert(data_path="rotation_euler", frame=f)

def render_and_pack_atlas(output_dir, atlas_filename="ember_kit_v1.png"):
    """
    Renders 16 frames and composites them into a 4x4 1024x1024 sprite atlas.
    """
    scene = bpy.context.scene
    temp_frames = []
    os.makedirs(output_dir, exist_ok=True)

    print("Rendering 16 animation frames for Ember Kit...")
    for frame_idx in range(1, 17):
        scene.frame_set(frame_idx)
        frame_path = os.path.join(output_dir, f"_temp_ember_{frame_idx:02d}.png")
        scene.render.filepath = frame_path
        bpy.ops.render.render(write_still=True)
        temp_frames.append(frame_path)

    # Composite into 1024x1024 4x4 atlas using Pillow if available
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
        print(f"SUCCESS: Baked Ember Kit 1024x1024 16-frame atlas to {atlas_path}")
    except ImportError:
        print("PIL not available in Blender Python. Individual frames saved. Atlas stitching requires Pillow.")

def main():
    col = clear_scene()
    char = build_ember_kit_model(col)
    setup_camera_and_lighting(bpy.context.scene)
    create_animation_actions(char)

    # Save .blend master source
    script_dir = os.path.dirname(os.path.abspath(__file__))
    blend_path = os.path.join(script_dir, "ember_kit_v1.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"SUCCESS: Saved Ember Kit master model to {blend_path}")

    # Output sprite directory
    repo_root = os.path.dirname(os.path.dirname(script_dir))
    sprite_dir = os.path.join(repo_root, "assets", "game", "sprites")
    render_and_pack_atlas(sprite_dir, "ember_kit_v1.png")

if __name__ == "__main__":
    main()
