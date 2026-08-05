extends Node3D
## Studio-forged actor: Skeleton3D + boxel mesh + idle/walk/attack clips.

@export var model_title: String = "Forged"
@export var albedo_path: String = ""
@export var photo_front: String = ""
@export var photo_side: String = ""
@export var photo_back: String = ""
@export var use_photo_replica: bool = false
@export var metallic: float = 0.05
@export var roughness: float = 0.55
@export var autoplay: String = "idle"

var _skeleton: Skeleton3D
var _player: AnimationPlayer


func _ready() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)
	_build_bones()
	_build_mesh()
	_build_anims()
	if not autoplay.is_empty():
		_player.play(autoplay)


func play(clip: String) -> void:
	if _player and _player.has_animation(clip):
		_player.play(clip)


func _build_bones() -> void:
	var hips := _bone("Hips", -1, Vector3(0, 0.95, 0))
	var chest := _bone("Chest", hips, Vector3(0, 0.42, 0))
	_bone("Head", chest, Vector3(0, 0.36, 0))
	var ls := _bone("ShoulderL", chest, Vector3(0.22, 0.28, 0))
	_bone("ArmL", ls, Vector3(0.28, -0.08, 0))
	var rs := _bone("ShoulderR", chest, Vector3(-0.22, 0.28, 0))
	_bone("ArmR", rs, Vector3(-0.28, -0.08, 0))
	var ll := _bone("UpperLegL", hips, Vector3(0.12, -0.05, 0))
	_bone("LowerLegL", ll, Vector3(0.02, -0.42, 0))
	var rl := _bone("UpperLegR", hips, Vector3(-0.12, -0.05, 0))
	_bone("LowerLegR", rl, Vector3(-0.02, -0.42, 0))
	_skeleton.reset_bone_poses()


func _bone(n: String, parent: int, rest_pos: Vector3) -> int:
	var i: int = _skeleton.add_bone(n)
	if parent >= 0:
		_skeleton.set_bone_parent(i, parent)
	_skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, rest_pos))
	return i


func _build_mesh() -> void:
	var atlas := _load_tex(albedo_path)
	var front := _load_tex(photo_front)
	if front == null:
		front = atlas
	var side := _load_tex(photo_side)
	if side == null:
		side = front
	var back := _load_tex(photo_back)
	if back == null:
		back = atlas
	var body := _make_mat(atlas, Vector2(0.72, 0.42), Vector2(0.02, 0.28))
	var head := _make_mat(front if front else atlas, Vector2(0.55, 0.38), Vector2(0.22, 0.04))
	var hips := _make_mat(atlas, Vector2(0.55, 0.22), Vector2(0.08, 0.58))
	var arm_tex: Texture2D = side if side else atlas
	var arm_scale := Vector2.ONE
	var arm_off := Vector2.ZERO
	if use_photo_replica:
		if side != null and side != front:
			arm_scale = Vector2(0.55, 0.85)
			arm_off = Vector2(0.22, 0.08)
		else:
			arm_tex = atlas
			arm_scale = Vector2(0.22, 0.48)
			arm_off = Vector2(0.76, 0.04)
	var arm := _make_mat(arm_tex, arm_scale, arm_off)
	var leg := _make_mat(atlas, Vector2(0.42, 0.28), Vector2(0.12, 0.68))
	_attach_box("Hips", Vector3(0.32, 0.16, 0.2), Vector3.ZERO, hips)
	_attach_box("Chest", Vector3(0.38, 0.42, 0.22), Vector3(0, 0.08, 0), body)
	_attach_box("Head", Vector3(0.24, 0.24, 0.24), Vector3(0, 0.08, 0), head)
	_attach_box("ArmL", Vector3(0.12, 0.38, 0.12), Vector3(0.06, -0.06, 0), arm)
	_attach_box("ArmR", Vector3(0.12, 0.38, 0.12), Vector3(-0.06, -0.06, 0), arm)
	_attach_box("UpperLegL", Vector3(0.14, 0.36, 0.14), Vector3(0, -0.12, 0), leg)
	_attach_box("UpperLegR", Vector3(0.14, 0.36, 0.14), Vector3(0, -0.12, 0), leg)
	_attach_box("LowerLegL", Vector3(0.12, 0.34, 0.12), Vector3(0, -0.1, 0), leg)
	_attach_box("LowerLegR", Vector3(0.12, 0.34, 0.12), Vector3(0, -0.1, 0), leg)
	if use_photo_replica and front:
		_attach_likeness("Chest", Vector2(0.40, 0.52), Vector3(0, 0.06, 0.12), front, Vector2(0.78, 0.55), Vector2(0.11, 0.22))
		_attach_likeness("Head", Vector2(0.22, 0.24), Vector3(0, 0.08, 0.13), front, Vector2(0.42, 0.36), Vector2(0.29, 0.04))
		if back:
			_attach_likeness("Chest", Vector2(0.38, 0.50), Vector3(0, 0.06, -0.12), back, Vector2(1, 1), Vector2.ZERO, true)


func _load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func _make_mat(tex: Texture2D, uv_scale: Vector2, uv_offset: Vector2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.metallic = metallic
	mat.roughness = roughness
	if tex:
		mat.albedo_texture = tex
		if use_photo_replica:
			mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
			mat.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat


func _attach_likeness(bone_name: String, size: Vector2, offset: Vector3, tex: Texture2D, uv_scale: Vector2, uv_offset: Vector2, flip_back: bool = false) -> void:
	var att := _skeleton.get_node_or_null("Att_%s" % bone_name) as BoneAttachment3D
	if att == null:
		return
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = offset
	if flip_back:
		mi.rotation_degrees.y = 180.0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.55
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	mat.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0)
	mi.material_override = mat
	att.add_child(mi)


func _attach_box(bone_name: String, size: Vector3, offset: Vector3, mat: Material) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	att.name = "Att_%s" % bone_name
	_skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = offset
	mi.material_override = mat
	att.add_child(mi)


func _build_anims() -> void:
	_player = AnimationPlayer.new()
	_player.name = "Anim"
	add_child(_player)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _clip_idle())
	lib.add_animation("walk", _clip_walk())
	lib.add_animation("attack", _clip_attack())
	_player.add_animation_library("", lib)


func _clip_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	_eul_track(a, "Att_Chest", Vector3(0.08, 0, 0), Vector3(-0.04, 0, 0), 1.2)
	return a


func _clip_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_LINEAR
	_eul_track(a, "Att_UpperLegL", Vector3(0.55, 0, 0), Vector3(-0.55, 0, 0), 0.7)
	_eul_track(a, "Att_UpperLegR", Vector3(-0.55, 0, 0), Vector3(0.55, 0, 0), 0.7)
	_eul_track(a, "Att_ArmL", Vector3(-0.45, 0, 0), Vector3(0.45, 0, 0), 0.7)
	_eul_track(a, "Att_ArmR", Vector3(0.45, 0, 0), Vector3(-0.45, 0, 0), 0.7)
	return a


func _clip_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_NONE
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath("Skeleton/Att_ArmR:rotation"))
	a.track_insert_key(t, 0.0, Vector3.ZERO)
	a.track_insert_key(t, 0.18, Vector3(-1.25, 0.15, 0))
	a.track_insert_key(t, 0.34, Vector3(0.35, -0.1, 0))
	a.track_insert_key(t, 0.55, Vector3.ZERO)
	return a


func _eul_track(a: Animation, att: String, e0: Vector3, e1: Vector3, length: float) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath("Skeleton/%s:rotation" % att))
	a.track_insert_key(t, 0.0, e0)
	a.track_insert_key(t, length * 0.5, e1)
	a.track_insert_key(t, length, e0)
