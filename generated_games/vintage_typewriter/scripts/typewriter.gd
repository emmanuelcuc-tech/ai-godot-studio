extends Control
## Royal Quiet De Luxe from three refs: full_machine, keys_closeup, striker.
## Invisible key hotspots; press shrinks a photo crop. Paper width = top rail.

enum ViewMode { FOLLOW, FULL, ALL_PAPER, KEYS, BOTTOM_CLOSE, TOP_PAPER }

const COLS := 42
const MARGIN_BELL_COL := 35
const PAPER_MARGIN := Vector2(16, 18)
const SAMPLE_DRAFT := "The quick brown fox jumps over the lazy dog.\n1948 Royal Quiet De Luxe.\nStart Typing uses this draft."
const PATH_FULL := "res://assets/images/full_machine.png"
const PATH_KEYS := "res://assets/images/keys_closeup.png"
const PATH_STRIKER := "res://assets/images/striker.png"
const RoyalKeyScript := preload("res://scripts/royal_key.gd")
const TypebarBasketScript := preload("res://scripts/typebar_basket.gd")
const TwSettingsScript := preload("res://scripts/tw_settings.gd")
const PhotoLayoutScript := preload("res://scripts/photo_key_layout.gd")

var settings = TwSettingsScript.new()

var _view: ViewMode = ViewMode.FULL
var _view_before_strike: ViewMode = ViewMode.FULL
var _strike_cinema_active := false
var _shift_on := false
var _typing_active := false
var _typing_paused := false
var _auto_queue := ""
var _auto_index := 0
var _auto_timer := 0.0
var _lines: PackedStringArray = PackedStringArray([""])
var _row := 0
var _col := 0
var _strike_punch := 0.0
var _bell_armed := true
var _key_map: Dictionary = {}
var _typebars: Control
var _paper_base_pos := Vector2.ZERO
var _paper_feed_offset := 0.0
var _paper_dragging := false
var _paper_drag_last_y := 0.0
var _caret_blink := 0.0
var _paper_font: Font
var _keys_tex: Texture2D
var _full_tex: Texture2D

@onready var status_label: Label = %StatusLabel
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value: Label = %SpeedValue
@onready var draft_edit: TextEdit = %DraftEdit
@onready var paper_label: Label = %PaperLabel
@onready var paper_texture: TextureRect = %PaperTexture
@onready var paper_placeholder: Label = %PaperPlaceholder
@onready var paper_surface: Control = %PaperSurface
@onready var ink_layer: Control = %InkLayer
@onready var strike_hammer: ColorRect = %StrikeHammer
@onready var machine: Control = %Machine
@onready var paper_panel: Control = %PaperPanel
@onready var keyboard_panel: Control = %KeyboardPanel
@onready var royal_photo: TextureRect = %RoyalPhoto
@onready var pause_btn: Button = %PauseBtn
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var ink_picker: ColorPickerButton = %InkColorPicker
@onready var font_picker: ColorPickerButton = %FontColorPicker
@onready var font_size_spin: SpinBox = %FontSizeSpin
@onready var font_style_opt: OptionButton = %FontStyleOpt
@onready var pack_opt: OptionButton = %SoundPackOpt
@onready var sfx: Node = %TypewriterSfx
@onready var caret_label: Label = %CaretLabel


func _ready() -> void:
	settings.load_cfg()
	if str(settings.sound_pack).begins_with("freesound"):
		settings.sound_pack = "buckling"
	sfx.set("pack_name", settings.sound_pack)
	sfx.call("load_pack", settings.sound_pack)
	_setup_paper_font()
	_load_royal_photo()
	_apply_paper_texture()
	_layout_photo_slots()
	_paper_base_pos = paper_panel.position
	_wire_paper_drag()
	_ensure_typebars()
	await _build_keyboard()
	_wire_controls()
	_sync_settings_ui()
	_apply_font_settings()
	if draft_edit.text.strip_edges().is_empty():
		draft_edit.text = SAMPLE_DRAFT
	_set_view(ViewMode.FULL, false)
	_refresh_paper_text()
	_update_paper_motion(false)
	_set_status("Stopped · type or Start Typing")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if machine == null or not is_node_ready():
			return
		_layout_photo_slots()
		_paper_base_pos = paper_panel.position
		_reposition_keys()
		_update_carriage_slide(false)


func _process(delta: float) -> void:
	_caret_blink += delta
	if caret_label:
		caret_label.visible = fmod(_caret_blink, 1.0) < 0.55
		caret_label.position = paper_label.position + Vector2(float(_col) * _char_width() - 1.0, float(_row) * _line_height())
	if _strike_punch > 0.0:
		_strike_punch = maxf(0.0, _strike_punch - delta * 5.0)
		strike_hammer.modulate.a = _strike_punch
		var hpos := _caret_local_pos()
		strike_hammer.position = Vector2(hpos.x - 6.0, hpos.y - 14.0 + lerpf(0.0, 6.0, _strike_punch))
	if _view == ViewMode.FOLLOW and not _strike_cinema_active:
		_apply_follow_camera(delta)
	if not _typing_active or _typing_paused:
		return
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	if _auto_index >= _auto_queue.length():
		_end_typing()
		return
	var ch := _auto_queue[_auto_index]
	_auto_index += 1
	_type_char(ch)
	_auto_timer = _speed_delay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and settings_panel.visible:
		settings_panel.visible = false
		accept_event()
		return
	if settings_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_BACKSPACE:
			_backspace()
			accept_event()
			return
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_type_char("\n")
			accept_event()
			return
		if key.keycode == KEY_TAB:
			_type_char("\t")
			accept_event()
			return
		var typed := String.chr(key.unicode) if key.unicode > 0 else ""
		if typed != "" and typed != "\t":
			_type_char(typed)
			accept_event()


func _speed_delay() -> float:
	return maxf(0.03, 0.5 / float(maxi(1, settings.typing_speed)))


func _setup_paper_font() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Courier New", "Consolas", "Courier", "Lucida Console", "monospace"])
	sf.multichannel_signed_distance_field = false
	_paper_font = sf
	paper_label.add_theme_font_override("font", _paper_font)
	if caret_label:
		caret_label.add_theme_font_override("font", _paper_font)
		caret_label.text = "▌"
		caret_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _load_royal_photo() -> void:
	_full_tex = _load_tex(PATH_FULL)
	if _full_tex == null:
		_full_tex = _load_tex("res://assets/images/royal_machine.png")
	_keys_tex = _load_tex(PATH_KEYS)
	if _full_tex:
		royal_photo.texture = _full_tex
		royal_photo.visible = true


func _layout_photo_slots() -> void:
	var ms := machine.size
	if ms.x < 10.0:
		ms = Vector2(720, 720)
	# Paper width = Quiet De Luxe / platen top rail; tall for feed.
	var paper_uv: Rect2 = PhotoLayoutScript.paper_uv()
	paper_panel.position = Vector2(paper_uv.position.x * ms.x, paper_uv.position.y * ms.y + _paper_feed_offset)
	paper_panel.size = Vector2(paper_uv.size.x * ms.x, paper_uv.size.y * ms.y)
	if _typebars:
		var tb: Rect2 = PhotoLayoutScript.typebar_uv()
		_typebars.position = Vector2(tb.position.x * ms.x, tb.position.y * ms.y)
		_typebars.size = Vector2(tb.size.x * ms.x, tb.size.y * ms.y)


func _wire_paper_drag() -> void:
	paper_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not paper_panel.gui_input.is_connected(_on_paper_gui_input):
		paper_panel.gui_input.connect(_on_paper_gui_input)


func _on_paper_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_paper_dragging = mb.pressed
			_paper_drag_last_y = mb.position.y
			if mb.pressed:
				_paper_base_pos = paper_panel.position - Vector2(0.0, _paper_feed_offset)
			accept_event()
	elif event is InputEventMouseMotion and _paper_dragging:
		var mm := event as InputEventMouseMotion
		var dy := mm.position.y - _paper_drag_last_y
		_paper_drag_last_y = mm.position.y
		_paper_feed_offset = clampf(_paper_feed_offset + dy, -220.0, 160.0)
		_apply_paper_feed_pos(false)
		accept_event()


func _apply_paper_feed_pos(animate: bool) -> void:
	var target := _paper_base_pos + Vector2(-float(_col) * 2.2, float(_row) * 1.1 + _paper_feed_offset)
	if animate:
		var tw := create_tween()
		tw.tween_property(paper_panel, "position", target, 0.08).set_trans(Tween.TRANS_SINE)
	else:
		paper_panel.position = target


func _ensure_typebars() -> void:
	_typebars = machine.get_node_or_null("TypebarBasket") as Control
	if _typebars == null:
		_typebars = TypebarBasketScript.new() as Control
		_typebars.name = "TypebarBasket"
		_typebars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		machine.add_child(_typebars)
	_layout_photo_slots()


func _wire_controls() -> void:
	%StartBtn.pressed.connect(_on_start)
	pause_btn.pressed.connect(_on_pause)
	%EndBtn.pressed.connect(_on_end)
	%LoadBtn.pressed.connect(_on_load_file)
	var shift_ui: Button = %UIShiftBtn
	var feed_up: Button = %UIFeedUpBtn
	var feed_dn: Button = %UIFeedDownBtn
	shift_ui.toggled.connect(func(on: bool) -> void:
		_shift_on = on
		%ShiftBtn.button_pressed = on
		_animate_key_id("shift")
	)
	feed_up.pressed.connect(func() -> void: _manual_feed(-1))
	feed_dn.pressed.connect(func() -> void: _manual_feed(1))
	%ShiftBtn.toggled.connect(func(on: bool) -> void:
		_shift_on = on
		shift_ui.button_pressed = on
	)
	%FeedUpBtn.pressed.connect(func() -> void: _manual_feed(-1))
	%FeedDownBtn.pressed.connect(func() -> void: _manual_feed(1))
	%SettingsBtn.pressed.connect(func() -> void:
		settings_panel.visible = not settings_panel.visible
		if settings_panel.visible:
			settings_panel.move_to_front()
	)
	%SettingsCloseBtn.pressed.connect(func() -> void: settings_panel.visible = false)
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_slider.value = settings.typing_speed
	%ViewFollowBtn.pressed.connect(func() -> void: _set_view(ViewMode.FOLLOW))
	%ViewFullBtn.pressed.connect(func() -> void: _set_view(ViewMode.FULL))
	%ViewAllPaperBtn.pressed.connect(func() -> void: _set_view(ViewMode.ALL_PAPER))
	%ViewKeysBtn.pressed.connect(func() -> void: _set_view(ViewMode.KEYS))
	%ViewBottomBtn.pressed.connect(func() -> void: _set_view(ViewMode.BOTTOM_CLOSE))
	ink_picker.color_changed.connect(func(c: Color) -> void:
		settings.ink_color = c
		settings.save_cfg()
	)
	font_picker.color_changed.connect(func(c: Color) -> void:
		settings.font_color = c
		_apply_font_settings()
		settings.save_cfg()
	)
	font_size_spin.value_changed.connect(func(v: float) -> void:
		settings.font_size = int(v)
		_apply_font_settings()
		settings.save_cfg()
	)
	font_style_opt.item_selected.connect(func(idx: int) -> void:
		settings.font_style = idx
		_apply_font_settings()
		settings.save_cfg()
	)


func _sync_settings_ui() -> void:
	ink_picker.color = settings.ink_color
	font_picker.color = settings.font_color
	font_size_spin.min_value = 12
	font_size_spin.max_value = 48
	font_size_spin.value = settings.font_size
	font_style_opt.clear()
	for t in ["Regular", "Bold", "Italic", "Bold Italic"]:
		font_style_opt.add_item(t)
	font_style_opt.select(clampi(settings.font_style, 0, 3))
	pack_opt.clear()
	var packs: PackedStringArray = sfx.call("list_packs") as PackedStringArray
	var sel := 0
	for i in packs.size():
		var label: String = packs[i]
		var nice := label
		if label.begins_with("km_"):
			nice = "Keymulate: " + label.substr(3)
		else:
			nice = "TypingSim: " + label
		pack_opt.add_item(nice)
		pack_opt.set_item_metadata(i, label)
		if label == settings.sound_pack:
			sel = i
	if pack_opt.item_count > 0:
		pack_opt.select(sel)
		if not pack_opt.item_selected.is_connected(_on_pack_selected):
			pack_opt.item_selected.connect(_on_pack_selected)
	_on_speed_changed(settings.typing_speed)


func _on_pack_selected(idx: int) -> void:
	var pack := str(pack_opt.get_item_metadata(idx))
	if pack.is_empty() or pack.begins_with("freesound"):
		pack = "buckling"
	settings.sound_pack = pack
	sfx.call("load_pack", pack)
	settings.save_cfg()
	_set_status("Sound: %s" % pack)


func _apply_font_settings() -> void:
	var size: int = settings.font_size
	if settings.font_style == 1 or settings.font_style == 3:
		size += 1
	if _paper_font == null:
		_setup_paper_font()
	paper_label.add_theme_font_override("font", _paper_font)
	paper_label.add_theme_font_size_override("font_size", size)
	paper_label.add_theme_color_override("font_color", settings.font_color)
	paper_label.rotation_degrees = -1.2 if settings.font_style >= 2 else 0.0
	if caret_label:
		caret_label.add_theme_font_size_override("font_size", size)
		caret_label.add_theme_color_override("font_color", settings.font_color)
	_refresh_paper_text()
	_update_paper_motion(false)


func _apply_paper_texture() -> void:
	var path := "res://assets/images/paper.png"
	var abs_path := ProjectSettings.globalize_path(path)
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex:
		paper_texture.texture = tex
		paper_texture.visible = true
		paper_placeholder.visible = false
		var fill := paper_surface.get_node_or_null("PaperFill") as ColorRect
		if fill:
			fill.visible = false
	else:
		paper_texture.visible = false
		paper_placeholder.visible = true


func _build_keyboard() -> void:
	var shift_map := {
		"1":"!","2":"@","3":"#","4":"$","5":"%","6":"^","7":"&","8":"*","9":"(","0":")",
		"-":"_","=":"+",";":":","'":"\"",",":"<",".":">","/":"?",
	}
	_key_map.clear()
	var grid: Control = %KeyRows
	for c in grid.get_children():
		c.queue_free()
	await get_tree().process_frame
	if _keys_tex == null:
		_keys_tex = _load_tex(PATH_KEYS)
	var specs: Array = PhotoLayoutScript.rows()
	var ms := machine.size
	if ms.x < 10.0:
		ms = Vector2(720, 720)
	for spec in specs:
		var id: String = str(spec[0])
		var label: String = str(spec[1])
		var nx: float = float(spec[2])
		var ny: float = float(spec[3])
		var nw: float = float(spec[4])
		var nh: float = float(spec[5])
		var circular: bool = bool(spec[6]) if spec.size() > 6 else true
		var kx: float = float(spec[7]) if spec.size() > 7 else nx
		var ky: float = float(spec[8]) if spec.size() > 8 else ny
		var kw: float = float(spec[9]) if spec.size() > 9 else nw
		var kh: float = float(spec[10]) if spec.size() > 10 else nh
		var btn: Button = RoyalKeyScript.new()
		var px := nx * ms.x
		var py := ny * ms.y
		var sz := Vector2(nw * ms.x, nh * ms.y)
		sz.x = maxf(sz.x, 22.0)
		sz.y = maxf(sz.y, 22.0)
		var atlas_uv := Rect2(kx - kw * 0.5, ky - kh * 0.5, kw, kh)
		btn.call("setup", id, label, sz, circular, _keys_tex, atlas_uv)
		btn.position = Vector2(px - sz.x * 0.5, py - sz.y * 0.5)
		btn.set_meta("uv", Vector2(nx, ny))
		btn.set_meta("uv_size", Vector2(nw, nh))
		btn.set_meta("atlas_uv", atlas_uv)
		match id:
			"backspace":
				btn.connect("key_struck", func(_a: String) -> void: _backspace())
			"tab":
				btn.connect("key_struck", func(_a: String) -> void: _type_char("\t"))
			" ":
				btn.connect("key_struck", func(_a: String) -> void: _type_char(" "))
			"\n":
				btn.connect("key_struck", func(_a: String) -> void: _type_char("\n"))
			"shift", "shift_r":
				btn.toggle_mode = true
				btn.connect("key_struck", func(_a: String) -> void:
					_shift_on = not _shift_on
					%UIShiftBtn.button_pressed = _shift_on
					btn.button_pressed = _shift_on
				)
			_:
				var k := id
				btn.connect("key_struck", func(action: String) -> void:
					var out := action
					if _shift_on:
						out = str(shift_map[action]) if shift_map.has(action) else action.to_upper()
					_type_char(out)
				)
		grid.add_child(btn)
		_key_map[id] = btn
		if id.length() == 1:
			_key_map[id.to_upper()] = btn
	_key_map["shift"] = _key_map.get("shift", %ShiftBtn)
	_key_map["return"] = _key_map.get("\n", null)


func _reposition_keys() -> void:
	var ms := machine.size
	if ms.x < 10.0:
		return
	for id in _key_map.keys():
		var btn = _key_map[id]
		if btn == null or not (btn is Control):
			continue
		if not btn.has_meta("uv"):
			continue
		var uv: Vector2 = btn.get_meta("uv")
		var uvs: Vector2 = btn.get_meta("uv_size")
		var sz := Vector2(maxf(uvs.x * ms.x, 26.0), maxf(uvs.y * ms.y, 26.0))
		btn.custom_minimum_size = sz
		btn.size = sz
		btn.position = Vector2(uv.x * ms.x - sz.x * 0.5, uv.y * ms.y - sz.y * 0.5)
		btn.remove_meta("_rest_set")


func _on_speed_changed(v: float) -> void:
	settings.typing_speed = int(v)
	speed_value.text = str(settings.typing_speed)
	settings.save_cfg()


func _on_start() -> void:
	var text := draft_edit.text.strip_edges()
	if text.is_empty():
		text = SAMPLE_DRAFT
		draft_edit.text = text
	_end_typing()
	_auto_queue = text
	_auto_index = 0
	_auto_timer = 0.0
	_typing_active = true
	_typing_paused = false
	pause_btn.text = "Pause Typing"
	_set_status("Typing")


func _on_pause() -> void:
	if not _typing_active:
		return
	_typing_paused = not _typing_paused
	pause_btn.text = "Resume Typing" if _typing_paused else "Pause Typing"
	_set_status("Paused" if _typing_paused else "Typing")


func _on_end() -> void:
	_end_typing()


func _end_typing() -> void:
	_typing_active = false
	_typing_paused = false
	_auto_queue = ""
	_auto_index = 0
	pause_btn.text = "Pause Typing"
	_set_status("Stopped")


func _on_load_file() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.txt ; Text Files"])
	add_child(dlg)
	dlg.file_selected.connect(func(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			draft_edit.text = f.get_as_text()
			_set_status("File Loaded")
			_on_start()
		else:
			_set_status("File Error")
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered_ratio(0.6)


func _manual_feed(dir: int) -> void:
	if dir > 0:
		_type_char("\n")
		return
	if _row > 0:
		_row -= 1
		_col = mini(_col, _lines[_row].length())
		_bell_armed = _col < MARGIN_BELL_COL
		_refresh_paper_text()
		_update_paper_motion(true)
		_update_carriage_slide(true)


func _backspace() -> void:
	if _col > 0:
		var line := _lines[_row]
		_lines[_row] = line.substr(0, _col - 1) + line.substr(_col)
		_col -= 1
	elif _row > 0:
		var prev := _lines[_row - 1]
		var cur := _lines[_row]
		_col = prev.length()
		_lines[_row - 1] = prev + cur
		_lines.remove_at(_row)
		_row -= 1
	else:
		return
	_bell_armed = _col < MARGIN_BELL_COL
	_animate_key_id("backspace")
	sfx.call("play_backspace", true)
	_refresh_paper_text()
	_update_paper_motion(true)
	_update_carriage_slide(true)
	_do_strike_fx(false, "backspace")


func _type_char(ch: String) -> void:
	if ch == "\t":
		# Typewriter tab ≈ 4 spaces (no nested tab recursion)
		_animate_key_id("tab")
		for _i in 4:
			if _col >= COLS:
				_row += 1
				_col = 0
				_bell_armed = true
				if _row >= _lines.size():
					_lines.append("")
			var line_t := _lines[_row]
			_lines[_row] = line_t + " "
			_col += 1
		if _col >= MARGIN_BELL_COL and _bell_armed:
			_bell_armed = false
			sfx.call("play_bell")
		sfx.call("play_space", true)
		_refresh_paper_text()
		_update_paper_motion(true)
		_update_carriage_slide(true)
		return
	if ch == "\n":
		_row += 1
		_col = 0
		_bell_armed = true
		if _row >= _lines.size():
			_lines.append("")
		_animate_key_for_char("\n")
		sfx.call("play_return", true)
		_refresh_paper_text()
		_update_paper_motion(true)
		_update_carriage_slide(true)
		_do_strike_fx(false, "\n")
		return
	if _col >= COLS:
		_row += 1
		_col = 0
		_bell_armed = true
		if _row >= _lines.size():
			_lines.append("")
	var line := _lines[_row]
	if _col >= line.length():
		_lines[_row] = line + ch
	else:
		_lines[_row] = line.substr(0, _col) + ch + line.substr(_col)
	_col += 1
	if _col >= MARGIN_BELL_COL and _bell_armed:
		_bell_armed = false
		sfx.call("play_bell")
	_animate_key_for_char(ch)
	if ch == " ":
		sfx.call("play_space", true)
	else:
		sfx.call("play_key", true)
	_refresh_paper_text()
	_update_paper_motion(true)
	_update_carriage_slide(true)
	_do_strike_fx(true, ch)


func _animate_key_for_char(ch: String) -> void:
	var id := ch.to_lower()
	if ch == "\n":
		id = "\n"
	elif ch == " ":
		id = " "
	_animate_key_id(id)


func _animate_key_id(id: String) -> void:
	if _key_map.has(id):
		var node = _key_map[id]
		if node and node.has_method("animate_press"):
			node.call("animate_press")


func _slot_for_char(ch: String) -> int:
	if ch.is_empty():
		return 14
	return absi(ch.unicode_at(0) * 7 + ch.length() * 3) % 28


func _refresh_paper_text() -> void:
	paper_label.text = "\n".join(_lines)


func _line_height() -> float:
	return float(settings.font_size) + 5.0


func _char_width() -> float:
	return float(settings.font_size) * 0.60


func _caret_local_pos() -> Vector2:
	return PAPER_MARGIN + Vector2(float(_col) * _char_width(), float(_row) * _line_height() + _line_height() * 0.5)


func _update_paper_motion(animate: bool) -> void:
	var caret := Vector2(float(_col) * _char_width(), float(_row) * _line_height())
	var view_size := paper_surface.size
	if view_size.x < 10.0:
		view_size = Vector2(300, 180)
	var target := Vector2(
		clampf(view_size.x * 0.35 - caret.x, -caret.x - 10.0, 20.0),
		clampf(view_size.y * 0.4 - caret.y, -float(_row) * _line_height() - 10.0, 20.0)
	)
	var label_pos := PAPER_MARGIN + target
	if animate:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(paper_label, "position", label_pos, 0.08).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ink_layer, "position", target, 0.08).set_trans(Tween.TRANS_SINE)
	else:
		paper_label.position = label_pos
		ink_layer.position = target


func _update_carriage_slide(animate: bool) -> void:
	## Carriage drifts left as column advances; vertical includes paper feed drag.
	_apply_paper_feed_pos(animate)


func _do_strike_fx(with_ink: bool, ch: String = "") -> void:
	var pos := _caret_local_pos()
	_strike_punch = 1.0
	strike_hammer.visible = true
	strike_hammer.size = Vector2(12, 16)
	strike_hammer.position = Vector2(pos.x - 6.0, pos.y - 14.0)
	if _typebars and _typebars.has_method("strike"):
		_typebars.call("strike", _slot_for_char(ch), 1.0)
	if with_ink and ch != " ":
		var blot := Control.new()
		blot.set_script(load("res://scripts/ink_blot.gd"))
		ink_layer.add_child(blot)
		blot.call("setup", pos - ink_layer.position, settings.ink_color, 2.8 + float(settings.font_size) * 0.06)
	if not _typing_active:
		_play_strike_cinema()


func _set_status(s: String) -> void:
	var audio := "ok" if bool(sfx.call("has_audio")) else "missing"
	status_label.text = "Status: %s · SFX %s/%s · col %d/%d" % [s, audio, settings.sound_pack, _col, COLS]


func _set_view(mode: ViewMode, animate: bool = true) -> void:
	if _strike_cinema_active and mode != ViewMode.TOP_PAPER:
		_view_before_strike = mode
		return
	_view = mode
	_apply_view_transform(animate)


func _play_strike_cinema() -> void:
	if _strike_cinema_active:
		return
	if _view == ViewMode.ALL_PAPER or _view == ViewMode.FOLLOW:
		return
	_strike_cinema_active = true
	_view_before_strike = _view if _view != ViewMode.TOP_PAPER else _view_before_strike
	_view = ViewMode.TOP_PAPER
	_apply_view_transform(true)
	await get_tree().create_timer(0.22).timeout
	_strike_cinema_active = false
	_view = _view_before_strike
	_apply_view_transform(true)


func _apply_follow_camera(delta: float) -> void:
	var caret := _caret_local_pos()
	var target := Vector2(40.0 - caret.x * 0.2, 10.0 - caret.y * 0.15)
	machine.position = machine.position.lerp(Vector2(180, 8) + target, clampf(delta * 5.0, 0.0, 1.0))
	machine.scale = machine.scale.lerp(Vector2(1.12, 1.12), clampf(delta * 4.0, 0.0, 1.0))
	paper_panel.visible = true
	keyboard_panel.visible = true


func _apply_view_transform(animate: bool) -> void:
	var target_pos := Vector2(180, 8)
	var target_scale := Vector2.ONE
	paper_panel.visible = true
	keyboard_panel.visible = true
	if _full_tex:
		royal_photo.texture = _full_tex
	match _view:
		ViewMode.FOLLOW:
			target_scale = Vector2(1.12, 1.12)
		ViewMode.FULL:
			pass
		ViewMode.ALL_PAPER:
			target_pos = Vector2(120, -20)
			target_scale = Vector2(1.35, 1.35)
		ViewMode.KEYS:
			# Zoom onto keyboard deck of full_machine (hotspots stay aligned).
			# keys_closeup.png supplies press-shrink atlas crops, not the backdrop.
			target_pos = Vector2(60, -300)
			target_scale = Vector2(1.6, 1.6)
		ViewMode.BOTTOM_CLOSE:
			target_pos = Vector2(40, -320)
			target_scale = Vector2(1.45, 1.45)
		ViewMode.TOP_PAPER:
			target_pos = Vector2(140, -10)
			target_scale = Vector2(1.3, 1.3)
	if animate:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(machine, "position", target_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(machine, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		machine.position = target_pos
		machine.scale = target_scale
