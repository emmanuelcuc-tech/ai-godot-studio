class_name LocalAssetLibrary
extends RefCounted
## Indexes only F:/asset (or Settings path). Never scans other F:\ dumps.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")

const DEFAULT_ROOT := "F:/asset"
const BLOCKED_ROOT_MARKERS: PackedStringArray = ["battlefield", "rom", "iso dump", "wad dump"]
const SKIP_DIR_NAMES: PackedStringArray = [
	".git", ".godot", "__pycache__", "godot-cpp", "installer", "utilities", "node_modules",
]
const TEX_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "tga", "bmp"]
const MAT_EXTS: PackedStringArray = ["tres", "res", "material", "mtl"]
const MODEL_EXTS: PackedStringArray = ["glb", "gltf", "obj", "fbx"]
const PHYS_NAME_HINTS: PackedStringArray = ["joint", "grab", "rigid", "physics", "collision", "phys"]

static var _cache_root: String = ""
static var _cache_at: int = 0
static var _cache_items: Array = []


static func configured_root() -> String:
	var raw: String = ""
	if Engine.get_main_loop() is SceneTree:
		var root_n: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AppSettings")
		if root_n and root_n.get("local_asset_folder") != null:
			raw = str(root_n.local_asset_folder).strip_edges()
	if raw.is_empty():
		raw = DEFAULT_ROOT
	return raw.replace("\\", "/")


static func is_allowed_root(path: String) -> bool:
	var n: String = path.replace("\\", "/").strip_edges().to_lower().rstrip("/")
	if n.is_empty():
		return false
	if n == "f:" or n == "f:/":
		return false
	for marker in BLOCKED_ROOT_MARKERS:
		if n.contains(marker):
			return false
	var base: String = n.get_file()
	if base != "asset":
		# still allow a renamed copy only if it ends with /asset
		if not n.ends_with("/asset"):
			return false
	return DirAccess.dir_exists_absolute(path)


static func scan(force: bool = false) -> Array:
	var root: String = configured_root()
	var now: int = int(Time.get_unix_time_from_system())
	if not force and _cache_root == root and _cache_at > now - 20:
		return _cache_items.duplicate(true)
	var out: Array = []
	if not is_allowed_root(root):
		_cache_root = root
		_cache_at = now
		_cache_items = out
		return out
	_walk(root, root, 0, out)
	_cache_root = root
	_cache_at = now
	_cache_items = out
	return out.duplicate(true)


static func list_for(section: String, kind: String = "") -> Array:
	var out: Array = []
	for row in scan():
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if not kind.is_empty() and str(row.get("kind", "")) != kind:
			continue
		var tags: PackedStringArray = row.get("tags", PackedStringArray())
		if typeof(tags) != TYPE_PACKED_STRING_ARRAY:
			tags = PackedStringArray()
		match section:
			"character":
				if tags.has("character") or tags.has("model") or tags.has("texture") or tags.has("material"):
					out.append(row)
			"world":
				if tags.has("world") or tags.has("texture") or tags.has("material") or str(row.get("kind", "")) == "image":
					out.append(row)
			"enemy":
				if tags.has("enemy") or tags.has("model") or tags.has("texture") or tags.has("material"):
					out.append(row)
			"weapon":
				if tags.has("weapon") or tags.has("model") or tags.has("texture") or tags.has("material"):
					out.append(row)
			"materials":
				if str(row.get("kind", "")) == "material" or tags.has("material"):
					out.append(row)
			"physics":
				if tags.has("physics"):
					out.append(row)
			"models":
				if str(row.get("kind", "")) == "model":
					out.append(row)
			_:
				out.append(row)
	return out


static func apply_on_create(project_path: String, genre_id: String, kinds: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": false, "copied": 0, "assigned": [], "physics": "", "error": ""}
	if project_path.is_empty() or not is_allowed_root(configured_root()):
		result["error"] = "local folder missing"
		return result
	LayoutScript.ensure_layout(project_path)
	var copied: int = 0
	var assigned: PackedStringArray = PackedStringArray()
	var want_tex: bool = bool(kinds.get("textures", true))
	var want_spr: bool = bool(kinds.get("sprites", true))
	var want_mdl: bool = bool(kinds.get("models", true))
	var items: Array = scan(true)
	for row in items:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var kind: String = str(row.get("kind", ""))
		var tags: PackedStringArray = row.get("tags", PackedStringArray())
		if kind == "image" and not (want_tex or want_spr):
			continue
		if kind == "model" and not want_mdl:
			continue
		if kind == "physics_scene":
			continue
		if kind == "cs":
			continue
		if kind == "plugin" or kind == "script":
			continue
		var cat: String = _dest_category(row, genre_id)
		if cat.is_empty():
			continue
		# Auto-create copies a focused subset, not the whole tree.
		if not _auto_pick(row, genre_id, kind, tags):
			continue
		var installed: Dictionary = import_file(project_path, str(row.get("abs", "")), cat)
		if not installed.get("ok", false):
			continue
		copied += 1
		_maybe_assign_auto(project_path, row, str(installed.get("res", "")), assigned)
	var phys: Dictionary = install_physics_helpers(project_path)
	if phys.get("ok", false):
		result["physics"] = str(phys.get("addon", "local helpers"))
		copied += int(phys.get("copied", 0))
	_write_attribution(project_path)
	result["ok"] = copied > 0 or bool(phys.get("ok", false))
	result["copied"] = copied
	result["assigned"] = assigned
	return result


static func import_file(project_path: String, src_abs: String, category: String) -> Dictionary:
	if project_path.is_empty() or src_abs.is_empty() or not FileAccess.file_exists(src_abs):
		return {"ok": false, "error": "missing source"}
	if not _src_is_under_allowed(src_abs):
		return {"ok": false, "error": "blocked path"}
	var fname: String = src_abs.get_file()
	if fname.get_extension().is_empty():
		return {"ok": false, "error": "no extension"}
	var installed: Dictionary = LayoutScript.install_asset(project_path, src_abs, "local_%s" % fname, category, true)
	if installed.get("ok", false):
		_write_attribution(project_path)
	return installed


static func install_physics_helpers(project_path: String) -> Dictionary:
	var root: String = configured_root()
	var out: Dictionary = {"ok": false, "copied": 0, "addon": "", "skipped_csharp": true}
	if project_path.is_empty() or not is_allowed_root(root):
		return out
	var addon_rel: String = "addons/f_asset_physics"
	var addon_abs: String = project_path.path_join(addon_rel)
	DirAccess.make_dir_recursive_absolute(addon_abs)
	var copied: int = 0
	# GDScript-safe PhysKit scenes only — skip Player*.cs / Player.tscn (C# RigidBody controller).
	for fname in ["fixed_joint.tscn", "Grab Pivot.tscn"]:
		var src: String = root.path_join(fname)
		if not FileAccess.file_exists(src):
			continue
		var dest_name: String = fname.to_lower().replace(" ", "_")
		if LayoutScript.copy_file(src, addon_abs.path_join(dest_name)):
			copied += 1
	var white_src: String = root.path_join("Materials").path_join("White.tres")
	if FileAccess.file_exists(white_src) and LayoutScript.copy_file(white_src, addon_abs.path_join("White.tres")):
		copied += 1
	var cfg_body: String = """[plugin]
name=\"F Asset Physics Helpers\"
description=\"GDScript-safe joints/grab scenes copied from local F:/asset. C# PhysKit player is skipped so Run Game stays GDScript-only.\"
author=\"Local F:/asset + studio\"
version=\"1.0\"
script=\"plugin.gd\"
"""
	var plug_gd: String = """@tool
extends EditorPlugin
## Optional editor marker. Gameplay uses built-in Godot/Jolt physics + copied joint/grab scenes.
func _enter_tree() -> void:
	pass
func _exit_tree() -> void:
	pass
"""
	var fcfg: FileAccess = FileAccess.open(addon_abs.path_join("plugin.cfg"), FileAccess.WRITE)
	if fcfg:
		fcfg.store_string(cfg_body)
		copied += 1
	var fgd: FileAccess = FileAccess.open(addon_abs.path_join("plugin.gd"), FileAccess.WRITE)
	if fgd:
		fgd.store_string(plug_gd)
		copied += 1
	var helper: String = """extends RefCounted
## Runtime notes for copied F:/asset physics scenes (no C# required).

static func joint_scene() -> String:
	return \"res://addons/f_asset_physics/fixed_joint.tscn\"

static func grab_pivot_scene() -> String:
	return \"res://addons/f_asset_physics/grab_pivot.tscn\"
"""
	var fh: FileAccess = FileAccess.open(addon_abs.path_join("phys_helpers.gd"), FileAccess.WRITE)
	if fh:
		fh.store_string(helper)
		copied += 1
	var phys: Dictionary = ConfigScript.load_physics(project_path)
	phys["addon"] = "F Asset Physics Helpers (GDScript-safe joints/grab; C# skipped)"
	phys["local_folder"] = root
	ConfigScript.save_physics(project_path, phys)
	_write_attribution(project_path)
	out["ok"] = copied > 0
	out["copied"] = copied
	out["addon"] = "addons/f_asset_physics"
	return out


static func _walk(root: String, dir_path: String, depth: int, out: Array) -> void:
	if depth > 6:
		return
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
			var low: String = n.to_lower()
			if SKIP_DIR_NAMES.has(low) or low.contains("battlefield"):
				n = d.get_next()
				continue
			_walk(root, full, depth + 1, out)
		else:
			var row: Dictionary = _classify(root, full)
			if not row.is_empty():
				out.append(row)
		n = d.get_next()


static func _classify(root: String, abs_path: String) -> Dictionary:
	var rel: String = abs_path.substr(root.length()).lstrip("/").lstrip("\\").replace("\\", "/")
	var rel_l: String = rel.to_lower()
	var fname: String = abs_path.get_file()
	var ext: String = fname.get_extension().to_lower()
	if ext == "import" or ext == "uid" or ext == "md" or ext == "txt":
		return {}
	if rel_l.contains("battlefield") or rel_l.contains("/rom/") or rel_l.begins_with("rom"):
		return {}
	var kind: String = ""
	var tags: PackedStringArray = PackedStringArray()
	if TEX_EXTS.has(ext):
		kind = "image"
		tags.append("texture")
	elif MAT_EXTS.has(ext) or rel_l.begins_with("materials/") or rel_l.contains("/materials/"):
		kind = "material"
		tags.append("material")
	elif MODEL_EXTS.has(ext):
		kind = "model"
		tags.append("model")
	elif fname == "plugin.cfg" or fname == "plugin.gd":
		kind = "plugin"
		tags.append("physics")
	elif ext == "cs":
		kind = "cs"
		tags.append("physics")
	elif ext == "tscn" and _name_has_phys(rel_l + " " + fname.to_lower()):
		kind = "physics_scene"
		tags.append("physics")
	elif ext == "gd" and _name_has_phys(fname.to_lower()):
		kind = "script"
		tags.append("physics")
	else:
		return {}
	if rel_l.contains("character") or rel_l.contains("player") or rel_l.contains("human") or fname.to_lower().contains("player"):
		tags.append("character")
	if rel_l.contains("enemy") or rel_l.contains("monster"):
		tags.append("enemy")
	if rel_l.contains("weapon") or rel_l.contains("gun") or rel_l.contains("sword"):
		tags.append("weapon")
	if rel_l.contains("world") or rel_l.contains("floor") or rel_l.contains("wall") or rel_l.contains("sky") or rel_l.contains("grass") or rel_l.contains("rock") or rel_l.contains("dirt"):
		tags.append("world")
	if rel_l.begins_with("textures/") or rel_l.contains("/textures/"):
		tags.append("world")
	return {
		"name": fname,
		"abs": abs_path.replace("\\", "/"),
		"rel": rel,
		"kind": kind,
		"tags": tags,
		"source": "local",
		"label": "[F:asset] %s" % rel,
	}


static func _name_has_phys(blob: String) -> bool:
	for h in PHYS_NAME_HINTS:
		if blob.contains(h):
			return true
	return blob.contains("player.tscn") or blob.contains("world.tscn")


static func _dest_category(row: Dictionary, _genre_id: String) -> String:
	var kind: String = str(row.get("kind", ""))
	var tags: PackedStringArray = row.get("tags", PackedStringArray())
	if tags.has("character"):
		return "character"
	if tags.has("enemy"):
		return "enemy"
	if tags.has("weapon"):
		return "weapon"
	if kind == "material":
		return "materials"
	if kind == "model":
		return "models"
	if kind == "image":
		return "world" if tags.has("world") else "textures"
	return ""


static func _auto_pick(row: Dictionary, genre_id: String, kind: String, tags: PackedStringArray) -> bool:
	var rel: String = str(row.get("rel", "")).to_lower()
	var name_l: String = str(row.get("name", "")).to_lower()
	if kind == "material":
		if rel.begins_with("materials/") or rel.contains("demos/assets/materials"):
			if genre_id == "fps" or genre_id == "tps" or genre_id == "voxel" or genre_id == "open_world":
				return name_l.contains("rock") or name_l.contains("grass") or name_l.contains("leaf") or name_l.contains("water") or name_l.contains("grey") or name_l.contains("dark") or name_l.contains("white") or name_l.contains("black")
			return name_l.contains("leaf") or name_l.contains("grass") or name_l.contains("white")
		return false
	if kind == "model":
		return rel.begins_with("models/")
	if kind == "image":
		return rel.begins_with("textures/") or tags.has("character")
	return false


static func _maybe_assign_auto(project_path: String, row: Dictionary, res_path: String, assigned: PackedStringArray) -> void:
	var name_l: String = str(row.get("name", "")).to_lower()
	var kind: String = str(row.get("kind", ""))
	if kind == "model" and not assigned.has("room_model"):
		ConfigScript.add_to_slot(project_path, "room_model", res_path)
		assigned.append("room_model")
	if kind == "material":
		if (name_l.contains("rock") or name_l.contains("grey") or name_l.contains("dark")) and not assigned.has("wall_material"):
			ConfigScript.add_to_slot(project_path, "wall_material", res_path)
			assigned.append("wall_material")
		elif (name_l.contains("grass") or name_l.contains("leaf")) and not assigned.has("floor_material"):
			ConfigScript.add_to_slot(project_path, "floor_material", res_path)
			assigned.append("floor_material")
		elif name_l.contains("white") and not assigned.has("character_material"):
			ConfigScript.add_to_slot(project_path, "character_material", res_path)
			assigned.append("character_material")
	if kind == "image":
		if name_l.contains("leaf") or name_l.contains("grass"):
			if not assigned.has("floor"):
				ConfigScript.add_to_slot(project_path, "floor", res_path)
				assigned.append("floor")
		if name_l.contains("sakura") or name_l.contains("feather"):
			if not assigned.has("skybox"):
				ConfigScript.add_to_slot(project_path, "skybox", res_path)
				assigned.append("skybox")


static func _src_is_under_allowed(src_abs: String) -> bool:
	var root: String = configured_root().replace("\\", "/").to_lower().rstrip("/")
	var src: String = src_abs.replace("\\", "/").to_lower()
	if not is_allowed_root(configured_root()):
		return false
	return src.begins_with(root + "/") or src == root


static func _write_attribution(project_path: String) -> void:
	var root: String = configured_root()
	var dest: String = project_path.path_join("docs/F_ASSET_ATTRIBUTION.md")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var body: String = "# Local F:/asset attribution\n\nCopied from `%s` into this project (runtime does not depend on F:).\n\n" % root
	for fname in ["ATTRIBUTION.md", "LICENSE.txt", "LICENSE", "README.md"]:
		var src: String = root.path_join(fname)
		if FileAccess.file_exists(src):
			body += "## %s\n\n```\n%s\n```\n\n" % [fname, FileAccess.get_file_as_string(src).left(6000)]
	body += "Physics: C# PhysKit player scripts were **not** copied so GDScript Run Game keeps working. GDScript-safe `fixed_joint.tscn` / grab pivot live under `addons/f_asset_physics/`.\n"
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)
