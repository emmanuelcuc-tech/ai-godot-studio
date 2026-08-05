extends MarginContainer
## Scripts tab — view/edit GDScript + C++ paths and collision-related code for the active game.

const COLLISION_MARKERS: PackedStringArray = [
	"collision", "collider", "hitbox", "hurtbox", "area2d", "area3d",
	"raycast", "shape", "staticbody", "characterbody", "rigidbody",
	"mask", "layer", "take_damage",
]

var _empty: Label
var _root: HSplitContainer
var _list: ItemList
var _filter: OptionButton
var _editor: TextEdit
var _path_label: Label
var _status: Label
var _files: Array = []
var _current_rel: String = ""


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
	_reload_list()


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game first to browse its scripts, collision code, and C++ sources."
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
	left.custom_minimum_size = Vector2(260, 0)
	_root.add_child(left)
	var title: Label = Label.new()
	title.text = "Scripts / sources"
	title.add_theme_font_size_override("font_size", 16)
	left.add_child(title)
	_filter = OptionButton.new()
	_filter.add_item("All code")
	_filter.add_item("Collision / physics")
	_filter.add_item("GDScript only")
	_filter.add_item("C++ only")
	_filter.item_selected.connect(func(_i: int): _reload_list())
	left.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_select)
	left.add_child(_list)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(right)
	_path_label = Label.new()
	_path_label.text = "Select a file"
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.add_theme_color_override("font_color", Color(0.45, 0.78, 0.65))
	right.add_child(_path_label)
	_editor = TextEdit.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_editor)
	var row: HBoxContainer = HBoxContainer.new()
	right.add_child(row)
	var save_btn: Button = Button.new()
	save_btn.text = "Save script"
	save_btn.pressed.connect(_on_save)
	row.add_child(save_btn)
	var reload_btn: Button = Button.new()
	reload_btn.text = "Reload from disk"
	reload_btn.pressed.connect(_on_reload_current)
	row.add_child(reload_btn)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
	row.add_child(_status)


func _reload_list() -> void:
	_list.clear()
	_files.clear()
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty():
		return
	var rels: PackedStringArray = PackedStringArray()
	_walk(root, root, rels)
	var mode: int = _filter.selected
	for rel in rels:
		var ext: String = rel.get_extension().to_lower()
		var is_gd: bool = ext == "gd"
		var is_cpp: bool = ext in ["cpp", "h", "hpp", "c", "cc"]
		if not is_gd and not is_cpp:
			continue
		if mode == 2 and not is_gd:
			continue
		if mode == 3 and not is_cpp:
			continue
		if mode == 1 and not _looks_collision(root.path_join(rel)):
			continue
		_files.append(rel)
		_list.add_item(rel)
	if _files.is_empty():
		_status.text = "No matching scripts."


func _looks_collision(abs_path: String) -> bool:
	var name_l: String = abs_path.get_file().to_lower()
	for m in COLLISION_MARKERS:
		if name_l.contains(m):
			return true
	if not FileAccess.file_exists(abs_path):
		return false
	var body: String = FileAccess.get_file_as_string(abs_path).to_lower()
	if body.length() > 20000:
		body = body.left(20000)
	for m2 in COLLISION_MARKERS:
		if body.contains(m2):
			return true
	return false


func _walk(root: String, dir_path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			if n in [".godot", "godot-cpp", "addons", "refs", ".scons_cache", "build", "__pycache__"]:
				n = d.get_next()
				continue
			_walk(root, full, out)
		else:
			var rel: String = full.substr(root.length()).lstrip("/").lstrip("\\").replace("\\", "/")
			out.append(rel)
		n = d.get_next()


func _on_select(idx: int) -> void:
	if idx < 0 or idx >= _files.size():
		return
	_current_rel = str(_files[idx])
	_on_reload_current()


func _on_reload_current() -> void:
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty() or _current_rel.is_empty():
		return
	var full: String = root.path_join(_current_rel)
	_path_label.text = _current_rel
	if not FileAccess.file_exists(full):
		_editor.text = ""
		_status.text = "Missing on disk."
		return
	_editor.text = FileAccess.get_file_as_string(full)
	_status.text = "Loaded %s chars" % str(_editor.text.length())


func _on_save() -> void:
	var root: String = AIOrchestrator.get_project_path()
	if root.is_empty() or _current_rel.is_empty():
		_status.text = "Nothing to save."
		return
	var full: String = root.path_join(_current_rel)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var f: FileAccess = FileAccess.open(full, FileAccess.WRITE)
	if f == null:
		_status.text = "Could not write file."
		return
	f.store_string(_editor.text)
	_status.text = "Saved %s — Run Game to play changes." % _current_rel
