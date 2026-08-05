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


func assigned(slot: String) -> String:
	var map_v: Variant = assets.get("assignments", {})
	if typeof(map_v) != TYPE_DICTIONARY:
		return ""
	return str((map_v as Dictionary).get(slot, ""))


func load_texture(names: Array) -> Texture2D:
	var candidates: PackedStringArray = PackedStringArray()
	for slot_name in ["wall", "floor", "sky", "character", "enemy", "weapon", "menu_background", "game_background", "ui", "material"]:
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


func _apply_all() -> void:
	_reload()
	await get_tree().process_frame
	_apply_backgrounds()
	_apply_camera()
	_apply_health_ui()
	_apply_weapon_view()
	_apply_effects()
	_apply_anims()
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
	var tex: Texture2D = load_texture(["weapon.png", "gun.png", assigned("weapon").get_file()])
	if tex:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = tex
		weapon.material_override = mat


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
