extends MarginContainer
## Animation tab / mode — list, rename, fps/loop, sprite frames; writes studio_anim.json + anim_config.gd.

const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")

var _empty: Label
var _root: HSplitContainer
var _mode_toggle: CheckButton
var _list: ItemList
var _name_edit: LineEdit
var _fps: SpinBox
var _loop: CheckButton
var _notes: TextEdit
var _frames: ItemList
var _frame_path: LineEdit
var _status: Label
var _data: Dictionary = {}
var _anims: Array = []


func _ready() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()
	if not AIOrchestrator.session_changed.is_connected(refresh):
		AIOrchestrator.session_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var path: String = AIOrchestrator.get_project_path()
	var active: bool = AIOrchestrator.has_active_session() and not path.is_empty()
	_empty.visible = not active
	_root.visible = active
	if not active:
		return
	ConfigScript.ensure_on_disk(path)
	_data = ConfigScript.load_anim(path)
	_anims = _data.get("animations", [])
	if typeof(_anims) != TYPE_ARRAY:
		_anims = []
	_mode_toggle.set_pressed_no_signal(bool(_data.get("mode_enabled", false)))
	_reload_list()


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game, then use Animation mode to edit clip names, fps, loop, and sprite frames."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_root = HSplitContainer.new()
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_root)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(240, 0)
	_root.add_child(left)
	var title: Label = Label.new()
	title.text = "Animation mode"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)
	_mode_toggle = CheckButton.new()
	_mode_toggle.text = "Enable animation mode (apply on Run)"
	_mode_toggle.toggled.connect(_on_mode)
	left.add_child(_mode_toggle)
	var hint: Label = Label.new()
	hint.text = "Clips write to studio_anim.json and scripts/anim_config.gd. StudioRuntime builds AnimatedSprite2D (2D) or AnimationPlayer tracks (3D)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	left.add_child(hint)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_select)
	left.add_child(_list)
	var lrow: HBoxContainer = HBoxContainer.new()
	left.add_child(lrow)
	var add_btn: Button = Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_on_add)
	lrow.add_child(add_btn)
	var del_btn: Button = Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_on_delete)
	lrow.add_child(del_btn)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(right)
	var name_row: HBoxContainer = HBoxContainer.new()
	right.add_child(name_row)
	var nl: Label = Label.new()
	nl.text = "Name"
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	var fps_row: HBoxContainer = HBoxContainer.new()
	right.add_child(fps_row)
	var fl: Label = Label.new()
	fl.text = "FPS / speed"
	fps_row.add_child(fl)
	_fps = SpinBox.new()
	_fps.min_value = 1.0
	_fps.max_value = 60.0
	_fps.step = 0.5
	_fps.value = 8.0
	fps_row.add_child(_fps)
	_loop = CheckButton.new()
	_loop.text = "Loop"
	_loop.button_pressed = true
	fps_row.add_child(_loop)
	var notes_l: Label = Label.new()
	notes_l.text = "Preview notes / AnimationPlayer hints"
	right.add_child(notes_l)
	_notes = TextEdit.new()
	_notes.custom_minimum_size = Vector2(0, 70)
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_notes)
	var fr_l: Label = Label.new()
	fr_l.text = "Sprite frames (res:// paths)"
	right.add_child(fr_l)
	_frames = ItemList.new()
	_frames.custom_minimum_size = Vector2(0, 100)
	right.add_child(_frames)
	var frow: HBoxContainer = HBoxContainer.new()
	right.add_child(frow)
	_frame_path = LineEdit.new()
	_frame_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_path.placeholder_text = "res://assets/character/walk_0.png"
	frow.add_child(_frame_path)
	var add_f: Button = Button.new()
	add_f.text = "Add frame"
	add_f.pressed.connect(_on_add_frame)
	frow.add_child(add_f)
	var scan_f: Button = Button.new()
	scan_f.text = "Scan character/sprites folders"
	scan_f.pressed.connect(_on_scan_frames)
	frow.add_child(scan_f)
	var rem_f: Button = Button.new()
	rem_f.text = "Remove frame"
	rem_f.pressed.connect(_on_remove_frame)
	frow.add_child(rem_f)
	var apply_btn: Button = Button.new()
	apply_btn.text = "Apply clip + write into game"
	apply_btn.pressed.connect(_on_apply)
	right.add_child(apply_btn)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
	right.add_child(_status)


func _reload_list() -> void:
	var prev: int = _list.get_selected_items()[0] if _list.get_selected_items().size() > 0 else 0
	_list.clear()
	for a in _anims:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		_list.add_item("%s  (%s fps, loop=%s)" % [str(a.get("name", "?")), str(a.get("fps", 8)), str(a.get("loop", true))])
	if _list.item_count > 0:
		_list.select(clampi(prev, 0, _list.item_count - 1))
		_on_select(_list.get_selected_items()[0])


func _on_mode(pressed: bool) -> void:
	_data["mode_enabled"] = pressed
	_persist()
	_status.text = "Animation mode %s — Run Game to apply StudioRuntime hooks." % ("ON" if pressed else "off")


func _on_select(idx: int) -> void:
	if idx < 0 or idx >= _anims.size():
		return
	var a: Dictionary = _anims[idx]
	_name_edit.text = str(a.get("name", ""))
	_fps.value = float(a.get("fps", 8.0))
	_loop.button_pressed = bool(a.get("loop", true))
	_notes.text = str(a.get("notes", ""))
	_frames.clear()
	var fr: Variant = a.get("frames", [])
	if typeof(fr) == TYPE_ARRAY:
		for p in fr:
			_frames.add_item(str(p))


func _on_add() -> void:
	_anims.append({"name": "new_clip", "fps": 8.0, "loop": true, "frames": [], "notes": ""})
	_reload_list()
	_list.select(_list.item_count - 1)
	_on_select(_list.item_count - 1)


func _on_delete() -> void:
	var idxs: PackedInt32Array = _list.get_selected_items()
	if idxs.is_empty():
		return
	_anims.remove_at(idxs[0])
	_reload_list()


func _on_add_frame() -> void:
	var p: String = _frame_path.text.strip_edges()
	if p.is_empty():
		return
	_frames.add_item(p)
	_frame_path.clear()


func _on_remove_frame() -> void:
	var idxs: PackedInt32Array = _frames.get_selected_items()
	if idxs.is_empty():
		return
	_frames.remove_item(idxs[0])


func _on_scan_frames() -> void:
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty():
		return
	var found: Array = []
	found.append_array(LayoutScript.list_category(root, "character"))
	found.append_array(LayoutScript.list_category(root, "sprites"))
	for item in found:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("kind", "")) != "image":
			continue
		var res_p: String = str(item.get("res", ""))
		var exists: bool = false
		for i in _frames.item_count:
			if _frames.get_item_text(i) == res_p:
				exists = true
				break
		if not exists:
			_frames.add_item(res_p)
	_status.text = "Scanned character/ + sprites/ into frame list."


func _on_apply() -> void:
	var idxs: PackedInt32Array = _list.get_selected_items()
	if idxs.is_empty():
		_status.text = "Select or add a clip."
		return
	var frames: Array = []
	for i in _frames.item_count:
		frames.append(_frames.get_item_text(i))
	_anims[idxs[0]] = {
		"name": _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "clip",
		"fps": _fps.value,
		"loop": _loop.button_pressed,
		"frames": frames,
		"notes": _notes.text.strip_edges(),
	}
	_persist()
	_reload_list()
	_status.text = "Wrote studio_anim.json + scripts/anim_config.gd. Run Game to preview."


func _persist() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	_data["animations"] = _anims
	_data["mode_enabled"] = _mode_toggle.button_pressed
	ConfigScript.save_anim(path, _data)
	var notes_path: String = path.path_join("docs/ANIMATION_NOTES.md")
	DirAccess.make_dir_recursive_absolute(notes_path.get_base_dir())
	var body: String = "# Animation notes (studio)\n\nMode enabled: %s\n\n" % str(_mode_toggle.button_pressed)
	for a in _anims:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		body += "- **%s** — %s fps, loop=%s — %s\n" % [
			str(a.get("name", "")), str(a.get("fps", 8)), str(a.get("loop", true)), str(a.get("notes", "")),
		]
	body += "\nAnimationPlayer library `studio/*` or AnimatedSprite2D `StudioAnimSprite` is created at runtime.\n"
	var f: FileAccess = FileAccess.open(notes_path, FileAccess.WRITE)
	if f:
		f.store_string(body)
