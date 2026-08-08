extends Control
## Interactive vintage typewriter: paper feed, platen roller, full key functions.

const SHIFT_MAP := {
	"1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
	"-": "_", "=": "+", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?", "`": "~",
}

const ROWS := [
	["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"],
	["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"],
]

var _haptic: Node
var _assets: Dictionary = {}
var _key_tex: Texture2D
var _key_press_tex: Texture2D
var _space_tex: Texture2D
var _striker_tex: Texture2D
var _paper_tex: Texture2D

var _lines: PackedStringArray = PackedStringArray([""])
var _col: int = 0
var _line: int = 0
var _shift: bool = false
var _shift_lock: bool = false
var _paper_loaded: bool = true
var _paper_release: bool = false
var _tab_stops: Array[int] = [8, 16, 24, 32, 40, 48]
var _margin_override: bool = false
var _bell_rung: bool = false
var _click: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _carriage_x: float = 0.0
var _pending: Dictionary = {}
var _pending_queue: Array = []
var _notes: String = ""

@onready var paper_view: Control = %PaperView
@onready var paper_bg: TextureRect = %PaperBg
@onready var paper_text: RichTextLabel = %PaperText
@onready var platen: Control = %Platen
@onready var platen_knob_l: Button = %PlatenKnobL
@onready var platen_knob_r: Button = %PlatenKnobR
@onready var keyboard: VBoxContainer = %Keyboard
@onready var carriage_label: Label = %CarriagePos
@onready var status: Label = %Status
@onready var feed_hint: Label = %FeedHint
@onready var typebar_fx: ColorRect = %TypebarFx
@onready var ribbon: ColorRect = %Ribbon

var _correct_bar: HBoxContainer
var _correct_label: Label
var _notes_label: Label
var _paper_sheet: Control
var _breath: Node
var _aero: Node
var _sfx: Node
var _feed: RefCounted ## scripts/paper_feed.gd — original line-advance adapter
var _blow_btn: Button
var _aero_hud: Label
var _curve_overlay: Control
var _angle_slider: HSlider
var _curve_toggle: CheckButton
var _blow_mode: OptionButton
var _paper_base_pos: Vector2 = Vector2.ZERO
var _paper_grabbed: bool = false
var _feed_hold_dir: float = 0.0
var _feed_chord_keys: Dictionary = {} ## keycode -> pressed
var _feed_sfx_cooldown: float = 0.0
var _feed_up_btn: Button
var _feed_down_btn: Button
var _feed_pull_btn: Button
var _paper_drag_layer: Control
var _paper_drag_active: bool = false
var _paper_drag_last_global: Vector2 = Vector2.ZERO
var _pull_armed: bool = false ## unused — grab always manual
var _pull_hint_label: Label
var _views: Node
var _view_label: Label
var _key_buttons: Dictionary = {} ## action/caption -> Button


func _ready() -> void:
	_haptic = preload("res://scripts/haptic_spring.gd").new()
	add_child(_haptic)
	_sfx = preload("res://scripts/typewriter_sfx.gd").new()
	add_child(_sfx)
	_breath = preload("res://scripts/breath_mic.gd").new()
	add_child(_breath)
	_aero = preload("res://scripts/paper_aero.gd").new()
	add_child(_aero)
	_feed = preload("res://scripts/paper_feed.gd").new()
	_views = preload("res://scripts/view_director.gd").new()
	add_child(_views)
	_setup_audio()
	_build_correct_bar()
	_build_notes_strip()
	_build_blow_controls()
	_build_deflection_overlay()
	_build_view_bar()
	TwSettings.changed.connect(_apply_settings)
	await _rebuild_assets()
	_build_keyboard()
	_wire_machine_controls()
	_views.setup(self, paper_view, keyboard)
	_apply_settings()
	_refresh_paper()
	status.text = "Views: All Keys · Paper · Auto Zoom · Bottom Keys · Full"
	set_process(true)


func _process(delta: float) -> void:
	if typebar_fx.visible:
		typebar_fx.modulate.a = move_toward(typebar_fx.modulate.a, 0.0, delta * 6.0)
		if typebar_fx.modulate.a <= 0.01:
			typebar_fx.visible = false
	if _feed:
		platen.rotation_degrees = float(_feed.platen_deg)
	_update_held_feed(delta)
	if _feed_sfx_cooldown > 0.0:
		_feed_sfx_cooldown = maxf(0.0, _feed_sfx_cooldown - delta)
	# Mic breath → aero cantilever (clipped at bottom)
	if _aero and _breath:
		_aero.physics_enabled = TwSettings.paper_physics
		_aero.gravity_enabled = TwSettings.paper_gravity
		_aero.clamp_stiff_mul = TwSettings.clamp_stiffness
		_breath.enabled = TwSettings.mic_breath
		_breath.sensitivity = TwSettings.mic_sensitivity
		var off := float(_feed.offset_px) if _feed else 0.0
		_aero.set_exposed_length(0.12 + clampf(off / 500.0, 0.0, 0.08))
		_aero.step(delta, float(_breath.vp), float(_breath.level))
		_apply_paper_deform(delta)
		if _aero_hud:
			_aero_hud.text = str(_aero.debug_text()) + ("  · mic OK" if _breath.mic_ok else "  · hold BLOW")
	## Paper stays put while typing — RichTextLabel scrolls lines; platen only on Return/manual.


func _apply_paper_deform(_delta: float) -> void:
	if _paper_sheet == null:
		return
	## Fixed size always. Feed offset + light aero tug only — no wild scale/scroll.
	var tug := Vector2.ZERO
	var ang := 0.0
	if _aero:
		var tip_px: float = clampf(_aero.tip_pixels(), -28.0, 28.0)
		var g: RefCounted = _aero.grab
		ang = clampf(float(_aero.angle) * 0.25, -0.08, 0.08)
		tug.x = tip_px * 0.15
		if g and bool(g.active):
			tug.x += clampf(float(g.local_defl_m) * 400.0, -18.0, 18.0)
			tug.y += clampf(float(g.force_feed) * 3.0, -10.0, 10.0)
	_paper_sheet.pivot_offset = Vector2(_paper_sheet.size.x * 0.5, _paper_sheet.size.y)
	_paper_sheet.scale = Vector2.ONE
	if _feed:
		_paper_sheet.position = _feed.sheet_position(tug)
	else:
		_paper_sheet.position = tug
	_paper_sheet.rotation = ang
	if paper_bg:
		paper_bg.scale = Vector2.ONE
		paper_bg.position = Vector2.ZERO
	if paper_text:
		paper_text.scale = Vector2.ONE


func _build_blow_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_blow_btn = Button.new()
	_blow_btn.text = "BLOW (or use mic)"
	_blow_btn.custom_minimum_size = Vector2(160, 40)
	_blow_btn.button_down.connect(func() -> void:
		if _breath:
			_breath.blow_impulse(0.95)
		_haptic.call("roller_pulse")
	)
	_blow_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			if _breath:
				_breath.blow_impulse(0.75)
	)
	row.add_child(_blow_btn)
	var ang_lab := Label.new()
	ang_lab.text = "θ"
	ang_lab.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	row.add_child(ang_lab)
	_angle_slider = HSlider.new()
	_angle_slider.min_value = 15.0
	_angle_slider.max_value = 90.0
	_angle_slider.step = 1.0
	_angle_slider.value = 90.0
	_angle_slider.custom_minimum_size = Vector2(120, 28)
	_angle_slider.tooltip_text = "Blow angle vs paper (90° = head-on)"
	_angle_slider.value_changed.connect(func(v: float) -> void:
		if _aero:
			_aero.blow_angle_deg = v
		if _aero_hud and _aero:
			_aero_hud.text = str(_aero.debug_text())
	)
	row.add_child(_angle_slider)
	_blow_mode = OptionButton.new()
	_blow_mode.add_item("Under", 0)
	_blow_mode.add_item("Over", 1)
	_blow_mode.add_item("Parallel", 2)
	_blow_mode.selected = 0
	_blow_mode.tooltip_text = "Under: low P below → push · Over: lift · Parallel: flutter"
	_blow_mode.item_selected.connect(func(idx: int) -> void:
		if _aero:
			_aero.set_blow_mode(idx)
	)
	row.add_child(_blow_mode)
	_curve_toggle = CheckButton.new()
	_curve_toggle.text = "Curve"
	_curve_toggle.button_pressed = false
	_curve_toggle.tooltip_text = "Optional deflection HUD"
	_curve_toggle.toggled.connect(func(on: bool) -> void:
		if _curve_overlay:
			_curve_overlay.visible = on
			_curve_overlay.show_hud = on
	)
	row.add_child(_curve_toggle)
	_aero_hud = Label.new()
	_aero_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aero_hud.add_theme_font_size_override("font_size", 11)
	_aero_hud.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	_aero_hud.text = "Aero idle"
	row.add_child(_aero_hud)
	var body := get_node_or_null("MachineMargin/Chassis/Body")
	if body:
		var feed := body.get_node_or_null("FeedHint")
		if feed:
			body.add_child(row)
			body.move_child(row, feed.get_index() + 1)
		else:
			body.add_child(row)
	else:
		add_child(row)


func _build_deflection_overlay() -> void:
	_curve_overlay = preload("res://scripts/deflection_overlay.gd").new()
	_curve_overlay.name = "DeflectionCurve"
	_curve_overlay.visible = false
	_curve_overlay.show_hud = false
	if paper_view:
		paper_view.add_child(_curve_overlay)
	else:
		add_child(_curve_overlay)
	_curve_overlay.bind_aero(_aero)
	if _aero and _angle_slider:
		_aero.blow_angle_deg = _angle_slider.value


func _build_view_bar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "View"
	title.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42))
	row.add_child(title)
	var names := ["Full", "All Keys", "Paper", "Auto Zoom", "Bottom Keys"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		var mi := i
		b.pressed.connect(func() -> void:
			if _views:
				_views.set_mode(mi)
				if _view_label:
					_view_label.text = "View: %s" % _views.mode_name()
				status.text = _view_status(mi)
		)
		row.add_child(b)
	_view_label = Label.new()
	_view_label.text = "View: Full"
	_view_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_view_label)
	var body := get_node_or_null("MachineMargin/Chassis/Body")
	if body:
		var top := body.get_node_or_null("TopBar")
		if top:
			body.add_child(row)
			body.move_child(row, top.get_index() + 1)
		else:
			body.add_child(row)
	else:
		add_child(row)


func _view_status(mi: int) -> String:
	match mi:
		1:
			return "All Keys — keyboard zoomed; paper dimmed"
		2:
			return "Paper — reading view; keys dimmed"
		3:
			return "Auto Zoom — each key zooms in, letter strikes, then zooms to paper"
		4:
			return "Bottom Keys — press ↑ to peek paper; typed letters animate strikes"
		_:
			return "Full machine view"


func _play_strike_for(action: String, letter: String) -> void:
	if typebar_fx:
		typebar_fx.visible = true
		typebar_fx.modulate.a = 0.7
	if _views == null:
		return
	var btn: Control = null
	if _key_buttons.has(action):
		btn = _key_buttons[action]
	elif _key_buttons.has(letter):
		btn = _key_buttons[letter]
	elif letter.length() == 1 and _key_buttons.has(letter.to_upper()):
		btn = _key_buttons[letter.to_upper()]
	var strength := TwSettings.click_feel if TwSettings else 0.85
	_views.play_key_cinema(btn, letter if not letter.is_empty() else action, strength)


func _build_correct_bar() -> void:
	_correct_bar = HBoxContainer.new()
	_correct_bar.visible = false
	_correct_bar.add_theme_constant_override("separation", 8)
	_correct_label = Label.new()
	_correct_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_correct_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_correct_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	_correct_bar.add_child(_correct_label)
	var fix_btn := Button.new()
	fix_btn.text = "Correct"
	fix_btn.pressed.connect(_accept_pending)
	_correct_bar.add_child(fix_btn)
	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(_skip_pending)
	_correct_bar.add_child(skip_btn)
	var all_btn := Button.new()
	all_btn.text = "Fix all"
	all_btn.pressed.connect(_fix_all_proof)
	_correct_bar.add_child(all_btn)
	# Insert above status if possible
	var body := get_node_or_null("MachineMargin/Chassis/Body")
	if body:
		var status_node := body.get_node_or_null("Status")
		if status_node:
			body.add_child(_correct_bar)
			body.move_child(_correct_bar, status_node.get_index())
		else:
			body.add_child(_correct_bar)
	else:
		add_child(_correct_bar)


func _build_notes_strip() -> void:
	if paper_view == null:
		return
	_paper_sheet = Control.new()
	_paper_sheet.name = "PaperSheet"
	_paper_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_view.add_child(_paper_sheet)
	paper_view.move_child(_paper_sheet, 0)
	# Reparent paper bg + text under sheet so they scroll together with notes
	if paper_bg and paper_bg.get_parent() == paper_view:
		paper_bg.reparent(_paper_sheet)
	if paper_text and paper_text.get_parent() == paper_view:
		paper_text.reparent(_paper_sheet)
	if paper_bg:
		paper_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if paper_text:
		paper_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paper_text.selection_enabled = false
	_notes_label = Label.new()
	_notes_label.name = "Notes"
	_notes_label.text = "Notes · Return feeds · grab to pull by hand"
	_notes_label.add_theme_font_size_override("font_size", 12)
	_notes_label.add_theme_color_override("font_color", Color(0.45, 0.35, 0.28, 0.75))
	_notes_label.position = Vector2(8, 6)
	_notes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_sheet.add_child(_notes_label)
	# Top hit target so mouse click+pull always reaches feed logic
	_paper_drag_layer = Control.new()
	_paper_drag_layer.name = "PaperDragLayer"
	_paper_drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper_drag_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper_drag_layer.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_paper_drag_layer.gui_input.connect(_on_paper_input)
	paper_view.add_child(_paper_drag_layer)
	paper_view.move_child(_paper_drag_layer, paper_view.get_child_count() - 1)
	var tip := Label.new()
	tip.text = "↕ Grab & pull manually · Return auto-feeds"
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2, 0.55))
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tip.offset_top = -22
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_drag_layer.add_child(tip)
	_pull_hint_label = tip


func _arm_pull_after_feed(_message: String = "") -> void:
	## Deprecated — feed is automatic; grab is always manual when you click the sheet.
	_pull_armed = false
	_clear_pull_arm_visual()


func _clear_pull_arm_visual() -> void:
	_pull_armed = false
	if _paper_drag_layer:
		_paper_drag_layer.modulate = Color.WHITE
		_paper_drag_layer.mouse_default_cursor_shape = Control.CURSOR_DRAG
	if _pull_hint_label:
		_pull_hint_label.text = "↕ Grab & pull manually · Return auto-feeds"
		_pull_hint_label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2, 0.55))
	if _feed_pull_btn:
		_feed_pull_btn.set_pressed_no_signal(false)


func _feed_paper(dir: float = 2.5, then_arm_pull: bool = false) -> void:
	## Discrete FEED button — one platen step. Grab stays manual.
	_paper_loaded = true
	_pull_armed = false
	_clear_pull_arm_visual()
	if _feed:
		_feed.paper_loaded = true
		_feed.feed_step(dir)
		_play_feed_sfx()
		_animate_feed_bump(signf(dir))
	status.text = "Paper fed · grab sheet by hand to pull/adjust"


func _animate_feed_bump(dir: float) -> void:
	if _paper_sheet == null or _feed == null:
		return
	var tw := create_tween()
	var y0 := -float(_feed.offset_px)
	var bump := 4.0 if dir >= 0.0 else -4.0
	tw.tween_property(_paper_sheet, "position:y", y0 + bump, 0.06)
	tw.tween_property(_paper_sheet, "position:y", y0, 0.10)


func _target_paper_scroll() -> Vector2:
	## Broken auto-scroll path removed — text scrolls in the label only.
	return Vector2.ZERO


func _rebuild_assets() -> void:
	status.text = "Baking HQ paper/key sprites…"
	await get_tree().process_frame
	var use_dropin := TwSettings.key_sprite_style == "dropin"
	_assets = HQAssets.ensure_assets(TwSettings.hq_assets, use_dropin)
	_key_tex = HQAssets.load_tex(str(_assets.get("key", "")))
	_key_press_tex = HQAssets.load_tex(str(_assets.get("key_pressed", "")))
	_space_tex = HQAssets.load_tex(str(_assets.get("space", "")))
	_striker_tex = HQAssets.load_tex(str(_assets.get("striker", "")))
	if _views:
		_views.set_striker_texture(_striker_tex)
	_load_paper_texture()
	var skin := "drop-in" if use_dropin else "procedural"
	status.text = "HQ %dx paper · %s keys · quiet until audio drop-in" % [
		int(_assets.get("paper_px", 0)),
		skin,
	]


func _load_paper_texture() -> void:
	var override_path := str(_assets.get("paper_override", ""))
	var papers: Dictionary = _assets.get("papers", {})
	## Prefer selected paper TYPE (textured or procedural), then optional paper.png override.
	var typed := str(papers.get(TwSettings.paper_type, ""))
	if not typed.is_empty():
		_paper_tex = HQAssets.load_tex(typed)
	elif not override_path.is_empty():
		_paper_tex = HQAssets.load_tex(override_path)
	else:
		_paper_tex = null
	if paper_bg == null:
		return
	if _paper_tex:
		paper_bg.texture = _paper_tex
	if TwSettings.use_custom_paper_color:
		paper_bg.modulate = TwSettings.paper_color
	elif HQAssets.is_textured_paper(TwSettings.paper_type):
		paper_bg.modulate = Color.WHITE
	else:
		paper_bg.modulate = Color.WHITE


func _apply_settings() -> void:
	if _feed:
		_feed.configure_from_font(TwSettings.font_size, TwSettings.line_height_mul())
	_load_paper_texture()
	if paper_text:
		paper_text.add_theme_font_size_override("normal_font_size", TwSettings.font_size)
		paper_text.add_theme_font_size_override("bold_font_size", TwSettings.font_size)
		paper_text.add_theme_font_size_override("italics_font_size", TwSettings.font_size)
		paper_text.add_theme_color_override("default_color", TwSettings.font_color)
		paper_text.add_theme_constant_override("line_separation", int(8 * TwSettings.line_height_mul()))
	if _sfx:
		_sfx.set_enabled(TwSettings.sound_enabled)
		_sfx.erase_enabled = TwSettings.erase_sound_enabled
		_sfx.surround_max = TwSettings.surround_max
		_sfx.reverb_amount = TwSettings.reverb_amount
		_sfx.mic_reverb_monitor = TwSettings.mic_reverb_monitor
		_sfx.ambient_enabled = TwSettings.ambient_room
		_sfx.ambient_volume_db = lerpf(-40.0, -18.0, TwSettings.ambient_volume)
		_sfx.click_volume_db = lerpf(-18.0, -1.0, TwSettings.sound_volume) + lerpf(-2.0, 1.0, TwSettings.click_feel - 0.85)
		if _sfx.has_method("reload_streams"):
			_sfx.reload_streams(TwSettings.use_asset_sounds)
		_sfx.apply_mix()
	if _haptic:
		_haptic.intensity = TwSettings.click_feel
	_refresh_paper()
	_build_keyboard()


func _setup_audio() -> void:
	_click = AudioStreamPlayer.new()
	_click.volume_db = -80.0
	add_child(_click)
	_bell = AudioStreamPlayer.new()
	_bell.volume_db = -80.0
	add_child(_bell)


func _wire_machine_controls() -> void:
	platen_knob_l.button_down.connect(func() -> void: _roll_platen(-1.2, true))
	platen_knob_r.button_down.connect(func() -> void: _roll_platen(1.2, true))
	platen_knob_l.button_down.connect(func() -> void: _feed_hold_dir = -1.0)
	platen_knob_l.button_up.connect(func() -> void: _clear_feed_hold_if(-1.0))
	platen_knob_r.button_down.connect(func() -> void: _feed_hold_dir = 1.0)
	platen_knob_r.button_up.connect(func() -> void: _clear_feed_hold_if(1.0))
	if paper_view:
		paper_view.mouse_filter = Control.MOUSE_FILTER_STOP
		if not paper_view.gui_input.is_connected(_on_paper_input):
			paper_view.gui_input.connect(_on_paper_input)
	if platen:
		platen.mouse_filter = Control.MOUSE_FILTER_STOP
		if not platen.gui_input.is_connected(_on_paper_input):
			platen.gui_input.connect(_on_paper_input)
	_build_feed_buttons()
	if feed_hint:
		feed_hint.text = "Return = one line · grab paper to pull · FEED↑/↓ · knobs"


func _on_paper_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_paper_drag(mb.global_position)
				accept_event()
			else:
				_end_paper_drag()
				accept_event()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_paper_drag(st.position)
		else:
			_end_paper_drag()
		accept_event()
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_paper_drag_active = true
		_paper_grabbed = true
		_apply_grab_drag(d.relative)
		accept_event()
		return
	if event is InputEventMouseMotion and _paper_drag_active:
		var mm := event as InputEventMouseMotion
		_apply_grab_drag(mm.relative)
		accept_event()


func _paper_local_grab_coords(global_pos: Vector2) -> Vector2:
	## Returns (ξ along length 0=clamp..1=tip, η across −1..+1).
	var target: Control = _paper_sheet if _paper_sheet else paper_view
	if target == null:
		return Vector2(0.7, 0.0)
	var local := target.get_global_transform_with_canvas().affine_inverse() * global_pos
	var sz := target.size
	if sz.x < 1.0 or sz.y < 1.0:
		return Vector2(0.7, 0.0)
	var eta := clampf((local.x / sz.x) * 2.0 - 1.0, -1.0, 1.0)
	## y=0 top (free tip) → ξ=1; y=max bottom (platen) → ξ=0
	var xi := clampf(1.0 - (local.y / sz.y), 0.02, 1.0)
	return Vector2(xi, eta)


func _apply_grab_drag(rel: Vector2) -> void:
	## Manual grab only — roll platen by hand; never rescale the sheet.
	if _feed:
		var roll_y := rel.y
		if _aero:
			roll_y = _aero.apply_grab_drag(rel, false)
		_feed.grab_roll(roll_y)
		if absf(roll_y) > 2.5:
			_play_feed_sfx()
		_apply_paper_deform(0.0)
		return
	_roll_platen(rel.y * 0.14, absf(rel.y) > 2.0)


func _begin_paper_drag(global_pos: Vector2) -> void:
	_paper_drag_active = true
	_paper_grabbed = true
	_paper_loaded = true
	if _feed:
		_feed.paper_loaded = true
	_paper_drag_last_global = global_pos
	_pull_armed = false
	_clear_pull_arm_visual()
	var coords := _paper_local_grab_coords(global_pos)
	if _aero:
		_aero.begin_grab(coords.x, coords.y)
	var where := "tip" if coords.x > 0.65 else ("mid" if coords.x > 0.35 else "near platen")
	status.text = "Manual grab (%s) — drag to pull/adjust paper" % where
	if feed_hint:
		feed_hint.text = "Manual pull · release to stop · Return advances one line"
	_haptic.call("roller_pulse")


func _end_paper_drag() -> void:
	_paper_drag_active = false
	_paper_grabbed = false
	if _aero:
		_aero.end_grab()
	if _feed_pull_btn:
		_feed_pull_btn.set_pressed_no_signal(false)
	status.text = "Paper released"
	if feed_hint:
		feed_hint.text = "Return = one line · grab paper to pull · FEED↑/↓"


func _input(event: InputEvent) -> void:
	# Track shift chords early
	if event is InputEventKey:
		_track_feed_chord(event as InputEventKey)
	# Continue mouse pull even if cursor leaves the paper control
	if _paper_drag_active:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_end_paper_drag()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			var delta := mm.global_position - _paper_drag_last_global
			_paper_drag_last_global = mm.global_position
			if delta.length() > 0.01:
				_apply_grab_drag(delta)


func _build_feed_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_feed_up_btn = Button.new()
	_feed_up_btn.text = "FEED ↑"
	_feed_up_btn.tooltip_text = "Roll paper back (manual)"
	_feed_up_btn.button_down.connect(func() -> void:
		_feed_hold_dir = -1.0
		_feed_paper(-1.5, false)
	)
	_feed_up_btn.button_up.connect(func() -> void: _clear_feed_hold_if(-1.0))
	row.add_child(_feed_up_btn)
	_feed_down_btn = Button.new()
	_feed_down_btn.text = "FEED ↓"
	_feed_down_btn.tooltip_text = "Advance paper (same as Return feed)"
	_feed_down_btn.button_down.connect(func() -> void:
		_feed_hold_dir = 1.0
		_feed_paper(1.8, false)
	)
	_feed_down_btn.button_up.connect(func() -> void: _clear_feed_hold_if(1.0))
	row.add_child(_feed_down_btn)
	_feed_pull_btn = Button.new()
	_feed_pull_btn.text = "GRAB HINT"
	_feed_pull_btn.tooltip_text = "Reminder: click the paper and drag to pull by hand"
	_feed_pull_btn.toggle_mode = false
	_feed_pull_btn.pressed.connect(func() -> void:
		status.text = "Click the paper, hold, and drag — manual pull like a real typewriter"
		if feed_hint:
			feed_hint.text = "Manual grab on the sheet · Return still auto-feeds lines"
	)
	row.add_child(_feed_pull_btn)
	var body := get_node_or_null("MachineMargin/Chassis/Body")
	if body:
		var prow := body.get_node_or_null("PlatenRow")
		if prow:
			body.add_child(row)
			body.move_child(row, prow.get_index() + 1)
		else:
			body.add_child(row)
	else:
		add_child(row)


func _clear_feed_hold_if(dir: float) -> void:
	if is_equal_approx(_feed_hold_dir, dir):
		_feed_hold_dir = 0.0


func _update_held_feed(delta: float) -> void:
	var dir := _feed_hold_dir
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_KP_2):
		dir = 1.0
	elif Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_KP_8):
		dir = -1.0
	if _chord_active():
		dir = 1.0
	if absf(dir) > 0.001:
		if _feed:
			_feed.feed_hold(dir, delta)
			_play_feed_sfx()
			_apply_paper_deform(0.0)
		else:
			_roll_platen(dir * delta * 14.0, false)


func _roll_platen(dir: float, play_sound: bool = true) -> void:
	## Legacy entry — routes through paper_feed (no wild sheet scroll).
	if absf(dir) < 0.0001:
		return
	_paper_loaded = true
	if _feed:
		_feed.paper_loaded = true
		_feed.feed_step(dir)
		_apply_paper_deform(0.0)
	if play_sound or _feed_sfx_cooldown <= 0.0:
		_play_feed_sfx()
	var off := float(_feed.offset_px) if _feed else 0.0
	status.text = "Platen %s · offset %.0f" % ["↑" if dir < 0 else "↓", off]
	_update_notes()


func _play_feed_sfx() -> void:
	if _feed_sfx_cooldown > 0.0:
		return
	_haptic.call("roller_pulse")
	if _sfx and TwSettings.sound_enabled:
		_sfx.play_platen()
	_feed_sfx_cooldown = 0.07


func _build_keyboard() -> void:
	if keyboard == null:
		return
	_key_buttons.clear()
	for c in keyboard.get_children():
		c.queue_free()
	# Function row
	var fn := _row()
	keyboard.add_child(fn)
	fn.add_child(_key("TAB", "TAB", Vector2(72, 56)))
	fn.add_child(_key("TAB SET", "TABSET", Vector2(78, 56)))
	fn.add_child(_key("TAB CLR", "TABCLR", Vector2(78, 56)))
	fn.add_child(_key("MARG REL", "MARGREL", Vector2(88, 56)))
	fn.add_child(_key("PAPER REL", "PAPERREL", Vector2(92, 56)))
	fn.add_child(_key("FEED ↑", "FEEDUP", Vector2(72, 56)))
	fn.add_child(_key("FEED ↓", "FEEDDOWN", Vector2(78, 56)))
	fn.add_child(_key("PROOF", "PROOF", Vector2(72, 56)))
	fn.add_child(_key("FIX ALL", "FIXALL", Vector2(78, 56)))
	for row in ROWS:
		var h := _row()
		keyboard.add_child(h)
		for label in row:
			h.add_child(_key(label, label, Vector2(52, 58)))
	var mid := _row()
	keyboard.add_child(mid)
	mid.add_child(_key("SHIFT", "SHIFT_L", Vector2(96, 58)))
	mid.add_child(_key("LOCK", "SHIFTLOCK", Vector2(72, 58)))
	mid.add_child(_key("SPACE", " ", Vector2(280, 58), true))
	mid.add_child(_key("BKSP", "BACK", Vector2(72, 58)))
	mid.add_child(_key("SHIFT", "SHIFT_R", Vector2(96, 58)))
	var bot := _row()
	keyboard.add_child(bot)
	bot.add_child(_key("RETURN ⏎", "RETURN", Vector2(140, 60)))
	bot.add_child(_key("LINE SPACE", "LINESPACE", Vector2(110, 60)))
	bot.add_child(_key("CLEAR PAGE", "CLEAR", Vector2(110, 60)))
	if _views and _views.mode == _views.Mode.BOTTOM:
		_views.apply_mode(_views.Mode.BOTTOM, false)


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	return h


func _key(caption: String, action: String, min_size: Vector2, is_space: bool = false) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13 if caption.length() > 2 else 18)
	## Underwood cream keys → dark serif-style lettering on ivory
	b.add_theme_color_override("font_color", Color(0.14, 0.12, 0.10))
	b.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0.18, 0.14, 0.10))
	var sb := StyleBoxTexture.new()
	sb.texture = _space_tex if is_space and _space_tex else _key_tex
	if sb.texture:
		sb.texture_margin_left = 12
		sb.texture_margin_top = 12
		sb.texture_margin_right = 12
		sb.texture_margin_bottom = 12
	else:
		## Cream face + chrome rim fallback
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.90, 0.86, 0.76)
		flat.set_corner_radius_all(26 if not is_space else 12)
		flat.set_border_width_all(2)
		flat.border_color = Color(0.68, 0.66, 0.58)
		flat.shadow_color = Color(0, 0, 0, 0.35)
		flat.shadow_size = 3
		flat.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		var press := flat.duplicate()
		press.bg_color = Color(0.82, 0.78, 0.68)
		press.shadow_size = 1
		press.shadow_offset = Vector2(0, 1)
		b.add_theme_stylebox_override("pressed", press)
		b.button_down.connect(func() -> void: _on_action(action, b))
		_key_buttons[action] = b
		_key_buttons[caption] = b
		return b
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sbp := StyleBoxTexture.new()
	sbp.texture = _key_press_tex if _key_press_tex else sb.texture
	sbp.texture_margin_left = 12
	sbp.texture_margin_top = 12
	sbp.texture_margin_right = 12
	sbp.texture_margin_bottom = 12
	b.add_theme_stylebox_override("pressed", sbp)
	b.button_down.connect(func() -> void: _on_action(action, b))
	_key_buttons[action] = b
	_key_buttons[caption] = b
	return b


func _on_action(action: String, btn: Button = null) -> void:
	if btn and TwSettings.key_fx_enabled:
		_bounce(btn)
	_flash_typebar()
	match action:
		"SHIFT_L", "SHIFT_R":
			if _shift_lock:
				_shift_lock = false
				_shift = false
			else:
				_shift = not _shift
			_haptic.call("spring_pulse")
			_click_sound()
			status.text = "Shift lock OFF" if not _shift_lock else "Shift"
			if _shift:
				status.text = "SHIFT held (next char)"
		"SHIFTLOCK":
			_shift_lock = not _shift_lock
			_shift = _shift_lock
			_haptic.call("spring_pulse")
			_click_sound()
			status.text = "SHIFT LOCK ON" if _shift_lock else "Shift lock off"
		"TAB":
			_do_tab()
		"TABSET":
			if not _tab_stops.has(_col):
				_tab_stops.append(_col)
				_tab_stops.sort()
			status.text = "Tab set at %d" % _col
			_haptic.call("spring_pulse")
			_click_sound()
		"TABCLR":
			_tab_stops.erase(_col)
			status.text = "Tab cleared at %d" % _col
			_haptic.call("spring_pulse")
			_click_sound()
		"MARGREL":
			_margin_override = true
			_bell_rung = false
			status.text = "Margin release"
			_haptic.call("spring_pulse")
			_click_sound()
		"PAPERREL":
			_paper_release = not _paper_release
			status.text = "Paper release %s — straighten sheet" % ("ON" if _paper_release else "OFF")
			_haptic.call("roller_pulse")
			_click_sound()
		"FEED":
			_feed_paper(2.5, true)
		"FEEDUP":
			_feed_paper(-2.0, true)
		"FEEDDOWN":
			_feed_paper(2.5, true)
		"PROOF":
			_run_proof_scan()
		"FIXALL":
			_fix_all_proof()
		"RETURN":
			_maybe_check_word()
			_carriage_return()
		"LINESPACE":
			_advance_line(1)
			_haptic.call("carriage_pulse")
			_click_sound()
			status.text = "Line space"
		"BACK":
			_backspace()
		"CLEAR":
			_lines = PackedStringArray([""])
			_line = 0
			_col = 0
			_notes = ""
			_refresh_paper()
			_haptic.call("carriage_pulse")
			status.text = "Page cleared"
		" ":
			_type_char(" ")
		_:
			_type_char(_resolve_char(action))


func _resolve_char(action: String) -> String:
	var upper := _shift or _shift_lock
	if action.length() == 1:
		if upper and SHIFT_MAP.has(action):
			return str(SHIFT_MAP[action])
		if action.to_upper() != action.to_lower():
			return action.to_upper() if upper else action.to_lower()
		return action
	return ""


func _type_char(ch: String) -> void:
	if ch.is_empty():
		return
	if not _paper_loaded:
		status.text = "Load paper — use FEED or turn platen"
		_haptic.call("bell_pulse")
		return
	if _col >= TwSettings.margin_right and not _margin_override:
		status.text = "Line lock — Margin Release to continue"
		_haptic.call("bell_pulse")
		_play_bell()
		return
	if _col >= TwSettings.margin_right - 7 and not _bell_rung:
		_bell_rung = true
		_play_bell()
		_haptic.call("bell_pulse")
		status.text = "Bell — near right margin"
	_ensure_line()
	var s := _lines[_line]
	if _col > s.length():
		s += " ".repeat(_col - s.length())
	if _col == s.length():
		s += ch
	else:
		s = s.substr(0, _col) + ch + s.substr(_col + 1)
	_lines[_line] = s
	_col += 1
	_margin_override = false
	if _shift and not _shift_lock:
		_shift = false
	_click_sound(ch)
	_play_strike_for(ch.to_upper() if ch.length() == 1 else ch, ch)
	_refresh_paper()
	_update_carriage()
	_update_notes()
	if ch == " " or (ch.length() == 1 and ",.;:!?".contains(ch)):
		_maybe_check_word()
		if ",.;:!?".contains(ch):
			_maybe_literary_line()


func _maybe_check_word() -> void:
	if not TwSettings.spell_check_enabled:
		return
	_ensure_line()
	var hit := ProofReader.scan_last_word(_lines[_line], _col)
	if not hit.get("ok", false):
		return
	hit["line"] = _line
	if TwSettings.offer_corrections:
		_queue_issue(hit)
	else:
		_lines = ProofReader.apply_issue(_lines, hit)
		_col = int(hit.get("start", _col)) + str(hit.get("suggestion", "")).length()
		_refresh_paper()
		status.text = "Auto-corrected %s → %s" % [hit.get("word", ""), hit.get("suggestion", "")]


func _maybe_literary_line() -> void:
	if not TwSettings.literary_check_enabled:
		return
	_ensure_line()
	var raw: String = _lines[_line]
	var fixed := ProofReader.apply_literary_line(raw)
	if fixed == raw:
		return
	var issue := {
		"ok": true,
		"kind": "literary",
		"word": raw.substr(0, mini(28, raw.length())),
		"suggestion": fixed,
		"line": _line,
		"start": 0,
		"end": raw.length(),
		"label": "comma / literature",
	}
	if TwSettings.auto_fix_literary or not TwSettings.offer_corrections:
		_lines[_line] = fixed
		_col = mini(_col, fixed.length())
		_refresh_paper()
		status.text = "Literature polish applied"
	else:
		_queue_issue(issue)


func _run_proof_scan() -> void:
	var issues := ProofReader.scan_document(_lines, TwSettings.spell_check_enabled, TwSettings.literary_check_enabled)
	if issues.is_empty():
		_hide_correct_bar()
		status.text = "No spelling or literature issues found"
		_haptic.call("spring_pulse")
		return
	_pending_queue = issues
	_show_next_pending()
	status.text = "%d correction(s) ready — Correct / Skip / Fix all" % issues.size()
	_haptic.call("bell_pulse")


func _queue_issue(issue: Dictionary) -> void:
	_pending_queue.append(issue)
	if _pending.is_empty() or not bool(_pending.get("ok", false)):
		_show_next_pending()


func _show_next_pending() -> void:
	while not _pending_queue.is_empty():
		var issue: Dictionary = _pending_queue.pop_front()
		if bool(issue.get("ok", false)):
			_pending = issue
			_show_correct_bar(issue)
			return
	_pending = {}
	_hide_correct_bar()


func _show_correct_bar(issue: Dictionary) -> void:
	if _correct_bar == null:
		return
	_correct_bar.visible = true
	var kind := str(issue.get("kind", "spell"))
	var label := str(issue.get("label", kind))
	_correct_label.text = "%s: “%s” → “%s”" % [label.capitalize(), str(issue.get("word", "")), str(issue.get("suggestion", ""))]


func _hide_correct_bar() -> void:
	if _correct_bar:
		_correct_bar.visible = false
	_pending = {}


func _accept_pending() -> void:
	if not _pending.get("ok", false):
		_show_next_pending()
		return
	var li := int(_pending.get("line", _line))
	var start := int(_pending.get("start", 0))
	var sug := str(_pending.get("suggestion", ""))
	_lines = ProofReader.apply_issue(_lines, _pending)
	if li == _line:
		_col = start + sug.length()
	_refresh_paper()
	_haptic.call("spring_pulse")
	_click_sound()
	status.text = "Corrected"
	_pending = {}
	_show_next_pending()


func _skip_pending() -> void:
	_haptic.call("spring_pulse")
	status.text = "Skipped correction"
	_pending = {}
	_show_next_pending()


func _fix_all_proof() -> void:
	_lines = ProofReader.apply_all(_lines, TwSettings.spell_check_enabled, TwSettings.literary_check_enabled)
	_ensure_line()
	_col = mini(_col, _lines[_line].length())
	_pending_queue.clear()
	_hide_correct_bar()
	_refresh_paper()
	_haptic.call("carriage_pulse")
	_click_sound()
	status.text = "All spelling + literature fixes applied"


func _update_notes() -> void:
	_notes = "Notes · L%d · %d lines · %d chars" % [_line + 1, _lines.size(), _full_text().length()]
	if _notes_label:
		_notes_label.text = _notes


func _full_text() -> String:
	return "\n".join(_lines)


func _do_tab() -> void:
	var next := TwSettings.margin_right
	for t in _tab_stops:
		if t > _col:
			next = t
			break
	_col = mini(next, TwSettings.margin_right)
	_haptic.call("spring_pulse")
	_click_sound()
	_refresh_paper()
	_update_carriage()
	status.text = "Tab → col %d" % _col


func _backspace() -> void:
	if _col > 0:
		_col -= 1
		_ensure_line()
		var s := _lines[_line]
		if _col < s.length():
			_lines[_line] = s.substr(0, _col) + s.substr(_col + 1)
	_haptic.call("spring_pulse")
	if _sfx and TwSettings.sound_enabled and TwSettings.erase_sound_enabled:
		_sfx.play_erase()
	_refresh_paper()
	_update_carriage()


func _carriage_return() -> void:
	_advance_line(1)
	_col = TwSettings.margin_left
	_bell_rung = false
	_margin_override = false
	_haptic.call("carriage_pulse")
	if _sfx and TwSettings.sound_enabled:
		_sfx.play_return()
	_animate_carriage_home()
	## Real typewriter: return advances one line via paper_feed (not whole-sheet scroll)
	_animate_feed_bump(1.0)
	status.text = "Carriage return — one line advanced"
	_refresh_paper()


func _advance_line(n: int) -> void:
	_line += n
	while _lines.size() <= _line:
		_lines.append("")
	## Automatic vertical feed with each new line — one line-step only
	if _feed:
		_feed.configure_from_font(TwSettings.font_size, TwSettings.line_height_mul())
		_feed.advance_line(n, TwSettings.line_height_mul())
		_play_feed_sfx()
		_apply_paper_deform(0.0)
	else:
		_roll_platen(float(n) * 1.35, true)


func _ensure_line() -> void:
	while _lines.size() <= _line:
		_lines.append("")


func _refresh_paper() -> void:
	_ensure_line()
	var parts: PackedStringArray = PackedStringArray()
	var open := ""
	var close := ""
	match TwSettings.font_style:
		"bold":
			open = "[b]"; close = "[/b]"
		"italic":
			open = "[i]"; close = "[/i]"
	for i in _lines.size():
		var line := _lines[i]
		if i == _line:
			while line.length() < _col:
				line += " "
			line = line.substr(0, _col) + "▮" + line.substr(_col)
		parts.append(open + line.replace("[", "[lb]") + close)
	paper_text.text = "\n".join(parts)
	_update_carriage()
	_update_notes()
	if paper_text:
		paper_text.scroll_to_line(_line)


func _update_carriage() -> void:
	carriage_label.text = "L%d  C%d  |  margins %d–%d" % [_line + 1, _col + 1, TwSettings.margin_left, TwSettings.margin_right]
	_carriage_x = float(_col) * 7.0
	ribbon.position.x = 40.0 + fmod(_carriage_x, 120.0)


func _animate_carriage_home() -> void:
	var tw := create_tween()
	tw.tween_property(ribbon, "position:x", 40.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bounce(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn.scale = Vector2(0.9, 0.84)
	tw.tween_property(btn, "scale", Vector2(1.05, 1.08), 0.06)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.14)


func _flash_typebar() -> void:
	if not TwSettings.key_fx_enabled:
		return
	typebar_fx.visible = true
	typebar_fx.modulate.a = 0.55


func _click_sound(ch: String = "") -> void:
	if _sfx and TwSettings.sound_enabled:
		var bias := 0.0
		if not ch.is_empty():
			bias = float(ch.unicode_at(0) % 24) / 24.0
		_sfx.play_key(bias)
	if _haptic:
		_haptic.call("click_pulse")


func _play_bell() -> void:
	if _sfx and TwSettings.sound_enabled:
		_sfx.play_bell()


func _chord_active() -> bool:
	if bool(_feed_chord_keys.get("lshift", false)) and bool(_feed_chord_keys.get("rshift", false)):
		return true
	if bool(_feed_chord_keys.get(KEY_1, false)) and (bool(_feed_chord_keys.get(KEY_EQUAL, false)) or bool(_feed_chord_keys.get(KEY_KP_ADD, false))):
		return true
	if bool(_feed_chord_keys.get(KEY_Z, false)) and bool(_feed_chord_keys.get(KEY_SLASH, false)):
		return true
	return false


func _track_feed_chord(ke: InputEventKey) -> void:
	var pressed := ke.pressed
	if ke.keycode == KEY_SHIFT or ke.physical_keycode == KEY_SHIFT:
		if ke.location == KEY_LOCATION_RIGHT:
			_feed_chord_keys["rshift"] = pressed
		else:
			# LEFT or UNSPECIFIED — treat as left; if both unspecified rapidly, also set r on second
			if ke.location == KEY_LOCATION_LEFT or not bool(_feed_chord_keys.get("lshift", false)):
				_feed_chord_keys["lshift"] = pressed
			else:
				_feed_chord_keys["rshift"] = pressed
		if not pressed:
			# Clear both if no shift remains
			if not Input.is_key_pressed(KEY_SHIFT):
				_feed_chord_keys["lshift"] = false
				_feed_chord_keys["rshift"] = false
		return
	for code in [KEY_1, KEY_EQUAL, KEY_KP_ADD, KEY_Z, KEY_SLASH, KEY_MINUS]:
		if ke.keycode == code or ke.physical_keycode == code:
			_feed_chord_keys[code] = pressed


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		_track_feed_chord(ke)
		# Hold arrows / Page keys handled in _update_held_feed; tap still nudges
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_DOWN or ke.keycode == KEY_KP_2 or ke.keycode == KEY_PAGEDOWN:
				_paper_loaded = true
				_roll_platen(1.8, true)
				return
			if ke.keycode == KEY_UP or ke.keycode == KEY_KP_8 or ke.keycode == KEY_PAGEUP:
				if _views and _views.mode == _views.Mode.BOTTOM:
					_views.peek_paper_from_bottom()
					status.text = "Peeking paper from bottom-keys view"
					return
				_roll_platen(-1.8, true)
				return
			if ke.keycode == KEY_F1:
				if _views:
					_views.cycle_mode()
					if _view_label:
						_view_label.text = "View: %s" % _views.mode_name()
					status.text = _view_status(_views.mode)
				return
			# Single-key feed shortcuts (when not typing letters into paper)
			if ke.keycode == KEY_EQUAL or ke.keycode == KEY_KP_ADD:
				if ke.ctrl_pressed or ke.alt_pressed or bool(_feed_chord_keys.get(KEY_1, false)):
					_paper_loaded = true
					_roll_platen(2.0, true)
					return
			if ke.keycode == KEY_1 and (ke.ctrl_pressed or ke.alt_pressed or bool(_feed_chord_keys.get(KEY_EQUAL, false))):
				_roll_platen(-2.0, true)
				return
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_BACKSPACE:
				_on_action("BACK")
			elif ke.keycode == KEY_ENTER:
				_on_action("RETURN")
			elif ke.keycode == KEY_TAB:
				_on_action("TAB")
			elif ke.keycode == KEY_SPACE:
				_on_action(" ")
			elif ke.unicode > 31:
				# Don't type chord partners while both held for feed
				if _chord_active():
					return
				_type_char(char(ke.unicode))
