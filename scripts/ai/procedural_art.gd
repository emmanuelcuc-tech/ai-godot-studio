class_name ProceduralArt
extends RefCounted
## Always-on starter art: colored PNGs + simple mesh placeholders.
## Used so generated games are never untextured gray. CC0 / original only.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const GraphicStyleScript = preload("res://scripts/graphic_style.gd")

static var active_styles: PackedStringArray = PackedStringArray()


static func set_styles(styles: PackedStringArray) -> void:
	active_styles = GraphicStyleScript.normalize(styles)


static func default_kinds() -> Dictionary:
	return {"textures": true, "sprites": true, "models": true}


static func normalize_kinds(kinds: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"textures": bool(kinds.get("textures", true)),
		"sprites": bool(kinds.get("sprites", true)),
		"models": bool(kinds.get("models", true)),
	}
	if not out["textures"] and not out["sprites"] and not out["models"]:
		out["textures"] = true
		out["sprites"] = true
		out["models"] = true
	return out


static func write_starter_art(project_path: String, genre_id: String, kinds: Dictionary = {}, overwrite: bool = false) -> Array:
	if project_path.is_empty():
		return []
	var k: Dictionary = normalize_kinds(kinds)
	LayoutScript.ensure_layout(project_path)
	var written: Array = []
	if bool(k.get("textures", true)):
		written.append_array(_write_world_textures(project_path, genre_id, overwrite))
		written.append(_write_named(project_path, "character.png", "character", "skin", overwrite))
	if bool(k.get("sprites", true)):
		written.append(_write_named(project_path, "sprite_player.png", "character", "hero", overwrite))
		written.append(_write_named(project_path, "sprite_enemy.png", "enemy", "enemy", overwrite))
		written.append(_write_named(project_path, "sprite_pickup.png", "ui", "pickup", overwrite))
		written.append(_write_named(project_path, "weapon.png", "weapon", "metal", overwrite))
	if bool(k.get("models", true)):
		written.append(_write_character_model(project_path, genre_id, overwrite))
		written.append(_write_named(project_path, "character.png", "character", "skin", overwrite))
		written.append(_write_weapon_model(project_path, overwrite))
		written.append(_write_room_model(project_path, overwrite))
	_assign_defaults(project_path, k)
	return written


static func write_named(project_path: String, filename: String, category: String = "", kind_hint: String = "", overwrite: bool = true) -> Dictionary:
	return _write_named(project_path, filename, category, kind_hint, overwrite)


static func write_character_model(project_path: String, genre_id: String = "fps", overwrite: bool = true) -> Dictionary:
	return _write_character_model(project_path, genre_id, overwrite)


static func write_weapon_model(project_path: String, overwrite: bool = true) -> Dictionary:
	return _write_weapon_model(project_path, overwrite)


static func write_room_model(project_path: String, overwrite: bool = true) -> Dictionary:
	return _write_room_model(project_path, overwrite)


static func write_unique(project_path: String, stem: String, ext: String, category: String, kind_hint: String) -> Dictionary:
	var fname: String = LayoutScript.unique_filename(stem, ext)
	return _write_named(project_path, fname, category, kind_hint, true)


static func write_shape_model(project_path: String, category: String, stem: String, shape: String, overwrite: bool = true) -> Dictionary:
	var kind: String = shape.strip_edges().to_lower()
	if kind.is_empty():
		kind = "capsule"
	var fname: String = "%s_%s.obj" % [stem.get_file().get_basename(), kind]
	var body: String = _obj_box(0.32, 0.75, 0.32)
	match kind:
		"humanoid":
			body = _obj_humanoid()
		"box":
			body = _obj_box(0.4, 0.4, 0.4) if category != "weapon" else _obj_box(0.08, 0.06, 0.28)
		"capsule":
			body = _obj_box(0.28, 0.8, 0.28) if category != "weapon" else _obj_box(0.06, 0.06, 0.32)
		_:
			body = _obj_box(0.32, 0.6, 0.32)
	return _write_obj_file(project_path, fname, category, body, "generated %s %s mesh" % [category, kind], overwrite)


static func ensure_kit_variants(project_path: String) -> void:
	if project_path.is_empty():
		return
	LayoutScript.ensure_layout(project_path)
	_write_named(project_path, "sky.png", "world", "sky", false)
	_write_named(project_path, "sky.png", "background", "sky", false)
	_write_named(project_path, "skybox.png", "background", "sky", false)
	_write_named(project_path, "enemy.png", "enemy", "enemy", false)
	_write_named(project_path, "sprite_weapon.png", "weapon", "metal", false)
	write_shape_model(project_path, "character", "character", "capsule", false)
	write_shape_model(project_path, "character", "character", "box", false)
	if not FileAccess.file_exists(LayoutScript.dest_abs(project_path, "character.obj", "character")):
		_write_character_model(project_path, "fps", false)
	write_shape_model(project_path, "enemy", "enemy", "capsule", false)
	write_shape_model(project_path, "enemy", "enemy", "box", false)
	write_shape_model(project_path, "enemy", "enemy", "humanoid", false)
	if not FileAccess.file_exists(LayoutScript.dest_abs(project_path, "weapon.obj", "weapon")):
		_write_weapon_model(project_path, false)
	_ensure_slot(project_path, "skybox", "res://assets/background/skybox.png")
	_ensure_slot(project_path, "character_sprite", "res://assets/character/sprite_player.png")
	_ensure_slot(project_path, "enemy_texture", "res://assets/enemy/enemy.png")
	_ensure_slot(project_path, "enemy_model", "res://assets/enemy/enemy_capsule.obj")
	_ensure_slot(project_path, "weapon_sprite", "res://assets/weapon/sprite_weapon.png")
	ConfigScript._ensure_default_materials(project_path)


static func _write_world_textures(project_path: String, genre_id: String, overwrite: bool = false) -> Array:
	var out: Array = []
	match genre_id:
		"voxel":
			out.append(_write_named(project_path, "grass.png", "world", "grass", overwrite))
			out.append(_write_named(project_path, "dirt.png", "world", "dirt", overwrite))
			out.append(_write_named(project_path, "stone.png", "world", "stone", overwrite))
			out.append(_write_named(project_path, "wall.png", "world", "wood", overwrite))
			out.append(_write_named(project_path, "floor.png", "world", "grass", overwrite))
			out.append(_write_named(project_path, "sky.png", "background", "sky", overwrite))
		"platformer", "beat_em_up", "fighting", "space_shooter", "arena":
			out.append(_write_named(project_path, "wall.png", "world", "brick", overwrite))
			out.append(_write_named(project_path, "floor.png", "world", "dirt", overwrite))
			out.append(_write_named(project_path, "ground.png", "world", "grass", overwrite))
			out.append(_write_named(project_path, "sky.png", "background", "sky", overwrite))
			out.append(_write_named(project_path, "background.png", "background", "sky", overwrite))
		"racing":
			out.append(_write_named(project_path, "floor.png", "world", "asphalt", overwrite))
			out.append(_write_named(project_path, "wall.png", "world", "concrete", overwrite))
			out.append(_write_named(project_path, "grass.png", "world", "grass", overwrite))
			out.append(_write_named(project_path, "sky.png", "background", "sky", overwrite))
		_:
			out.append(_write_named(project_path, "wall.png", "world", "brick", overwrite))
			out.append(_write_named(project_path, "floor.png", "world", "concrete", overwrite))
			out.append(_write_named(project_path, "sky.png", "background", "sky", overwrite))
			out.append(_write_named(project_path, "sky.png", "world", "sky", overwrite))
			out.append(_write_named(project_path, "skybox.png", "background", "sky", overwrite))
			out.append(_write_named(project_path, "ceiling.png", "world", "metal", overwrite))
			out.append(_write_named(project_path, "enemy.png", "enemy", "enemy", overwrite))
			out.append(_write_named(project_path, "sprite_weapon.png", "weapon", "metal", overwrite))
	return out


static func _write_named(project_path: String, filename: String, category: String, kind_hint: String, overwrite: bool = false) -> Dictionary:
	var fname: String = filename.get_file()
	if fname.is_empty():
		fname = "wall.png"
	var cat: String = category if not category.is_empty() else LayoutScript.categorize(fname, kind_hint)
	var hint: String = kind_hint if not kind_hint.is_empty() else fname.get_basename()
	var img: Image = make_image(hint)
	var dest: String = LayoutScript.dest_abs(project_path, fname, cat)
	var alias: String = LayoutScript.root_alias_abs(project_path, fname)
	if not overwrite and FileAccess.file_exists(dest):
		return {
			"filename": fname,
			"category": cat,
			"path": dest,
			"res": LayoutScript.dest_res(fname, cat),
			"license": "on disk",
			"source": "existing",
			"query": "existing %s" % hint,
		}
	if not overwrite and FileAccess.file_exists(alias) and not FileAccess.file_exists(dest):
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		LayoutScript.copy_file(alias, dest)
		return {
			"filename": fname,
			"category": cat,
			"path": dest,
			"res": LayoutScript.dest_res(fname, cat),
			"license": "on disk",
			"source": "existing",
			"query": "existing %s" % hint,
		}
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	img.save_png(dest)
	img.save_png(alias)
	return {
		"filename": fname,
		"category": cat,
		"path": dest,
		"res": LayoutScript.dest_res(fname, cat),
		"license": "generated",
		"source": "procedural",
		"query": "generated %s" % hint,
	}


static func _write_character_model(project_path: String, genre_id: String, overwrite: bool = false) -> Dictionary:
	var fname: String = "character.obj"
	var cat: String = "character"
	var dest: String = LayoutScript.dest_abs(project_path, fname, cat)
	if not overwrite and FileAccess.file_exists(dest):
		return {
			"filename": fname,
			"category": cat,
			"path": dest,
			"res": LayoutScript.dest_res(fname, cat),
			"license": "on disk",
			"source": "existing",
			"query": "existing character mesh",
		}
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var body: String = _obj_humanoid() if genre_id != "space_shooter" else _obj_box(0.4, 0.25, 0.6)
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)
	var alias: String = LayoutScript.root_alias_abs(project_path, fname)
	var f2: FileAccess = FileAccess.open(alias, FileAccess.WRITE)
	if f2:
		f2.store_string(body)
	var models_copy: String = project_path.path_join("assets/models").path_join(fname)
	DirAccess.make_dir_recursive_absolute(models_copy.get_base_dir())
	var f3: FileAccess = FileAccess.open(models_copy, FileAccess.WRITE)
	if f3:
		f3.store_string(body)
	return {
		"filename": fname,
		"category": cat,
		"path": dest,
		"res": LayoutScript.dest_res(fname, cat),
		"license": "generated",
		"source": "procedural",
		"query": "generated character mesh",
	}


static func _write_weapon_model(project_path: String, overwrite: bool = false) -> Dictionary:
	return _write_obj_file(project_path, "weapon.obj", "weapon", _obj_box(0.08, 0.06, 0.28), "generated weapon mesh", overwrite)


static func _write_room_model(project_path: String, overwrite: bool = false) -> Dictionary:
	return _write_obj_file(project_path, "room.obj", "models", _obj_box(2.4, 1.4, 2.4), "generated room mesh", overwrite)


static func _write_obj_file(project_path: String, fname: String, cat: String, body: String, query: String, overwrite: bool) -> Dictionary:
	var dest: String = LayoutScript.dest_abs(project_path, fname, cat)
	if not overwrite and FileAccess.file_exists(dest):
		return {
			"filename": fname,
			"category": cat,
			"path": dest,
			"res": LayoutScript.dest_res(fname, cat),
			"license": "on disk",
			"source": "existing",
			"query": "existing %s" % fname,
		}
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(body)
	var alias: String = LayoutScript.root_alias_abs(project_path, fname)
	var f2: FileAccess = FileAccess.open(alias, FileAccess.WRITE)
	if f2:
		f2.store_string(body)
	return {
		"filename": fname,
		"category": cat,
		"path": dest,
		"res": LayoutScript.dest_res(fname, cat),
		"license": "generated",
		"source": "procedural",
		"query": query,
	}


static func _assign_defaults(project_path: String, kinds: Dictionary) -> void:
	if bool(kinds.get("textures", true)) or bool(kinds.get("sprites", true)):
		_ensure_slot(project_path, "wall", "res://assets/world/wall.png")
		_ensure_slot(project_path, "floor", "res://assets/world/floor.png")
		_ensure_slot(project_path, "sky", "res://assets/background/sky.png")
		_ensure_slot(project_path, "skybox", "res://assets/background/skybox.png")
		if bool(kinds.get("sprites", true)):
			_ensure_slot(project_path, "character", "res://assets/character/sprite_player.png")
			_ensure_slot(project_path, "character_sprite", "res://assets/character/sprite_player.png")
			_ensure_slot(project_path, "enemy", "res://assets/enemy/sprite_enemy.png")
			_ensure_slot(project_path, "weapon", "res://assets/weapon/weapon.png")
			_ensure_slot(project_path, "weapon_sprite", "res://assets/weapon/sprite_weapon.png")
		else:
			_ensure_slot(project_path, "character", "res://assets/character/character.png")
		_ensure_slot(project_path, "character_texture", "res://assets/character/character.png")
		_ensure_slot(project_path, "enemy_texture", "res://assets/enemy/enemy.png")
	if bool(kinds.get("models", true)):
		_ensure_slot(project_path, "character_model", "res://assets/character/character.obj")
		_ensure_slot(project_path, "enemy_model", "res://assets/enemy/enemy_capsule.obj")
		_ensure_slot(project_path, "weapon_model", "res://assets/weapon/weapon.obj")
		_ensure_slot(project_path, "room_model", "res://assets/models/room.obj")
		_ensure_slot(project_path, "room", "res://assets/world/wall.png")
		_ensure_slot(project_path, "weapon_texture", "res://assets/weapon/weapon.png")
	ensure_kit_variants(project_path)


static func _ensure_slot(project_path: String, slot: String, res_path: String) -> void:
	var assets: Dictionary = ConfigScript.load_assets(project_path)
	var assignments: Variant = assets.get("assignments", {})
	if typeof(assignments) == TYPE_DICTIONARY:
		var cur: String = str((assignments as Dictionary).get(slot, ""))
		if not cur.is_empty():
			var rel: String = cur.trim_prefix("res://").trim_prefix("/")
			if FileAccess.file_exists(project_path.path_join(rel)):
				return
	ConfigScript.assign_slot(project_path, slot, res_path)


static func make_image(kind: String, size: int = 128) -> Image:
	var styles: PackedStringArray = GraphicStyleScript.normalize(active_styles)
	var sz: int = 64 if styles.has("pixel") else size
	if styles.has("detailed") and not styles.has("pixel"):
		sz = maxi(sz, 160)
	var img: Image = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var k: String = kind.to_lower()
	var brick: Color = _style_color(Color(0.58, 0.26, 0.18), styles)
	var concrete: Color = _style_color(Color(0.22, 0.22, 0.24), styles)
	var stone: Color = _style_color(Color(0.42, 0.42, 0.44), styles)
	var metal: Color = _style_color(Color(0.52, 0.55, 0.58), styles)
	var dirt: Color = _style_color(Color(0.45, 0.30, 0.16), styles)
	var grass: Color = _style_color(Color(0.28, 0.58, 0.22), styles)
	var amp: float = 0.04 if styles.has("minimal") else (0.22 if styles.has("detailed") else 0.12)
	if k.contains("brick"):
		if styles.has("minimal"):
			img.fill(brick)
		else:
			_fill_bricks(img, brick, Color(0.38, 0.34, 0.30), styles.has("pixel"))
	elif k.contains("concrete") or k.contains("stone") or k.contains("asphalt"):
		if styles.has("minimal"):
			img.fill(stone if k.contains("stone") else concrete)
		else:
			_fill_noise(img, stone if k.contains("stone") else concrete, amp)
	elif k.contains("metal"):
		if styles.has("minimal"):
			img.fill(metal)
		else:
			_fill_noise(img, metal, amp * 0.7)
			if styles.has("detailed"):
				_hatch(img, metal.darkened(0.25))
	elif k.contains("dirt") or k.contains("wood"):
		if styles.has("minimal"):
			img.fill(dirt)
		else:
			_fill_noise(img, dirt, amp)
	elif k.contains("grass"):
		if styles.has("minimal"):
			img.fill(grass)
		else:
			_fill_noise(img, grass, amp)
	elif k.contains("sky"):
		_fill_sky(img, styles)
	elif k.contains("enemy") or k.contains("monster"):
		_fill_sprite_figure(img, _style_color(Color(0.72, 0.18, 0.16), styles), _style_color(Color(0.12, 0.08, 0.08), styles), styles.has("pixel"))
	elif k.contains("hero") or k.contains("player") or k.contains("skin") or k.contains("character"):
		_fill_sprite_figure(img, _style_color(Color(0.92, 0.72, 0.52), styles), _style_color(Color(0.18, 0.22, 0.55), styles), styles.has("pixel"))
	elif k.contains("pickup") or k.contains("health"):
		_fill_cross(img, _style_color(Color(0.15, 0.7, 0.28), styles), Color(0.95, 0.95, 0.95))
	elif k.contains("weapon") or k.contains("gun"):
		if styles.has("minimal"):
			img.fill(_style_color(Color(0.25, 0.26, 0.28), styles))
		else:
			_fill_noise(img, _style_color(Color(0.25, 0.26, 0.28), styles), amp * 0.5)
			if not styles.has("cartoon"):
				_hatch(img, Color(0.55, 0.45, 0.2))
	else:
		if styles.has("minimal"):
			img.fill(_style_color(Color(0.4, 0.42, 0.45), styles))
		else:
			_fill_noise(img, _style_color(Color(0.4, 0.42, 0.45), styles), amp)
	return img


static func _style_color(base: Color, styles: PackedStringArray) -> Color:
	var c: Color = base
	if styles.has("cartoon"):
		c = Color.from_hsv(c.h, minf(c.s * 1.35 + 0.08, 1.0), minf(c.v * 1.12, 1.0))
	if styles.has("realistic"):
		c = Color.from_hsv(c.h, c.s * 0.72, c.v * 0.92)
	if styles.has("minimal"):
		c = Color.from_hsv(c.h, c.s * 0.55, minf(c.v * 1.05, 1.0))
	return c


static func _fill_bricks(img: Image, brick: Color, mortar: Color, chunky: bool = false) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill(mortar)
	var bw: int = 40 if chunky else 32
	var bh: int = 20 if chunky else 14
	var row: int = 0
	var y: int = 1
	while y < h:
		var offset: int = (row % 2) * int(bw / 2.0)
		var x: int = -offset
		while x < w:
			var x0: int = maxi(x + 1, 0)
			var y0: int = y
			var x1: int = mini(x + bw - 1, w)
			var y1: int = mini(y + bh - 1, h)
			var shade: Color = brick.darkened(randf() * 0.14)
			for py in range(y0, y1):
				for px in range(x0, x1):
					img.set_pixel(px, py, shade)
			x += bw
		y += bh
		row += 1


static func _fill_noise(img: Image, base: Color, amp: float) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var n: float = (sin(x * 0.21 + y * 0.13) + cos(x * 0.09 - y * 0.17)) * 0.25
			img.set_pixel(x, y, Color(
				clampf(base.r + n * amp, 0.0, 1.0),
				clampf(base.g + n * amp, 0.0, 1.0),
				clampf(base.b + n * amp * 0.85, 0.0, 1.0)
			))


static func _hatch(img: Image, line: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(0, h, 8):
		for x in w:
			img.set_pixel(x, y, line)


static func _fill_sky(img: Image, styles: PackedStringArray = PackedStringArray()) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top: Color = _style_color(Color(0.35, 0.55, 0.92), styles)
	var bot: Color = _style_color(Color(0.78, 0.88, 0.98), styles)
	for y in h:
		var t: float = float(y) / float(maxi(h - 1, 1))
		var col: Color = top.lerp(bot, t)
		for x in w:
			img.set_pixel(x, y, col)
	if styles.has("minimal"):
		return
	for _i in (3 if styles.has("pixel") else 8):
		var cx: int = randi_range(10, w - 10)
		var cy: int = randi_range(8, int(h * 0.45))
		var r: int = randi_range(6, 14)
		for y in range(maxi(0, cy - r), mini(h, cy + r)):
			for x in range(maxi(0, cx - r * 2), mini(w, cx + r * 2)):
				if Vector2(x - cx, (y - cy) * 2.0).length() < float(r):
					img.set_pixel(x, y, Color(0.95, 0.96, 0.98, 0.9))


static func _fill_sprite_figure(img: Image, skin: Color, cloth: Color, chunky: bool = false) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill(Color(0, 0, 0, 0))
	var cx: int = int(w / 2.0)
	var head: int = 14 if chunky else 10
	var body: int = 18 if chunky else 14
	_fill_rect(img, cx - head, int(h * 0.18), cx + head, int(h * 0.38), skin)
	_fill_rect(img, cx - body, int(h * 0.38), cx + body, int(h * 0.72), cloth)
	_fill_rect(img, cx - body - 4, int(h * 0.42), cx - body + 2, int(h * 0.68), skin)
	_fill_rect(img, cx + body - 2, int(h * 0.42), cx + body + 4, int(h * 0.68), skin)
	_fill_rect(img, cx - 12, int(h * 0.72), cx - 2, int(h * 0.95), Color(0.15, 0.15, 0.2))
	_fill_rect(img, cx + 2, int(h * 0.72), cx + 12, int(h * 0.95), Color(0.15, 0.15, 0.2))
	img.set_pixel(cx - 4, int(h * 0.26), Color(0.1, 0.1, 0.12))
	img.set_pixel(cx + 4, int(h * 0.26), Color(0.1, 0.1, 0.12))


static func _fill_cross(img: Image, bg: Color, fg: Color) -> void:
	img.fill(bg)
	var w: int = img.get_width()
	var h: int = img.get_height()
	_fill_rect(img, int(w * 0.42), int(h * 0.18), int(w * 0.58), int(h * 0.82), fg)
	_fill_rect(img, int(w * 0.18), int(h * 0.42), int(w * 0.82), int(h * 0.58), fg)


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(clampi(y0, 0, h), clampi(y1, 0, h)):
		for x in range(clampi(x0, 0, w), clampi(x1, 0, w)):
			img.set_pixel(x, y, col)


static func _obj_box(hx: float, hy: float, hz: float) -> String:
	return """# Generated CC0 placeholder box
o StudioBox
v %s %s %s
v %s %s %s
v %s %s %s
v %s %s %s
v %s %s %s
v %s %s %s
v %s %s %s
v %s %s %s
f 1 2 3 4
f 5 8 7 6
f 1 5 6 2
f 2 6 7 3
f 3 7 8 4
f 5 1 4 8
""" % [
		-hx, -hy, -hz, hx, -hy, -hz, hx, hy, -hz, -hx, hy, -hz,
		-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz,
	]


static func _obj_humanoid() -> String:
	return """# Generated CC0 placeholder humanoid (capsule-like boxes)
o StudioCharacter
v -0.22 -0.85 -0.16
v 0.22 -0.85 -0.16
v 0.22 0.05 -0.16
v -0.22 0.05 -0.16
v -0.22 -0.85 0.16
v 0.22 -0.85 0.16
v 0.22 0.05 0.16
v -0.22 0.05 0.16
v -0.16 0.05 -0.16
v 0.16 0.05 -0.16
v 0.16 0.55 -0.16
v -0.16 0.55 -0.16
v -0.16 0.05 0.16
v 0.16 0.05 0.16
v 0.16 0.55 0.16
v -0.16 0.55 0.16
f 1 2 3 4
f 5 8 7 6
f 1 5 6 2
f 2 6 7 3
f 3 7 8 4
f 5 1 4 8
f 9 10 11 12
f 13 16 15 14
f 9 13 14 10
f 10 14 15 11
f 11 15 16 12
f 13 9 12 16
"""
