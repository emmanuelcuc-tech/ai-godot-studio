extends Button
class_name RoyalKey
## Semi-transparent hotspot over photo keys; snappy depress animation.

signal key_struck(action: String)

var action_id: String = ""
var _rest_y: float = 0.0
var _press_tween: Tween
var _pressed_depth: float = 5.0
var _idle_modulate := Color(1, 1, 1, 0.42)


func setup(id: String, label: String, size: Vector2 = Vector2(46, 46), circular: bool = true) -> void:
	action_id = id
	text = label
	custom_minimum_size = size
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate = _idle_modulate
	_apply_style(circular, size)
	pressed.connect(_on_clicked)


func _ready() -> void:
	_rest_y = position.y


func _apply_style(circular: bool, size: Vector2) -> void:
	var r := int(mini(size.x, size.y) * 0.5) if circular else 6
	var normal := _make_style(Color(0.05, 0.05, 0.06, 0.55), Color(0.78, 0.80, 0.84, 0.75), r, 2)
	var hover := _make_style(Color(0.12, 0.12, 0.13, 0.72), Color(0.92, 0.93, 0.95, 0.9), r, 2)
	var down := _make_style(Color(0.02, 0.02, 0.03, 0.85), Color(0.55, 0.56, 0.58, 0.9), r, 2)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("focus", normal)
	add_theme_color_override("font_color", Color(0.95, 0.95, 0.93, 0.95))
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.82))
	var fs := 10 if size.x < 70 else 12
	if label_is_special():
		fs = 8
	add_theme_font_size_override("font_size", fs)


func label_is_special() -> bool:
	return text.length() > 2


func _make_style(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	return sb


func _on_clicked() -> void:
	key_struck.emit(action_id)


## Mechanical press: down then spring back. Returns approx duration.
func animate_press() -> float:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	if not has_meta("_rest_set"):
		_rest_y = position.y
		set_meta("_rest_set", true)
	var down := 0.05
	var up := 0.09
	modulate = Color(1, 1, 1, 0.85)
	_press_tween = create_tween()
	_press_tween.set_parallel(false)
	_press_tween.tween_property(self, "position:y", _rest_y + _pressed_depth, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_press_tween.parallel().tween_property(self, "scale", Vector2(0.94, 0.9), down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_press_tween.tween_property(self, "position:y", _rest_y, up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.parallel().tween_property(self, "scale", Vector2.ONE, up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "modulate", _idle_modulate, 0.12)
	return down + up
