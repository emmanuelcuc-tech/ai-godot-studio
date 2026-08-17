class_name GameAssetLayout
extends RefCounted
## Per-game asset folder layout and download categorization.

const IMAGE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga"]
const MODEL_EXTS: PackedStringArray = ["glb", "gltf", "obj", "fbx", "dae", "blend"]
const MATERIAL_EXTS: PackedStringArray = ["tres", "res", "material", "mtl"]

const CATEGORIES: PackedStringArray = [
	"character",
	"enemy",
	"weapon",
	"world",
	"ui",
	"effects",
	"background",
	"materials",
	"models",
	"sprites",
	"textures",
]

const ASSIGN_SLOTS: PackedStringArray = [
	"wall",
	"floor",
	"sky",
	"skybox",
	"character",
	"character_sprite",
	"character_texture",
	"character_model",
	"character_material",
	"enemy",
	"enemy_texture",
	"enemy_model",
	"enemy_anim",
	"enemy_material",
	"weapon",
	"weapon_texture",
	"weapon_model",
	"weapon_sprite",
	"weapon_material",
	"wall_material",
	"floor_material",
	"skybox_material",
	"room",
	"room_model",
	"menu_background",
	"game_background",
	"ui",
	"material",
	"physics",
]


static func category_rel(category: String) -> String:
	return "assets/%s" % category


static func ensure_layout(project_path: String) -> void:
	if project_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(project_path.path_join("assets"))
	for cat in CATEGORIES:
		DirAccess.make_dir_recursive_absolute(project_path.path_join("assets").path_join(cat))
	DirAccess.make_dir_recursive_absolute(project_path.path_join("scripts"))
	DirAccess.make_dir_recursive_absolute(project_path.path_join("docs"))


static func categorize(filename: String, query: String = "", usage: String = "") -> String:
	var name_l: String = filename.get_file().to_lower()
	var blob: String = "%s %s %s" % [name_l, query.to_lower(), usage.to_lower()]
	var ext: String = name_l.get_extension()
	if MODEL_EXTS.has(ext):
		return "models"
	if MATERIAL_EXTS.has(ext) or blob.contains("material") and ext == "tres":
		return "materials"
	if blob.contains("weapon") or blob.contains("gun") or blob.contains("sword") or blob.contains("muzzle") or name_l.begins_with("weapon"):
		return "weapon"
	if blob.contains("enemy") or blob.contains("monster") or blob.contains("foe") or name_l.contains("enemy"):
		return "enemy"
	if blob.contains("player") or blob.contains("character") or blob.contains("hero") or blob.contains("npc") or name_l.contains("player"):
		return "character"
	if blob.contains("menu") or blob.contains("hud") or blob.contains("icon") or blob.contains("button") or blob.contains("ui") or blob.contains("pickup") or blob.contains("health pack"):
		return "ui"
	if blob.contains("bullet") or blob.contains("explosion") or blob.contains("particle") or blob.contains("muzzle") or blob.contains("fx") or blob.contains("vfx") or blob.contains("impact"):
		return "effects"
	if blob.contains("sky") or blob.contains("background") or blob.contains("backdrop") or blob.contains("horizon") or name_l.contains("sky") or name_l.contains("background"):
		return "background"
	if blob.contains("wall") or blob.contains("floor") or blob.contains("ceiling") or blob.contains("brick") or blob.contains("concrete") or blob.contains("dirt") or blob.contains("grass") or blob.contains("stone") or blob.contains("wood") or blob.contains("tile") or blob.contains("ground") or blob.contains("terrain") or blob.contains("asphalt"):
		return "world"
	if name_l.begins_with("sprite_") or blob.contains("sprite"):
		return "sprites"
	if IMAGE_EXTS.has(ext):
		return "textures"
	return "textures"


static func dest_abs(project_path: String, filename: String, category: String = "") -> String:
	var fname: String = filename.get_file()
	if fname.is_empty():
		fname = "asset.png"
	var cat: String = category if not category.is_empty() else categorize(fname)
	if not CATEGORIES.has(cat):
		cat = "textures"
	return project_path.path_join("assets").path_join(cat).path_join(fname)


static func dest_res(filename: String, category: String = "") -> String:
	var fname: String = filename.get_file()
	var cat: String = category if not category.is_empty() else categorize(fname)
	return "res://assets/%s/%s" % [cat, fname]


static func root_alias_abs(project_path: String, filename: String) -> String:
	return project_path.path_join("assets").path_join(filename.get_file())


static func copy_bytes(dest: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty() or dest.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	return true


static func copy_file(src: String, dest: String) -> bool:
	if src.is_empty() or dest.is_empty() or not FileAccess.file_exists(src):
		return false
	return copy_bytes(dest, FileAccess.get_file_as_bytes(src))


static func install_asset(project_path: String, src_abs: String, filename: String, category: String = "", also_root_alias: bool = true) -> Dictionary:
	ensure_layout(project_path)
	var cat: String = category if not category.is_empty() else categorize(filename)
	var dest: String = dest_abs(project_path, filename, cat)
	if not copy_file(src_abs, dest):
		return {"ok": false, "error": "copy failed"}
	var alias: String = ""
	if also_root_alias:
		alias = root_alias_abs(project_path, filename)
		copy_file(src_abs, alias)
	return {
		"ok": true,
		"category": cat,
		"abs": dest,
		"res": dest_res(filename, cat),
		"alias_abs": alias,
		"alias_res": "res://assets/%s" % filename.get_file(),
	}


static func save_image_bytes(project_path: String, filename: String, bytes: PackedByteArray, category: String = "", also_root_alias: bool = true) -> Dictionary:
	ensure_layout(project_path)
	var cat: String = category if not category.is_empty() else categorize(filename)
	var dest: String = dest_abs(project_path, filename, cat)
	if not copy_bytes(dest, bytes):
		return {"ok": false, "error": "write failed"}
	var alias: String = ""
	if also_root_alias:
		alias = root_alias_abs(project_path, filename)
		copy_bytes(alias, bytes)
	return {
		"ok": true,
		"category": cat,
		"abs": dest,
		"res": dest_res(filename, cat),
		"alias_abs": alias,
		"alias_res": "res://assets/%s" % filename.get_file(),
	}


static func save_image_texture(project_path: String, filename: String, texture: Texture2D, category: String = "") -> Dictionary:
	if texture == null:
		return {"ok": false, "error": "no texture"}
	var img: Image = texture.get_image()
	if img == null:
		return {"ok": false, "error": "no image"}
	ensure_layout(project_path)
	var cat: String = category if not category.is_empty() else categorize(filename)
	var dest: String = dest_abs(project_path, filename.get_basename() + ".png", cat)
	img.save_png(dest)
	var alias: String = root_alias_abs(project_path, dest.get_file())
	img.save_png(alias)
	return {
		"ok": true,
		"category": cat,
		"abs": dest,
		"res": dest_res(dest.get_file(), cat),
		"alias_abs": alias,
		"alias_res": "res://assets/%s" % dest.get_file(),
	}


static func list_category(project_path: String, category: String) -> Array:
	var out: Array = []
	if project_path.is_empty():
		return out
	var dir_path: String = project_path.path_join("assets")
	if not category.is_empty() and category != "all":
		dir_path = dir_path.path_join(category)
	_walk_assets(project_path, dir_path, category, out)
	return out


static func list_all(project_path: String) -> Array:
	var out: Array = []
	if project_path.is_empty():
		return out
	ensure_layout(project_path)
	_walk_assets(project_path, project_path.path_join("assets"), "all", out)
	return out


static func _walk_assets(project_root: String, dir_path: String, category_hint: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			var sub_cat: String = n if CATEGORIES.has(n) else category_hint
			_walk_assets(project_root, full, sub_cat, out)
		else:
			var rel: String = full.substr(project_root.length()).lstrip("/").lstrip("\\").replace("\\", "/")
			var ext: String = n.get_extension().to_lower()
			var kind: String = "file"
			if IMAGE_EXTS.has(ext):
				kind = "image"
			elif MODEL_EXTS.has(ext):
				kind = "model"
			elif MATERIAL_EXTS.has(ext):
				kind = "material"
			var cat: String = category_hint
			if cat.is_empty() or cat == "all":
				cat = categorize(n)
				for known in CATEGORIES:
					if rel.begins_with("assets/%s/" % known):
						cat = known
						break
			out.append({
				"name": n,
				"abs": full,
				"rel": rel,
				"res": "res://%s" % rel,
				"category": cat,
				"kind": kind,
				"ext": ext,
			})
		n = d.get_next()


static func find_existing(project_path: String, filename: String) -> String:
	var fname: String = filename.get_file()
	if fname.is_empty() or project_path.is_empty():
		return ""
	var root_hit: String = root_alias_abs(project_path, fname)
	if FileAccess.file_exists(root_hit):
		return root_hit
	for cat in CATEGORIES:
		var hit: String = project_path.path_join("assets").path_join(cat).path_join(fname)
		if FileAccess.file_exists(hit):
			return hit
	return ""


static func slot_filename(slot: String) -> String:
	match slot:
		"wall":
			return "wall.png"
		"floor":
			return "floor.png"
		"sky", "game_background":
			return "sky.png"
		"skybox":
			return "skybox.png"
		"character", "character_sprite":
			return "sprite_player.png"
		"character_texture":
			return "character.png"
		"character_model":
			return "character.obj"
		"character_material":
			return "character.tres"
		"enemy":
			return "sprite_enemy.png"
		"enemy_texture":
			return "enemy.png"
		"enemy_model":
			return "enemy.obj"
		"enemy_anim":
			return "idle"
		"enemy_material":
			return "enemy.tres"
		"weapon", "weapon_texture":
			return "weapon.png"
		"weapon_sprite":
			return "sprite_weapon.png"
		"weapon_model":
			return "weapon.obj"
		"weapon_material":
			return "weapon.tres"
		"wall_material":
			return "wall.tres"
		"floor_material":
			return "floor.tres"
		"skybox_material":
			return "skybox.tres"
		"room":
			return "wall.png"
		"room_model":
			return "room.obj"
		"menu_background":
			return "menu_bg.png"
		"ui":
			return "ui_panel.png"
		"material":
			return "material.tres"
		"physics":
			return "physics.json"
		_:
			return "%s.png" % slot


static func slot_category(slot: String) -> String:
	match slot:
		"wall", "floor", "room":
			return "world"
		"room_model":
			return "models"
		"sky", "skybox", "game_background", "menu_background":
			return "background"
		"character", "character_sprite", "character_texture", "character_model":
			return "character"
		"enemy", "enemy_texture", "enemy_model", "enemy_anim":
			return "enemy"
		"weapon", "weapon_texture", "weapon_model", "weapon_sprite":
			return "weapon"
		"ui":
			return "ui"
		"material", "character_material", "enemy_material", "weapon_material", "wall_material", "floor_material", "skybox_material":
			return "materials"
		"physics":
			return "effects"
		_:
			return "textures"


static func unique_filename(stem: String, ext: String) -> String:
	var safe_stem: String = stem.get_file().get_basename()
	if safe_stem.is_empty():
		safe_stem = "asset"
	var safe_ext: String = ext.lstrip(".")
	if safe_ext.is_empty():
		safe_ext = "png"
	return "%s_%s.%s" % [safe_stem, str(Time.get_unix_time_from_system()).replace(".", ""), safe_ext]


static func unique_sibling(abs_path: String) -> String:
	if abs_path.is_empty():
		return ""
	var dir_path: String = abs_path.get_base_dir()
	var base: String = abs_path.get_file().get_basename()
	var ext: String = abs_path.get_extension()
	var i: int = 2
	var dest: String = dir_path.path_join("%s_v%s.%s" % [base, str(i), ext])
	while FileAccess.file_exists(dest):
		i += 1
		dest = dir_path.path_join("%s_v%s.%s" % [base, str(i), ext])
	return dest


static func archive_as_variant(project_path: String, res_path: String) -> String:
	var rel: String = res_path.trim_prefix("res://").lstrip("/").replace("\\", "/")
	if rel.is_empty() or project_path.is_empty():
		return ""
	var abs_path: String = project_path.path_join(rel)
	if not FileAccess.file_exists(abs_path):
		return ""
	var dest: String = unique_sibling(abs_path)
	if dest.is_empty() or not copy_file(abs_path, dest):
		return ""
	var new_rel: String = dest.substr(project_path.length()).lstrip("/").lstrip("\\").replace("\\", "/")
	return "res://%s" % new_rel
