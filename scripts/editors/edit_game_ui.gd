extends MarginContainer
## Edit Game tab — add more / change Character · World · Enemy · Weapon · Physics from F:/asset.

const PanelScript = preload("res://scripts/editors/add_to_game_panel.gd")
const LocalLibScript = preload("res://scripts/editors/local_asset_library.gd")
const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")

var _empty: Label
var _body: HSplitContainer
var _panel: Control
var _source_opt: OptionButton
var _section_opt: OptionButton
var _file_list: ItemList
var _preview: TextureRect
var _meta: Label
var _status: Label
var _listed: Array = []
var _selected: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_bottom", 8)
	_build()
	if not AIOrchestrator.session_changed.is_connected(refresh):
		AIOrchestrator.session_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var path: String = AIOrchestrator.get_project_path()
	var active: bool = AIOrchestrator.has_active_session() and not path.is_empty()
	_empty.visible = not active
	_body.visible = active
	if not active:
		_status.text = "Create a game first, then return here to add more from F:/asset."
		return
	LayoutScript.ensure_layout(path)
	ConfigScript.ensure_on_disk(path)
	if _panel and _panel.has_method("refresh"):
		_panel.refresh()
	_reload_browser()


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game, then use this tab to add more from F:/asset (character, world, enemy, weapon, materials, physics)."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_body = HSplitContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)

	_panel = PanelScript.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_panel)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 280
	right.add_theme_constant_override("separation", 6)
	_body.add_child(right)

	var title: Label = Label.new()
	title.text = "Add more from F:/asset"
	title.add_theme_font_size_override("font_size", 16)
	right.add_child(title)

	var hint: Label = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.78))
	hint.text = "Browse the local folder (default F:/asset) or this game’s assets/. Add more copies into the project. Add to game / Change also updates studio_assets.json + StudioRuntime."
	right.add_child(hint)

	var filters: HBoxContainer = HBoxContainer.new()
	right.add_child(filters)
	_source_opt = OptionButton.new()
	_source_opt.add_item("F:/asset")
	_source_opt.add_item("Project assets/")
	_source_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_opt.item_selected.connect(func(_i): _reload_browser())
	filters.add_child(_source_opt)
	_section_opt = OptionButton.new()
	for s in ["all", "character", "world", "enemy", "weapon", "materials", "physics", "models"]:
		_section_opt.add_item(s)
	_section_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_opt.item_selected.connect(func(_i): _reload_browser())
	filters.add_child(_section_opt)

	_file_list = ItemList.new()
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.item_selected.connect(_on_file_selected)
	right.add_child(_file_list)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 96)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_preview)

	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	right.add_child(_meta)

	var actions: HBoxContainer = HBoxContainer.new()
	right.add_child(actions)
	var more_btn: Button = Button.new()
	more_btn.text = "Add more"
	more_btn.tooltip_text = "Copy into the game as an extra variant. Does not replace the current slot."
	more_btn.pressed.connect(func(): _apply_selected(false, false))
	actions.add_child(more_btn)
	var add_btn: Button = Button.new()
	add_btn.text = "Add to game"
	add_btn.pressed.connect(func(): _apply_selected(true, false))
	actions.add_child(add_btn)
	var ch_btn: Button = Button.new()
	ch_btn.text = "Change"
	ch_btn.pressed.connect(func(): _apply_selected(true, true))
	actions.add_child(ch_btn)

	var folder_row: HBoxContainer = HBoxContainer.new()
	right.add_child(folder_row)
	var open_local: Button = Button.new()
	open_local.text = "Open F:/asset"
	open_local.pressed.connect(_on_open_local)
	folder_row.add_child(open_local)
	var refresh_btn: Button = Button.new()
	refresh_btn.text = "Refresh list"
	refresh_btn.pressed.connect(func(): _reload_browser(true))
	folder_row.add_child(refresh_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
	right.add_child(_status)


func _reload_browser(force_scan: bool = false) -> void:
	_file_list.clear()
	_listed.clear()
	_selected = {}
	_preview.texture = null
	var section: String = _section_opt.get_item_text(_section_opt.selected) if _section_opt.item_count > 0 else "all"
	if _source_opt.selected <= 0:
		if force_scan:
			LocalLibScript.scan(true)
		var rows: Array = LocalLibScript.list_for(section if section != "all" else "")
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if str(row.get("kind", "")) == "cs":
				continue
			_listed.append(row)
			_file_list.add_item(str(row.get("label", row.get("name", "?"))))
		_meta.text = "%s items in %s" % [str(_listed.size()), LocalLibScript.configured_root()]
		return
	var path: String = AIOrchestrator.get_project_path()
	var cat: String = section if section != "all" and section != "physics" else "all"
	if section == "materials":
		cat = "materials"
	elif section == "models":
		cat = "models"
	var proj_rows: Array = LayoutScript.list_category(path, cat) if cat != "all" else LayoutScript.list_all(path)
	for row in proj_rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_listed.append(row)
		_file_list.add_item("%s [%s]" % [str(row.get("name", "?")), str(row.get("category", ""))])
	_meta.text = "%s files in project assets/" % str(_listed.size())


func _on_file_selected(idx: int) -> void:
	if idx < 0 or idx >= _listed.size():
		return
	_selected = _listed[idx] if typeof(_listed[idx]) == TYPE_DICTIONARY else {}
	_meta.text = str(_selected.get("rel", _selected.get("res", _selected.get("abs", ""))))
	_preview.texture = null
	var abs_path: String = str(_selected.get("abs", ""))
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return
	if not LayoutScript.IMAGE_EXTS.has(abs_path.get_extension().to_lower()):
		return
	var img: Image = Image.new()
	if img.load(abs_path) == OK:
		_preview.texture = ImageTexture.create_from_image(img)


func _apply_selected(assign: bool, replace: bool) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty() or _selected.is_empty():
		_status.text = "Select a file first."
		return
	var section: String = _section_opt.get_item_text(_section_opt.selected) if _section_opt.item_count > 0 else "all"
	if str(_selected.get("kind", "")) == "physics_scene" or str(_selected.get("kind", "")) == "plugin" or section == "physics":
		var phys: Dictionary = LocalLibScript.install_physics_helpers(path)
		_status.text = "Physics helpers → %s" % str(phys.get("addon", "addons/f_asset_physics"))
		if _panel and _panel.has_method("refresh"):
			_panel.refresh()
		return
	var cat: String = _dest_category(section, _selected)
	var res_p: String = str(_selected.get("res", "")).strip_edges()
	if str(_selected.get("source", "")) == "local" or bool(_selected.get("local", false)) or res_p.is_empty():
		var installed: Dictionary = LocalLibScript.import_file(path, str(_selected.get("abs", "")), cat)
		if not installed.get("ok", false):
			_status.text = "Copy failed: %s" % str(installed.get("error", "unknown"))
			return
		res_p = str(installed.get("res", ""))
	if assign and not res_p.is_empty():
		var slot: String = _slot_for(section, _selected)
		if not slot.is_empty():
			if replace:
				ConfigScript.change_slot(path, slot, res_p)
			else:
				ConfigScript.add_to_slot(path, slot, res_p)
	if _panel and _panel.has_method("refresh"):
		_panel.refresh()
	_reload_browser()
	if assign:
		_status.text = ("%s assigned to %s. Run Game to see StudioRuntime pick it up." % [res_p, _slot_for(section, _selected)]) if replace else ("Added %s into the game." % res_p)
	else:
		_status.text = "Added more: %s — pick it in the lists, then Add to game or Change." % res_p


func _dest_category(section: String, row: Dictionary) -> String:
	match section:
		"character":
			return "character"
		"enemy":
			return "enemy"
		"weapon":
			return "weapon"
		"materials":
			return "materials"
		"models":
			return "models"
		"world":
			if str(row.get("kind", "")) == "material":
				return "materials"
			if str(row.get("kind", "")) == "model":
				return "models"
			var nm: String = str(row.get("name", "")).to_lower()
			return "background" if nm.contains("sky") or nm.contains("skybox") else "world"
		_:
			return LayoutScript.categorize(str(row.get("name", "asset.png")))


func _slot_for(section: String, row: Dictionary) -> String:
	var kind: String = str(row.get("kind", ""))
	var name_l: String = str(row.get("name", "")).to_lower()
	match section:
		"character":
			if kind == "model":
				return "character_model"
			if kind == "material":
				return "character_material"
			return "character_sprite" if name_l.contains("sprite") else "character_texture"
		"enemy":
			if kind == "model":
				return "enemy_model"
			if kind == "material":
				return "enemy_material"
			return "enemy_texture"
		"weapon":
			if kind == "model":
				return "weapon_model"
			if kind == "material":
				return "weapon_material"
			return "weapon_sprite" if name_l.contains("sprite") else "weapon_texture"
		"materials":
			if name_l.contains("floor") or name_l.contains("grass") or name_l.contains("leaf"):
				return "floor_material"
			if name_l.contains("sky"):
				return "skybox_material"
			if name_l.contains("char") or name_l.contains("white"):
				return "character_material"
			return "wall_material"
		"world":
			if kind == "material":
				return "wall_material"
			if kind == "model":
				return "room_model"
			if name_l.contains("sky"):
				return "skybox"
			if name_l.contains("floor") or name_l.contains("grass") or name_l.contains("leaf") or name_l.contains("sand"):
				return "floor"
			return "wall"
		_:
			return ""


func _on_open_local() -> void:
	var root: String = LocalLibScript.configured_root()
	if DirAccess.dir_exists_absolute(root):
		OS.shell_show_in_file_manager(root)
	else:
		_status.text = "Local folder missing: %s (set it in Settings)." % root
