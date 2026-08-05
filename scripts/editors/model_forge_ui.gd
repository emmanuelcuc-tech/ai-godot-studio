extends MarginContainer
## Describe a model + material → Blender/Godot/Unity forge pipeline.

const ForgeScript = preload("res://scripts/model_forge.gd")
const ArtPipelineScript = preload("res://scripts/art_pipeline.gd")

var _model: TextEdit
var _material: TextEdit
var _texture: LineEdit
var _photos: PackedStringArray = PackedStringArray()
var _photo_list: Label
var _status: Label
var _log: RichTextLabel
var _tex_dialog: FileDialog
var _photo_dialog: FileDialog


func _ready() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var title := Label.new()
	title.text = "Model Forge — Studio + Blender + Unity"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	hint.text = "Describe the model, then add photos (front, optional side + back) for a closer replica. Photos wrap onto head/torso/limbs and drive Blender UVs. Studio still builds Skeleton3D + idle/walk/attack, plus .glb/.fbx if Blender is set."
	root.add_child(hint)
	var ml := Label.new()
	ml.text = "What is the model?"
	root.add_child(ml)
	_model = TextEdit.new()
	_model.custom_minimum_size.y = 72
	_model.placeholder_text = "Example: cartoon knight with a round helmet and a short cape"
	root.add_child(_model)
	var matl := Label.new()
	matl.text = "Texture or material to use"
	root.add_child(matl)
	_material = TextEdit.new()
	_material.custom_minimum_size.y = 56
	_material.placeholder_text = "Example: scratched steel armor, red cloth cape, leather brown straps  — or #c45a2a wood"
	root.add_child(_material)
	var trow := HBoxContainer.new()
	root.add_child(trow)
	_texture = LineEdit.new()
	_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texture.placeholder_text = "Optional texture file (PNG/JPG) — F:/asset/... or any path"
	trow.add_child(_texture)
	var browse := Button.new()
	browse.text = "Browse texture"
	browse.pressed.connect(_on_browse_tex)
	trow.add_child(browse)
	var prow := HBoxContainer.new()
	root.add_child(prow)
	var add_photos := Button.new()
	add_photos.text = "Add photos (front / side / back)"
	add_photos.pressed.connect(_on_browse_photos)
	prow.add_child(add_photos)
	var clear_photos := Button.new()
	clear_photos.text = "Clear photos"
	clear_photos.pressed.connect(func() -> void:
		_photos = PackedStringArray()
		_refresh_photo_list()
	)
	prow.add_child(clear_photos)
	_photo_list = Label.new()
	_photo_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_photo_list.add_theme_color_override("font_color", Color(0.72, 0.82, 0.68))
	_photo_list.text = "No photos yet — add a front shot (and side/back if you have them) for a better replica."
	root.add_child(_photo_list)
	var brow := HBoxContainer.new()
	root.add_child(brow)
	var make := Button.new()
	make.text = "Forge model (Blender + Godot + Unity kit)"
	make.pressed.connect(_on_forge)
	brow.add_child(make)
	var open_b := Button.new()
	open_b.text = "Open Blender"
	open_b.pressed.connect(_on_open_blender)
	brow.add_child(open_b)
	var open_u := Button.new()
	open_u.text = "Open Unity import"
	open_u.pressed.connect(_on_open_unity)
	brow.add_child(open_u)
	_status = Label.new()
	_status.text = "Create or open a game first, then forge a model into that project."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.bbcode_enabled = true
	_log.fit_content = false
	_log.scroll_active = true
	_log.custom_minimum_size.y = 140
	root.add_child(_log)
	_tex_dialog = FileDialog.new()
	_tex_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_tex_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_tex_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; Images"])
	_tex_dialog.file_selected.connect(func(p: String) -> void: _texture.text = p)
	add_child(_tex_dialog)
	_photo_dialog = FileDialog.new()
	_photo_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_photo_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_photo_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; Photos"])
	_photo_dialog.files_selected.connect(_on_photos_picked)
	add_child(_photo_dialog)


func _on_browse_tex() -> void:
	_tex_dialog.popup_centered_ratio(0.6)


func _on_browse_photos() -> void:
	_photo_dialog.popup_centered_ratio(0.7)


func _on_photos_picked(paths: PackedStringArray) -> void:
	for p in paths:
		var n := p.replace("\\", "/")
		if n.is_empty():
			continue
		var dup := false
		for e in _photos:
			if e == n:
				dup = true
				break
		if not dup:
			_photos.append(n)
	_refresh_photo_list()


func _refresh_photo_list() -> void:
	if _photos.is_empty():
		_photo_list.text = "No photos yet — add a front shot (and side/back if you have them) for a better replica."
		return
	var bits: PackedStringArray = PackedStringArray()
	var roles := PackedStringArray(["front", "side", "back"])
	for i in mini(_photos.size(), 8):
		var role := "extra"
		if i < roles.size():
			role = roles[i]
		var low := _photos[i].get_file().to_lower()
		if low.contains("side") or low.contains("left") or low.contains("right") or low.contains("profile"):
			role = "side"
		elif low.contains("back") or low.contains("rear"):
			role = "back"
		elif low.contains("front") or low.contains("face"):
			role = "front"
		bits.append("%s: %s" % [role, _photos[i].get_file()])
	_photo_list.text = "Photos (%d): %s" % [_photos.size(), ", ".join(bits)]


func _on_forge() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty() or not AIOrchestrator.has_active_session():
		_status.text = "No active game. Create a game on the Create tab first."
		return
	var md := _model.text.strip_edges()
	var mat := _material.text.strip_edges()
	if md.is_empty():
		_status.text = "Describe the model first."
		return
	if mat.is_empty():
		mat = "painted plastic, medium roughness"
	_status.text = "Forging…"
	var result: Dictionary = ForgeScript.forge(path, md, mat, _texture.text.strip_edges(), _photos)
	_status.text = str(result.get("message", "Done"))
	_log.append_text("\n[b]%s[/b] → %s\n%s\n" % [md, str(result.get("dir", "")), str(result.get("message", ""))])


func _on_open_blender() -> void:
	var err := ArtPipelineScript.open_blender(AppSettings.blender_executable)
	if err != OK:
		_status.text = "Blender not found. Set blender.exe in Settings."
	else:
		_status.text = "Opened Blender."


func _on_open_unity() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		_status.text = "No active game / unity_import folder yet. Forge a model first."
		return
	var err := ForgeScript.open_unity_bridge(path)
	if err != OK:
		_status.text = "Could not open Unity bridge. Forge a model first."
	else:
		_status.text = "Opened Unity import project (or folder)."
