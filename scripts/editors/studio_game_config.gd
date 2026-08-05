class_name StudioGameConfig
extends RefCounted
## Per-game studio JSON configs + generated runtime hooks.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const GraphicStyleScript = preload("res://scripts/graphic_style.gd")

const DISPLAY_FILE := "studio_display.json"
const EFFECTS_FILE := "studio_effects.json"
const CONTROLS_FILE := "studio_controls.json"
const ANIM_FILE := "studio_anim.json"
const ASSETS_FILE := "studio_assets.json"
const STYLE_FILE := "studio_style.json"

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
		"graphic_styles": ["3d", "detailed"],
	}


static func default_style() -> Dictionary:
	return {
		"graphic_styles": ["3d", "detailed"],
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
			{"name": "hit", "fps": 12.0, "loop": false, "frames": [], "notes": "Enemy hurt flash / hit react"},
			{"name": "death", "fps": 8.0, "loop": false, "frames": [], "notes": "Enemy death"},
		],
	}


static func default_physics() -> Dictionary:
	return {
		"engine": "jolt_or_default",
		"character_collision": true,
		"enemy_collision": true,
		"world_static": true,
		"weapon_rigid": true,
		"room_static": true,
		"addon": "",
	}


static func default_assets() -> Dictionary:
	return {
		"assignments": {
			"wall": "res://assets/world/wall.png",
			"floor": "res://assets/world/floor.png",
			"sky": "res://assets/background/sky.png",
			"skybox": "res://assets/background/skybox.png",
			"character": "res://assets/character/sprite_player.png",
			"character_sprite": "res://assets/character/sprite_player.png",
			"character_texture": "res://assets/character/character.png",
			"character_model": "res://assets/character/character.obj",
			"character_material": "res://assets/materials/character.tres",
			"enemy": "res://assets/enemy/sprite_enemy.png",
			"enemy_texture": "res://assets/enemy/enemy.png",
			"enemy_model": "res://assets/enemy/enemy.obj",
			"enemy_anim": "idle",
			"enemy_material": "res://assets/materials/enemy.tres",
			"weapon": "res://assets/weapon/weapon.png",
			"weapon_texture": "res://assets/weapon/weapon.png",
			"weapon_model": "res://assets/weapon/weapon.obj",
			"weapon_sprite": "res://assets/weapon/sprite_weapon.png",
			"weapon_material": "res://assets/materials/weapon.tres",
			"wall_material": "res://assets/materials/wall.tres",
			"floor_material": "res://assets/materials/floor.tres",
			"skybox_material": "res://assets/materials/skybox.tres",
			"room": "res://assets/world/wall.png",
			"room_model": "res://assets/models/room.obj",
			"menu_background": "res://assets/background/menu_bg.png",
			"game_background": "res://assets/background/sky.png",
			"ui": "res://assets/ui/ui_panel.png",
			"material": "res://assets/materials/material.tres",
			"physics": "res://docs/PHYSICS.md",
		},
		"variants": {},
		"physics": default_physics(),
		"kinds": {
			"textures": true,
			"sprites": true,
			"models": true,
		},
	}


static func set_art_kinds(project_path: String, kinds: Dictionary) -> void:
	var assets: Dictionary = load_assets(project_path)
	assets["kinds"] = {
		"textures": bool(kinds.get("textures", true)),
		"sprites": bool(kinds.get("sprites", true)),
		"models": bool(kinds.get("models", true)),
	}
	save_assets(project_path, assets)


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


static func load_style(project_path: String) -> Dictionary:
	var style: Dictionary = load_json(project_path, STYLE_FILE, default_style())
	var display: Dictionary = load_display(project_path)
	if style.get("graphic_styles", []).is_empty() and display.has("graphic_styles"):
		style["graphic_styles"] = display.get("graphic_styles", [])
	return style


static func save_style(project_path: String, data: Dictionary) -> bool:
	var ok: bool = save_json(project_path, STYLE_FILE, data)
	var display: Dictionary = load_display(project_path)
	display["graphic_styles"] = data.get("graphic_styles", display.get("graphic_styles", []))
	save_json(project_path, DISPLAY_FILE, display)
	return ok


static func set_graphic_styles(project_path: String, styles: PackedStringArray) -> void:
	var normalized: PackedStringArray = GraphicStyleScript.normalize(styles)
	var arr: Array = []
	for s in normalized:
		arr.append(s)
	save_style(project_path, {"graphic_styles": arr})


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


static func assigned(project_path: String, slot: String) -> String:
	var assets: Dictionary = load_assets(project_path)
	var assignments: Variant = assets.get("assignments", {})
	if typeof(assignments) != TYPE_DICTIONARY:
		return ""
	return str((assignments as Dictionary).get(slot, ""))


static func list_variants(project_path: String, slot: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if slot.is_empty():
		return out
	var assets: Dictionary = load_assets(project_path)
	var variants: Variant = assets.get("variants", {})
	if typeof(variants) != TYPE_DICTIONARY:
		return out
	var arr: Variant = (variants as Dictionary).get(slot, [])
	if typeof(arr) != TYPE_ARRAY:
		return out
	for item in arr:
		var p: String = str(item).strip_edges()
		if not p.is_empty() and not out.has(p):
			out.append(p)
	return out


static func remember_variant(project_path: String, slot: String, res_path: String) -> void:
	if slot.is_empty() or res_path.is_empty():
		return
	var assets: Dictionary = load_assets(project_path)
	var variants: Variant = assets.get("variants", {})
	if typeof(variants) != TYPE_DICTIONARY:
		variants = {}
	var arr: Array = []
	var existing: Variant = (variants as Dictionary).get(slot, [])
	if typeof(existing) == TYPE_ARRAY:
		arr = existing
	if not arr.has(res_path):
		arr.append(res_path)
	(variants as Dictionary)[slot] = arr
	assets["variants"] = variants
	save_assets(project_path, assets)


static func add_to_slot(project_path: String, slot: String, res_path: String) -> void:
	if res_path.is_empty():
		return
	var cur: String = assigned(project_path, slot)
	if not cur.is_empty() and cur != res_path:
		remember_variant(project_path, slot, cur)
		var archived: String = LayoutScript.archive_as_variant(project_path, cur)
		if not archived.is_empty():
			remember_variant(project_path, slot, archived)
	remember_variant(project_path, slot, res_path)
	assign_slot(project_path, slot, res_path)


static func change_slot(project_path: String, slot: String, res_path: String) -> void:
	if res_path.is_empty():
		return
	assign_slot(project_path, slot, res_path)


static func load_physics(project_path: String) -> Dictionary:
	var assets: Dictionary = load_assets(project_path)
	var phys: Variant = assets.get("physics", {})
	var merged: Dictionary = default_physics()
	if typeof(phys) == TYPE_DICTIONARY:
		_deep_merge(merged, phys)
	return merged


static func save_physics(project_path: String, data: Dictionary) -> void:
	var assets: Dictionary = load_assets(project_path)
	var merged: Dictionary = default_physics()
	_deep_merge(merged, data)
	assets["physics"] = merged
	save_assets(project_path, assets)
	_write_physics_docs(project_path, merged)


static func upsert_anim_clip(project_path: String, clip_name: String, fps: float, loop: bool, enable_mode: bool = true) -> void:
	var data: Dictionary = load_anim(project_path)
	var anims: Variant = data.get("animations", [])
	var list: Array = anims if typeof(anims) == TYPE_ARRAY else []
	var found: bool = false
	for i in list.size():
		if typeof(list[i]) != TYPE_DICTIONARY:
			continue
		if str(list[i].get("name", "")) != clip_name:
			continue
		var row: Dictionary = list[i]
		row["fps"] = fps
		row["loop"] = loop
		if not row.has("frames"):
			row["frames"] = []
		list[i] = row
		found = true
		break
	if not found:
		list.append({"name": clip_name, "fps": fps, "loop": loop, "frames": [], "notes": "Studio enemy clip"})
	data["animations"] = list
	if enable_mode:
		data["mode_enabled"] = true
	save_anim(project_path, data)


static func assign_slot(project_path: String, slot: String, res_path: String) -> void:
	var assets: Dictionary = load_assets(project_path)
	var assignments: Dictionary = assets.get("assignments", {})
	if typeof(assignments) != TYPE_DICTIONARY:
		assignments = {}
	assignments[slot] = res_path
	match slot:
		"sky", "skybox", "game_background":
			assignments["sky"] = res_path
			assignments["skybox"] = res_path
			assignments["game_background"] = res_path
		"character", "character_sprite":
			assignments["character"] = res_path
			assignments["character_sprite"] = res_path
		_:
			pass
	assets["assignments"] = assignments
	save_assets(project_path, assets)
	var display: Dictionary = load_display(project_path)
	match slot:
		"menu_background":
			display["menu_background"] = res_path
			save_display(project_path, display)
		"game_background", "sky", "skybox":
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
	if not FileAccess.file_exists(project_path.path_join(STYLE_FILE)):
		save_json(project_path, STYLE_FILE, default_style())
	_copy_template(RUNTIME_SRC, project_path.path_join("scripts/studio_runtime.gd"))
	_copy_template(ANIM_SRC, project_path.path_join("scripts/anim_config.gd"))
	_copy_template(FX_SRC, project_path.path_join("scripts/effects_config.gd"))
	_write_anim_script(project_path, load_anim(project_path))
	_write_effects_script(project_path, load_effects(project_path))
	patch_project_autoload(project_path)
	patch_project_physics(project_path)
	_write_editor_docs(project_path)
	_write_physics_docs(project_path, load_physics(project_path))
	_ensure_default_materials(project_path)


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
	if not by_path.has(STYLE_FILE):
		_upsert(out, by_path, STYLE_FILE, JSON.stringify(default_style(), "\t"))
	_upsert(out, by_path, "scripts/studio_runtime.gd", _read_res_text(RUNTIME_SRC))
	_upsert(out, by_path, "scripts/anim_config.gd", _read_res_text(ANIM_SRC))
	_upsert(out, by_path, "scripts/effects_config.gd", _read_res_text(FX_SRC))
	if not by_path.has("docs/STUDIO_EDITORS.md"):
		_upsert(out, by_path, "docs/STUDIO_EDITORS.md", _editor_docs())
	if not by_path.has("docs/PHYSICS.md"):
		_upsert(out, by_path, "docs/PHYSICS.md", _physics_docs(default_physics()))
	if by_path.has("project.godot"):
		by_path["project.godot"]["content"] = _patch_physics_text(_patch_autoload_text(str(by_path["project.godot"].get("content", ""))))
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


static func patch_project_physics(project_path: String) -> void:
	var pg_path: String = project_path.path_join("project.godot")
	if not FileAccess.file_exists(pg_path):
		return
	var pg: String = FileAccess.get_file_as_string(pg_path)
	var patched: String = _patch_physics_text(pg)
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


static func _patch_physics_text(pg: String) -> String:
	var text: String = pg
	if text.contains("3d/physics_engine"):
		return text
	if text.contains("[physics]"):
		return text.replace("[physics]", "[physics]\n3d/physics_engine=\"Jolt Physics\"")
	return text + "\n[physics]\n3d/physics_engine=\"Jolt Physics\"\n"


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
	var mat_slot: String = ""
	var albedo: String = res_path
	match slot:
		"wall", "wall_material":
			mat_slot = "wall_material"
			if slot == "wall_material":
				return
			albedo = res_path
		"floor", "floor_material":
			mat_slot = "floor_material"
			if slot == "floor_material":
				return
		"sky", "skybox", "skybox_material":
			mat_slot = "skybox_material"
			if slot == "skybox_material":
				return
		"character_texture", "character_material":
			mat_slot = "character_material"
			if slot == "character_material":
				return
		"enemy", "enemy_texture", "enemy_material":
			mat_slot = "enemy_material"
			if slot == "enemy_material":
				return
		"weapon", "weapon_texture", "weapon_material":
			mat_slot = "weapon_material"
			if slot == "weapon_material":
				return
		"material":
			mat_slot = "material"
		_:
			return
	if albedo.is_empty() or not (albedo.ends_with(".png") or albedo.ends_with(".jpg") or albedo.ends_with(".jpeg") or albedo.ends_with(".webp")):
		return
	var mat_res: String = write_material_file(project_path, mat_slot, albedo)
	if not mat_res.is_empty() and mat_slot != "material":
		var assets: Dictionary = load_assets(project_path)
		var assignments: Dictionary = assets.get("assignments", {})
		if typeof(assignments) != TYPE_DICTIONARY:
			assignments = {}
		assignments[mat_slot] = mat_res
		assets["assignments"] = assignments
		save_assets(project_path, assets)


static func write_material_file(project_path: String, mat_slot: String, albedo_res: String) -> String:
	var fname: String = LayoutScript.slot_filename(mat_slot)
	if not fname.ends_with(".tres"):
		fname = "%s.tres" % mat_slot
	var dest: String = project_path.path_join("assets/materials").path_join(fname)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var styles: PackedStringArray = GraphicStyleScript.from_variant(load_style(project_path).get("graphic_styles", []))
	var roughness: float = 0.55 if styles.has("realistic") else (0.95 if styles.has("cartoon") else 0.85)
	var metallic: float = 0.18 if styles.has("realistic") else 0.05
	var shading: int = 0 if styles.has("pixel") else 1
	var col: Color = Color.WHITE
	if styles.has("cartoon"):
		col = Color(1.0, 0.96, 0.88)
	elif styles.has("realistic"):
		col = Color(0.86, 0.86, 0.84)
	elif styles.has("minimal"):
		col = Color(0.92, 0.93, 0.94)
	var tex_line: String = ""
	var load_steps: int = 1
	if not albedo_res.is_empty():
		load_steps = 2
		tex_line = "\n[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_tex\"]\n" % albedo_res
	var albedo_tex_line: String = "albedo_texture = ExtResource(\"1_tex\")\n" if load_steps == 2 else ""
	var body: String = """[gd_resource type=\"StandardMaterial3D\" load_steps=%s format=3]
%s[resource]
albedo_color = Color(%s, %s, %s, 1)
%sshading_mode = %s
roughness = %s
metallic = %s
""" % [
		str(load_steps),
		tex_line,
		str(col.r), str(col.g), str(col.b),
		albedo_tex_line,
		str(shading),
		str(roughness),
		str(metallic),
	]
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)
	return "res://assets/materials/%s" % fname


static func _ensure_default_materials(project_path: String) -> void:
	var pairs: Array = [
		["wall_material", "wall"],
		["floor_material", "floor"],
		["skybox_material", "skybox"],
		["character_material", "character_texture"],
		["enemy_material", "enemy_texture"],
		["weapon_material", "weapon_texture"],
	]
	for pair in pairs:
		var mat_slot: String = str(pair[0])
		var tex_slot: String = str(pair[1])
		var mat_rel: String = "assets/materials/%s" % LayoutScript.slot_filename(mat_slot)
		if FileAccess.file_exists(project_path.path_join(mat_rel)):
			continue
		var albedo: String = assigned(project_path, tex_slot)
		if albedo.is_empty():
			albedo = assigned(project_path, tex_slot.replace("_texture", "").replace("_material", ""))
		write_material_file(project_path, mat_slot, albedo)


static func _write_physics_docs(project_path: String, data: Dictionary) -> void:
	if project_path.is_empty():
		return
	var dest: String = project_path.path_join("docs/PHYSICS.md")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(_physics_docs(data))


static func _physics_docs(data: Dictionary) -> String:
	return """# Physics (studio)

This game uses **built-in Godot physics** (free). No paid plugins.

- **Engine:** `%s` — `project.godot` requests **Jolt Physics** when the editor supports it (Godot 4.4+). If Jolt is unavailable, Godot falls back to default Godot Physics automatically.
- **Character:** CharacterBody3D/2D + capsule/box collision matching the assigned model (`character_collision=%s`)
- **Enemy:** CharacterBody3D/2D + collision (`enemy_collision=%s`)
- **World:** StaticBody collision on floor / walls (`world_static=%s`)
- **Room props:** StaticBody around `room_model` (`room_static=%s`)
- **Weapon / debris:** RigidBody3D chips / optional projectiles (`weapon_rigid=%s`)
- **Open addon:** `%s` — MIT/CC0 physics helpers from AssetLib are installed into `addons/` only when license-safe. Gameplay still runs if `addons/` is empty.

StudioRuntime applies collision shapes at Run if a body is missing them. Add / Change in the studio can toggle these flags in `studio_assets.json` → `physics`.
""" % [
		str(data.get("engine", "jolt_or_default")),
		str(data.get("character_collision", true)),
		str(data.get("enemy_collision", true)),
		str(data.get("world_static", true)),
		str(data.get("room_static", true)),
		str(data.get("weapon_rigid", true)),
		str(data.get("addon", "")) if not str(data.get("addon", "")).is_empty() else "(none — built-in only)",
	]


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
- `studio_assets.json` — assigned wall/floor/character texture + character model / enemy / weapon paths
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
