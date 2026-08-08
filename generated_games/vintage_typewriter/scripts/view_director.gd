class_name ViewDirector
extends Node
## View director: keys / paper / auto / bottom — zoom + letter-strike cinematics.

enum Mode { FULL, KEYS, PAPER, AUTO, BOTTOM }

signal mode_changed(mode: int)

var mode: int = Mode.FULL
var auto_busy: bool = false

var _machine: Control
var _paper: Control
var _keyboard: Control
var _platen_row: Control
var _feed_hint: Control
var _top_bar: Control
var _strike_layer: Control
var _tween: Tween
var _bottom_only: bool = false
var _striker_tex: Texture2D
var _paper_base_ratio: float = 1.15
var _key_base_ratio: float = 1.0


func setup(machine: Control, paper: Control, keyboard: Control) -> void:
	_machine = machine
	_paper = paper
	_keyboard = keyboard
	_platen_row = machine.get_node_or_null("MachineMargin/Chassis/Body/PlatenRow")
	_feed_hint = machine.get_node_or_null("MachineMargin/Chassis/Body/FeedHint")
	_top_bar = machine.get_node_or_null("MachineMargin/Chassis/Body/TopBar")
	_strike_layer = Control.new()
	_strike_layer.name = "StrikeLayer"
	_strike_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strike_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine.add_child(_strike_layer)
	_load_striker_tex()
	apply_mode(Mode.FULL, false)


func set_striker_texture(tex: Texture2D) -> void:
	_striker_tex = tex


func _load_striker_tex() -> void:
	## Drop-in only — no packaged cinema atlases. Missing = scale/shadow feedback only.
	for path in [
		"res://assets/images/striker.png",
		"res://assets/keys/striker.png",
	]:
		if ResourceLoader.exists(path):
			var r := load(path)
			if r is Texture2D:
				_striker_tex = r
				return
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.new()
			if img.load(abs_path) == OK:
				_striker_tex = ImageTexture.create_from_image(img)
				return
	_striker_tex = null


func set_mode(m: int) -> void:
	apply_mode(m, true)


func cycle_mode() -> void:
	set_mode((mode + 1) % 5)


func apply_mode(m: int, animate: bool = true) -> void:
	mode = m
	_bottom_only = mode == Mode.BOTTOM
	if _tween and _tween.is_running():
		_tween.kill()
	match mode:
		Mode.FULL:
			_paper_base_ratio = 1.15
			_key_base_ratio = 1.0
			_layout(1.15, 1.0, true, true, true, animate)
		Mode.KEYS:
			_paper_base_ratio = 0.05
			_key_base_ratio = 2.4
			_layout(0.05, 2.4, false, true, true, animate)
			_zoom_keyboard(1.0, animate)
		Mode.PAPER:
			_paper_base_ratio = 2.6
			_key_base_ratio = 0.15
			_layout(2.6, 0.15, true, false, true, animate)
		Mode.AUTO:
			_paper_base_ratio = 1.0
			_key_base_ratio = 1.2
			_layout(1.0, 1.2, true, true, true, animate)
		Mode.BOTTOM:
			_paper_base_ratio = 0.35
			_key_base_ratio = 1.8
			_layout(0.35, 1.8, true, true, false, animate)
			_show_bottom_rows_only(true)
	if mode != Mode.BOTTOM:
		_show_bottom_rows_only(false)
	## Paper control size stays layout-stable — never scale the sheet node
	_stabilize_paper_scale()
	mode_changed.emit(mode)


func _stabilize_paper_scale() -> void:
	if _paper == null:
		return
	_paper.scale = Vector2.ONE
	var sheet := _paper.get_node_or_null("PaperSheet")
	if sheet is Control:
		(sheet as Control).scale = Vector2.ONE


func _layout(paper_ratio: float, key_ratio: float, show_paper: bool, show_keys: bool, show_chrome: bool, animate: bool) -> void:
	if _paper == null or _keyboard == null:
		return
	_paper.visible = show_paper or mode == Mode.AUTO or mode == Mode.BOTTOM
	_keyboard.visible = show_keys or mode == Mode.AUTO
	if _platen_row:
		_platen_row.visible = show_chrome or mode == Mode.PAPER or mode == Mode.FULL
	if _feed_hint:
		_feed_hint.visible = show_chrome or mode == Mode.PAPER or mode == Mode.FULL
	if animate:
		_tween = _machine.create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_paper, "size_flags_stretch_ratio", paper_ratio, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_keyboard, "size_flags_stretch_ratio", key_ratio, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if show_paper:
			_tween.tween_property(_paper, "modulate:a", 1.0, 0.25)
		elif mode == Mode.KEYS:
			_tween.tween_property(_paper, "modulate:a", 0.15, 0.25)
		if show_keys:
			_tween.tween_property(_keyboard, "modulate:a", 1.0, 0.25)
		elif mode == Mode.PAPER:
			_tween.tween_property(_keyboard, "modulate:a", 0.2, 0.25)
	else:
		_paper.size_flags_stretch_ratio = paper_ratio
		_keyboard.size_flags_stretch_ratio = key_ratio
		_paper.modulate.a = 1.0 if show_paper else 0.15
		_keyboard.modulate.a = 1.0 if show_keys else 0.2
	_stabilize_paper_scale()


func _zoom_keyboard(scale: float, animate: bool) -> void:
	if _keyboard == null:
		return
	_keyboard.pivot_offset = _keyboard.size * 0.5
	if animate:
		var tw := _machine.create_tween()
		tw.tween_property(_keyboard, "scale", Vector2(scale, scale), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_keyboard.scale = Vector2(scale, scale)


func _show_bottom_rows_only(on: bool) -> void:
	if _keyboard == null:
		return
	var rows := _keyboard.get_children()
	# rows: fn, number, Q, A, Z, mid, bot  — keep mid+bot (+ maybe Z) when bottom mode
	for i in rows.size():
		var row := rows[i] as Control
		if row == null:
			continue
		if on:
			row.visible = i >= rows.size() - 3 ## last 3 rows
		else:
			row.visible = true


func peek_paper_from_bottom() -> void:
	## Called when user presses Up in BOTTOM mode
	if mode != Mode.BOTTOM:
		return
	_layout(2.2, 0.6, true, true, true, true)
	await _machine.get_tree().create_timer(1.4).timeout
	if mode == Mode.BOTTOM:
		_layout(0.35, 1.8, true, true, false, true)
		_show_bottom_rows_only(true)


func play_key_cinema(key_btn: Control, letter: String, press_strength: float = 0.85) -> void:
	var strength := clampf(press_strength, 0.15, 1.25)
	if mode != Mode.AUTO or auto_busy or key_btn == null:
		# Still play strike flash in other modes
		_spawn_key_drop(key_btn, strength)
		_spawn_strike(key_btn, letter, mode != Mode.AUTO, strength)
		_spawn_ink_soak(letter, strength)
		return
	auto_busy = true
	# 1) Key drop + shadow, zoom to keys
	_layout(0.25, 2.2, true, true, false, true)
	_focus_key(key_btn)
	_spawn_key_drop(key_btn, strength)
	_spawn_strike(key_btn, letter, false, strength)
	await _machine.get_tree().create_timer(0.22 + strength * 0.08).timeout
	# 2) Zoom to paper — typebar lands, ink soaks by press strength
	_layout(2.5, 0.35, true, true, true, true)
	_zoom_keyboard(1.0, true)
	_spawn_ink_soak(letter, strength)
	await _machine.get_tree().create_timer(0.45 + strength * 0.12).timeout
	# 3) Rest in auto balanced view — paper size unchanged (stretch ratios only)
	_layout(1.0, 1.2, true, true, true, true)
	_stabilize_paper_scale()
	auto_busy = false


func _focus_key(key_btn: Control) -> void:
	if _keyboard == null or key_btn == null:
		return
	_keyboard.pivot_offset = key_btn.get_global_rect().get_center() - _keyboard.global_position
	var tw := _machine.create_tween()
	tw.tween_property(_keyboard, "scale", Vector2(1.35, 1.35), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_key_drop(key_btn: Control, strength: float) -> void:
	if key_btn == null or _strike_layer == null:
		return
	## Drop/shadow under the pressed key
	var shadow := ColorRect.new()
	shadow.color = Color(0.05, 0.04, 0.03, 0.0)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike_layer.add_child(shadow)
	var r := key_btn.get_global_rect()
	var local := r.position - _strike_layer.global_position
	shadow.position = local + Vector2(4, 10)
	shadow.size = r.size * Vector2(0.92, 0.35)
	var depth := lerpf(6.0, 16.0, strength)
	var tw := _machine.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shadow, "modulate:a", lerpf(0.25, 0.55, strength), 0.06)
	tw.tween_property(shadow, "position:y", shadow.position.y + depth * 0.35, 0.08)
	tw.chain().tween_property(shadow, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(shadow.queue_free)
	## Depress the key visually
	key_btn.pivot_offset = key_btn.size * 0.5
	var drop := lerpf(0.94, 0.86, strength)
	var twk := _machine.create_tween()
	twk.tween_property(key_btn, "scale", Vector2(drop, drop * 0.92), 0.05)
	twk.tween_property(key_btn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_strike(key_btn: Control, letter: String, quick: bool, strength: float = 0.85) -> void:
	if _strike_layer == null or letter.is_empty():
		return
	## Without drop-in striker.png, skip flying sprite (scale/shadow still run).
	if _striker_tex == null:
		return
	var start := Vector2.ZERO
	if key_btn:
		var r := key_btn.get_global_rect()
		start = r.get_center() - _strike_layer.global_position
	else:
		start = _strike_layer.size * Vector2(0.5, 0.75)
	var end := start
	if _paper:
		var pr := _paper.get_global_rect()
		end = Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.55) - _strike_layer.global_position
		end.x += randf_range(-40.0, 40.0)

	var striker := TextureRect.new()
	striker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	striker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	striker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	striker.texture = _striker_tex
	striker.custom_minimum_size = Vector2(lerpf(48, 72, strength), lerpf(64, 96, strength))
	striker.size = striker.custom_minimum_size
	striker.pivot_offset = striker.size * 0.5
	striker.modulate = Color(1, 1, 1, 0.95)
	_strike_layer.add_child(striker)
	striker.position = start - striker.size * 0.5
	striker.rotation_degrees = randf_range(-28.0, 28.0)
	striker.scale = Vector2(0.35, 0.35)

	var lab := Label.new()
	lab.text = letter
	lab.add_theme_font_size_override("font_size", int(lerpf(28, 48, strength)) if not quick else 26)
	lab.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06, 1))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike_layer.add_child(lab)
	lab.position = start
	lab.pivot_offset = lab.get_minimum_size() * 0.5
	lab.rotation_degrees = randf_range(-18.0, 18.0)
	lab.scale = Vector2(0.4, 0.4)

	var fly := 0.18 + (0.0 if quick else 0.08) + strength * 0.06
	var tw := _machine.create_tween()
	tw.set_parallel(true)
	tw.tween_property(striker, "position", start + Vector2(0, -80) - striker.size * 0.5, 0.07).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lab, "position", start + Vector2(0, -70), 0.08).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_property(striker, "position", end - striker.size * 0.5, fly).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lab, "position", end, fly).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(striker, "scale", Vector2(1.15, 1.15) * strength, fly * 0.55)
	tw.parallel().tween_property(lab, "scale", Vector2(1.15, 1.15) * lerpf(0.9, 1.2, strength), fly * 0.55)
	tw.parallel().tween_property(striker, "rotation_degrees", 0.0, fly)
	tw.parallel().tween_property(lab, "rotation_degrees", 0.0, fly)
	tw.chain().tween_property(striker, "modulate:a", 0.0, 0.14)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(func() -> void:
		striker.queue_free()
		lab.queue_free()
	)


func _spawn_ink_soak(letter: String, strength: float) -> void:
	if _strike_layer == null or letter.is_empty() or _paper == null:
		return
	var blot := Label.new()
	blot.text = letter
	var sz := int(lerpf(22, 46, strength))
	blot.add_theme_font_size_override("font_size", sz)
	## Stronger press → denser, wider ink soak
	var a0 := lerpf(0.35, 0.85, strength)
	blot.add_theme_color_override("font_color", Color(0.1, 0.08, 0.06, a0))
	blot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike_layer.add_child(blot)
	var pr := _paper.get_global_rect()
	var pos := Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.55) - _strike_layer.global_position
	pos.x += randf_range(-36.0, 36.0)
	blot.position = pos
	blot.pivot_offset = Vector2(sz * 0.35, sz * 0.4)
	blot.scale = Vector2(0.6, 0.6)
	var spread := lerpf(1.05, 1.45, strength)
	var tw := _machine.create_tween()
	tw.set_parallel(true)
	tw.tween_property(blot, "scale", Vector2(spread, spread * 0.92), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(blot, "modulate:a", 1.0, 0.05)
	tw.chain().tween_property(blot, "modulate:a", 0.0, lerpf(0.28, 0.55, strength))
	tw.parallel().tween_property(blot, "scale", Vector2(spread * 1.08, spread), lerpf(0.28, 0.55, strength))
	tw.chain().tween_callback(blot.queue_free)


func mode_name(m: int = -1) -> String:
	if m < 0:
		m = mode
	match m:
		Mode.FULL:
			return "Full"
		Mode.KEYS:
			return "All Keys"
		Mode.PAPER:
			return "Paper"
		Mode.AUTO:
			return "Auto Zoom"
		Mode.BOTTOM:
			return "Bottom Keys"
	return "View"
