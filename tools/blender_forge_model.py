# Blender 3.6+ / 4.x — build a simple rigged character from a JSON spec and export glTF + FBX.
# Invoked: blender --background --python blender_forge_model.py -- <spec.json>
import json
import math
import os
import sys

import bpy


def _argv_after_dashes():
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1 :]
    return []


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color, roughness, metallic, tex_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    out = nt.nodes.get("Material Output")
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if tex_path and os.path.isfile(tex_path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(tex_path)
        tex.image = img
        tex.interpolation = "Linear"
        mapping = nt.nodes.new("ShaderNodeMapping")
        texcoord = nt.nodes.new("ShaderNodeTexCoord")
        nt.links.new(texcoord.outputs["UV"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if out:
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def unwrap_front_photo(ob, u_span=0.74):
    """Orthographic front unwrap (X/Z) that fits the left photo strip of the atlas."""
    if ob is None or ob.type != "MESH":
        return
    me = ob.data
    uv_layer = me.uv_layers.active
    if uv_layer is None:
        uv_layer = me.uv_layers.new(name="UVMap")
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    if not xs or not zs:
        return
    minx, maxx = min(xs), max(xs)
    minz, maxz = min(zs), max(zs)
    dx = max(maxx - minx, 1e-6)
    dz = max(maxz - minz, 1e-6)
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = ((co.x - minx) / dx) * u_span
            v = (co.z - minz) / dz
            uv_layer.data[li].uv = (u, v)


def add_photo_cards(front_path, back_path, mat_front, mat_back):
    cards = []
    if front_path and os.path.isfile(front_path):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.14, 1.48))
        card = bpy.context.active_object
        card.name = "PhotoFront"
        card.scale = (0.42, 0.01, 0.58)
        card.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if mat_front:
            card.data.materials.append(mat_front)
        cards.append(card)
    if back_path and os.path.isfile(back_path):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0.14, 1.48))
        card = bpy.context.active_object
        card.name = "PhotoBack"
        card.scale = (0.40, 0.01, 0.55)
        card.rotation_euler = (math.radians(90), 0, math.radians(180))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if mat_back:
            card.data.materials.append(mat_back)
        cards.append(card)
    return cards


def add_box(name, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        if ob.data.materials:
            ob.data.materials[0] = mat
        else:
            ob.data.materials.append(mat)
    return ob


def build_armature():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "Armature"
    eb = arm.data.edit_bones
    root = eb[0]
    root.name = "Hips"
    root.head = (0, 0, 0.95)
    root.tail = (0, 0, 1.12)

    def bone(name, parent, head, tail):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        b.parent = parent
        return b

    spine = bone("Spine", root, (0, 0, 1.12), (0, 0, 1.35))
    chest = bone("Chest", spine, (0, 0, 1.35), (0, 0, 1.58))
    neck = bone("Neck", chest, (0, 0, 1.58), (0, 0, 1.68))
    bone("Head", neck, (0, 0, 1.68), (0, 0, 1.92))
    ls = bone("Shoulder.L", chest, (0.08, 0, 1.55), (0.22, 0, 1.55))
    lu = bone("UpperArm.L", ls, (0.22, 0, 1.55), (0.48, 0, 1.38))
    ll = bone("LowerArm.L", lu, (0.48, 0, 1.38), (0.68, 0, 1.18))
    bone("Hand.L", ll, (0.68, 0, 1.18), (0.80, 0, 1.12))
    rs = bone("Shoulder.R", chest, (-0.08, 0, 1.55), (-0.22, 0, 1.55))
    ru = bone("UpperArm.R", rs, (-0.22, 0, 1.55), (-0.48, 0, 1.38))
    rl = bone("LowerArm.R", ru, (-0.48, 0, 1.38), (-0.68, 0, 1.18))
    bone("Hand.R", rl, (-0.68, 0, 1.18), (-0.80, 0, 1.12))
    lu_leg = bone("UpperLeg.L", root, (0.12, 0, 0.95), (0.14, 0, 0.52))
    ll_leg = bone("LowerLeg.L", lu_leg, (0.14, 0, 0.52), (0.14, 0, 0.12))
    bone("Foot.L", ll_leg, (0.14, 0, 0.12), (0.14, 0.18, 0.04))
    ru_leg = bone("UpperLeg.R", root, (-0.12, 0, 0.95), (-0.14, 0, 0.52))
    rl_leg = bone("LowerLeg.R", ru_leg, (-0.14, 0, 0.52), (-0.14, 0, 0.12))
    bone("Foot.R", rl_leg, (-0.14, 0, 0.12), (-0.14, 0.18, 0.04))
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def build_body(mat):
    parts = [
        ("HipsMesh", (0.28, 0.16, 0.14), (0, 0, 1.02)),
        ("Torso", (0.34, 0.18, 0.42), (0, 0, 1.38)),
        ("HeadMesh", (0.22, 0.22, 0.24), (0, 0, 1.80)),
        ("ArmL", (0.10, 0.10, 0.42), (0.42, 0, 1.36)),
        ("ArmR", (0.10, 0.10, 0.42), (-0.42, 0, 1.36)),
        ("LegL", (0.12, 0.14, 0.55), (0.13, 0, 0.52)),
        ("LegR", (0.12, 0.14, 0.55), (-0.13, 0, 0.52)),
    ]
    meshes = []
    for name, size, loc in parts:
        meshes.append(add_box(name, size, loc, mat))
    for ob in meshes[1:]:
        meshes[0].select_set(True)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "Body"
    return body


def parent_armature(body, arm):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def make_actions(arm):
    arm.animation_data_create()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones

    def key_bone(frame, bname, quat=None, loc=None):
        b = pb.get(bname)
        if not b:
            return
        if quat is not None:
            b.rotation_mode = "QUATERNION"
            b.rotation_quaternion = quat
            b.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if loc is not None:
            b.location = loc
            b.keyframe_insert(data_path="location", frame=frame)

    def q_axis(axis, deg):
        ang = math.radians(deg) * 0.5
        c, s = math.cos(ang), math.sin(ang)
        if axis == "x":
            return (c, s, 0, 0)
        if axis == "y":
            return (c, 0, s, 0)
        return (c, 0, 0, s)

    # idle
    idle = bpy.data.actions.new("idle")
    arm.animation_data.action = idle
    for f, d in ((1, 0), (20, 4), (40, 0)):
        key_bone(f, "Chest", q_axis("x", d))
        key_bone(f, "Head", q_axis("y", d * 0.5))
    idle.use_fake_user = True

    walk = bpy.data.actions.new("walk")
    arm.animation_data.action = walk
    for f, a in ((1, 28), (12, -28), (24, 28)):
        key_bone(f, "UpperLeg.L", q_axis("x", a))
        key_bone(f, "UpperLeg.R", q_axis("x", -a))
        key_bone(f, "UpperArm.L", q_axis("x", -a * 0.7))
        key_bone(f, "UpperArm.R", q_axis("x", a * 0.7))
    walk.use_fake_user = True

    attack = bpy.data.actions.new("attack")
    arm.animation_data.action = attack
    key_bone(1, "UpperArm.R", q_axis("x", -10))
    key_bone(8, "UpperArm.R", q_axis("x", -80))
    key_bone(16, "UpperArm.R", q_axis("x", 20))
    key_bone(24, "UpperArm.R", q_axis("x", -10))
    attack.use_fake_user = True
    bpy.ops.object.mode_set(mode="OBJECT")


def export_files(out_dir, slug):
    os.makedirs(out_dir, exist_ok=True)
    glb = os.path.join(out_dir, slug + ".glb")
    fbx = os.path.join(out_dir, slug + ".fbx")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_animations=True, export_skins=True, export_texcoords=True, export_normals=True)
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, add_leaf_bones=False, bake_anim=True)
    return glb, fbx


def main():
    args = _argv_after_dashes()
    if not args:
        raise SystemExit("missing spec.json")
    with open(args[0], "r", encoding="utf-8") as f:
        spec = json.load(f)
    reset_scene()
    color = spec.get("color", [0.55, 0.45, 0.85])
    tex = spec.get("texture") or spec.get("photo_front") or ""
    front = spec.get("photo_front") or tex
    side = spec.get("photo_side") or ""
    back = spec.get("photo_back") or ""
    mat = make_material(
        "ForgeMat",
        color,
        float(spec.get("roughness", 0.55)),
        float(spec.get("metallic", 0.05)),
        tex,
    )
    mat_front = make_material("PhotoFrontMat", color, 0.5, 0.0, front) if front else mat
    mat_back = make_material("PhotoBackMat", color, 0.55, 0.0, back or front) if (back or front) else mat
    arm = build_armature()
    body = build_body(mat)
    if spec.get("use_photos"):
        unwrap_front_photo(body)
        cards = add_photo_cards(front, back, mat_front, mat_back)
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        for card in cards:
            card.select_set(True)
        bpy.context.view_layer.objects.active = body
        if cards:
            bpy.ops.object.join()
            body = bpy.context.active_object
            body.name = "Body"
    parent_armature(body, arm)
    make_actions(arm)
    glb, fbx = export_files(spec["out_dir"], spec["slug"])
    print("FORGE_OK", glb, fbx, "photos" if spec.get("use_photos") else "nophotos", side)


if __name__ == "__main__":
    main()
