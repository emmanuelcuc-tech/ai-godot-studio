class_name ModelForge
extends RefCounted
## Describe a model → Blender rig/anim (if available) + Godot fallback actor + Unity import kit.

const ArtPipelineScript = preload("res://scripts/art_pipeline.gd")
const ActorTemplate := "res://scripts/templates/generated/forged_actor.gd"


static func slugify(text: String) -> String:
	var s := text.strip_edges().to_lower()
	var out := ""
	for i in s.length():
		var ch := s.unicode_at(i)
		if (ch >= 97 and ch <= 122) or (ch >= 48 and ch <= 57):
			out += char(ch)
		elif out.is_empty() or not out.ends_with("_"):
			out += "_"
	return out.trim_prefix("_").trim_suffix("_").left(32)


static func parse_material(desc: String) -> Dictionary:
	var d := desc.strip_edges().to_lower()
	var color := Color(0.62, 0.48, 0.88)
	var metallic := 0.05
	var roughness := 0.55
	if d.contains("#") and d.length() >= 7:
		var hx := d.substr(d.find("#"), 7)
		color = Color.html(hx)
	elif d.contains("gold"):
		color = Color(0.86, 0.68, 0.22); metallic = 0.85; roughness = 0.28
	elif d.contains("silver") or d.contains("steel") or d.contains("metal"):
		color = Color(0.72, 0.74, 0.78); metallic = 0.8; roughness = 0.32
	elif d.contains("wood"):
		color = Color(0.48, 0.30, 0.16); metallic = 0.0; roughness = 0.78
	elif d.contains("leather"):
		color = Color(0.42, 0.24, 0.14); metallic = 0.0; roughness = 0.7
	elif d.contains("cloth") or d.contains("fabric"):
		color = Color(0.28, 0.42, 0.72); metallic = 0.0; roughness = 0.88
	elif d.contains("slime") or d.contains("goo"):
		color = Color(0.28, 0.82, 0.38); metallic = 0.05; roughness = 0.18
	elif d.contains("red"):
		color = Color(0.78, 0.18, 0.16)
	elif d.contains("blue"):
		color = Color(0.22, 0.42, 0.86)
	elif d.contains("green"):
		color = Color(0.22, 0.62, 0.28)
	elif d.contains("black"):
		color = Color(0.12, 0.12, 0.14)
	elif d.contains("white"):
		color = Color(0.92, 0.92, 0.94)
	if d.contains("shiny") or d.contains("gloss"):
		roughness = minf(roughness, 0.22)
	if d.contains("rough") or d.contains("matte"):
		roughness = maxf(roughness, 0.75)
	return {"color": color, "metallic": metallic, "roughness": roughness, "label": desc.strip_edges()}


static func forge(project_path: String, model_desc: String, material_desc: String, texture_path: String = "", photos: PackedStringArray = PackedStringArray()) -> Dictionary:
	var slug := slugify(model_desc)
	if slug.is_empty():
		slug = "hero"
	var mat := parse_material(material_desc)
	var out_rel := "assets/models/%s" % slug
	var out_abs := project_path.path_join(out_rel).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(out_abs)
	var photo_pack: Dictionary = _ingest_photos(out_abs, photos, texture_path)
	if bool(photo_pack.get("ok", false)):
		mat["color"] = photo_pack.get("avg_color", mat["color"])
		mat["metallic"] = minf(float(mat["metallic"]), 0.12)
		mat["roughness"] = clampf(float(mat["roughness"]), 0.42, 0.78)
	else:
		_write_albedo_png(out_abs.path_join("albedo.png"), mat["color"], mat["roughness"], mat["metallic"])
	var tex_for_blender := str(photo_pack.get("atlas", ""))
	if tex_for_blender.is_empty():
		tex_for_blender = texture_path.replace("\\", "/")
	var spec := {
		"slug": slug,
		"title": model_desc.strip_edges(),
		"material": material_desc.strip_edges(),
		"color": [mat["color"].r, mat["color"].g, mat["color"].b],
		"roughness": mat["roughness"],
		"metallic": mat["metallic"],
		"texture": tex_for_blender,
		"photo_front": str(photo_pack.get("front", "")),
		"photo_side": str(photo_pack.get("side", "")),
		"photo_back": str(photo_pack.get("back", "")),
		"use_photos": bool(photo_pack.get("ok", false)),
		"out_dir": out_abs,
		"clips": ["idle", "walk", "attack"],
	}
	var spec_path := out_abs.path_join("forge_spec.json")
	var sf := FileAccess.open(spec_path, FileAccess.WRITE)
	if sf:
		sf.store_string(JSON.stringify(spec, "\t"))
	_write_actor_files(project_path, slug, spec, mat)
	var blender_ok := _run_blender(spec_path)
	_write_unity_bridge(project_path, slug, out_abs, blender_ok)
	var note := "Godot actor + skeleton/animation written."
	if blender_ok:
		note += " Blender exported .glb/.fbx."
	else:
		note += " Blender not found or failed — using Godot forged actor (set blender.exe in Settings)."
	note += " Unity import kit in unity_import/."
	if bool(photo_pack.get("ok", false)):
		note += " Photo replica: front/side/back wrapped onto the actor."
	return {"ok": true, "slug": slug, "dir": out_rel, "blender": blender_ok, "photos": bool(photo_pack.get("ok", false)), "message": note}


static func _ingest_photos(out_abs: String, photos: PackedStringArray, texture_path: String) -> Dictionary:
	var paths: PackedStringArray = PackedStringArray()
	for p in photos:
		var n := p.strip_edges().replace("\\", "/")
		if not n.is_empty() and FileAccess.file_exists(n):
			paths.append(n)
	var tex := texture_path.strip_edges().replace("\\", "/")
	if not tex.is_empty() and FileAccess.file_exists(tex) and not paths.has(tex):
		paths.append(tex)
	if paths.is_empty():
		return {"ok": false}
	DirAccess.make_dir_recursive_absolute(out_abs.path_join("refs"))
	var front := ""
	var side := ""
	var back := ""
	var extras: PackedStringArray = PackedStringArray()
	for p in paths:
		var low := p.get_file().to_lower()
		if front.is_empty() and (low.contains("front") or low.contains("face") or low.contains("portrait")):
			front = p
		elif side.is_empty() and (low.contains("side") or low.contains("profile") or low.contains("left") or low.contains("right")):
			side = p
		elif back.is_empty() and (low.contains("back") or low.contains("rear")):
			back = p
		else:
			extras.append(p)
	for p in extras:
		if front.is_empty():
			front = p
		elif side.is_empty():
			side = p
		elif back.is_empty():
			back = p
	if front.is_empty() and not paths.is_empty():
		front = paths[0]
	var front_dst := _copy_photo(front, out_abs.path_join("photo_front.png"))
	var side_dst := _copy_photo(side, out_abs.path_join("photo_side.png"))
	var back_dst := _copy_photo(back, out_abs.path_join("photo_back.png"))
	var atlas_path := out_abs.path_join("albedo.png")
	var avg := _compose_photo_atlas(atlas_path, front_dst, side_dst, back_dst)
	return {
		"ok": not front_dst.is_empty(),
		"front": front_dst,
		"side": side_dst,
		"back": back_dst,
		"atlas": atlas_path,
		"avg_color": avg,
	}


static func _copy_photo(src: String, dst: String) -> String:
	if src.is_empty() or not FileAccess.file_exists(src):
		return ""
	var img := Image.new()
	if img.load(src) != OK:
		return ""
	if img.get_width() > 1024 or img.get_height() > 1024:
		var w := img.get_width()
		var h := img.get_height()
		var scale := 1024.0 / float(maxi(w, h))
		img.resize(maxi(1, int(w * scale)), maxi(1, int(h * scale)), Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.save_png(dst)
	var ref_name := src.get_file()
	if ref_name.is_empty():
		ref_name = dst.get_file()
	img.save_png(dst.get_base_dir().path_join("refs").path_join(ref_name.get_basename() + ".png"))
	return dst


static func _compose_photo_atlas(dst: String, front: String, side: String, back: String) -> Color:
	var atlas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.18, 0.18, 0.2, 1))
	var avg := Color(0.55, 0.48, 0.42)
	var samples := 0
	var acc := Color(0, 0, 0, 0)
	if not front.is_empty() and FileAccess.file_exists(front):
		var fimg := Image.new()
		if fimg.load(front) == OK:
			fimg.resize(384, 512, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(fimg, Rect2i(0, 0, 384, 512), Vector2i(0, 0))
			acc += _sample_avg(fimg)
			samples += 1
	if not side.is_empty() and FileAccess.file_exists(side):
		var simg := Image.new()
		if simg.load(side) == OK:
			simg.resize(128, 256, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(simg, Rect2i(0, 0, 128, 256), Vector2i(384, 0))
			acc += _sample_avg(simg)
			samples += 1
	elif not front.is_empty() and FileAccess.file_exists(front):
		var f2 := Image.new()
		if f2.load(front) == OK:
			f2.resize(128, 256, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(f2, Rect2i(0, 0, 128, 256), Vector2i(384, 0))
	if not back.is_empty() and FileAccess.file_exists(back):
		var bimg := Image.new()
		if bimg.load(back) == OK:
			bimg.resize(128, 256, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(bimg, Rect2i(0, 0, 128, 256), Vector2i(384, 256))
			acc += _sample_avg(bimg)
			samples += 1
	elif not front.is_empty() and FileAccess.file_exists(front):
		var f3 := Image.new()
		if f3.load(front) == OK:
			f3.resize(128, 256, Image.INTERPOLATE_LANCZOS)
			for y in 256:
				for x in 128:
					atlas.set_pixel(384 + x, 256 + y, f3.get_pixel(x, y).darkened(0.18))
	atlas.save_png(dst)
	if samples > 0:
		avg = acc / float(samples)
	return avg


static func _sample_avg(img: Image) -> Color:
	var step_x := maxi(1, img.get_width() / 16)
	var step_y := maxi(1, img.get_height() / 16)
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for y in range(0, img.get_height(), step_y):
		for x in range(0, img.get_width(), step_x):
			acc += img.get_pixel(x, y)
			n += 1
	if n == 0:
		return Color(0.5, 0.5, 0.5)
	return acc / float(n)


static func _write_albedo_png(path: String, color: Color, roughness: float, metallic: float) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var n := ((x * 13 + y * 7) % 11) / 11.0
			var c := color.lightened((n - 0.5) * 0.12)
			if metallic > 0.4 and ((x + y) % 8 == 0):
				c = c.lightened(0.15)
			if roughness > 0.7 and (x % 5 == 0):
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	img.save_png(path)


static func _write_actor_files(project_path: String, slug: String, spec: Dictionary, mat: Dictionary) -> void:
	var actor_src := FileAccess.get_file_as_string(ActorTemplate)
	if actor_src.is_empty():
		actor_src = FORGED_ACTOR_FALLBACK
	var dest_script := project_path.path_join("scripts/forged_actor.gd")
	DirAccess.make_dir_recursive_absolute(project_path.path_join("scripts"))
	var f := FileAccess.open(dest_script, FileAccess.WRITE)
	if f:
		f.store_string(actor_src)
	var title_esc := str(spec.get("title", slug)).replace("\\", "\\\\").replace("\"", "\\\"")
	var use_photos := "false"
	if bool(spec.get("use_photos", false)):
		use_photos = "true"
	var scene := """[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/forged_actor.gd" id="1"]
[node name="Forged_%s" type="Node3D"]
script = ExtResource("1")
model_title = "%s"
albedo_path = "res://assets/models/%s/albedo.png"
photo_front = "res://assets/models/%s/photo_front.png"
photo_side = "res://assets/models/%s/photo_side.png"
photo_back = "res://assets/models/%s/photo_back.png"
use_photo_replica = %s
metallic = %s
roughness = %s
""" % [slug, title_esc, slug, slug, slug, slug, use_photos, str(mat["metallic"]), str(mat["roughness"])]
	DirAccess.make_dir_recursive_absolute(project_path.path_join("scenes"))
	var sc := FileAccess.open(project_path.path_join("scenes/forged_%s.tscn" % slug), FileAccess.WRITE)
	if sc:
		sc.store_string(scene)
	var readme := FileAccess.open(project_path.path_join("assets/models/%s/README.md" % slug), FileAccess.WRITE)
	if readme:
		readme.store_string("# %s\n\nMaterial: %s\n\n- Godot scene: `scenes/forged_%s.tscn` (Skeleton3D + AnimationPlayer idle/walk/attack)\n- Photo replica: `photo_front.png` / `photo_side.png` / `photo_back.png` + atlas `albedo.png`\n- Refs copied into `refs/`\n- If Blender ran: `%s.glb` / `%s.fbx` (front-projected photo UVs)\n- Unity: copy FBX/GLB into `unity_import/Assets/Models` and open the bridge project.\n" % [
			str(spec.get("title", slug)), str(spec.get("material", "")), slug, slug, slug
		])


static func _run_blender(spec_path: String) -> bool:
	var exe := AppSettings.blender_executable
	if exe.is_empty() or not FileAccess.file_exists(exe):
		exe = ArtPipelineScript.guess_blender_path()
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return false
	var py := ProjectSettings.globalize_path("res://tools/blender_forge_model.py")
	if not FileAccess.file_exists(py):
		return false
	var args := PackedStringArray(["--background", "--python", py, "--", spec_path])
	var output: Array = []
	var code := OS.execute(exe, args, output, true, false)
	return code == 0


static func _write_unity_bridge(project_path: String, slug: String, model_abs: String, blender_ok: bool) -> void:
	var root := project_path.path_join("unity_import")
	DirAccess.make_dir_recursive_absolute(root.path_join("Assets/Editor"))
	DirAccess.make_dir_recursive_absolute(root.path_join("Assets/Models"))
	DirAccess.make_dir_recursive_absolute(root.path_join("ProjectSettings"))
	var ver := FileAccess.open(root.path_join("ProjectSettings/ProjectVersion.txt"), FileAccess.WRITE)
	if ver:
		ver.store_string("m_EditorVersion: 6000.3.18f1\nm_EditorVersionWithRevision: 6000.3.18f1\n")
	var cs := FileAccess.open(root.path_join("Assets/Editor/StudioModelImport.cs"), FileAccess.WRITE)
	if cs:
		cs.store_string("""using UnityEditor;
using UnityEngine;
public static class StudioModelImport {
    [MenuItem("Studio/Refresh Forged Models")]
    public static void Refresh() {
        AssetDatabase.Refresh();
        Debug.Log("Studio models refreshed.");
    }
    public static void BatchImport() {
        Refresh();
        EditorApplication.Exit(0);
    }
}
""")
	if blender_ok:
		for ext in ["glb", "fbx"]:
			var src := model_abs.path_join("%s.%s" % [slug, ext])
			if FileAccess.file_exists(src):
				DirAccess.copy_absolute(src, root.path_join("Assets/Models/%s.%s" % [slug, ext]))
	for photo_name in ["albedo.png", "photo_front.png", "photo_side.png", "photo_back.png"]:
		var psrc := model_abs.path_join(photo_name)
		if FileAccess.file_exists(psrc):
			DirAccess.copy_absolute(psrc, root.path_join("Assets/Models/%s_%s" % [slug, photo_name]))
	var how := FileAccess.open(root.path_join("HOW_TO_IMPORT.md"), FileAccess.WRITE)
	if how:
		how.store_string("# Unity import\n\n1. Open this folder in Unity Hub / Unity 6000.3+\n2. Menu **Studio → Refresh Forged Models**\n3. Models land in `Assets/Models`\n\nBatch:\n```\nUnity.exe -batchmode -nographics -quit -projectPath \"%s\" -executeMethod StudioModelImport.BatchImport\n```\n" % root)


static func guess_unity_path() -> String:
	var p := "C:/Program Files/Unity/Hub/Editor/6000.3.18f1/Editor/Unity.exe"
	if FileAccess.file_exists(p):
		return p
	var base := "C:/Program Files/Unity/Hub/Editor"
	var d := DirAccess.open(base)
	if d:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			var exe := base.path_join(n).path_join("Editor/Unity.exe")
			if FileAccess.file_exists(exe):
				return exe
			n = d.get_next()
	return ""


static func open_unity_bridge(project_path: String) -> Error:
	var bridge := project_path.path_join("unity_import")
	if not DirAccess.dir_exists_absolute(bridge):
		return ERR_FILE_NOT_FOUND
	var exe := AppSettings.unity_executable
	if exe.is_empty() or not FileAccess.file_exists(exe):
		exe = guess_unity_path()
	if exe.is_empty() or not FileAccess.file_exists(exe):
		OS.shell_open(bridge)
		return OK
	return OS.create_process(exe, PackedStringArray(["-projectPath", bridge]))


const FORGED_ACTOR_FALLBACK := """extends Node3D
@export var model_title := \"Forged\"
@export var albedo_path := \"\"
@export var metallic := 0.05
@export var roughness := 0.55
func _ready() -> void:
	var sk := Skeleton3D.new()
	add_child(sk)
	_add_bone(sk, \"Hips\", -1, Vector3(0, 0.95, 0))
	_add_bone(sk, \"Chest\", 0, Vector3(0, 0.45, 0))
	_add_bone(sk, \"Head\", 1, Vector3(0, 0.38, 0))
	_box(self, Vector3(0, 1.15, 0), Vector3(0.35, 0.5, 0.22))
	_box(self, Vector3(0, 1.72, 0), Vector3(0.22, 0.22, 0.22))
	var ap := AnimationPlayer.new()
	add_child(ap)
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	ap.add_animation_library(\"\", AnimationLibrary.new())
	ap.get_animation_library(\"\").add_animation(\"idle\", idle)
	ap.play(\"idle\")
func _add_bone(sk: Skeleton3D, n: String, parent: int, rest_pos: Vector3) -> int:
	var i := sk.add_bone(n)
	if parent >= 0:
		sk.set_bone_parent(i, parent)
	var r := Transform3D(Basis.IDENTITY, rest_pos)
	sk.set_bone_rest(i, r)
	return i
func _box(host: Node3D, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	if not albedo_path.is_empty() and ResourceLoader.exists(albedo_path):
		mat.albedo_texture = load(albedo_path)
	mat.metallic = metallic
	mat.roughness = roughness
	mi.material_override = mat
	host.add_child(mi)
"""
