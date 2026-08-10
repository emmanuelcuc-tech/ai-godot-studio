extends Button
class_name RoyalKey
## Invisible hotspot over photo keys. On press, a cropped photo key scales down ~8% then springs back.

signal key_struck(action: String)

var action_id: String = ""
var _press_tween: Tween
var _face: TextureRect
var _atlas: AtlasTexture
var _press_scale := 0.90


func setup(
	id: String,
	_label: String,
	size: Vector2 = Vector2(46, 46),
	circular: bool = true,
	keys_tex: Texture2D = null,
	atlas_uv: Rect2 = Rect2()
) -> void:
	action_id = id
	text = ""
	custom_minimum_size = size
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate = Color(1, 1, 1, 1)
	flat = true
	_apply_invisible_style(circular, size)
	_ensure_face(keys_tex, atlas_uv, size)
	if not pressed.is_connected(_on_clicked):
		pressed.connect(_on_clicked)


func _apply_invisible_style(circular: bool, size: Vector2) -> void:
	var r := int(mini(size.x, size.y) * 0.5) if circular else 4
	var empty := _make_empty(r)
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_font_size_override("font_size", 1)


func _make_empty(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	sb.border_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.shadow_size = 0
	return sb


func _ensure_face(keys_tex: Texture2D, atlas_uv: Rect2, size: Vector2) -> void:
	if _face == null:
		_face = TextureRect.new()
		_face.name = "PhotoFace"
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_face.pivot_offset = size * 0.5
		add_child(_face)
	_face.position = Vector2.ZERO
	_face.size = size
	_face.pivot_offset = size * 0.5
	_face.modulate = Color(1, 1, 1, 0)
	_face.scale = Vector2.ONE
	if keys_tex == null or atlas_uv.size.x <= 0.0:
		_face.texture = null
		return
	_atlas = AtlasTexture.new()
	_atlas.atlas = keys_tex
	var tw := float(keys_tex.get_width())
	var th := float(keys_tex.get_height())
	_atlas.region = Rect2(
		atlas_uv.position.x * tw,
		atlas_uv.position.y * th,
		atlas_uv.size.x * tw,
		atlas_uv.size.y * th
	)
	_face.texture = _atlas


func set_photo_face(keys_tex: Texture2D, atlas_uv: Rect2) -> void:
	_ensure_face(keys_tex, atlas_uv, size)


func _on_clicked() -> void:
	key_struck.emit(action_id)


## Photo key depress: shrink crop ~8–10%, spring back. Returns approx duration.
func animate_press() -> float:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	if _face == null:
		return 0.12
	_face.pivot_offset = size * 0.5
	_face.position = Vector2.ZERO
	_face.size = size
	var down := 0.045
	var up := 0.10
	_face.modulate = Color(1, 1, 1, 1)
	_face.scale = Vector2.ONE
	_press_tween = create_tween()
	_press_tween.set_parallel(false)
	_press_tween.tween_property(_face, "scale", Vector2(_press_scale, _press_scale), down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_press_tween.tween_property(_face, "scale", Vector2.ONE, up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(_face, "modulate:a", 0.0, 0.08)
	return down + up
