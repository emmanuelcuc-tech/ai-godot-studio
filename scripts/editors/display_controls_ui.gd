extends MarginContainer
## Controls / Display — backgrounds, UI style, health, weapon view, camera first/third.

const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")

var _empty: Label
var _scroll: ScrollContainer
var _root: VBoxContainer
var _menu_bg: LineEdit
var _game_bg: LineEdit
var _ui_style: OptionButton
var _max_hp: SpinBox
var _show_hp: CheckButton
var _weapon: CheckButton
var _camera: OptionButton
var _status: Label
var _preview_menu: TextureRect
var _preview_game: TextureRect


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
	_scroll.visible = active
	if not active:
		return
	ConfigScript.ensure_on_disk(path)
	var display: Dictionary = ConfigScript.load_display(path)
	var controls: Dictionary = ConfigScript.load_controls(path)
	_menu_bg.text = str(display.get("menu_background", ""))
	_game_bg.text = str(display.get("game_background", ""))
	_set_option(_ui_style, str(controls.get("ui_style", display.get("ui_style", "neon"))))
	_max_hp.value = float(controls.get("max_hp", display.get("max_hp", 100)))
	_show_hp.button_pressed = bool(controls.get("show_health", display.get("show_health", true)))
	_weapon.button_pressed = bool(controls.get("show_weapon", display.get("weapon_view", true)))
	_set_option(_camera, str(controls.get("camera_mode", display.get("camera_mode", "first_person"))))
	_load_preview(_preview_menu, _menu_bg.text)
	_load_preview(_preview_game, _game_bg.text)


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game, then set menu/game backgrounds, UI style, health, weapon view, and camera."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 8)
	_scroll.add_child(_root)

	var title: Label = Label.new()
	title.text = "Controls / Display"
	title.add_theme_font_size_override("font_size", 18)
	_root.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Writes studio_display.json + studio_controls.json. StudioRuntime applies them on Run Game."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_root.add_child(hint)

	_root.add_child(_caption("Menu background (res:// path)"))
	_menu_bg = LineEdit.new()
	_menu_bg.placeholder_text = "res://assets/background/menu_bg.png"
	_root.add_child(_menu_bg)
	_preview_menu = _make_preview()
	_root.add_child(_preview_menu)

	_root.add_child(_caption("Game background / sky"))
	_game_bg = LineEdit.new()
	_game_bg.placeholder_text = "res://assets/background/sky.png"
	_root.add_child(_game_bg)
	_preview_game = _make_preview()
	_root.add_child(_preview_game)

	var pick_row: HBoxContainer = HBoxContainer.new()
	_root.add_child(pick_row)
	var pick_menu: Button = Button.new()
	pick_menu.text = "Use selected Library background as menu"
	pick_menu.pressed.connect(func(): _fill_from_folder("menu"))
	pick_row.add_child(pick_menu)
	var pick_game: Button = Button.new()
	pick_game.text = "Use first background/sky as game BG"
	pick_game.pressed.connect(func(): _fill_from_folder("game"))
	pick_row.add_child(pick_game)

	_root.add_child(_caption("UI style"))
	_ui_style = OptionButton.new()
	_ui_style.add_item("neon")
	_ui_style.add_item("classic")
	_ui_style.add_item("minimal")
	_root.add_child(_ui_style)

	_root.add_child(_caption("Character health"))
	var hp_row: HBoxContainer = HBoxContainer.new()
	_root.add_child(hp_row)
	var hp_l: Label = Label.new()
	hp_l.text = "Max HP"
	hp_row.add_child(hp_l)
	_max_hp = SpinBox.new()
	_max_hp.min_value = 1.0
	_max_hp.max_value = 9999.0
	_max_hp.value = 100.0
	hp_row.add_child(_max_hp)
	_show_hp = CheckButton.new()
	_show_hp.text = "Show health HUD"
	_show_hp.button_pressed = true
	hp_row.add_child(_show_hp)

	_weapon = CheckButton.new()
	_weapon.text = "Show weapon view (FPS gun mesh / sprite)"
	_weapon.button_pressed = true
	_root.add_child(_weapon)

	_root.add_child(_caption("Camera"))
	_camera = OptionButton.new()
	_camera.add_item("first_person")
	_camera.add_item("third_person")
	_root.add_child(_camera)

	var apply_btn: Button = Button.new()
	apply_btn.text = "Apply to active game"
	apply_btn.pressed.connect(_on_apply)
	_root.add_child(apply_btn)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.3, 0.86, 0.59))
	_root.add_child(_status)


func _caption(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	return l


func _make_preview() -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.custom_minimum_size = Vector2(0, 90)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func _set_option(opt: OptionButton, value: String) -> void:
	for i in opt.item_count:
		if opt.get_item_text(i) == value:
			opt.select(i)
			return
	if opt.item_count > 0:
		opt.select(0)


func _load_preview(rect: TextureRect, res_path: String) -> void:
	rect.texture = null
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty() or res_path.is_empty():
		return
	var rel: String = res_path.trim_prefix("res://")
	var abs_path: String = root.path_join(rel)
	if not FileAccess.file_exists(abs_path):
		return
	var img: Image = Image.new()
	if img.load(abs_path) == OK:
		rect.texture = ImageTexture.create_from_image(img)


func _fill_from_folder(kind: String) -> void:
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty():
		return
	var items: Array = LayoutScript.list_category(root, "background")
	if items.is_empty():
		items = LayoutScript.list_category(root, "textures")
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("kind", "")) != "image":
			continue
		var res_p: String = str(item.get("res", ""))
		if kind == "menu":
			_menu_bg.text = res_p
			_load_preview(_preview_menu, res_p)
		else:
			_game_bg.text = res_p
			_load_preview(_preview_game, res_p)
		return
	_status.text = "No background images found yet — download one in Library."


func _on_apply() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	var display: Dictionary = ConfigScript.load_display(path)
	display["menu_background"] = _menu_bg.text.strip_edges()
	display["game_background"] = _game_bg.text.strip_edges()
	display["ui_style"] = _ui_style.get_item_text(_ui_style.selected)
	display["max_hp"] = int(_max_hp.value)
	display["show_health"] = _show_hp.button_pressed
	display["weapon_view"] = _weapon.button_pressed
	display["camera_mode"] = _camera.get_item_text(_camera.selected)
	ConfigScript.save_display(path, display)
	var controls: Dictionary = {
		"camera_mode": display["camera_mode"],
		"show_weapon": _weapon.button_pressed,
		"show_health": _show_hp.button_pressed,
		"max_hp": int(_max_hp.value),
		"ui_style": display["ui_style"],
	}
	ConfigScript.save_controls(path, controls)
	ConfigScript.assign_slot(path, "menu_background", str(display["menu_background"]))
	ConfigScript.assign_slot(path, "game_background", str(display["game_background"]))
	ConfigScript.ensure_on_disk(path)
	_load_preview(_preview_menu, _menu_bg.text)
	_load_preview(_preview_game, _game_bg.text)
	_status.text = "Saved display/controls. Run Game to see camera, HP, backgrounds, and weapon view."
