extends Node
## Autoload: applies studio_display / controls / effects / anim / assets when the game runs.

var display: Dictionary = {}
var controls: Dictionary = {}
var effects: Dictionary = {}
var anim: Dictionary = {}
var assets: Dictionary = {}


func _ready() -> void:
	_reload()
	call_deferred("_apply_all")


func _reload() -> void:
	display = _load_json("res://studio_display.json")
	controls = _load_json("res://studio_controls.json")
	effects = _load_json("res://studio_effects.json")
	anim = _load_json("res://studio_anim.json")
	assets = _load_json("res://studio_assets.json")


func fx_on(key: String, fallback: bool = true) -> bool:
	return bool(effects.get(key, fallback))


func fx_intensity(key: String, fallback: float = 1.0) -> float:
	return float(effects.get(key, fallback))


func camera_mode() -> String:
	var mode: String = str(controls.get("camera_mode", display.get("camera_mode", "first_person")))
	return mode if not mode.is_empty() else "first_person"


func max_hp() -> int:
	return int(controls.get("max_hp", display.get("max_hp", 100)))


func show_health() -> bool:
	return bool(controls.get("show_health", display.get("show_health", true)))


func show_weapon() -> bool:
	return bool(controls.get("show_weapon", display.get("weapon_view", true)))


func ui_style() -> String:
	return str(controls.get("ui_style", display.get("ui_style", "neon")))


func want_art(kind: String) -> bool:
	var kinds_v: Variant = assets.get("kinds", {})
	if typeof(kinds_v) != TYPE_DICTIONARY:
		return true
	return bool((kinds_v as Dictionary).get(kind, true))


func assigned(slot: String) -> String:
	var map_v: Variant = assets.get("assignments", {})
	if typeof(map_v) != TYPE_DICTIONARY:
		return ""
	return str((map_v as Dictionary).get(slot, ""))


func load_texture(names: Array) -> Texture2D:
	var candidates: PackedStringArray = PackedStringArray()
	for slot_name in ["wall", "floor", "sky", "skybox", "room", "character", "character_sprite", "character_texture", "character_model", "enemy", "enemy_texture", "enemy_model", "weapon", "weapon_texture", "weapon_model", "weapon_sprite", "room_model", "menu_background", "game_background", "ui", "material"]:
		for n in names:
			if str(n).get_file().get_basename().to_lower().contains(slot_name) or str(n).to_lower().contains(slot_name):
				var mapped: String = assigned(slot_name)
				if not mapped.is_empty():
					candidates.append(mapped)
	for n in names:
		var fname: String = str(n).get_file()
		candidates.append("res://assets/%s" % fname)
		for folder in ["world", "textures", "materials", "background", "character", "enemy", "weapon", "sprites", "ui", "effects", "models"]:
			candidates.append("res://assets/%s/%s" % [folder, fname])
	for p in candidates:
		if p.is_empty():
			continue
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			var tex: Resource = load(p)
			if tex is Texture2D:
				return tex as Texture2D
	return null


func physics_on(key: String, fallback: bool = true) -> bool:
	var phys_v: Variant = assets.get("physics", {})
	if typeof(phys_v) != TYPE_DICTIONARY:
		return fallback
	return bool((phys_v as Dictionary).get(key, fallback))


func _apply_all() -> void:
	_reload()
	await get_tree().process_frame
	_apply_backgrounds()
	_apply_skybox()
	_apply_world_textures()
	_apply_room_model()
	_apply_camera()
	_apply_character_visuals()
	_apply_health_ui()
	_apply_weapon_view()
	_apply_effects()
	_apply_anims()
	_apply_enemy_anims()
	_apply_physics()
	_apply_ui_style()


func _apply_backgrounds() -> void:
	var menu_bg: String = str(display.get("menu_background", assigned("menu_background")))
	var game_bg: String = str(display.get("game_background", assigned("game_background")))
	if game_bg.is_empty():
		game_bg = assigned("sky")
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var is_menu: bool = scene.name.to_lower().contains("menu") or scene.get_script() != null and str(scene.get_script().resource_path).ends_with("menu.gd")
	var path: String = menu_bg if is_menu else game_bg
	var tex: Texture2D = load_texture([path.get_file(), "sky.png", "background.png", "menu_bg.png"]) if not path.is_empty() else null
	if tex == null and not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		return
	var bg_rect: Node = scene.find_child("BG", true, false)
	if bg_rect is ColorRect:
		var tr: TextureRect = scene.find_child("StudioBG", true, false) as TextureRect
		if tr == null:
			tr = TextureRect.new()
			tr.name = "StudioBG"
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_rect.get_parent().add_child(tr)
			bg_rect.get_parent().move_child(tr, bg_rect.get_index() + 1)
		tr.texture = tex
	elif scene is Node2D:
		var spr: Sprite2D = scene.find_child("StudioBG", true, false) as Sprite2D
		if spr == null:
			spr = Sprite2D.new()
			spr.name = "StudioBG"
			spr.z_index = -20
			scene.add_child(spr)
			scene.move_child(spr, 0)
		spr.texture = tex
		spr.centered = true
		spr.position = Vector2(640, 360)
		if tex.get_size().x > 0.0:
			spr.scale = Vector2(1280.0 / tex.get_size().x, 720.0 / tex.get_size().y)
	elif scene is Node3D:
		_apply_sky_mesh(scene as Node3D, tex)


func _apply_skybox() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return
	var tex: Texture2D = _tex_for_slot("skybox", ["skybox.png", "sky.png", "background.png"])
	if tex == null:
		tex = _tex_for_slot("sky", ["sky.png", "skybox.png", "background.png"])
	if tex == null:
		return
	var env_node: WorldEnvironment = scene.find_child("StudioWorldEnv", true, false) as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "StudioWorldEnv"
		scene.add_child(env_node)
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var pano: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	pano.panorama = tex
	sky.sky_material = pano
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var sky_mat: Material = _load_material_slot("skybox_material")
	if sky_mat is StandardMaterial3D and (sky_mat as StandardMaterial3D).albedo_texture:
		pano.panorama = (sky_mat as StandardMaterial3D).albedo_texture
	env_node.environment = env
	_apply_sky_mesh(scene as Node3D, tex)


func _apply_sky_mesh(scene: Node3D, tex: Texture2D) -> void:
	if tex == null:
		return
	var sky_mi: MeshInstance3D = scene.find_child("StudioSky", true, false) as MeshInstance3D
	if sky_mi == null:
		sky_mi = MeshInstance3D.new()
		sky_mi.name = "StudioSky"
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 80.0
		sphere.height = 160.0
		sky_mi.mesh = sphere
		scene.add_child(sky_mi)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mi.material_override = mat


func _apply_world_textures() -> void:
	if not want_art("textures"):
		return
	var scene: Node = get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return
	var wall: Texture2D = _tex_for_slot("wall", ["wall.png", "brick.png"])
	var floor: Texture2D = _tex_for_slot("floor", ["floor.png", "ground.png", "dirt.png"])
	var wall_mat: Material = _load_material_slot("wall_material")
	var floor_mat: Material = _load_material_slot("floor_material")
	if wall == null and floor == null and wall_mat == null and floor_mat == null:
		return
	_paint_meshes(scene, wall, floor, wall_mat, floor_mat)


func _paint_meshes(node: Node, wall: Texture2D, floor: Texture2D, wall_mat: Material = null, floor_mat: Material = null) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var n: String = mi.name.to_lower()
		if n == "studiosky":
			return
		var use_floor: bool = n.contains("floor") or n.contains("ground")
		var use_wall: bool = n.contains("wall") or n.contains("ceil")
		if not use_floor and not use_wall and mi.mesh is BoxMesh:
			var box: BoxMesh = mi.mesh as BoxMesh
			if box.size.y <= 1.2 and box.size.x >= 8.0:
				use_floor = true
			else:
				use_wall = true
		if use_floor:
			if floor_mat:
				mi.material_override = floor_mat
			elif floor or wall:
				mi.material_override = _make_tex_mat(floor if floor else wall)
		elif use_wall:
			if wall_mat:
				mi.material_override = wall_mat
			elif wall or floor:
				mi.material_override = _make_tex_mat(wall if wall else floor)
	for child in node.get_children():
		_paint_meshes(child, wall, floor, wall_mat, floor_mat)


func _make_tex_mat(tex: Texture2D) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.roughness = 0.85
	mat.metallic = 0.05
	return mat


func _load_material_slot(slot: String) -> Material:
	var path: String = assigned(slot)
	if path.is_empty():
		return null
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return null
	var res: Resource = load(path)
	return res as Material if res is Material else null


func _apply_character_visuals() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var char_tex: Texture2D = null
	if want_art("sprites") or want_art("textures"):
		char_tex = _tex_for_slot("character_sprite", ["sprite_player.png", "character.png", "player.png"])
		if char_tex == null:
			char_tex = _tex_for_slot("character", ["sprite_player.png", "character.png", "player.png"])
		if char_tex == null:
			char_tex = _tex_for_slot("character_texture", ["character.png", "sprite_player.png"])
	var enemy_tex: Texture2D = null
	if want_art("sprites") or want_art("textures"):
		enemy_tex = _tex_for_slot("enemy_texture", ["enemy.png", "sprite_enemy.png"])
		if enemy_tex == null:
			enemy_tex = _tex_for_slot("enemy", ["sprite_enemy.png", "enemy.png"])
	var model_path: String = assigned("character_model") if want_art("models") else ""
	var enemy_model: String = assigned("enemy_model") if want_art("models") else ""
	var char_mat: Material = _load_material_slot("character_material")
	var enemy_mat: Material = _load_material_slot("enemy_material")
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		if player is Node3D:
			_attach_3d_character(player as Node3D, char_tex, model_path, false, char_mat)
		elif player is CanvasItem or player is Node2D:
			_attach_2d_sprite(player, char_tex)
	for child in scene.get_children():
		if child == player:
			continue
		var is_enemy: bool = child.is_in_group("enemy") or str(child.name).to_lower().contains("enemy")
		if child is CharacterBody3D:
			_attach_3d_character(child, enemy_tex if enemy_tex else char_tex, enemy_model if is_enemy else "", is_enemy, enemy_mat if is_enemy else null)
		elif child is CharacterBody2D or (child is Node2D and is_enemy):
			_attach_2d_sprite(child, enemy_tex if enemy_tex else char_tex)


func _tex_for_slot(slot: String, names: Array) -> Texture2D:
	var mapped: String = assigned(slot)
	if not mapped.is_empty():
		var hit: Texture2D = load_texture([mapped.get_file(), mapped])
		if hit:
			return hit
	return load_texture(names)


func _attach_2d_sprite(host: Node, tex: Texture2D) -> void:
	if tex == null:
		return
	var spr: Sprite2D = host.find_child("StudioCharSprite", true, false) as Sprite2D
	if spr == null:
		spr = host.find_child("Sprite2D", true, false) as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "StudioCharSprite"
		host.add_child(spr)
	spr.texture = tex


func _attach_3d_character(body: Node3D, tex: Texture2D, model_path: String, is_enemy: bool, slot_mat: Material = null) -> void:
	var model_node_name: String = "StudioEnemyModel" if is_enemy else "StudioCharModel"
	if not model_path.is_empty() and body.get_node_or_null(model_node_name) == null:
		var inst: Node = _try_instance_model(model_path)
		if inst:
			inst.name = model_node_name
			if inst is Node3D:
				(inst as Node3D).position = Vector3(0.0, 0.0, 0.0)
			body.add_child(inst)
			_apply_mat_to_node(inst, slot_mat, tex)
			if not is_enemy and camera_mode() != "third_person":
				inst.visible = false
	var mi: MeshInstance3D = body.find_child("StudioBody", true, false) as MeshInstance3D
	if mi == null:
		for child in body.get_children():
			if child is MeshInstance3D and not str(child.name).begins_with("Studio"):
				mi = child
				break
	if mi == null:
		mi = body.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "StudioBody"
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.35 if is_enemy else 0.32
		cap.height = 1.5
		mi.mesh = cap
		body.add_child(mi)
	if slot_mat:
		mi.material_override = slot_mat
	elif tex:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE
		mi.material_override = mat
	if not is_enemy and camera_mode() != "third_person":
		mi.visible = false


func _apply_mat_to_node(node: Node, slot_mat: Material, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		if slot_mat:
			(node as MeshInstance3D).material_override = slot_mat
		elif tex:
			var mm: StandardMaterial3D = StandardMaterial3D.new()
			mm.albedo_texture = tex
			(node as MeshInstance3D).material_override = mm
	for child in node.get_children():
		_apply_mat_to_node(child, slot_mat, tex)


func _try_instance_model(path: String) -> Node:
	var p: String = path.strip_edges()
	if p.is_empty():
		return null
	if not (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
		var fname: String = p.get_file()
		for folder in ["character", "enemy", "weapon", "models", ""]:
			var alt: String = "res://assets/%s%s" % [("" if folder.is_empty() else folder + "/"), fname]
			if ResourceLoader.exists(alt) or FileAccess.file_exists(alt):
				p = alt
				break
	if not (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
		return null
	var res: Resource = load(p)
	if res is PackedScene:
		return (res as PackedScene).instantiate()
	if res is Mesh:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = res as Mesh
		return mi
	return null


func _apply_camera() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam: Camera3D = player.find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		return
	var mode: String = camera_mode()
	if mode == "third_person":
		if cam.get_parent() == player or str(cam.get_parent().name) == "Camera3D":
			var pivot: Node3D = player.get_node_or_null("StudioCamPivot") as Node3D
			if pivot == null:
				pivot = Node3D.new()
				pivot.name = "StudioCamPivot"
				player.add_child(pivot)
			var arm: SpringArm3D = pivot.get_node_or_null("SpringArm3D") as SpringArm3D
			if arm == null:
				arm = SpringArm3D.new()
				arm.name = "SpringArm3D"
				arm.spring_length = 4.8
				arm.position = Vector3(0.0, 1.35, 0.0)
				pivot.add_child(arm)
			if cam.get_parent() != arm:
				cam.reparent(arm)
			cam.position = Vector3.ZERO
			cam.current = true
	else:
		if cam.get_parent() != player:
			cam.reparent(player)
		cam.position = Vector3(0.0, 0.55, 0.0)
		cam.current = true


func _apply_health_ui() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		if player.get("max_hp") != null:
			player.max_hp = max_hp()
		else:
			player.set_meta("max_hp", max_hp())
		if player.get("hp") != null:
			player.hp = max_hp()
		else:
			player.set_meta("hp", max_hp())
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var ui: Node = scene.find_child("UI", true, false)
	if ui == null:
		ui = CanvasLayer.new()
		ui.name = "UI"
		scene.add_child(ui)
	var bar: ProgressBar = ui.find_child("StudioHealth", true, false) as ProgressBar
	if not show_health():
		if bar:
			bar.visible = false
		return
	if bar == null:
		bar = ProgressBar.new()
		bar.name = "StudioHealth"
		bar.min_value = 0.0
		bar.max_value = float(max_hp())
		bar.value = float(max_hp())
		bar.custom_minimum_size = Vector2(220, 18)
		bar.position = Vector2(16, 48)
		bar.show_percentage = false
		ui.add_child(bar)
	bar.visible = true
	bar.max_value = float(max_hp())
	bar.value = float(max_hp())
	var hp_label: Label = ui.find_child("StudioHealthLabel", true, false) as Label
	if hp_label == null:
		hp_label = Label.new()
		hp_label.name = "StudioHealthLabel"
		hp_label.position = Vector2(16, 28)
		ui.add_child(hp_label)
	hp_label.text = "HP %s / %s" % [str(max_hp()), str(max_hp())]
	hp_label.visible = true


func _apply_weapon_view() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player is Node2D or player is CharacterBody2D:
		var spr_tex: Texture2D = _tex_for_slot("weapon_sprite", ["sprite_weapon.png", "weapon.png"])
		if spr_tex == null:
			spr_tex = _tex_for_slot("weapon", ["weapon.png", "gun.png"])
		if spr_tex:
			var wspr: Sprite2D = player.find_child("StudioWeaponSprite", true, false) as Sprite2D
			if wspr == null:
				wspr = Sprite2D.new()
				wspr.name = "StudioWeaponSprite"
				wspr.position = Vector2(18, 8)
				player.add_child(wspr)
			wspr.texture = spr_tex
			wspr.visible = show_weapon()
		return
	var cam: Camera3D = player.find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		return
	var weapon: MeshInstance3D = cam.get_node_or_null("StudioWeapon") as MeshInstance3D
	if not show_weapon():
		if weapon:
			weapon.visible = false
		return
	if weapon == null:
		weapon = MeshInstance3D.new()
		weapon.name = "StudioWeapon"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.45)
		weapon.mesh = box
		weapon.position = Vector3(0.22, -0.18, -0.42)
		weapon.rotation_degrees = Vector3(8.0, 8.0, 0.0)
		cam.add_child(weapon)
	weapon.visible = true
	var tex: Texture2D = _tex_for_slot("weapon_texture", ["weapon.png", "gun.png"])
	if tex == null:
		tex = _tex_for_slot("weapon", ["weapon.png", "gun.png"])
	var wmat: Material = _load_material_slot("weapon_material")
	if wmat:
		weapon.material_override = wmat
	elif tex:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = tex
		weapon.material_override = mat
	var wmodel: String = assigned("weapon_model") if want_art("models") else ""
	if not wmodel.is_empty() and cam.get_node_or_null("StudioWeaponModel") == null:
		var inst: Node = _try_instance_model(wmodel)
		if inst and inst is Node3D:
			inst.name = "StudioWeaponModel"
			(inst as Node3D).position = Vector3(0.22, -0.18, -0.42)
			cam.add_child(inst)
			_apply_mat_to_node(inst, wmat, tex)
	var player2: Node = get_tree().get_first_node_in_group("player")
	if player2 and (player2 is Node2D or player2 is CharacterBody2D):
		var spr_tex: Texture2D = _tex_for_slot("weapon_sprite", ["sprite_weapon.png", "weapon.png"])
		if spr_tex:
			_attach_2d_sprite(player2, spr_tex)


func _apply_effects() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var muzzle: GPUParticles3D = player.find_child("MuzzleFX", true, false) as GPUParticles3D
	if muzzle:
		var on: bool = fx_on("muzzle_flash", true)
		muzzle.visible = on
		var intensity: float = fx_intensity("muzzle_intensity", 1.0)
		muzzle.amount = maxi(4, int(18.0 * intensity))
		if not on:
			muzzle.emitting = false
	var impact: GPUParticles3D = player.find_child("ImpactFX", true, false) as GPUParticles3D
	if impact:
		var trail_on: bool = fx_on("bullet_trail", true)
		impact.visible = trail_on
		impact.amount = maxi(6, int(28.0 * fx_intensity("bullet_intensity", 1.0)))
	player.set_meta("studio_destroy_fx", fx_on("destroy_fx", true))
	player.set_meta("studio_destroy_intensity", fx_intensity("destroy_intensity", 1.0))
	player.set_meta("studio_death_fx", fx_on("enemy_death", true))
	player.set_meta("studio_death_intensity", fx_intensity("enemy_death_intensity", 1.0))


func _apply_anims() -> void:
	if not bool(anim.get("mode_enabled", false)):
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	var host: Node = player if player else scene
	var anims_v: Variant = anim.get("animations", [])
	if typeof(anims_v) != TYPE_ARRAY:
		return
	var anims: Array = anims_v
	if host is Node2D or host is CharacterBody2D:
		var sprite: AnimatedSprite2D = host.find_child("StudioAnimSprite", true, false) as AnimatedSprite2D
		if sprite == null:
			sprite = AnimatedSprite2D.new()
			sprite.name = "StudioAnimSprite"
			host.add_child(sprite)
		var frames: SpriteFrames = SpriteFrames.new()
		for a in anims:
			if typeof(a) != TYPE_DICTIONARY:
				continue
			var anim_name: String = str(a.get("name", "anim"))
			if frames.has_animation(anim_name):
				frames.remove_animation(anim_name)
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, float(a.get("fps", 8.0)))
			frames.set_animation_loop(anim_name, bool(a.get("loop", true)))
			var frame_list: Variant = a.get("frames", [])
			if typeof(frame_list) == TYPE_ARRAY:
				for fp in frame_list:
					var tex: Texture2D = null
					var p: String = str(fp)
					if not p.is_empty() and (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
						var res: Resource = load(p)
						if res is Texture2D:
							tex = res as Texture2D
					if tex:
						frames.add_frame(anim_name, tex)
			if frames.get_frame_count(anim_name) == 0:
				var fallback: Texture2D = load_texture(["sprite_player.png", "sprite_enemy.png"])
				if fallback:
					frames.add_frame(anim_name, fallback)
		sprite.sprite_frames = frames
		if frames.get_animation_names().size() > 0:
			sprite.play(frames.get_animation_names()[0])
		return
	var ap: AnimationPlayer = host.find_child("StudioAnimPlayer", true, false) as AnimationPlayer
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "StudioAnimPlayer"
		host.add_child(ap)
	var lib: AnimationLibrary = AnimationLibrary.new()
	for a2 in anims:
		if typeof(a2) != TYPE_DICTIONARY:
			continue
		var nm: String = str(a2.get("name", "anim"))
		var animation: Animation = Animation.new()
		var fps: float = maxf(1.0, float(a2.get("fps", 8.0)))
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if bool(a2.get("loop", true)) else Animation.LOOP_NONE
		var track: int = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(":position:y"))
		animation.track_insert_key(track, 0.0, 0.0)
		animation.track_insert_key(track, 0.5 / fps * 8.0, 0.04)
		animation.track_insert_key(track, 1.0, 0.0)
		lib.add_animation(nm, animation)
	if ap.has_animation_library("studio"):
		ap.remove_animation_library("studio")
	ap.add_animation_library("studio", lib)


func _apply_room_model() -> void:
	if not want_art("models") or not physics_on("room_static", true):
		return
	var scene: Node = get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return
	var path: String = assigned("room_model")
	if path.is_empty() or scene.find_child("StudioRoomModel", true, false):
		return
	var inst: Node = _try_instance_model(path)
	if inst == null:
		return
	var host: StaticBody3D = StaticBody3D.new()
	host.name = "StudioRoomModel"
	host.position = Vector3(0.0, 1.2, -2.0)
	scene.add_child(host)
	host.add_child(inst)
	_ensure_static_collision(host)


func _apply_enemy_anims() -> void:
	if not bool(anim.get("mode_enabled", false)) and assigned("enemy_anim").is_empty():
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var clip: String = assigned("enemy_anim")
	if clip.is_empty():
		clip = "idle"
	for child in scene.get_children():
		if not (child is CharacterBody3D or child is CharacterBody2D):
			continue
		if child.is_in_group("player"):
			continue
		if child is Node2D or child is CharacterBody2D:
			var sprite: AnimatedSprite2D = child.find_child("StudioAnimSprite", true, false) as AnimatedSprite2D
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(clip):
				sprite.play(clip)
		else:
			var ap: AnimationPlayer = child.find_child("StudioAnimPlayer", true, false) as AnimationPlayer
			if ap and ap.has_animation("studio/%s" % clip):
				ap.play("studio/%s" % clip)


func _apply_physics() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and physics_on("character_collision", true):
		_ensure_actor_collision(player, false)
	if scene is Node3D and physics_on("world_static", true):
		_ensure_world_static(scene)
	for child in scene.get_children():
		if child == player:
			continue
		if (child is CharacterBody3D or child is CharacterBody2D) and physics_on("enemy_collision", true):
			_ensure_actor_collision(child, true)
	if player:
		player.set_meta("studio_weapon_rigid", physics_on("weapon_rigid", true))


func _ensure_actor_collision(body: Node, is_enemy: bool) -> void:
	if body is CharacterBody3D:
		if body.find_child("CollisionShape3D", true, false):
			return
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "StudioCollision"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.38 if is_enemy else 0.35
		cap.height = 1.6
		cs.shape = cap
		body.add_child(cs)
	elif body is CharacterBody2D:
		if body.find_child("CollisionShape2D", true, false):
			return
		var cs2: CollisionShape2D = CollisionShape2D.new()
		cs2.name = "StudioCollision"
		var cap2: CapsuleShape2D = CapsuleShape2D.new()
		cap2.radius = 12.0
		cap2.height = 28.0
		cs2.shape = cap2
		body.add_child(cs2)


func _ensure_world_static(node: Node) -> void:
	if node is StaticBody3D:
		_ensure_static_collision(node as StaticBody3D)
	for child in node.get_children():
		_ensure_world_static(child)


func _ensure_static_collision(body: StaticBody3D) -> void:
	if body.find_child("CollisionShape3D", true, false):
		return
	var size: Vector3 = Vector3(1, 1, 1)
	for child in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			size = ((child as MeshInstance3D).mesh as BoxMesh).size
			break
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "StudioCollision"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)


func _apply_ui_style() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var hud: Label = scene.find_child("HUD", true, false) as Label
	if hud == null:
		return
	var style: String = ui_style()
	match style:
		"classic":
			hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		"minimal":
			hud.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		_:
			hud.add_theme_color_override("font_color", Color(0.24, 0.86, 0.59))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
