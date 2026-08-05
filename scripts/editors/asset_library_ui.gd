extends MarginContainer
## Library / Assets — browse category folders, preview, replace, assign to the active game.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const ImageClientScript = preload("res://scripts/ai/image_asset_client.gd")

var _empty: Label
var _root: HSplitContainer
var _cat_list: ItemList
var _file_list: ItemList
var _preview: TextureRect
var _meta: RichTextLabel
var _model_label: Label
var _model_view: SubViewport
var _model_mesh: MeshInstance3D
var _slot_option: OptionButton
var _search_edit: LineEdit
var _status: Label
var _images
var _search_results: Array = []
var _search_list: ItemList
var _current_cat: String = "all"
var _listed: Array = []
var _selected: Dictionary = {}
var _file_dialog: FileDialog


func _ready() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()
	_images = ImageClientScript.new()
	_images.attach(self)
	_images.search_done.connect(_on_search_done)
	_images.preview_ready.connect(_on_search_preview)
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
	LayoutScript.ensure_layout(path)
	ConfigScript.ensure_on_disk(path)
	_reload_files()


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game in the Create tab — Library browses that project's assets/ folders."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_root = HSplitContainer.new()
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	_root.add_child(left)
	var cat_title: Label = Label.new()
	cat_title.text = "Categories"
	cat_title.add_theme_font_size_override("font_size", 16)
	left.add_child(cat_title)
	_cat_list = ItemList.new()
	_cat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cat_list.item_selected.connect(_on_cat)
	left.add_child(_cat_list)
	_cat_list.add_item("all")
	for c in LayoutScript.CATEGORIES:
		_cat_list.add_item(c)
	_cat_list.select(0)

	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(mid)
	var mid_title: Label = Label.new()
	mid_title.text = "Assets in folder"
	mid_title.add_theme_font_size_override("font_size", 16)
	mid.add_child(mid_title)
	_file_list = ItemList.new()
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.item_selected.connect(_on_file)
	mid.add_child(_file_list)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(right)

	var prev_title: Label = Label.new()
	prev_title.text = "Preview / replace / assign"
	prev_title.add_theme_font_size_override("font_size", 16)
	right.add_child(prev_title)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 180)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_preview)

	_model_label = Label.new()
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_model_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	right.add_child(_model_label)

	var svh: SubViewportContainer = SubViewportContainer.new()
	svh.custom_minimum_size = Vector2(0, 120)
	svh.stretch = true
	right.add_child(svh)
	_model_view = SubViewport.new()
	_model_view.size = Vector2i(320, 120)
	_model_view.own_world_3d = true
	_model_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svh.add_child(_model_view)
	var world3: Node3D = Node3D.new()
	_model_view.add_child(world3)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 0.35, 1.6)
	world3.add_child(cam)
	cam.look_at(Vector3.ZERO)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	world3.add_child(light)
	_model_mesh = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	_model_mesh.mesh = box
	world3.add_child(_model_mesh)

	_meta = RichTextLabel.new()
	_meta.bbcode_enabled = true
	_meta.fit_content = true
	_meta.scroll_active = false
	_meta.custom_minimum_size = Vector2(0, 70)
	right.add_child(_meta)

	var slot_row: HBoxContainer = HBoxContainer.new()
	right.add_child(slot_row)
	var slot_l: Label = Label.new()
	slot_l.text = "Assign as"
	slot_row.add_child(slot_l)
	_slot_option = OptionButton.new()
	_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in LayoutScript.ASSIGN_SLOTS:
		_slot_option.add_item(s)
	slot_row.add_child(_slot_option)
	var assign_btn: Button = Button.new()
	assign_btn.text = "Assign to game"
	assign_btn.pressed.connect(_on_assign)
	slot_row.add_child(assign_btn)

	var local_row: HBoxContainer = HBoxContainer.new()
	right.add_child(local_row)
	var pick_btn: Button = Button.new()
	pick_btn.text = "Replace from file…"
	pick_btn.pressed.connect(_on_pick_file)
	local_row.add_child(pick_btn)
	var open_folder: Button = Button.new()
	open_folder.text = "Open assets folder"
	open_folder.pressed.connect(_on_open_folder)
	local_row.add_child(open_folder)

	var search_l: Label = Label.new()
	search_l.text = "Search CC0 replacement"
	right.add_child(search_l)
	var search_row: HBoxContainer = HBoxContainer.new()
	right.add_child(search_row)
	_search_edit = LineEdit.new()
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.placeholder_text = "cc0 brick wall seamless"
	search_row.add_child(_search_edit)
	var search_btn: Button = Button.new()
	search_btn.text = "Search"
	search_btn.pressed.connect(_on_search)
	search_row.add_child(search_btn)
	_search_list = ItemList.new()
	_search_list.custom_minimum_size = Vector2(0, 90)
	_search_list.item_selected.connect(_on_search_select)
	right.add_child(_search_list)
	var dl_btn: Button = Button.new()
	dl_btn.text = "Download selected into category"
	dl_btn.pressed.connect(_on_download_selected)
	right.add_child(dl_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
	right.add_child(_status)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.glb,*.gltf,*.obj,*.tres ; Assets"])
	_file_dialog.file_selected.connect(_on_file_picked)
	add_child(_file_dialog)


func _on_cat(idx: int) -> void:
	_current_cat = _cat_list.get_item_text(idx)
	_reload_files()


func _reload_files() -> void:
	_file_list.clear()
	_listed.clear()
	var path: String = AIOrchestrator.get_project_path()
	if _current_cat == "all":
		_listed = LayoutScript.list_all(path)
	else:
		_listed = LayoutScript.list_category(path, _current_cat)
	for item in _listed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_file_list.add_item("%s  [%s]" % [str(item.get("rel", "")), str(item.get("kind", ""))])


func _on_file(idx: int) -> void:
	if idx < 0 or idx >= _listed.size():
		return
	_selected = _listed[idx]
	_show_preview(_selected)


func _show_preview(item: Dictionary) -> void:
	var abs_path: String = str(item.get("abs", ""))
	var kind: String = str(item.get("kind", ""))
	_preview.texture = null
	_model_label.text = ""
	if kind == "image" and FileAccess.file_exists(abs_path):
		var img: Image = Image.new()
		if img.load(abs_path) == OK:
			_preview.texture = ImageTexture.create_from_image(img)
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_texture = _preview.texture
			_model_mesh.material_override = mat
			_model_mesh.mesh = BoxMesh.new()
	elif kind == "model":
		_model_label.text = "Model: %s\n%s" % [str(item.get("name", "")), abs_path]
		_model_mesh.mesh = CapsuleMesh.new()
		_model_mesh.material_override = null
	elif kind == "material":
		_model_label.text = "Material: %s" % abs_path
	_meta.text = "[b]%s[/b]\nCategory: %s\nPath: %s\nKind: %s" % [
		str(item.get("name", "")),
		str(item.get("category", "")),
		str(item.get("res", "")),
		kind,
	]


func _on_assign() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty() or _selected.is_empty():
		_status.text = "Select an asset first."
		return
	var slot: String = _slot_option.get_item_text(_slot_option.selected)
	var src: String = str(_selected.get("abs", ""))
	var dest_name: String = LayoutScript.slot_filename(slot)
	var cat: String = LayoutScript.slot_category(slot)
	var installed: Dictionary = LayoutScript.install_asset(path, src, dest_name, cat, true)
	if not installed.get("ok", false):
		_status.text = "Assign failed."
		return
	ConfigScript.assign_slot(path, slot, str(installed.get("res", "")))
	_status.text = "Assigned %s → %s (%s)" % [slot, str(installed.get("res", "")), cat]
	_reload_files()


func _on_pick_file() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_file_picked(src: String) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	var cat: String = _current_cat if _current_cat != "all" else LayoutScript.categorize(src.get_file())
	var installed: Dictionary = LayoutScript.install_asset(path, src, src.get_file(), cat, true)
	if installed.get("ok", false):
		_status.text = "Imported %s" % str(installed.get("res", ""))
		_reload_files()
	else:
		_status.text = "Import failed."


func _on_open_folder() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	var cat: String = _current_cat if _current_cat != "all" else "textures"
	OS.shell_show_in_file_manager(path.path_join("assets").path_join(cat))


func _on_search() -> void:
	var q: String = _search_edit.text.strip_edges()
	if q.is_empty():
		q = "CC0 game texture seamless"
	if not q.to_lower().contains("cc0") and not q.to_lower().contains("public domain"):
		q += " CC0"
	_status.text = "Searching open images…"
	_images.search(q)


func _on_search_done(ok: bool, results: Array, error: String) -> void:
	_search_results = results
	_search_list.clear()
	if not ok:
		_status.text = error if not error.is_empty() else "Search failed"
		return
	for r in results:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		_search_list.add_item("%s [%s]" % [str(r.get("title", "image")).left(60), str(r.get("license", ""))])
	_status.text = "%s open results" % str(results.size())


func _on_search_select(idx: int) -> void:
	_images.load_preview(idx)


func _on_search_preview(ok: bool, _index: int, texture: Texture2D, meta: Dictionary, error: String) -> void:
	if not ok:
		_status.text = error
		return
	_preview.texture = texture
	_meta.text = "[b]Search preview[/b]\n%s\nLicense: %s\n%s" % [
		str(meta.get("title", "")),
		str(meta.get("license", "")),
		str(meta.get("page", "")),
	]


func _on_download_selected() -> void:
	var idxs: PackedInt32Array = _search_list.get_selected_items()
	if idxs.is_empty():
		_status.text = "Select a search result."
		return
	var idx: int = idxs[0]
	var item: Dictionary = _images.get_result(idx)
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty() or item.is_empty():
		return
	var cat: String = _current_cat if _current_cat != "all" else LayoutScript.categorize("download.png", str(item.get("title", "")), "")
	var fname: String = "dl_%s.png" % str(Time.get_unix_time_from_system()).replace(".", "")
	var dest: String = LayoutScript.dest_abs(path, fname, cat)
	var err: Error = _images.download_full(idx, dest)
	if err != OK:
		if _preview.texture:
			var saved: Dictionary = LayoutScript.save_image_texture(path, fname, _preview.texture, cat)
			if saved.get("ok", false):
				_status.text = "Saved procedural/preview → %s" % str(saved.get("res", ""))
				_reload_files()
				return
		_status.text = "Download failed (preview first, then retry)."
		return
	LayoutScript.copy_file(dest, LayoutScript.root_alias_abs(path, fname))
	_status.text = "Downloaded → %s" % LayoutScript.dest_res(fname, cat)
	_reload_files()
