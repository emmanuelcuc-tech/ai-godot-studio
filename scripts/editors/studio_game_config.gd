class_name StudioGameConfig
extends RefCounted
## Per-game studio JSON configs + generated runtime hooks.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")

const DISPLAY_FILE := "studio_display.json"
const EFFECTS_FILE := "studio_effects.json"
const CONTROLS_FILE := "studio_controls.json"
const ANIM_FILE := "studio_anim.json"
const ASSETS_FILE := "studio_assets.json"

const RUNTIME_SRC := "res://scripts/templates/generated/studio_runtime.gd"
const ANIM_SRC := "res://scripts/templates/generated/anim_config.gd"
const FX_SRC := "res://scripts/templates/generated/effects_config.gd"


static func default_display() -> Dictionary:
	return {
		"menu_background": "res://assets/background/menu_bg.png",
		"game_background": "res://assets/background/sky.png",
		"ui_style": "neon",
		"max_hp": 100,
		"show_health": true,
		"weapon_view": true,
		"camera_mode": "first_person",
	}


static func default_controls() -> Dictionary:
	return {
		"camera_mode": "first_person",
		"show_weapon": true,
		"show_health": true,
		"max_hp": 100,
		"ui_style": "neon",
	}


static func default_effects() -> Dictionary:
	return {
		"muzzle_flash": true,
		"muzzle_intensity": 1.0,
		"bullet_trail": true,
		"bullet_intensity": 1.0,
		"enemy_death": true,
		"enemy_death_intensity": 1.0,
		"destroy_fx": true,
		"destroy_intensity": 1.0,
	}


static func default_anim() -> Dictionary:
	return {
		"mode_enabled": false,
		"animations": [
			{"name": "idle", "fps": 8.0, "loop": true, "frames": [], "notes": "Idle / stand"},
			{"name": "walk", "fps": 10.0, "loop": true, "frames": [], "notes": "Locomotion / walk-bob fallback"},
			{"name": "attack", "fps": 12.0, "loop": false, "frames": [], "notes": "Fire / melee swing"},
		],
	}


static func default_assets() -> Dictionary:
	return {
		"assignments": {
			"wall": "res://assets/world/wall.png",
			"floor": "res://assets/world/floor.png",
			"sky": "res://assets/background/sky.png",
			"character": "res://assets/character/sprite_player.png",
			"enemy": "res://assets/enemy/sprite_enemy.png",
			"weapon": "res://assets/weapon/weapon.png",
			"menu_background": "res://assets/background/menu_bg.png",
			"game_background": "res://assets/background/sky.png",
			"ui": "res://assets/ui/ui_panel.png",
			"material": "res://assets/materials/material.png",
		}
	}


static func load_json(project_path: String, rel: String, fallback: Dictionary) -> Dictionary:
	if project_path.is_empty():
		return fallback.duplicate(true)
	var full: String = project_path.path_join(rel)
	if not FileAccess.file_exists(full):
		return fallback.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full))
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback.duplicate(true)
	var merged: Dictionary = fallback.duplicate(true)
	_deep_merge(merged, parsed)
	return merged


static func save_json(project_path: String, rel: String, data: Dictionary) -> bool:
	if project_path.is_empty():
		return false
	var full: String = project_path.path_join(rel)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var f: FileAccess = FileAccess.open(full, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func load_display(project_path: String) -> Dictionary:
	return load_json(project_path, DISPLAY_FILE, default_display())


static func load_controls(project_path: String) -> Dictionary:
	return load_json(project_path, CONTROLS_FILE, default_controls())


static func load_effects(project_path: String) -> Dictionary:
	return load_json(project_path, EFFECTS_FILE, default_effects())


static func load_anim(project_path: String) -> Dictionary:
	return load_json(project_path, ANIM_FILE, default_anim())


static func load_assets(project_path: String) -> Dictionary:
	return load_json(project_path, ASSETS_FILE, default_assets())


static func save_display(project_path: String, data: Dictionary) -> bool:
	var ok: bool = save_json(project_path, DISPLAY_FILE, data)
	_sync_controls_from_display(project_path, data)
	return ok


static func save_controls(project_path: String, data: Dictionary) -> bool:
	var ok: bool = save_json(project_path, CONTROLS_FILE, data)
	var display: Dictionary = load_display(project_path)
	if data.has("camera_mode"):
		display["camera_mode"] = data.get("camera_mode", display.get("camera_mode", "first_person"))
	if data.has("show_weapon"):
		display["weapon_view"] = data.get("show_weapon", true)
	if data.has("show_health"):
		display["show_health"] = data.get("show_health", true)
	if data.has("max_hp"):
		display["max_hp"] = int(data.get("max_hp", 100))
	if data.has("ui_style"):
		display["ui_style"] = str(data.get("ui_style", "neon"))
	save_json(project_path, DISPLAY_FILE, display)
	return ok


static func save_effects(project_path: String, data: Dictionary) -> bool:
	return save_json(project_path, EFFECTS_FILE, data)


static func save_anim(project_path: String, data: Dictionary) -> bool:
	var ok: bool = save_json(project_path, ANIM_FILE, data)
	_write_anim_script(project_path, data)
	return ok


static func save_assets(project_path: String, data: Dictionary) -> bool:
	return save_json(project_path, ASSETS_FILE, data)


static func assign_slot(project_path: String, slot: String, res_path: String) -> void:
	var assets: Dictionary = load_assets(project_path)
	var assignments: Dictionary = assets.get("assignments", {})
	if typeof(assignments) != TYPE_DICTIONARY:
		assignments = {}
	assignments[slot] = res_path
	assets["assignments"] = assignments
	save_assets(project_path, assets)
	var display: Dictionary = load_display(project_path)
	match slot:
		"menu_background":
			display["menu_background"] = res_path
			save_display(project_path, display)
		"game_background", "sky":
			display["game_background"] = res_path
			save_display(project_path, display)
		_:
			pass
	_write_simple_material_if_needed(project_path, slot, res_path)


static func ensure_on_disk(project_path: String) -> void:
	if project_path.is_empty():
		return
	LayoutScript.ensure_layout(project_path)
	if not FileAccess.file_exists(project_path.path_join(DISPLAY_FILE)):
		save_json(project_path, DISPLAY_FILE, default_display())
	if not FileAccess.file_exists(project_path.path_join(CONTROLS_FILE)):
		save_json(project_path, CONTROLS_FILE, default_controls())
	if not FileAccess.file_exists(project_path.path_join(EFFECTS_FILE)):
		save_json(project_path, EFFECTS_FILE, default_effects())
	if not FileAccess.file_exists(project_path.path_join(ANIM_FILE)):
		save_json(project_path, ANIM_FILE, default_anim())
	if not FileAccess.file_exists(project_path.path_join(ASSETS_FILE)):
		save_json(project_path, ASSETS_FILE, default_assets())
	_copy_template(RUNTIME_SRC, project_path.path_join("scripts/studio_runtime.gd"))
	_copy_template(ANIM_SRC, project_path.path_join("scripts/anim_config.gd"))
	_copy_template(FX_SRC, project_path.path_join("scripts/effects_config.gd"))
	_write_anim_script(project_path, load_anim(project_path))
	_write_effects_script(project_path, load_effects(project_path))
	patch_project_autoload(project_path)
	_write_editor_docs(project_path)


static func inject_into_files(files: Array) -> Array:
	var out: Array = files.duplicate(true)
	var by_path: Dictionary = {}
	for f in out:
		if typeof(f) == TYPE_DICTIONARY:
			by_path[str(f.get("path", ""))] = f
	if not by_path.has(DISPLAY_FILE):
		_upsert(out, by_path, DISPLAY_FILE, JSON.stringify(default_display(), "\t"))
	if not by_path.has(CONTROLS_FILE):
		_upsert(out, by_path, CONTROLS_FILE, JSON.stringify(default_controls(), "\t"))
	if not by_path.has(EFFECTS_FILE):
		_upsert(out, by_path, EFFECTS_FILE, JSON.stringify(default_effects(), "\t"))
	if not by_path.has(ANIM_FILE):
		_upsert(out, by_path, ANIM_FILE, JSON.stringify(default_anim(), "\t"))
	if not by_path.has(ASSETS_FILE):
		_upsert(out, by_path, ASSETS_FILE, JSON.stringify(default_assets(), "\t"))
	_upsert(out, by_path, "scripts/studio_runtime.gd", _read_res_text(RUNTIME_SRC))
	_upsert(out, by_path, "scripts/anim_config.gd", _read_res_text(ANIM_SRC))
	_upsert(out, by_path, "scripts/effects_config.gd", _read_res_text(FX_SRC))
	if not by_path.has("docs/STUDIO_EDITORS.md"):
		_upsert(out, by_path, "docs/STUDIO_EDITORS.md", _editor_docs())
	if by_path.has("project.godot"):
		by_path["project.godot"]["content"] = _patch_autoload_text(str(by_path["project.godot"].get("content", "")))
	return out


static func patch_project_autoload(project_path: String) -> void:
	var pg_path: String = project_path.path_join("project.godot")
	if not FileAccess.file_exists(pg_path):
		return
	var pg: String = FileAccess.get_file_as_string(pg_path)
	var patched: String = _patch_autoload_text(pg)
	if patched != pg:
		var f: FileAccess = FileAccess.open(pg_path, FileAccess.WRITE)
		if f:
			f.store_string(patched)


static func _patch_autoload_text(pg: String) -> String:
	var text: String = pg
	if text.contains("StudioRuntime="):
		return text
	if text.contains("[autoload]"):
		return text.replace("[autoload]", "[autoload]\nStudioRuntime=\"*res://scripts/studio_runtime.gd\"")
	return text + "\n[autoload]\nStudioRuntime=\"*res://scripts/studio_runtime.gd\"\n"


static func _sync_controls_from_display(project_path: String, display: Dictionary) -> void:
	var controls: Dictionary = load_controls(project_path)
	controls["camera_mode"] = display.get("camera_mode", controls.get("camera_mode", "first_person"))
	controls["show_weapon"] = display.get("weapon_view", controls.get("show_weapon", true))
	controls["show_health"] = display.get("show_health", controls.get("show_health", true))
	controls["max_hp"] = int(display.get("max_hp", controls.get("max_hp", 100)))
	controls["ui_style"] = str(display.get("ui_style", controls.get("ui_style", "neon")))
	save_json(project_path, CONTROLS_FILE, controls)


static func _write_anim_script(project_path: String, data: Dictionary) -> void:
	var body: String = """extends RefCounted
## Generated animation table. Game scripts / StudioRuntime read this.

static func data() -> Dictionary:
	return %s


static func animations() -> Array:
	var d: Dictionary = data()
	var anims: Variant = d.get(\"animations\", [])
	return anims if typeof(anims) == TYPE_ARRAY else []


static func find_anim(anim_name: String) -> Dictionary:
	for a in animations():
		if typeof(a) == TYPE_DICTIONARY and str(a.get(\"name\", \"\")) == anim_name:
			return a
	return {}
""" % JSON.stringify(data, "\t")
	var dest: String = project_path.path_join("scripts/anim_config.gd")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)


static func _write_effects_script(project_path: String, data: Dictionary) -> void:
	var body: String = """extends RefCounted
## Generated VFX toggles. Player / enemy / break scripts can call enabled().

static func data() -> Dictionary:
	return %s


static func enabled(key: String, fallback: bool = true) -> bool:
	return bool(data().get(key, fallback))


static func intensity(key: String, fallback: float = 1.0) -> float:
	return float(data().get(key, fallback))
""" % JSON.stringify(data, "\t")
	var dest: String = project_path.path_join("scripts/effects_config.gd")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)


static func _write_simple_material_if_needed(project_path: String, slot: String, res_path: String) -> void:
	if slot != "material" and slot != "wall" and slot != "floor":
		return
	var mat_name: String = "wall.tres" if slot == "wall" else ("floor.tres" if slot == "floor" else "material.tres")
	var dest: String = project_path.path_join("assets/materials").path_join(mat_name)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var body: String = """[gd_resource type=\"StandardMaterial3D\" load_steps=2 format=3]
[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_tex\"]
[resource]
albedo_texture = ExtResource(\"1_tex\")
roughness = 0.9
metallic = 0.05
""" % res_path
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)


static func _write_editor_docs(project_path: String) -> void:
	var dest: String = project_path.path_join("docs/STUDIO_EDITORS.md")
	if FileAccess.file_exists(dest):
		return
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(_editor_docs())


static func _editor_docs() -> String:
	return """# Studio editors (per-game)

This project is edited from AI Godot Studio tabs. Choices persist here:

- `studio_display.json` — menu/game background, UI style, HP, weapon view, camera
- `studio_controls.json` — camera first/third, health/weapon toggles
- `studio_effects.json` — muzzle / bullet / death / destroy VFX
- `studio_anim.json` + `scripts/anim_config.gd` — animation names, fps, loop, frames
- `studio_assets.json` — assigned wall/floor/character/enemy/weapon paths
- `scripts/studio_runtime.gd` — autoload that applies configs when you Run Game
- `scripts/effects_config.gd` — VFX helpers

Asset folders:

```
assets/character/
assets/enemy/
assets/weapon/
assets/world/
assets/ui/
assets/effects/
assets/background/
assets/materials/
assets/models/
assets/sprites/
assets/textures/
```

Legal: CC0 / open licenses only.
"""


static func _copy_template(res_path: String, dest_abs: String) -> void:
	var text: String = _read_res_text(res_path)
	if text.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dest_abs.get_base_dir())
	var f: FileAccess = FileAccess.open(dest_abs, FileAccess.WRITE)
	if f:
		f.store_string(text)


static func _read_res_text(res_path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		return FileAccess.get_file_as_string(abs_path)
	if FileAccess.file_exists(res_path):
		return FileAccess.get_file_as_string(res_path)
	return ""


static func _upsert(out: Array, by_path: Dictionary, path: String, content: String) -> void:
	if by_path.has(path):
		by_path[path]["content"] = content
		return
	var row: Dictionary = {"path": path, "content": content}
	out.append(row)
	by_path[path] = row


static func _deep_merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		var sv: Variant = src[k]
		if dst.has(k) and typeof(dst[k]) == TYPE_DICTIONARY and typeof(sv) == TYPE_DICTIONARY:
			_deep_merge(dst[k], sv)
		else:
			dst[k] = sv
