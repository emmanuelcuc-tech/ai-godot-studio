class_name GenreTemplates
extends RefCounted
## Playable Godot 4 starters per genre. Generation modifies these with user direction + refs.


static func build(genre_id: String, title: String = "") -> Dictionary:
	match genre_id:
		"fps":
			return _fps(title)
		"tps":
			return _tps(title)
		"platformer":
			return _platformer(title)
		"space_shooter":
			return _space(title)
		"racing":
			return _racing(title)
		"simulation":
			return _sim(title)
		"open_world":
			return _open(title)
		"beat_em_up":
			return _brawler(title)
		"fighting":
			return _fight(title)
		"voxel":
			return _voxel(title)
		_:
			return _arena(title)


static func _pack(name: String, summary: String, howto: Array, files: Array) -> Dictionary:
	return {"ok": true, "project_name": name, "summary": summary, "howto": howto, "files": files}


static func _godot(title: String, main := "res://scenes/main.tscn") -> String:
	return """; Engine configuration file.
config_version=5
[application]
config/name=\"%s\"
run/main_scene=\"%s\"
config/features=PackedStringArray(\"4.3\", \"Forward Plus\")
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
environment/defaults/default_clear_color=Color(0.06, 0.08, 0.1, 1)
""" % [title, main]


static func _fps(title: String) -> Dictionary:
	var t := title if title else "Corridor FPS"
	var world := """extends Node3D
@onready var hud: Label = $UI/HUD
var kills := 0
var _wall_tex: Texture2D
var _floor_tex: Texture2D
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_wall_tex = _try_load_tex([\"wall.png\", \"wall.jpg\", \"material.png\", \"brick.png\"])
	_floor_tex = _try_load_tex([\"floor.png\", \"floor.jpg\", \"dirt.png\", \"concrete.png\"])
	_level(); _enemies()
func _try_load_tex(names: Array) -> Texture2D:
	if Engine.get_main_loop() is SceneTree:
		var rt: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(\"StudioRuntime\")
		if rt and rt.has_method(\"load_texture\"):
			var mapped: Texture2D = rt.load_texture(names)
			if mapped:
				return mapped
	var folders: Array = [\"\", \"world/\", \"textures/\", \"materials/\", \"background/\", \"character/\", \"enemy/\", \"weapon/\", \"sprites/\", \"ui/\", \"effects/\"]
	for n in names:
		for folder in folders:
			var p := \"res://assets/%s%s\" % [folder, n]
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				return load(p) as Texture2D
	return null
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(\"ui_cancel\"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
func add_kill() -> void:
	kills += 1
	hud.text = \"FPS | Kills %s | WASD · Mouse · LMB · Esc\" % kills
func _mat(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.05
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(2, 2, 2)
	return mat
func _box(parent: Node, pos: Vector3, size: Vector3, color: Color, solid := true, tex: Texture2D = null) -> void:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(color, tex)
	body.add_child(mi)
	if solid:
		var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = size; c.shape = s; body.add_child(c)
	parent.add_child(body)
func _level() -> void:
	_box(self, Vector3(0,-0.5,0), Vector3(40,1,40), Color(0.12, 0.1, 0.09), true, _floor_tex if _floor_tex else _wall_tex)
	for w in [[Vector3(0,1.5,-14),Vector3(28,3,1)],[Vector3(0,1.5,14),Vector3(28,3,1)],[Vector3(-14,1.5,0),Vector3(1,3,28)],[Vector3(14,1.5,0),Vector3(1,3,28)],[Vector3(-5,1.5,-5),Vector3(10,3,1)],[Vector3(5,1.5,5),Vector3(1,3,10)]]:
		_box(self, w[0], w[1], Color(0.55, 0.28, 0.2), true, _wall_tex)
	_box(self, Vector3(0, 1.2, -2), Vector3(2, 2.2, 0.4), Color(0.28, 0.32, 0.18))
func _enemies() -> void:
	for p in [Vector3(6,1,-6), Vector3(-6,1,6), Vector3(8,1,2), Vector3(-3,1,-8)]:
		var e = load(\"res://scripts/enemy.gd\").new(); e.position = p; add_child(e)
"""
	var player := """extends CharacterBody3D
const SPEED := 7.0
var pitch := 0.0
var _bob_t := 0.0
var max_hp := 100
var hp := 100
@onready var cam: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var muzzle: GPUParticles3D = $Camera3D/MuzzleFX
@onready var impact_fx: GPUParticles3D = $ImpactFX
func _ready() -> void:
	add_to_group(\"player\")
	_setup_fx(muzzle, Color(1.0, 0.75, 0.2), 18, 0.08)
	_setup_fx(impact_fx, Color(1.0, 0.55, 0.15), 28, 0.35)
func _studio_fx(key: String, fallback: bool = true) -> bool:
	var rt := get_node_or_null(\"/root/StudioRuntime\")
	if rt and rt.has_method(\"fx_on\"):
		return rt.fx_on(key, fallback)
	if FileAccess.file_exists(\"res://studio_effects.json\"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(\"res://studio_effects.json\"))
		if typeof(d) == TYPE_DICTIONARY:
			return bool(d.get(key, fallback))
	return fallback
func _setup_fx(p: GPUParticles3D, col: Color, amount: int, life: float) -> void:
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 25.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -4, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	mat.color = col
	p.process_material = mat
	var dm := SphereMesh.new(); dm.radius = 0.05; dm.height = 0.1
	p.draw_pass_1 = dm
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * 0.0025)
		pitch = clamp(pitch - e.relative.y * 0.0025, deg_to_rad(-85), deg_to_rad(85))
		cam.rotation.x = pitch
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_fire()
func _physics_process(d: float) -> void:
	var i := Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\")
	var dir := (transform.basis * Vector3(i.x,0,i.y)).normalized()
	velocity.x = dir.x * SPEED; velocity.z = dir.z * SPEED
	velocity.y -= 20.0 * d if not is_on_floor() else 0.0
	if is_on_floor() and Input.is_action_just_pressed(\"ui_accept\"): velocity.y = 7.0
	# Walk bob animation (texture/camera feel when no skeletal anim found)
	var moving := dir.length() > 0.1 and is_on_floor()
	if moving:
		_bob_t += d * 10.0
		cam.position.y = 0.55 + sin(_bob_t) * 0.045
		cam.position.x = cos(_bob_t * 0.5) * 0.02
	else:
		cam.position = cam.position.lerp(Vector3(0, 0.55, 0), d * 8.0)
	move_and_slide()
func _fire() -> void:
	if _studio_fx(\"muzzle_flash\", true):
		muzzle.restart()
		muzzle.emitting = true
	ray.force_raycast_update()
	if ray.is_colliding():
		var pt: Vector3 = ray.get_collision_point()
		if _studio_fx(\"bullet_trail\", true):
			impact_fx.global_position = pt
			impact_fx.restart()
			impact_fx.emitting = true
		if _studio_fx(\"destroy_fx\", true):
			_spawn_debris(pt, ray.get_collision_normal())
		var h = ray.get_collider()
		if h and h.has_method(\"take_damage\"): h.take_damage(34)
func _spawn_debris(pos: Vector3, normal: Vector3) -> void:
	# Real physics chips (RigidBody3D) — genre engine feel for shooters
	for i in 4:
		var rb := RigidBody3D.new()
		rb.position = pos + normal * 0.05
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.08, 0.08); mi.mesh = bm
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.5, 0.35, 0.25); mi.material_override = mat
		rb.add_child(mi)
		var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = bm.size; c.shape = s; rb.add_child(c)
		get_tree().current_scene.add_child(rb)
		rb.apply_central_impulse(normal * randf_range(1.5, 3.5) + Vector3(randf_range(-1,1), randf_range(1,2), randf_range(-1,1)))
		get_tree().create_timer(2.0).timeout.connect(rb.queue_free)
"""
	var enemy := """extends CharacterBody3D
var hp := 100
var _hurt_flash := 0.0
@onready var _mesh: MeshInstance3D
func _ready() -> void:
	var c := CollisionShape3D.new(); var s := CapsuleShape3D.new(); s.radius=0.4; s.height=1.6; c.shape=s; add_child(c)
	_mesh = MeshInstance3D.new(); var m := CapsuleMesh.new(); m.radius=0.4; m.height=1.6; _mesh.mesh=m
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.55,0.12,0.1); _mesh.material_override=mat; add_child(_mesh)
func _physics_process(d: float) -> void:
	if _hurt_flash > 0.0:
		_hurt_flash -= d
		if _mesh and _mesh.material_override:
			_mesh.material_override.albedo_color = Color(1, 0.4, 0.3) if fmod(_hurt_flash, 0.1) < 0.05 else Color(0.55,0.12,0.1)
	var p := get_tree().get_first_node_in_group(\"player\")
	if p == null: return
	var to: Vector3 = p.global_position - global_position; to.y = 0
	if to.length() > 0.5: velocity = to.normalized() * 2.8; move_and_slide()
func take_damage(a: int) -> void:
	hp -= a
	_hurt_flash = 0.35
	if hp <= 0:
		var w = get_parent(); if w and w.has_method(\"add_kill\"): w.add_kill()
		var death_on := true
		var rt := get_node_or_null(\"/root/StudioRuntime\")
		if rt and rt.has_method(\"fx_on\"):
			death_on = rt.fx_on(\"enemy_death\", true)
		if death_on:
			var p := GPUParticles3D.new()
			p.one_shot = true
			p.emitting = true
			p.amount = 20
			p.lifetime = 0.35
			p.explosiveness = 1.0
			var mat := ParticleProcessMaterial.new()
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 80.0
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 6.0
			mat.color = Color(1.0, 0.3, 0.15)
			p.process_material = mat
			var dm := SphereMesh.new(); dm.radius = 0.06; dm.height = 0.12
			p.draw_pass_1 = dm
			p.global_position = global_position
			if get_parent(): get_parent().add_child(p)
			get_tree().create_timer(0.5).timeout.connect(p.queue_free)
		queue_free()
"""
	var scene := """[gd_scene load_steps=4 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/world.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[sub_resource type=\"CapsuleShape3D\" id=\"cap\"]
radius = 0.35
height = 1.6
[node name=\"World\" type=\"Node3D\"]
script = ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody3D\" parent=\".\" groups=[\"player\"]]
transform = Transform3D(1,0,0,0,1,0,0,0,1,0,1.2,8)
script = ExtResource(\"2\")
[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"Player\"]
shape = SubResource(\"cap\")
[node name=\"Camera3D\" type=\"Camera3D\" parent=\"Player\"]
transform = Transform3D(1,0,0,0,1,0,0,0,1,0,0.55,0)
current = true
fov = 80.0
[node name=\"RayCast3D\" type=\"RayCast3D\" parent=\"Player/Camera3D\"]
target_position = Vector3(0, 0, -45)
[node name=\"MuzzleFX\" type=\"GPUParticles3D\" parent=\"Player/Camera3D\"]
transform = Transform3D(1,0,0,0,1,0,0,0,1,0.15,-0.1,-0.4)
emitting = false
[node name=\"ImpactFX\" type=\"GPUParticles3D\" parent=\"Player\"]
emitting = false
[node name=\"DirectionalLight3D\" type=\"DirectionalLight3D\" parent=\".\"]
transform = Transform3D(0.8,-0.4,0.4,0,0.7,0.7,-0.5,-0.55,0.65,0,10,0)
shadow_enabled = true
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right = 1100.0
offset_bottom = 40.0
theme_override_font_sizes/font_size = 18
text = \"FPS | WASD · Mouse · LMB shoot · Esc\"
[node name=\"Cross\" type=\"Label\" parent=\"UI\"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -8.0
offset_top = -12.0
offset_right = 8.0
offset_bottom = 12.0
text = \"+\"
horizontal_alignment = 1
"""
	return _pack("corridor_fps", "Doom-feel recreation: textured corridors, walk-bob, muzzle/impact particles, RigidBody debris — original art, not a ROM.", ["Play in Godot 4", "WASD · mouse look · LMB", "Esc toggles mouse", "Drop wall.png into assets/ for brick/wall materials"], [
		{"path": "project.godot", "content": _godot(t)},
		{"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/world.gd", "content": world},
		{"path": "scripts/player.gd", "content": player},
		{"path": "scripts/enemy.gd", "content": enemy},
		{"path": "docs/SHOOTER_FX.md", "content": "# Shooter genre engine notes\\n- Animation: camera walk-bob (fallback when no Blender/glTF anim)\\n- Bullet FX: GPUParticles3D muzzle + impact\\n- Physics: RigidBody3D debris chips on hit\\n- Materials: StandardMaterial3D + optional assets/wall.png from Asset Browser\\n- Godot is the game engine for this FPS template\\n"},
		{"path": "GENRE_REFS.md", "content": "Templates:\\n- https://github.com/KenneyNL/Starter-Kit-FPS\\n- https://github.com/bukkbeek/GodotFPS-Template\\nAssets: https://kenney.nl (CC0), Openverse CC0 textures, Wikimedia Commons\\n"},
	])


static func _tps(title: String) -> Dictionary:
	var t := title if title else "Third Person Strike"
	var player := """extends CharacterBody3D
const SPEED := 6.5
var yaw := 0.0
@onready var pivot: Node3D = $CamPivot
@onready var arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var cam: Camera3D = $CamPivot/SpringArm3D/Camera3D
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius=0.35; cm.height=1.5; mi.mesh=cm
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.25,0.55,0.95); mi.material_override=mat; $Mesh.add_child(mi)
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.004; pivot.rotation.y = yaw
		arm.rotation.x = clamp(arm.rotation.x - e.relative.y * 0.003, deg_to_rad(-35), deg_to_rad(25))
	if e.is_action_pressed(\"ui_cancel\"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _shoot()
func _physics_process(d: float) -> void:
	var i := Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(i.x,0,i.y)).normalized()
	velocity.x = dir.x * SPEED; velocity.z = dir.z * SPEED
	velocity.y = velocity.y - 22.0 * d if not is_on_floor() else (7.0 if Input.is_action_just_pressed(\"ui_accept\") else 0.0)
	move_and_slide()
func _shoot() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from + (-cam.global_transform.basis.z) * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to); q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit and hit.collider and hit.collider.has_method(\"take_damage\"): hit.collider.take_damage(28)
"""
	var world := """extends Node3D
@onready var hud: Label = $UI/HUD
var score := 0
func _ready() -> void:
	var b := StaticBody3D.new(); b.position.y = -0.5
	var mi := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(60,1,60); mi.mesh=box
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.18,0.32,0.22); mi.material_override=mat; b.add_child(mi)
	var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size=Vector3(60,1,60); c.shape=s; b.add_child(c); add_child(b)
	for p in [Vector3(7,1,-4), Vector3(-6,1,5), Vector3(4,1,9)]:
		var e = load(\"res://scripts/enemy.gd\").new(); e.position = p; add_child(e)
func add_score() -> void:
	score += 1; hud.text = \"TPS | Score %s | WASD · Mouse · LMB\" % score
"""
	var enemy := """extends CharacterBody3D
var hp := 80
func _ready() -> void:
	var c := CollisionShape3D.new(); var s := CapsuleShape3D.new(); s.radius=0.4; s.height=1.5; c.shape=s; add_child(c)
	var mi := MeshInstance3D.new(); var m := CapsuleMesh.new(); m.radius=0.4; m.height=1.5; mi.mesh=m
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.85,0.25,0.2); mi.material_override=mat; add_child(mi)
func take_damage(a:int) -> void:
	hp -= a
	if hp <= 0:
		var w=get_parent(); if w.has_method(\"add_score\"): w.add_score()
		queue_free()
"""
	var scene := """[gd_scene load_steps=4 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/world.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[sub_resource type=\"CapsuleShape3D\" id=\"cap\"]
radius=0.35
height=1.6
[node name=\"World\" type=\"Node3D\"]
script=ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody3D\" parent=\".\" groups=[\"player\"]]
transform=Transform3D(1,0,0,0,1,0,0,0,1,0,1.2,0)
script=ExtResource(\"2\")
[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"Player\"]
shape=SubResource(\"cap\")
[node name=\"Mesh\" type=\"Node3D\" parent=\"Player\"]
[node name=\"CamPivot\" type=\"Node3D\" parent=\"Player\"]
[node name=\"SpringArm3D\" type=\"SpringArm3D\" parent=\"Player/CamPivot\"]
spring_length=4.8
[node name=\"Camera3D\" type=\"Camera3D\" parent=\"Player/CamPivot/SpringArm3D\"]
current=true
[node name=\"DirectionalLight3D\" type=\"DirectionalLight3D\" parent=\".\"]
transform=Transform3D(0.8,-0.4,0.4,0,0.7,0.7,-0.5,-0.55,0.65,0,10,0)
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=900.0
offset_bottom=36.0
text=\"TPS | WASD · Mouse · LMB\"
"""
	return _pack("third_person_strike", "Third-person shooter with SpringArm camera and aim-shoot.", ["Play", "Orbit with mouse", "LMB shoot"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/world.gd", "content": world}, {"path": "scripts/player.gd", "content": player},
		{"path": "scripts/enemy.gd", "content": enemy},
	])


static func _platformer(title: String) -> Dictionary:
	var t := title if title else "Precision Platformer"
	var main := """extends Node2D
@onready var hud: Label = $UI/HUD
var coins := 0
func _ready() -> void:
	hud.text = \"PLATFORMER | Arrows/WASD · Space jump · coins: 0\"
func add_coin() -> void:
	coins += 1; hud.text = \"PLATFORMER | coins: %s · reach the flag\" % coins
"""
	var player := """extends CharacterBody2D
const SPEED := 240.0
const JUMP := -420.0
const GRAV := 1100.0
var coyote := 0.0
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(22,30); c.shape=r; add_child(c)
	var spr_path := \"\"
	for pth in [\"res://assets/character/sprite_player.png\", \"res://assets/sprites/sprite_player.png\", \"res://assets/sprite_player.png\"]:
		if ResourceLoader.exists(pth) or FileAccess.file_exists(pth):
			spr_path = pth
			break
	if not spr_path.is_empty():
		var spr := Sprite2D.new(); spr.texture = load(spr_path); add_child(spr)
	else:
		var p := Polygon2D.new(); p.color=Color(0.95,0.45,0.3); p.polygon=PackedVector2Array([Vector2(-11,-15),Vector2(11,-15),Vector2(11,15),Vector2(-11,15)]); add_child(p)
func _physics_process(d: float) -> void:
	if not is_on_floor(): velocity.y += GRAV * d; coyote = max(0.0, coyote - d)
	else: coyote = 0.12
	if Input.is_action_just_pressed(\"ui_accept\") and coyote > 0.0:
		velocity.y = JUMP; coyote = 0.0
	velocity.x = Input.get_axis(\"ui_left\",\"ui_right\") * SPEED
	move_and_slide()
	if position.y > 900: position = Vector2(80, 360); velocity = Vector2.ZERO
"""
	var scene := """[gd_scene load_steps=5 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[sub_resource type=\"RectangleShape2D\" id=\"floor\"]
size=Vector2(1400,40)
[sub_resource type=\"RectangleShape2D\" id=\"plat\"]
size=Vector2(180,24)
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\"]
position=Vector2(80,360)
script=ExtResource(\"2\")
[node name=\"Floor\" type=\"StaticBody2D\" parent=\".\"]
position=Vector2(640,680)
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Floor\"]
shape=SubResource(\"floor\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Floor\"]
color=Color(0.2,0.3,0.4,1)
polygon=PackedVector2Array(-700,-20,700,-20,700,20,-700,20)
[node name=\"Plat1\" type=\"StaticBody2D\" parent=\".\"]
position=Vector2(320,520)
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Plat1\"]
shape=SubResource(\"plat\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Plat1\"]
color=Color(0.25,0.55,0.45,1)
polygon=PackedVector2Array(-90,-12,90,-12,90,12,-90,12)
[node name=\"Plat2\" type=\"StaticBody2D\" parent=\".\"]
position=Vector2(560,400)
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Plat2\"]
shape=SubResource(\"plat\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Plat2\"]
color=Color(0.25,0.55,0.45,1)
polygon=PackedVector2Array(-90,-12,90,-12,90,12,-90,12)
[node name=\"Plat3\" type=\"StaticBody2D\" parent=\".\"]
position=Vector2(820,300)
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Plat3\"]
shape=SubResource(\"plat\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Plat3\"]
color=Color(0.25,0.55,0.45,1)
polygon=PackedVector2Array(-90,-12,90,-12,90,12,-90,12)
[node name=\"Flag\" type=\"Area2D\" parent=\".\"]
position=Vector2(820,250)
[node name=\"p\" type=\"Polygon2D\" parent=\"Flag\"]
color=Color(0.95,0.85,0.2,1)
polygon=PackedVector2Array(-8,-40,8,-40,8,40,-8,40)
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=900.0
offset_bottom=40.0
text=\"PLATFORMER\"
[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Player\"]
position_smoothing_enabled=true
"""
	return _pack("precision_platformer", "Side-view platformer with coyote jump, platforms, camera follow, goal flag.", ["Arrows/WASD", "Space jump", "Reach gold flag"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/player.gd", "content": player},
		{"path": "GENRE_REFS.md", "content": "https://github.com/KenneyNL/Starter-Kit-3D-Platformer\\nhttps://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html\\n"},
	])


static func _space(title: String) -> Dictionary:
	var t := title if title else "Space Assault"
	var main := """extends Node2D
@onready var player: Area2D = $Player
@onready var hud: Label = $UI/HUD
var score := 0
var cool := 0.0
var wave := 0.0
func _process(d: float) -> void:
	cool = max(0.0, cool - d); wave -= d
	if wave <= 0.0: wave = max(0.45, 1.0 - score * 0.01); _enemy()
	if Input.is_action_pressed(\"ui_accept\") and cool <= 0.0:
		cool = 0.14; _bullet()
	hud.text = \"SPACE SHOOTER | Score %s | Arrows move · Space fire\" % score
	for c in get_children():
		if c is Area2D and c.has_meta(\"vy\"):
			c.position.y += float(c.get_meta(\"vy\")) * d
			if c.position.y < -50 or c.position.y > 800: c.queue_free()
	_hits()
func _bullet() -> void:
	var b := Area2D.new(); b.position = player.position + Vector2(0,-18)
	var s := CollisionShape2D.new(); var c := CircleShape2D.new(); c.radius=4; s.shape=c; b.add_child(s)
	var p := Polygon2D.new(); p.color=Color(1,0.9,0.3); p.polygon=PackedVector2Array([Vector2(-3,-8),Vector2(3,-8),Vector2(3,8),Vector2(-3,8)]); b.add_child(p)
	b.set_meta(\"vy\", -480.0); b.set_meta(\"kind\",\"bullet\"); add_child(b)
func _enemy() -> void:
	var e := Area2D.new(); e.position = Vector2(randf_range(40,1240), -20)
	var s := CollisionShape2D.new(); var c := CircleShape2D.new(); c.radius=16; s.shape=c; e.add_child(s)
	var p := Polygon2D.new(); p.color=Color(0.9,0.25,0.35); p.polygon=PackedVector2Array([Vector2(-16,-12),Vector2(16,-12),Vector2(12,14),Vector2(-12,14)]); e.add_child(p)
	e.set_meta(\"vy\", 130.0 + score * 2.0); e.set_meta(\"kind\",\"enemy\"); add_child(e)
func _hits() -> void:
	var bullets: Array = []; var enemies: Array = []
	for c in get_children():
		if c is Area2D and c.has_meta(\"kind\"):
			if c.get_meta(\"kind\") == \"bullet\": bullets.append(c)
			elif c.get_meta(\"kind\") == \"enemy\": enemies.append(c)
	for b in bullets:
		for e in enemies:
			if b.position.distance_to(e.position) < 22:
				score += 1; b.queue_free(); e.queue_free(); break
"""
	var player := """extends Area2D
func _ready() -> void:
	var s := CollisionShape2D.new(); var c := CircleShape2D.new(); c.radius=14; s.shape=c; add_child(s)
	var p := Polygon2D.new(); p.color=Color(0.35,0.75,1); p.polygon=PackedVector2Array([Vector2(0,-18),Vector2(14,14),Vector2(0,6),Vector2(-14,14)]); add_child(p)
	position = Vector2(640, 620)
func _process(d: float) -> void:
	position += Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\") * 320.0 * d
	position.x = clamp(position.x, 30, 1250); position.y = clamp(position.y, 360, 690)
"""
	var scene := """[gd_scene load_steps=3 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Player\" type=\"Area2D\" parent=\".\"]
script=ExtResource(\"2\")
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=1000.0
offset_bottom=40.0
text=\"SPACE SHOOTER\"
"""
	return _pack("space_assault", "Vertical space shooter with escalating waves and score.", ["Arrows move", "Space fire"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/player.gd", "content": player},
	])


static func _racing(title: String) -> Dictionary:
	var t := title if title else "Arcade Circuit"
	var main := """extends Node2D
@onready var car: CharacterBody2D = $Car
@onready var hud: Label = $UI/HUD
var laps := 0
var checkpoint := 0
func _physics_process(d: float) -> void:
	var steer := Input.get_axis(\"ui_left\",\"ui_right\")
	var throttle := Input.get_axis(\"ui_down\",\"ui_up\")
	car.rotation += steer * 2.6 * d
	var forward := Vector2.UP.rotated(car.rotation)
	car.velocity = car.velocity.lerp(forward * throttle * 420.0, 1.0 - exp(-3.0 * d))
	car.velocity *= 0.99
	car.move_and_slide()
	hud.text = \"RACING | Lap %s | Arrows steer/throttle · pass gates in order\" % laps
func gate(id: int) -> void:
	if id == checkpoint:
		checkpoint += 1
		if checkpoint >= 3:
			checkpoint = 0; laps += 1
"""
	var car := """extends CharacterBody2D
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(28,48); c.shape=r; add_child(c)
	var p := Polygon2D.new(); p.color=Color(0.95,0.55,0.15); p.polygon=PackedVector2Array([Vector2(-14,-24),Vector2(14,-24),Vector2(14,24),Vector2(-14,24)]); add_child(p)
"""
	var gate_script := """extends Area2D
@export var gate_id := 0
func _ready() -> void:
	body_entered.connect(func(b):
		if b.name == \"Car\":
			var m = get_parent(); if m.has_method(\"gate\"): m.gate(gate_id)
	)
"""
	var scene := """[gd_scene load_steps=5 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/car.gd\" id=\"2\"]
[ext_resource type=\"Script\" path=\"res://scripts/gate.gd\" id=\"3\"]
[sub_resource type=\"RectangleShape2D\" id=\"g\"]
size=Vector2(120,24)
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Track\" type=\"Polygon2D\" parent=\".\"]
color=Color(0.15,0.18,0.22,1)
polygon=PackedVector2Array(40,40,1240,40,1240,680,40,680)
[node name=\"Car\" type=\"CharacterBody2D\" parent=\".\"]
position=Vector2(640,560)
script=ExtResource(\"2\")
[node name=\"Gate0\" type=\"Area2D\" parent=\".\"]
position=Vector2(640,120)
script=ExtResource(\"3\")
gate_id=0
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Gate0\"]
shape=SubResource(\"g\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Gate0\"]
color=Color(0.2,0.8,0.4,0.5)
polygon=PackedVector2Array(-60,-12,60,-12,60,12,-60,12)
[node name=\"Gate1\" type=\"Area2D\" parent=\".\"]
position=Vector2(1100,360)
script=ExtResource(\"3\")
gate_id=1
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Gate1\"]
shape=SubResource(\"g\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Gate1\"]
color=Color(0.2,0.8,0.4,0.5)
polygon=PackedVector2Array(-60,-12,60,-12,60,12,-60,12)
[node name=\"Gate2\" type=\"Area2D\" parent=\".\"]
position=Vector2(200,360)
script=ExtResource(\"3\")
gate_id=2
[node name=\"c\" type=\"CollisionShape2D\" parent=\"Gate2\"]
shape=SubResource(\"g\")
[node name=\"p\" type=\"Polygon2D\" parent=\"Gate2\"]
color=Color(0.2,0.8,0.4,0.5)
polygon=PackedVector2Array(-60,-12,60,-12,60,12,-60,12)
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=1000.0
offset_bottom=40.0
text=\"RACING\"
[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Car\"]
position_smoothing_enabled=true
"""
	return _pack("arcade_circuit", "Top-down arcade racer with checkpoint laps (Kenney racing kit patterns).", ["Arrows throttle/steer", "Pass green gates in order"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/car.gd", "content": car},
		{"path": "scripts/gate.gd", "content": gate_script},
		{"path": "GENRE_REFS.md", "content": "https://github.com/KenneyNL/Starter-Kit-Racing\\n"},
	])


static func _sim(title: String) -> Dictionary:
	var t := title if title else "Resource Outpost"
	var main := """extends Control
var ore := 0
var energy := 0
var bots := 1
var tick := 0.0
@onready var hud: Label = $HUD
@onready var log: RichTextLabel = $Log
func _process(d: float) -> void:
	tick += d
	if tick >= 1.0:
		tick = 0.0
		ore += bots * 2
		energy += 1
		_refresh()
func _refresh() -> void:
	hud.text = \"SIMULATION | Ore %s · Energy %s · Bots %s\" % [ore, energy, bots]
func _on_mine() -> void:
	ore += 5; log.append_text(\"Manual mine +5 ore\\n\"); _refresh()
func _on_bot() -> void:
	if ore >= 20:
		ore -= 20; bots += 1; log.append_text(\"Built miner bot\\n\"); _refresh()
	else:
		log.append_text(\"Need 20 ore for a bot\\n\")
func _on_reactor() -> void:
	if ore >= 15 and energy >= 5:
		ore -= 15; energy -= 5; energy += 25; log.append_text(\"Reactor burst +25 energy\\n\"); _refresh()
"""
	var scene := """[gd_scene load_steps=2 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[node name=\"Main\" type=\"Control\"]
layout_mode=3
anchors_preset=15
anchor_right=1
anchor_bottom=1
script=ExtResource(\"1\")
[node name=\"BG\" type=\"ColorRect\" parent=\".\"]
layout_mode=1
anchors_preset=15
anchor_right=1
anchor_bottom=1
color=Color(0.08,0.1,0.14,1)
[node name=\"HUD\" type=\"Label\" parent=\".\"]
layout_mode=0
offset_left=24.0
offset_top=24.0
offset_right=900.0
offset_bottom=60.0
theme_override_font_sizes/font_size=22
text=\"SIMULATION\"
[node name=\"Mine\" type=\"Button\" parent=\".\"]
layout_mode=0
offset_left=24.0
offset_top=100.0
offset_right=220.0
offset_bottom=140.0
text=\"Mine ore\"
[node name=\"Bot\" type=\"Button\" parent=\".\"]
layout_mode=0
offset_left=240.0
offset_top=100.0
offset_right=460.0
offset_bottom=140.0
text=\"Build bot (20 ore)\"
[node name=\"Reactor\" type=\"Button\" parent=\".\"]
layout_mode=0
offset_left=480.0
offset_top=100.0
offset_right=720.0
offset_bottom=140.0
text=\"Reactor (15 ore, 5 energy)\"
[node name=\"Log\" type=\"RichTextLabel\" parent=\".\"]
layout_mode=0
offset_left=24.0
offset_top=180.0
offset_right=900.0
offset_bottom=500.0
text=\"Outpost online. Grow bots, gather ore, burn reactors.\"
"""
	# Connect buttons via script
	main = main + """
func _ready() -> void:
	$Mine.pressed.connect(_on_mine)
	$Bot.pressed.connect(_on_bot)
	$Reactor.pressed.connect(_on_reactor)
	_refresh()
"""
	return _pack("resource_outpost", "Management simulation: mine, build bots, spend resources.", ["Click buttons", "Watch idle bots gather"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main},
	])


static func _open(title: String) -> Dictionary:
	var t := title if title else "Zone Explorer"
	var world := """extends Node3D
@onready var hud: Label = $UI/HUD
var found := 0
func _ready() -> void:
	_terrain(); _pois()
func note(msg: String) -> void:
	found += 1; hud.text = \"OPEN WORLD | POIs %s | %s\" % [found, msg]
func _terrain() -> void:
	var b := StaticBody3D.new(); b.position.y = -0.5
	var mi := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(120,1,120); mi.mesh=box
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.2,0.4,0.25); mi.material_override=mat; b.add_child(mi)
	var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size=Vector3(120,1,120); c.shape=s; b.add_child(c); add_child(b)
	for i in 12:
		var rock := StaticBody3D.new(); rock.position = Vector3(randf_range(-50,50), 0.5, randf_range(-50,50))
		var rmi := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size=Vector3(2,2,2); rmi.mesh=rb
		var rm := StandardMaterial3D.new(); rm.albedo_color=Color(0.35,0.32,0.3); rmi.material_override=rm; rock.add_child(rmi)
		var rc := CollisionShape3D.new(); var rs := BoxShape3D.new(); rs.size=Vector3(2,2,2); rc.shape=rs; rock.add_child(rc); add_child(rock)
func _pois() -> void:
	for p in [Vector3(20,1,15), Vector3(-25,1,-10), Vector3(5,1,-30)]:
		var a := Area3D.new(); a.position = p
		var cs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius=2.0; cs.shape=sp; a.add_child(cs)
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius=1.2; mi.mesh=sm
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.95,0.8,0.2); mi.material_override=mat; a.add_child(mi)
		a.body_entered.connect(func(b):
			if b.is_in_group(\"player\"):
				note(\"Discovered landmark\"); a.queue_free()
		)
		add_child(a)
"""
	var player := """extends CharacterBody3D
var yaw := 0.0
@onready var pivot: Node3D = $CamPivot
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius=0.4; cm.height=1.6; mi.mesh=cm
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.3,0.6,1); mi.material_override=mat; add_child(mi)
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.004; pivot.rotation.y = yaw
		pivot.get_node(\"SpringArm3D\").rotation.x = clamp(pivot.get_node(\"SpringArm3D\").rotation.x - e.relative.y*0.003, deg_to_rad(-30), deg_to_rad(20))
	if e.is_action_pressed(\"ui_cancel\"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
func _physics_process(d: float) -> void:
	var i := Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(i.x,0,i.y)).normalized()
	velocity.x = dir.x * 8.0; velocity.z = dir.z * 8.0
	if not is_on_floor(): velocity.y -= 20.0 * d
	elif Input.is_action_just_pressed(\"ui_accept\"): velocity.y = 7.0
	move_and_slide()
"""
	var scene := """[gd_scene load_steps=4 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/world.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[sub_resource type=\"CapsuleShape3D\" id=\"cap\"]
radius=0.4
height=1.6
[node name=\"World\" type=\"Node3D\"]
script=ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody3D\" parent=\".\" groups=[\"player\"]]
transform=Transform3D(1,0,0,0,1,0,0,0,1,0,1.2,0)
script=ExtResource(\"2\")
[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"Player\"]
shape=SubResource(\"cap\")
[node name=\"CamPivot\" type=\"Node3D\" parent=\"Player\"]
[node name=\"SpringArm3D\" type=\"SpringArm3D\" parent=\"Player/CamPivot\"]
spring_length=6.0
[node name=\"Camera3D\" type=\"Camera3D\" parent=\"Player/CamPivot/SpringArm3D\"]
current=true
[node name=\"DirectionalLight3D\" type=\"DirectionalLight3D\" parent=\".\"]
transform=Transform3D(0.8,-0.4,0.4,0,0.7,0.7,-0.5,-0.55,0.65,0,20,0)
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=1000.0
offset_bottom=40.0
text=\"OPEN WORLD | Find golden landmarks\"
"""
	return _pack("zone_explorer", "Open-world exploration sandbox with landmarks on a large terrain.", ["WASD explore", "Mouse look", "Touch gold spheres"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/world.gd", "content": world}, {"path": "scripts/player.gd", "content": player},
	])


static func _brawler(title: String) -> Dictionary:
	var t := title if title else "Street Brawl"
	var main := """extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var hud: Label = $UI/HUD
var score := 0
var spawn_t := 0.0
func _physics_process(d: float) -> void:
	spawn_t -= d
	if spawn_t <= 0.0:
		spawn_t = 2.2; _spawn()
	hud.text = \"BEAT EM UP | Score %s | WASD/Arrows move · J/Space attack\" % score
func add_score() -> void:
	score += 1
func _spawn() -> void:
	var e = load(\"res://scripts/enemy.gd\").new()
	e.position = Vector2(player.position.x + 420, randf_range(360, 520))
	add_child(e)
"""
	var player := """extends CharacterBody2D
var facing := 1.0
var attack_cd := 0.0
@onready var hitbox: Area2D = $Hitbox
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(28,48); c.shape=r; add_child(c)
	var p := Polygon2D.new(); p.color=Color(0.3,0.7,1); p.polygon=PackedVector2Array([Vector2(-14,-24),Vector2(14,-24),Vector2(14,24),Vector2(-14,24)]); add_child(p)
	hitbox.monitoring = false
func _physics_process(d: float) -> void:
	attack_cd = max(0.0, attack_cd - d)
	var i := Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\")
	velocity = i * 220.0
	if abs(i.x) > 0.1: facing = sign(i.x)
	move_and_slide()
	position.y = clamp(position.y, 320, 560)
	if (Input.is_action_just_pressed(\"ui_accept\") or Input.is_key_pressed(KEY_J)) and attack_cd <= 0.0:
		attack_cd = 0.35; _attack()
func _attack() -> void:
	hitbox.position.x = 28 * facing
	hitbox.monitoring = true
	await get_tree().create_timer(0.12).timeout
	hitbox.monitoring = false
"""
	var enemy := """extends CharacterBody2D
var hp := 3
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(28,48); c.shape=r; add_child(c)
	var p := Polygon2D.new(); p.color=Color(0.9,0.3,0.25); p.polygon=PackedVector2Array([Vector2(-14,-24),Vector2(14,-24),Vector2(14,24),Vector2(-14,24)]); add_child(p)
	add_to_group(\"enemies\")
func _physics_process(_d: float) -> void:
	var p := get_tree().get_first_node_in_group(\"player\")
	if p == null: return
	var to: Vector2 = p.position - position
	velocity = to.normalized() * 90.0
	move_and_slide()
func hurt() -> void:
	hp -= 1
	if hp <= 0:
		var m = get_parent(); if m.has_method(\"add_score\"): m.add_score()
		queue_free()
"""
	var hit := """extends Area2D
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(40,30); c.shape=r; add_child(c)
	body_entered.connect(func(b):
		if b.is_in_group(\"enemies\") and b.has_method(\"hurt\"): b.hurt()
	)
"""
	var scene := """[gd_scene load_steps=4 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[ext_resource type=\"Script\" path=\"res://scripts/hitbox.gd\" id=\"3\"]
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Ground\" type=\"Polygon2D\" parent=\".\"]
color=Color(0.18,0.16,0.2,1)
polygon=PackedVector2Array(0,300,2000,300,2000,720,0,720)
[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\" groups=[\"player\"]]
position=Vector2(200,450)
script=ExtResource(\"2\")
[node name=\"Hitbox\" type=\"Area2D\" parent=\"Player\"]
script=ExtResource(\"3\")
monitoring=false
[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Player\"]
position_smoothing_enabled=true
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=1000.0
offset_bottom=40.0
text=\"BEAT EM UP\"
"""
	return _pack("street_brawl", "Side-scrolling beat-em-up with attack hitbox and enemy waves (Quiver template patterns).", ["Move with WASD/arrows", "Space/J attack"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/player.gd", "content": player},
		{"path": "scripts/enemy.gd", "content": enemy}, {"path": "scripts/hitbox.gd", "content": hit},
		{"path": "GENRE_REFS.md", "content": "https://github.com/quiver-dev/template-beat-em-up\\n"},
	])


static func _fight(title: String) -> Dictionary:
	var t := title if title else "Arena Duel"
	var main := """extends Node2D
@onready var p1: CharacterBody2D = $P1
@onready var p2: CharacterBody2D = $P2
@onready var hud: Label = $UI/HUD
func _process(_d: float) -> void:
	hud.text = \"FIGHTING | P1 HP %s | P2 HP %s | P1:A/D+J  P2:Left/Right+K\" % [p1.hp, p2.hp]
	if p1.hp <= 0 or p2.hp <= 0:
		hud.text += \"  — KO! R to restart\"
		if Input.is_key_pressed(KEY_R): get_tree().reload_current_scene()
"""
	var fighter := """extends CharacterBody2D
@export var player_id := 1
var hp := 100
var cd := 0.0
var facing := 1.0
func _ready() -> void:
	var c := CollisionShape2D.new(); var r := RectangleShape2D.new(); r.size=Vector2(30,60); c.shape=r; add_child(c)
	var p := Polygon2D.new(); p.color = Color(0.3,0.6,1) if player_id==1 else Color(1,0.35,0.3)
	p.polygon=PackedVector2Array([Vector2(-15,-30),Vector2(15,-30),Vector2(15,30),Vector2(-15,30)]); add_child(p)
	var hb := Area2D.new(); hb.name=\"Hit\"; hb.monitoring=false
	var hs := CollisionShape2D.new(); var hr := RectangleShape2D.new(); hr.size=Vector2(36,24); hs.shape=hr; hb.add_child(hs)
	hb.position = Vector2(28, -10); add_child(hb)
	hb.body_entered.connect(_on_hit)
func _physics_process(d: float) -> void:
	cd = max(0.0, cd - d)
	var left := KEY_A if player_id==1 else KEY_LEFT
	var right := KEY_D if player_id==1 else KEY_RIGHT
	var atk := KEY_J if player_id==1 else KEY_K
	var x := (-1.0 if Input.is_key_pressed(left) else 0.0) + (1.0 if Input.is_key_pressed(right) else 0.0)
	if abs(x) > 0: facing = x
	velocity.x = x * 220.0
	velocity.y += 900.0 * d
	move_and_slide()
	position.x = clamp(position.x, 80, 1200)
	if position.y > 520: position.y = 520; velocity.y = 0
	$Hit.position.x = 28 * facing
	if Input.is_key_pressed(atk) and cd <= 0.0:
		cd = 0.4; $Hit.monitoring = true
		await get_tree().create_timer(0.1).timeout
		$Hit.monitoring = false
func _on_hit(b: Node) -> void:
	if b == self: return
	if b is CharacterBody2D and b.has_method(\"hurt\"): b.hurt(12)
func hurt(a: int) -> void:
	hp = max(0, hp - a)
"""
	var scene := """[gd_scene load_steps=3 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/fighter.gd\" id=\"2\"]
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Floor\" type=\"Polygon2D\" parent=\".\"]
color=Color(0.2,0.22,0.28,1)
polygon=PackedVector2Array(0,520,1280,520,1280,720,0,720)
[node name=\"P1\" type=\"CharacterBody2D\" parent=\".\"]
position=Vector2(360,520)
script=ExtResource(\"2\")
player_id=1
[node name=\"P2\" type=\"CharacterBody2D\" parent=\".\"]
position=Vector2(920,520)
script=ExtResource(\"2\")
player_id=2
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=1200.0
offset_bottom=40.0
text=\"FIGHTING\"
"""
	return _pack("arena_duel", "1v1 fighting prototype with health, attack recovery, KO restart.", ["P1: A/D + J", "P2: arrows + K", "R after KO"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/fighter.gd", "content": fighter},
	])


static func _voxel(title: String) -> Dictionary:
	var t := title if title else "Blockcraft"
	var world := """extends Node3D
## Minecraft-feel recreation: blocks, break particles, physics chips, materials, HUD.
## Original Godot code — not Mojang assets/ROMs.

const SIZE := 24
const HEIGHT := 10
var blocks := {}
@onready var hud: Label = $UI/HUD
@onready var player: CharacterBody3D = $Player
@onready var fx: GPUParticles3D = $BreakFX
var selected := 0
var palette: Array[Color] = [
	Color(0.35, 0.72, 0.28), Color(0.48, 0.33, 0.2), Color(0.55, 0.55, 0.58),
	Color(0.95, 0.85, 0.3), Color(0.22, 0.48, 0.9)
]
var _root: Node3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root = Node3D.new(); add_child(_root)
	_setup_particles()
	_generate(); _rebuild(); _refresh_hud()

func _setup_particles() -> void:
	fx.emitting = false
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = 28
	fx.lifetime = 0.55
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0, -12, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.18
	fx.process_material = mat
	var draw := SphereMesh.new(); draw.radius = 0.08; draw.height = 0.16
	fx.draw_pass_1 = draw

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(\"ui_cancel\"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_5:
		selected = e.keycode - KEY_1; _refresh_hud()
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if e.button_index == MOUSE_BUTTON_LEFT: _break_block()
		elif e.button_index == MOUSE_BUTTON_RIGHT: _place_block()

func _generate() -> void:
	for x in SIZE:
		for z in SIZE:
			var h := 2 + int(2.5 * sin(x * 0.35) * cos(z * 0.28))
			for y in h:
				var c := palette[0] if y == h - 1 else palette[1]
				if y == 0: c = palette[2]
				blocks[Vector3i(x, y, z)] = c

func _rebuild() -> void:
	for c in _root.get_children(): c.queue_free()
	for cell in blocks.keys():
		var body := StaticBody3D.new()
		body.position = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
		body.set_meta(\"cell\", cell)
		body.collision_layer = 1; body.collision_mask = 1
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3.ONE * 0.98; mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = blocks[cell]
		mat.roughness = 0.85
		mi.material_override = mat
		body.add_child(mi)
		var col := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3.ONE; col.shape = sh; body.add_child(col)
		_root.add_child(body)

func _aim() -> Dictionary:
	var cam: Camera3D = player.get_node(\"Camera3D\")
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from + (-cam.global_transform.basis.z) * 8.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player]
	q.collision_mask = 1
	return space.intersect_ray(q)

func _burst(at: Vector3, col: Color) -> void:
	fx.global_position = at
	if fx.process_material is ParticleProcessMaterial:
		(fx.process_material as ParticleProcessMaterial).color = col
	fx.restart()
	fx.emitting = true
	for i in 5:
		var chip := RigidBody3D.new()
		chip.position = at + Vector3(randf_range(-0.2,0.2), randf_range(0.0,0.3), randf_range(-0.2,0.2))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3.ONE * 0.12; mi.mesh = bm
		var mat := StandardMaterial3D.new(); mat.albedo_color = col; mi.material_override = mat
		chip.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3.ONE * 0.12; cs.shape = sh; chip.add_child(cs)
		add_child(chip)
		chip.apply_central_impulse(Vector3(randf_range(-2,2), randf_range(2,5), randf_range(-2,2)))
		get_tree().create_timer(1.2).timeout.connect(func(): chip.queue_free())

func _break_block() -> void:
	var hit := _aim()
	if hit.is_empty(): return
	var collider = hit.collider
	if collider and collider.has_meta(\"cell\"):
		var cell: Vector3i = collider.get_meta(\"cell\")
		var col: Color = blocks.get(cell, Color.WHITE)
		blocks.erase(cell)
		_burst(Vector3(cell) + Vector3(0.5, 0.5, 0.5), col)
		_rebuild(); _refresh_hud()

func _place_block() -> void:
	var hit := _aim()
	if hit.is_empty(): return
	var collider = hit.collider
	if collider == null or not collider.has_meta(\"cell\"): return
	var base: Vector3i = collider.get_meta(\"cell\")
	var n: Vector3 = hit.normal
	var cell := base + Vector3i(round(n.x), round(n.y), round(n.z))
	if cell.y < 0 or cell.y >= HEIGHT or blocks.has(cell): return
	blocks[cell] = palette[selected]
	_rebuild(); _refresh_hud()

func _refresh_hud() -> void:
	hud.text = \"BLOCKCRAFT | LMB break+FX · RMB place · 1-5 type (%s) · Esc mouse\" % (selected + 1)
"""
	var player := """extends CharacterBody3D
const SPEED := 6.5
var pitch := 0.0
var _bob := 0.0
@onready var cam: Camera3D = $Camera3D
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * 0.0025)
		pitch = clamp(pitch - e.relative.y * 0.0025, deg_to_rad(-89), deg_to_rad(89))
		cam.rotation.x = pitch
func _physics_process(d: float) -> void:
	var i := Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\")
	var dir := (transform.basis * Vector3(i.x, 0, i.y)).normalized()
	velocity.x = dir.x * SPEED; velocity.z = dir.z * SPEED
	if not is_on_floor(): velocity.y -= 22.0 * d
	elif Input.is_action_just_pressed(\"ui_accept\"): velocity.y = 7.5
	move_and_slide()
	# Simple walk bob animation
	if dir.length() > 0.1 and is_on_floor():
		_bob += d * 10.0
		cam.position.y = 0.6 + sin(_bob) * 0.05
	else:
		cam.position.y = lerpf(cam.position.y, 0.6, 0.2)
"""
	var menu_gd := """extends Control
func _ready() -> void:
	$Center/VBox/Play.pressed.connect(func(): get_tree().change_scene_to_file(\"res://scenes/main.tscn\"))
	$Center/VBox/Quit.pressed.connect(func(): get_tree().quit())
"""
	var menu_tscn := """[gd_scene load_steps=2 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/menu.gd\" id=\"1\"]
[node name=\"Menu\" type=\"Control\"]
layout_mode=3
anchors_preset=15
anchor_right=1
anchor_bottom=1
script=ExtResource(\"1\")
[node name=\"BG\" type=\"ColorRect\" parent=\".\"]
layout_mode=1
anchors_preset=15
anchor_right=1
anchor_bottom=1
color=Color(0.12,0.55,0.35,1)
[node name=\"Center\" type=\"CenterContainer\" parent=\".\"]
layout_mode=1
anchors_preset=15
anchor_right=1
anchor_bottom=1
[node name=\"VBox\" type=\"VBoxContainer\" parent=\"Center\"]
layout_mode=2
theme_override_constants/separation=12
[node name=\"Title\" type=\"Label\" parent=\"Center/VBox\"]
layout_mode=2
theme_override_font_sizes/font_size=36
text=\"BLOCKCRAFT\"
horizontal_alignment=1
[node name=\"Sub\" type=\"Label\" parent=\"Center/VBox\"]
layout_mode=2
text=\"Minecraft-feel recreation · particles · physics break\"
horizontal_alignment=1
[node name=\"Play\" type=\"Button\" parent=\"Center/VBox\"]
custom_minimum_size=Vector2(220,40)
layout_mode=2
text=\"Play\"
[node name=\"Quit\" type=\"Button\" parent=\"Center/VBox\"]
custom_minimum_size=Vector2(220,40)
layout_mode=2
text=\"Quit\"
"""
	var scene := """[gd_scene load_steps=4 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/world.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[sub_resource type=\"CapsuleShape3D\" id=\"cap\"]
radius = 0.35
height = 1.5
[node name=\"World\" type=\"Node3D\"]
script = ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody3D\" parent=\".\" groups=[\"player\"]]
transform = Transform3D(1,0,0,0,1,0,0,0,1,12,8,12)
script = ExtResource(\"2\")
[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"Player\"]
shape = SubResource(\"cap\")
[node name=\"Camera3D\" type=\"Camera3D\" parent=\"Player\"]
transform = Transform3D(1,0,0,0,1,0,0,0,1,0,0.6,0)
current = true
fov = 75.0
[node name=\"BreakFX\" type=\"GPUParticles3D\" parent=\".\"]
emitting = false
[node name=\"DirectionalLight3D\" type=\"DirectionalLight3D\" parent=\".\"]
transform = Transform3D(0.8,-0.4,0.4,0,0.7,0.7,-0.5,-0.55,0.65,0,30,0)
shadow_enabled = true
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right = 1200.0
offset_bottom = 40.0
theme_override_font_sizes/font_size = 18
text = \"BLOCKCRAFT\"
"""
	var pg := _godot(t).replace("run/main_scene=\"res://scenes/main.tscn\"", "run/main_scene=\"res://scenes/menu.tscn\"")
	return _pack("blockcraft", "Minecraft-feel recreation: menu UI, materials, walk bob, break particles + physics chips.", [
		"Open project — menu Play",
		"WASD · mouse · Space jump",
		"LMB break (particles+debris) · RMB place · 1-5 types",
	], [
		{"path": "project.godot", "content": pg},
		{"path": "scenes/menu.tscn", "content": menu_tscn},
		{"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/menu.gd", "content": menu_gd},
		{"path": "scripts/world.gd", "content": world},
		{"path": "scripts/player.gd", "content": player},
		{"path": "GENRE_REFS.md", "content": "# Minecraft-feel recreation\\nKenney voxel pack CC0 · Godot GPUParticles3D · RigidBody3D debris\\nNot Mojang assets.\\n"},
	])


static func _arena(title: String) -> Dictionary:
	var t := title if title else "Arena Survivor"
	var main := """extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var hud: Label = $UI/HUD
var score := 0
var tmr := 0.0
func _physics_process(d: float) -> void:
	tmr -= d
	if tmr <= 0.0:
		tmr = 0.9
		var g := Area2D.new(); g.position = Vector2(randf_range(40,1240), randf_range(40,680))
		var s := CollisionShape2D.new(); var c := CircleShape2D.new(); c.radius=12; s.shape=c; g.add_child(s)
		var p := Polygon2D.new(); p.color=Color(0.2,0.9,0.55); p.polygon=PackedVector2Array([Vector2(0,-14),Vector2(14,0),Vector2(0,14),Vector2(-14,0)]); g.add_child(p)
		g.body_entered.connect(func(b):
			if b == player: score += 1; g.queue_free()
		)
		add_child(g)
	hud.text = \"ARENA | Score %s | WASD collect gems\" % score
"""
	var player := """extends CharacterBody2D
func _ready() -> void:
	var s := CollisionShape2D.new(); var c := CircleShape2D.new(); c.radius=16; s.shape=c; add_child(s)
	var p := Polygon2D.new(); p.color=Color(0.95,0.65,0.25); p.polygon=PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]); add_child(p)
	position = Vector2(640,360)
func _physics_process(_d: float) -> void:
	velocity = Input.get_vector(\"ui_left\",\"ui_right\",\"ui_up\",\"ui_down\") * 280.0
	move_and_slide()
"""
	var scene := """[gd_scene load_steps=3 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/main.gd\" id=\"1\"]
[ext_resource type=\"Script\" path=\"res://scripts/player.gd\" id=\"2\"]
[node name=\"Main\" type=\"Node2D\"]
script=ExtResource(\"1\")
[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\"]
script=ExtResource(\"2\")
[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]
[node name=\"HUD\" type=\"Label\" parent=\"UI\"]
offset_right=900.0
offset_bottom=40.0
text=\"ARENA\"
"""
	return _pack("arena_survivor", "Top-down arena collector / survivor starter.", ["WASD move", "Touch gems"], [
		{"path": "project.godot", "content": _godot(t)}, {"path": "scenes/main.tscn", "content": scene},
		{"path": "scripts/main.gd", "content": main}, {"path": "scripts/player.gd", "content": player},
	])
