extends Control
## Full-screen vintage typewriter for iPad — spring haptic on every key.

const KEY_ROWS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"],
	["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"],
]

@onready var paper_label: Label = %Paper
@onready var caret: Label = %Caret
@onready var keyboard: VBoxContainer = %Keyboard
@onready var chassis: Panel = %Chassis
@onready var brand: Label = %Brand
@onready var status: Label = %Status

var _text: String = ""
var _shift: bool = false
var _caps: bool = false
var _haptic: Node
var _click: AudioStreamPlayer
var _caret_blink: float = 0.0
var _max_chars_line: int = 42


func _ready() -> void:
	get_window().mode = Window.MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_haptic = preload("res://scripts/haptic_spring.gd").new()
	add_child(_haptic)
	_setup_audio()
	_build_keyboard()
	_refresh_paper()
	status.text = "Tap keys · Return for newline · Spring haptic on each press"
	resized.connect(_on_resized)
	_on_resized()


func _process(delta: float) -> void:
	_caret_blink += delta
	caret.visible = fmod(_caret_blink, 1.0) < 0.55


func _on_resized() -> void:
	var w := size.x
	_max_chars_line = clampi(int(w / 22.0), 28, 56)


func _setup_audio() -> void:
	_click = AudioStreamPlayer.new()
	_click.volume_db = -8.0
	add_child(_click)
	_click.stream = _make_click_stream()


func _make_click_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(sample_rate * 0.035)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 55.0)
		var noise := (randf() * 2.0 - 1.0) * 0.35
		var tone := sin(t * TAU * 980.0) * 0.25 + sin(t * TAU * 420.0) * 0.15
		var s := clampf((noise + tone) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _build_keyboard() -> void:
	for child in keyboard.get_children():
		child.queue_free()
	for row in KEY_ROWS:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 8)
		keyboard.add_child(h)
		for label in row:
			h.add_child(_make_key(label, label))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	keyboard.add_child(bottom)
	bottom.add_child(_make_key("SHIFT", "SHIFT", Vector2(108, 64)))
	bottom.add_child(_make_key("SPACE", " ", Vector2(320, 64)))
	bottom.add_child(_make_key("RETURN", "RETURN", Vector2(120, 64)))
	bottom.add_child(_make_key("⌫", "BACK", Vector2(88, 64)))


func _make_key(caption: String, action: String, min_size: Vector2 = Vector2(58, 64)) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18 if caption.length() <= 2 else 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09)
	sb.border_color = Color(0.28, 0.26, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(28 if caption.length() <= 2 else 14)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	var sb_press := sb.duplicate()
	sb_press.bg_color = Color(0.16, 0.15, 0.14)
	sb_press.shadow_size = 1
	sb_press.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb_press)
	b.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	b.add_theme_color_override("font_pressed_color", Color(0.98, 0.94, 0.78))
	b.button_down.connect(func() -> void: _on_key(action, b))
	return b


func _on_key(action: String, btn: Button = null) -> void:
	_haptic.call("spring_pulse")
	_play_click()
	if btn:
		_bounce_key(btn)
	match action:
		"SHIFT":
			_shift = not _shift
			status.text = "SHIFT locked" if _shift else "SHIFT off"
		"RETURN":
			_append("\n")
		"BACK":
			if not _text.is_empty():
				_text = _text.substr(0, _text.length() - 1)
				_refresh_paper()
		" ":
			_append(" ")
		_:
			var ch := action
			var upper := _shift or _caps
			if ch.length() == 1:
				ch = ch.to_upper() if upper else ch.to_lower()
			_append(ch)
			if _shift and action != "SHIFT":
				_shift = false


func _append(ch: String) -> void:
	_text += ch
	_refresh_paper()


func _refresh_paper() -> void:
	if _text.is_empty():
		paper_label.text = "Begin typing…"
		paper_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.32, 0.85))
	else:
		paper_label.text = _text
		paper_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08, 1))
	caret.text = "▌"


func _bounce_key(btn: Button) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	btn.scale = Vector2(0.92, 0.86)
	btn.pivot_offset = btn.size * 0.5
	tw.tween_property(btn, "scale", Vector2(1.04, 1.06), 0.07)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.16)


func _play_click() -> void:
	if _click and _click.stream:
		_click.pitch_scale = randf_range(0.92, 1.08)
		_click.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_BACKSPACE:
			_on_key("BACK")
		elif ke.keycode == KEY_ENTER:
			_on_key("RETURN")
		elif ke.keycode == KEY_SPACE:
			_on_key(" ")
		elif ke.unicode > 31:
			_haptic.call("spring_pulse")
			_play_click()
			_append(char(ke.unicode))
