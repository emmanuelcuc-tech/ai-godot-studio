extends Control
## Rotary volume knob (270° pot). Drag to twist.

const MixerBus = preload("res://scripts/audio_studio/mixer_bus.gd")

signal value_changed(value: float)

var volume: float = MixerBus.UNITY
var label_text: String = "IN"
var dragging: bool = false
var last_ang: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(88, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				last_ang = _ang_to(mb.position)
			else:
				dragging = false
			accept_event()
	elif dragging and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var ang := _ang_to(mm.position)
		volume = MixerBus.twist_volume(volume, last_ang, ang)
		last_ang = ang
		value_changed.emit(volume)
		queue_redraw()
		accept_event()


func _ang_to(local: Vector2) -> float:
	var c := size * 0.5
	return atan2(c.y - local.y, local.x - c.x)


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var r := minf(size.x, size.y) * 0.32
	draw_circle(c, r * 1.22, Color(0.05, 0.03, 0.03, 0.9))
	draw_circle(c, r * 1.02, Color(0.13, 0.1, 0.1))
	draw_circle(c, r * 0.86, Color(0.07, 0.05, 0.05))
	var neon := MixerBus.neon_rgb(float(Time.get_ticks_msec()) / 1000.0)
	var ang := MixerBus.knob_angle_from_volume(volume)
	var tip := c + Vector2(cos(ang), -sin(ang)) * r * 0.7
	draw_line(c, tip, neon, 3.0)
	draw_circle(tip, 4.0, neon)
	draw_circle(c, 5.0, Color(0.04, 0.03, 0.03))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, size.y - 18), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 13, neon)
	draw_string(font, Vector2(4, size.y - 4), "%.0f%%" % ((volume / MixerBus.UNITY) * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 12, neon)
