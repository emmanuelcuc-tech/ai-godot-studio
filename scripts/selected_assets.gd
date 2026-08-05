class_name SelectedAssets
extends RefCounted
## Studio-wide picks from the texture browser (wall/material/sprite).

const STATE_PATH := "user://selected_assets.json"

var wall_texture_path: String = ""
var wall_texture_title: String = ""
var wall_license: String = ""
var material_hint: String = ""
var animation_pref: String = "bob_and_muzzle" # bob_and_muzzle | spritesheet | gltf


func load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	wall_texture_path = str(data.get("wall_texture_path", ""))
	wall_texture_title = str(data.get("wall_texture_title", ""))
	wall_license = str(data.get("wall_license", ""))
	material_hint = str(data.get("material_hint", ""))
	animation_pref = str(data.get("animation_pref", animation_pref))


func save_state() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"wall_texture_path": wall_texture_path,
		"wall_texture_title": wall_texture_title,
		"wall_license": wall_license,
		"material_hint": material_hint,
		"animation_pref": animation_pref,
	}, "\t"))


func set_wall_texture(abs_path: String, title: String, license: String, hint: String = "") -> void:
	wall_texture_path = abs_path
	wall_texture_title = title
	wall_license = license
	if not hint.is_empty():
		material_hint = hint
	save_state()


func clear_wall() -> void:
	wall_texture_path = ""
	wall_texture_title = ""
	wall_license = ""
	save_state()


func has_wall_texture() -> bool:
	return not wall_texture_path.is_empty() and FileAccess.file_exists(wall_texture_path)


func context_for_ai() -> String:
	if not has_wall_texture():
		return "No wall/material texture selected in the Asset Browser yet."
	return """SELECTED WALL/MATERIAL TEXTURE (must use if walls/materials requested):
- Title: %s
- License: %s
- Local file: %s
- Copy into project as assets/wall.png (or assets/material.png) and assign StandardMaterial3D.albedo_texture on walls/floors.
- Material hint: %s
- Animation preference: %s
""" % [wall_texture_title, wall_license, wall_texture_path, material_hint, animation_pref]


func copy_wall_into_project(project_root: String) -> String:
	if not has_wall_texture():
		return ""
	var dest_dir := project_root.path_join("assets")
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var ext := wall_texture_path.get_extension().to_lower()
	if ext.is_empty():
		ext = "png"
	var dest := dest_dir.path_join("wall.%s" % ext)
	var bytes := FileAccess.get_file_as_bytes(wall_texture_path)
	if bytes.is_empty():
		return ""
	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(bytes)
	return dest
