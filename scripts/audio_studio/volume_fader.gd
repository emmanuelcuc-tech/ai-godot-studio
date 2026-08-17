extends Control
## Vertical mixer fader.

signal value_changed(value: float)

var volume: float = MixerBus.UNITY
var label_text: String = "IN"
var dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(64, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_VSIZE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
			if dragging:
				_apply_y(mb.position.y)
			accept_event()
	elif dragging and event is InputEventMouseMotion:
		_apply_y((event as InputEventMouseMotion).position.y)
		accept_event()


func _apply_y(y: float) -> void:
	var pad := 22.0
	# Control Y grows down; fader math wants bottom = quiet.
	var y0 := size.y - pad
	var y1 := pad
	volume = MixerBus.volume_from_fader_y(y, y0, y1)
	value_changed.emit(volume)
	queue_redraw()


func _draw() -> void:
	var neon := MixerBus.neon_rgb(float(Time.get_ticks_msec()) / 1000.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.035, 0.95), true)
	var pad := 22.0
	var fx := size.x * 0.5
	draw_line(Vector2(fx, pad), Vector2(fx, size.y - pad), Color(0.12, 0.1, 0.1), 6.0)
	var fy := MixerBus.fader_y_from_volume(volume, size.y - pad, pad)
	draw_rect(Rect2(fx - 16, fy - 8, 32, 16), neon, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(2, 14), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 12, neon)
	draw_string(font, Vector2(2, size.y - 4), "%.0f%%" % ((volume / MixerBus.UNITY) * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 11, neon)
