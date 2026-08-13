extends MarginContainer
## Edit Game — Add to game / Change: Character → World → Enemy → Weapon → Materials → Physics.

const LayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const ImageClientScript = preload("res://scripts/ai/image_asset_client.gd")
const GraphicStyleScript = preload("res://scripts/graphic_style.gd")
const ProceduralArtScript = preload("res://scripts/ai/procedural_art.gd")
const LocalLibScript = preload("res://scripts/editors/local_asset_library.gd")

signal applied(message: String)

var _empty: Label
var _scroll: ScrollContainer
var _status: Label
var _images
var _file_dialog: FileDialog
var _import_ctx: Dictionary = {}
var _search_ctx: Dictionary = {}
var _search_dialog: AcceptDialog
var _search_edit: LineEdit
var _search_list: ItemList
var _search_results: Array = []
var _opt_items: Dictionary = {}

var _char_preview: TextureRect
var _char_tex: OptionButton
var _char_spr: OptionButton
var _char_mdl: OptionButton
var _char_mat: OptionButton
var _char_shape: OptionButton
var _phys_char: CheckButton

var _world_preview: TextureRect
var _floor_opt: OptionButton
var _wall_opt: OptionButton
var _sky_opt: OptionButton
var _floor_mat: OptionButton
var _wall_mat: OptionButton
var _sky_mat: OptionButton
var _phys_world: CheckButton

var _enemy_preview: TextureRect
var _enemy_tex: OptionButton
var _enemy_mdl: OptionButton
var _enemy_mat: OptionButton
var _enemy_anim: OptionButton
var _enemy_fps: SpinBox
var _enemy_loop: CheckButton
var _phys_enemy: CheckButton

var _wep_preview: TextureRect
var _wep_tex: OptionButton
var _wep_mdl: OptionButton
var _wep_spr: OptionButton
var _wep_mat: OptionButton
var _phys_wep: CheckButton

var _mat_preview: TextureRect
var _mat_opt: OptionButton
var _mat_slot: OptionButton
var _phys_list: ItemList
var _phys_local_items: Array = []
var _more_dialog: AcceptDialog
var _more_list: ItemList
var _more_items: Array = []
var _more_section: String = ""

## Live enemy anim preview — replaces the static photo as soon as a clip is picked.
var _live_frames: Array = []
var _live_fps: float = 8.0
var _live_loop: bool = true
var _live_t: float = 0.0
var _live_i: int = 0
var _live_active: bool = false


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_bottom", 8)
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
	_scroll.visible = active
	if not active:
		_status.text = "Create a game first. After Run, Add / Change still works on this session."
		return
	LayoutScript.ensure_layout(path)
	ConfigScript.ensure_on_disk(path)
	ProceduralArtScript.set_styles(GraphicStyleScript.from_variant(ConfigScript.load_style(path).get("graphic_styles", [])))
	ProceduralArtScript.ensure_kit_variants(path)
	_reload_all_options()
	_status.text = "Session active — Add merges; Change replaces that slot only."


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game, then use Edit Game to add more from F:/asset (textures, materials, models, physics)."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	_scroll.add_child(col)

	var title: Label = Label.new()
	title.text = "Add to game / Change"
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var hint: Label = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.78))
	hint.text = "Lists F:/asset first, then this game’s assets/. Add copies into the project (no F: link at runtime). Change replaces that slot only. After testing, add more anytime."
	col.add_child(hint)

	var add_all: Button = Button.new()
	add_all.text = "Add to game"
	add_all.tooltip_text = "Merge every section’s current picks into the running game session without clearing other slots."
	add_all.pressed.connect(_on_add_all)
	col.add_child(add_all)

	_char_preview = TextureRect.new()
	_char_tex = OptionButton.new()
	_char_spr = OptionButton.new()
	_char_mdl = OptionButton.new()
	_char_mat = OptionButton.new()
	_char_shape = OptionButton.new()
	_char_shape.add_item("capsule")
	_char_shape.add_item("humanoid")
	_char_shape.add_item("box")
	_phys_char = CheckButton.new()
	_phys_char.text = "Physics collision (CharacterBody)"
	_phys_char.button_pressed = true
	col.add_child(_section_box("2. Character — Change character", _char_preview, [
		_labeled_row("Texture", _char_tex),
		_labeled_row("Sprite", _char_spr),
		_labeled_row("Model", _char_mdl),
		_labeled_row("Material", _char_mat),
		_labeled_row("New model shape", _char_shape),
		_phys_char,
	], func(): _on_section_add("character"), func(): _on_section_change("character"), func(): _generate_section("character"), func(): _download_section("character"), func(): _import_section("character"), func(): _open_add_more("character")))

	_world_preview = TextureRect.new()
	_floor_opt = OptionButton.new()
	_wall_opt = OptionButton.new()
	_sky_opt = OptionButton.new()
	_floor_mat = OptionButton.new()
	_wall_mat = OptionButton.new()
	_sky_mat = OptionButton.new()
	_phys_world = CheckButton.new()
	_phys_world.text = "StaticBody collision on floor / walls"
	_phys_world.button_pressed = true
	col.add_child(_section_box("3. World — floor / walls / skybox", _world_preview, [
		_labeled_row("Floor texture", _floor_opt),
		_labeled_row("Wall texture", _wall_opt),
		_labeled_row("Skybox", _sky_opt),
		_labeled_row("Floor material", _floor_mat),
		_labeled_row("Wall material", _wall_mat),
		_labeled_row("Skybox material", _sky_mat),
		_phys_world,
	], func(): _on_section_add("world"), func(): _on_section_change("world"), func(): _generate_section("world"), func(): _download_section("world"), func(): _import_section("world"), func(): _open_add_more("world")))

	_enemy_preview = TextureRect.new()
	_enemy_tex = OptionButton.new()
	_enemy_mdl = OptionButton.new()
	_enemy_mat = OptionButton.new()
	_enemy_anim = OptionButton.new()
	_enemy_fps = SpinBox.new()
	_enemy_fps.min_value = 1.0
	_enemy_fps.max_value = 60.0
	_enemy_fps.step = 0.5
	_enemy_fps.value = 8.0
	_enemy_loop = CheckButton.new()
	_enemy_loop.text = "Loop"
	_enemy_loop.button_pressed = true
	_phys_enemy = CheckButton.new()
	_phys_enemy.text = "Physics collision (CharacterBody)"
	_phys_enemy.button_pressed = true
	col.add_child(_section_box("4. Enemy — textures / models / animation", _enemy_preview, [
		_labeled_row("Texture", _enemy_tex),
		_labeled_row("Model", _enemy_mdl),
		_labeled_row("Material", _enemy_mat),
		_labeled_row("Anim clip", _enemy_anim),
		_anim_row(),
		_phys_enemy,
	], func(): _on_section_add("enemy"), func(): _on_section_change("enemy"), func(): _generate_section("enemy"), func(): _download_section("enemy"), func(): _import_section("enemy"), func(): _open_add_more("enemy")))

	_wep_preview = TextureRect.new()
	_wep_tex = OptionButton.new()
	_wep_mdl = OptionButton.new()
	_wep_spr = OptionButton.new()
	_wep_mat = OptionButton.new()
	_phys_wep = CheckButton.new()
	_phys_wep.text = "RigidBody debris / projectiles"
	_phys_wep.button_pressed = true
	col.add_child(_section_box("5. Weapon — textures / models / sprites", _wep_preview, [
		_labeled_row("Texture", _wep_tex),
		_labeled_row("Model", _wep_mdl),
		_labeled_row("Sprite (2D)", _wep_spr),
		_labeled_row("Material", _wep_mat),
		_phys_wep,
	], func(): _on_section_add("weapon"), func(): _on_section_change("weapon"), func(): _generate_section("weapon"), func(): _download_section("weapon"), func(): _import_section("weapon"), func(): _open_add_more("weapon")))

	_mat_preview = TextureRect.new()
	_mat_opt = OptionButton.new()
	_mat_slot = OptionButton.new()
	for s in ["wall_material", "floor_material", "skybox_material", "character_material", "enemy_material", "weapon_material"]:
		_mat_slot.add_item(s)
	col.add_child(_section_box("6. Materials — .tres / StandardMaterial3D", _mat_preview, [
		_labeled_row("Material", _mat_opt),
		_labeled_row("Assign as", _mat_slot),
	], func(): _on_section_add("materials"), func(): _on_section_change("materials"), func(): _generate_section("materials"), func(): _download_section("world"), func(): _import_section("materials"), func(): _open_add_more("materials")))

	_phys_list = ItemList.new()
	_phys_list.custom_minimum_size = Vector2(0, 90)
	var phys_box: VBoxContainer = VBoxContainer.new()
	var phys_h: Label = Label.new()
	phys_h.text = "7. Physics — local F:/asset helpers + Godot/Jolt"
	phys_h.add_theme_font_size_override("font_size", 15)
	phys_box.add_child(phys_h)
	var phys_hint: Label = Label.new()
	phys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phys_hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.78))
	phys_hint.text = "C# PhysKit player is skipped (keeps Run Game GDScript-only). Add copies fixed_joint / grab pivot into addons/f_asset_physics/."
	phys_box.add_child(phys_hint)
	phys_box.add_child(_phys_list)
	var prow: HBoxContainer = HBoxContainer.new()
	phys_box.add_child(prow)
	var padd: Button = Button.new()
	padd.text = "Add to game"
	padd.pressed.connect(_on_section_add.bind("physics"))
	prow.add_child(padd)
	var pch: Button = Button.new()
	pch.text = "Change"
	pch.pressed.connect(_on_section_change.bind("physics"))
	prow.add_child(pch)
	var pmore: Button = Button.new()
	pmore.text = "Add more"
	pmore.pressed.connect(_open_add_more.bind("physics"))
	prow.add_child(pmore)
	col.add_child(phys_box)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
	col.add_child(_status)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.glb,*.gltf,*.obj ; Assets"])
	_file_dialog.file_selected.connect(_on_file_picked)
	add_child(_file_dialog)

	_search_dialog = AcceptDialog.new()
	_search_dialog.title = "Download CC0"
	_search_dialog.ok_button_text = "Download into folder"
	_search_dialog.confirmed.connect(_on_search_download)
	var sbox: VBoxContainer = VBoxContainer.new()
	sbox.custom_minimum_size = Vector2(420, 260)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "CC0 search…"
	sbox.add_child(_search_edit)
	var srow: HBoxContainer = HBoxContainer.new()
	sbox.add_child(srow)
	var sbtn: Button = Button.new()
	sbtn.text = "Search"
	sbtn.pressed.connect(_on_search_go)
	srow.add_child(sbtn)
	_search_list = ItemList.new()
	_search_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_search_list.custom_minimum_size = Vector2(0, 160)
	_search_list.item_selected.connect(func(idx): _images.load_preview(idx))
	sbox.add_child(_search_list)
	_search_dialog.add_child(sbox)
	add_child(_search_dialog)

	_more_dialog = AcceptDialog.new()
	_more_dialog.title = "Add more from F:/asset"
	_more_dialog.ok_button_text = "Copy into game"
	_more_dialog.confirmed.connect(_on_more_confirmed)
	var mbox: VBoxContainer = VBoxContainer.new()
	mbox.custom_minimum_size = Vector2(460, 280)
	var mhint: Label = Label.new()
	mhint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mhint.text = "Select one or more local files. Copy keeps the current slot; then Add to game / Change to assign."
	mbox.add_child(mhint)
	_more_list = ItemList.new()
	_more_list.select_mode = ItemList.SELECT_MULTI
	_more_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_more_list.custom_minimum_size = Vector2(0, 200)
	mbox.add_child(_more_list)
	_more_dialog.add_child(mbox)
	add_child(_more_dialog)

	_char_tex.item_selected.connect(func(_i): _preview_from(_char_tex, _char_preview))
	_char_spr.item_selected.connect(func(_i): _preview_from(_char_spr, _char_preview))
	_floor_opt.item_selected.connect(func(_i): _preview_from(_floor_opt, _world_preview))
	_wall_opt.item_selected.connect(func(_i): _preview_from(_wall_opt, _world_preview))
	_sky_opt.item_selected.connect(func(_i): _preview_from(_sky_opt, _world_preview))
	_enemy_tex.item_selected.connect(func(_i):
		_stop_live_anim_preview()
		_preview_from(_enemy_tex, _enemy_preview)
	)
	_wep_tex.item_selected.connect(func(_i): _preview_from(_wep_tex, _wep_preview))
	_wep_spr.item_selected.connect(func(_i): _preview_from(_wep_spr, _wep_preview))
	_enemy_anim.item_selected.connect(_on_enemy_anim_selected)
	_enemy_fps.value_changed.connect(func(v: float):
		_live_fps = v
	)
	_enemy_loop.toggled.connect(func(pressed: bool):
		_live_loop = pressed
	)


func _section_box(title_text: String, preview: TextureRect, rows: Array, add_cb: Callable, change_cb: Callable, gen_cb: Callable, dl_cb: Callable, imp_cb: Callable, more_cb: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head: Label = Label.new()
	head.text = title_text
	head.add_theme_font_size_override("font_size", 15)
	box.add_child(head)
	# Enemy preview is taller so live clip playback is easier to see.
	preview.custom_minimum_size = Vector2(0, 96 if preview == _enemy_preview else 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(preview)
	for row in rows:
		if row is Control:
			box.add_child(row)
	var tools: HBoxContainer = HBoxContainer.new()
	box.add_child(tools)
	var gen: Button = Button.new()
	gen.text = "Generate new"
	gen.pressed.connect(gen_cb)
	tools.add_child(gen)
	var dl: Button = Button.new()
	dl.text = "Download CC0"
	dl.pressed.connect(dl_cb)
	tools.add_child(dl)
	var imp: Button = Button.new()
	imp.text = "Import file"
	imp.pressed.connect(imp_cb)
	tools.add_child(imp)
	var actions: HBoxContainer = HBoxContainer.new()
	box.add_child(actions)
	var add_btn: Button = Button.new()
	add_btn.text = "Add to game"
	add_btn.tooltip_text = "Assign this section. Keeps the previous file as a variant in the folder."
	add_btn.pressed.connect(add_cb)
	actions.add_child(add_btn)
	var ch_btn: Button = Button.new()
	ch_btn.text = "Change"
	ch_btn.tooltip_text = "Replace this section’s slot only. Other sections stay."
	ch_btn.pressed.connect(change_cb)
	actions.add_child(ch_btn)
	var more_btn: Button = Button.new()
	more_btn.text = "Add more"
	more_btn.tooltip_text = "Copy extra files from F:/asset into this game without replacing the current slot."
	more_btn.pressed.connect(more_cb)
	actions.add_child(more_btn)
	var sep: HSeparator = HSeparator.new()
	box.add_child(sep)
	return box


func _labeled_row(caption: String, opt: OptionButton) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var lab: Label = Label.new()
	lab.text = caption
	lab.custom_minimum_size.x = 110
	row.add_child(lab)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true
	row.add_child(opt)
	return row


func _anim_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var lab: Label = Label.new()
	lab.text = "FPS / loop"
	lab.custom_minimum_size.x = 110
	row.add_child(lab)
	row.add_child(_enemy_fps)
	row.add_child(_enemy_loop)
	return row


func _reload_all_options() -> void:
	var path: String = AIOrchestrator.get_project_path()
	var assets: Dictionary = ConfigScript.load_assets(path)
	var assigns: Dictionary = assets.get("assignments", {}) if typeof(assets.get("assignments", {})) == TYPE_DICTIONARY else {}
	_fill_opt(_char_tex, path, ["character", "textures", "sprites"], "image", str(assigns.get("character_texture", "")))
	_fill_opt(_char_spr, path, ["character", "sprites"], "image", str(assigns.get("character_sprite", assigns.get("character", ""))))
	_fill_opt(_char_mdl, path, ["character", "models"], "model", str(assigns.get("character_model", "")))
	_fill_opt(_char_mat, path, ["materials"], "material", str(assigns.get("character_material", "")))
	_fill_opt(_floor_opt, path, ["world", "textures"], "image", str(assigns.get("floor", "")), ["floor", "ground", "dirt", "grass", "concrete", "asphalt"])
	_fill_opt(_wall_opt, path, ["world", "textures"], "image", str(assigns.get("wall", "")), ["wall", "brick", "stone", "wood", "metal", "concrete"])
	_fill_opt(_sky_opt, path, ["world", "background", "textures"], "image", str(assigns.get("skybox", assigns.get("sky", ""))), ["sky", "skybox", "background", "horizon", "ceiling"])
	_fill_opt(_floor_mat, path, ["materials"], "material", str(assigns.get("floor_material", "")))
	_fill_opt(_wall_mat, path, ["materials"], "material", str(assigns.get("wall_material", "")))
	_fill_opt(_sky_mat, path, ["materials"], "material", str(assigns.get("skybox_material", "")))
	_fill_opt(_enemy_tex, path, ["enemy", "textures", "sprites"], "image", str(assigns.get("enemy_texture", assigns.get("enemy", ""))))
	_fill_opt(_enemy_mdl, path, ["enemy", "models"], "model", str(assigns.get("enemy_model", "")))
	_fill_opt(_enemy_mat, path, ["materials"], "material", str(assigns.get("enemy_material", "")))
	_fill_opt(_wep_tex, path, ["weapon", "textures"], "image", str(assigns.get("weapon_texture", assigns.get("weapon", ""))))
	_fill_opt(_wep_mdl, path, ["weapon", "models"], "model", str(assigns.get("weapon_model", "")))
	_fill_opt(_wep_spr, path, ["weapon", "sprites"], "image", str(assigns.get("weapon_sprite", assigns.get("weapon", ""))))
	_fill_opt(_wep_mat, path, ["materials"], "material", str(assigns.get("weapon_material", "")))
	_fill_opt(_mat_opt, path, ["materials"], "material", str(assigns.get("wall_material", "")))
	_reload_phys_list()
	var phys: Dictionary = ConfigScript.load_physics(path)
	_phys_char.set_pressed_no_signal(bool(phys.get("character_collision", true)))
	_phys_world.set_pressed_no_signal(bool(phys.get("world_static", true)))
	_phys_enemy.set_pressed_no_signal(bool(phys.get("enemy_collision", true)))
	_phys_wep.set_pressed_no_signal(bool(phys.get("weapon_rigid", true)))
	_preview_from(_char_spr, _char_preview)
	if _char_preview.texture == null:
		_preview_from(_char_tex, _char_preview)
	_preview_from(_wall_opt, _world_preview)
	if _world_preview.texture == null:
		_preview_from(_floor_opt, _world_preview)
	if _world_preview.texture == null:
		_preview_from(_sky_opt, _world_preview)
	_preview_from(_enemy_tex, _enemy_preview)
	_preview_from(_wep_tex, _wep_preview)
	if _wep_preview.texture == null:
		_preview_from(_wep_spr, _wep_preview)
	# Anim clip last so live playback replaces the enemy photo immediately.
	_reload_enemy_anims(path, str(assigns.get("enemy_anim", "idle")))


func _fill_opt(opt: OptionButton, project_path: String, cats: Array, kind: String, selected_res: String, name_hints: Array = []) -> void:
	opt.clear()
	var items: Array = [{"res": "", "abs": "", "name": "(none)", "kind": kind}]
	var seen: Dictionary = {}
	var local_section: String = _local_section_for_opt(opt)
	for row in LocalLibScript.list_for(local_section, kind if kind != "image" else ""):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var lk: String = str(row.get("kind", ""))
		if kind == "image" and lk != "image":
			continue
		if kind == "model" and lk != "model":
			continue
		if kind == "material" and lk != "material":
			continue
		var abs_l: String = str(row.get("abs", ""))
		if abs_l.is_empty() or seen.has(abs_l):
			continue
		if not name_hints.is_empty() and kind == "image":
			var nm_l: String = str(row.get("name", "")).to_lower() + " " + str(row.get("rel", "")).to_lower()
			var hit_l: bool = false
			for h in name_hints:
				if nm_l.contains(str(h)):
					hit_l = true
					break
			if not hit_l and local_section == "world":
				hit_l = true
			if not hit_l:
				continue
		seen[abs_l] = true
		var local_row: Dictionary = row.duplicate(true)
		local_row["name"] = str(row.get("label", row.get("name", "")))
		local_row["local"] = true
		items.append(local_row)
	for cat in cats:
		for row in LayoutScript.list_category(project_path, str(cat)):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if str(row.get("kind", "")) != kind:
				continue
			var res_p: String = str(row.get("res", ""))
			if res_p.is_empty() or seen.has(res_p):
				continue
			if not name_hints.is_empty():
				var nm: String = str(row.get("name", "")).to_lower()
				var hit: bool = false
				for h in name_hints:
					if nm.contains(str(h)):
						hit = true
						break
				if not hit and cat != "world" and cat != "background":
					continue
				if not hit and kind == "image" and (cat == "world" or cat == "background" or cat == "textures"):
					# still allow exact assigned path even if name does not match hints
					if res_p != selected_res:
						continue
			seen[res_p] = true
			items.append(row)
	for vres in ConfigScript.list_variants(project_path, _slot_for_opt(opt)):
		if seen.has(vres):
			continue
		var rel: String = vres.trim_prefix("res://")
		var abs_p: String = project_path.path_join(rel)
		if FileAccess.file_exists(abs_p):
			seen[vres] = true
			items.append({"res": vres, "abs": abs_p, "name": vres.get_file(), "kind": kind})
	_opt_items[opt.get_instance_id()] = items
	var select_idx: int = 0
	for i in items.size():
		var it: Dictionary = items[i]
		opt.add_item(str(it.get("name", it.get("res", "?"))))
		if str(it.get("res", "")) == selected_res and not selected_res.is_empty():
			select_idx = i
	if opt.item_count > 0:
		opt.select(select_idx)


func _slot_for_opt(opt: OptionButton) -> String:
	if opt == _char_tex:
		return "character_texture"
	if opt == _char_spr:
		return "character_sprite"
	if opt == _char_mdl:
		return "character_model"
	if opt == _char_mat:
		return "character_material"
	if opt == _floor_opt:
		return "floor"
	if opt == _wall_opt:
		return "wall"
	if opt == _sky_opt:
		return "skybox"
	if opt == _floor_mat:
		return "floor_material"
	if opt == _wall_mat:
		return "wall_material"
	if opt == _sky_mat:
		return "skybox_material"
	if opt == _enemy_tex:
		return "enemy_texture"
	if opt == _enemy_mdl:
		return "enemy_model"
	if opt == _enemy_mat:
		return "enemy_material"
	if opt == _wep_tex:
		return "weapon_texture"
	if opt == _wep_mdl:
		return "weapon_model"
	if opt == _wep_spr:
		return "weapon_sprite"
	if opt == _wep_mat:
		return "weapon_material"
	if opt == _mat_opt:
		if _mat_slot and _mat_slot.item_count > 0:
			return _mat_slot.get_item_text(_mat_slot.selected)
		return "wall_material"
	return ""


func _local_section_for_opt(opt: OptionButton) -> String:
	if opt == _char_tex or opt == _char_spr or opt == _char_mdl or opt == _char_mat:
		return "character"
	if opt == _floor_opt or opt == _wall_opt or opt == _sky_opt or opt == _floor_mat or opt == _wall_mat or opt == _sky_mat:
		return "world"
	if opt == _enemy_tex or opt == _enemy_mdl or opt == _enemy_mat:
		return "enemy"
	if opt == _wep_tex or opt == _wep_mdl or opt == _wep_spr or opt == _wep_mat:
		return "weapon"
	if opt == _mat_opt:
		return "materials"
	return "world"


func _reload_phys_list() -> void:
	_phys_list.clear()
	_phys_local_items.clear()
	for row in LocalLibScript.list_for("physics"):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("kind", "")) == "cs":
			_phys_list.add_item("%s  (C# skipped)" % str(row.get("label", row.get("name", ""))))
		else:
			_phys_list.add_item(str(row.get("label", row.get("name", ""))))
		_phys_local_items.append(row)


func _reload_enemy_anims(project_path: String, selected: String) -> void:
	_enemy_anim.clear()
	var data: Dictionary = ConfigScript.load_anim(project_path)
	var anims: Variant = data.get("animations", [])
	var names: PackedStringArray = PackedStringArray(["idle", "walk", "hit", "death"])
	if typeof(anims) == TYPE_ARRAY:
		for a in anims:
			if typeof(a) != TYPE_DICTIONARY:
				continue
			var nm: String = str(a.get("name", "")).strip_edges()
			if nm.is_empty() or names.has(nm):
				continue
			names.append(nm)
	var sel: int = 0
	for i in names.size():
		_enemy_anim.add_item(names[i])
		if names[i] == selected:
			sel = i
	if _enemy_anim.item_count > 0:
		_enemy_anim.select(sel)
	_on_enemy_anim_selected(sel)


func _on_enemy_anim_selected(_idx: int) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty() or _enemy_anim.item_count == 0:
		_stop_live_anim_preview()
		return
	var clip: String = _enemy_anim.get_item_text(_enemy_anim.selected)
	var data: Dictionary = ConfigScript.load_anim(path)
	var anims: Variant = data.get("animations", [])
	var row: Dictionary = {}
	if typeof(anims) == TYPE_ARRAY:
		for a in anims:
			if typeof(a) == TYPE_DICTIONARY and str(a.get("name", "")) == clip:
				row = a
				break
	if not row.is_empty():
		_enemy_fps.set_value_no_signal(float(row.get("fps", 8.0)))
		_enemy_loop.set_pressed_no_signal(bool(row.get("loop", true)))
	var fps: float = float(_enemy_fps.value)
	var loop: bool = _enemy_loop.button_pressed
	var frames: Array = _resolve_clip_frame_textures(path, clip, row)
	# Replace the enemy photo right away and play the clip live in the preview.
	_start_live_anim_preview(frames, fps, loop)
	if frames.size() > 1:
		_status.text = "Live preview: %s (%d frames @ %.1f fps)" % [clip, frames.size(), fps]
	elif frames.size() == 1:
		_status.text = "Preview: %s (1 frame — add sprite frames in Animation tab for a multi-frame clip)" % clip
	else:
		_status.text = "No frames for %s yet — pick a texture or add frames in Animation." % clip


func _process(delta: float) -> void:
	if not _live_active or _live_frames.is_empty() or _enemy_preview == null:
		return
	if _live_frames.size() == 1:
		_enemy_preview.texture = _live_frames[0]
		return
	_live_t += delta
	var frame_dur: float = 1.0 / maxf(_live_fps, 0.01)
	while _live_t >= frame_dur:
		_live_t -= frame_dur
		_live_i += 1
		if _live_i >= _live_frames.size():
			if _live_loop:
				_live_i = 0
			else:
				_live_i = _live_frames.size() - 1
				_live_active = false
				break
		_enemy_preview.texture = _live_frames[_live_i]


func _start_live_anim_preview(frames: Array, fps: float, loop: bool) -> void:
	_live_frames = frames
	_live_fps = fps
	_live_loop = loop
	_live_t = 0.0
	_live_i = 0
	_live_active = not frames.is_empty()
	if _enemy_preview == null:
		return
	if frames.is_empty():
		# Keep whatever photo/texture is already shown.
		return
	_enemy_preview.texture = frames[0]


func _stop_live_anim_preview() -> void:
	_live_active = false
	_live_frames = []
	_live_t = 0.0
	_live_i = 0


func _resolve_clip_frame_textures(project_path: String, clip: String, row: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var listed: Variant = row.get("frames", []) if not row.is_empty() else []
	if typeof(listed) == TYPE_ARRAY:
		for p in listed:
			var tex: Texture2D = _load_preview_texture(project_path, str(p))
			if tex == null:
				continue
			var key: String = str(p)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(tex)
	if out.is_empty():
		# Fall back to images whose filenames mention the clip (enemy / sprites / character).
		var clip_l: String = clip.to_lower()
		for cat in ["enemy", "sprites", "character"]:
			for item in LayoutScript.list_category(project_path, cat):
				if typeof(item) != TYPE_DICTIONARY:
					continue
				if str(item.get("kind", "")) != "image":
					continue
				var fname: String = str(item.get("name", item.get("res", ""))).get_file().to_lower()
				if not fname.contains(clip_l):
					continue
				var abs_path: String = str(item.get("abs", ""))
				var tex2: Texture2D = _load_preview_texture(project_path, abs_path)
				if tex2 == null:
					continue
				if seen.has(abs_path):
					continue
				seen[abs_path] = true
				out.append(tex2)
	if out.is_empty():
		# Last resort: current enemy texture as a single-frame stand-in so the photo still updates.
		var item: Dictionary = _selected_item(_enemy_tex)
		var abs_tex: String = str(item.get("abs", ""))
		var fallback: Texture2D = _load_preview_texture(project_path, abs_tex)
		if fallback != null:
			out.append(fallback)
	return out


func _load_preview_texture(project_path: String, path: String) -> Texture2D:
	if path.is_empty():
		return null
	var abs_path: String = path
	if path.begins_with("res://"):
		abs_path = project_path.path_join(path.substr(6))
	elif path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	if not LayoutScript.IMAGE_EXTS.has(abs_path.get_extension().to_lower()):
		return null
	var img: Image = Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _selected_item(opt: OptionButton) -> Dictionary:
	var items: Array = _opt_items.get(opt.get_instance_id(), [])
	if opt.selected < 0 or opt.selected >= items.size():
		return {}
	var row: Variant = items[opt.selected]
	return row if typeof(row) == TYPE_DICTIONARY else {}


func _preview_from(opt: OptionButton, preview: TextureRect) -> void:
	var item: Dictionary = _selected_item(opt)
	var abs_path: String = str(item.get("abs", ""))
	preview.texture = null
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return
	if not LayoutScript.IMAGE_EXTS.has(abs_path.get_extension().to_lower()):
		return
	var img: Image = Image.new()
	if img.load(abs_path) == OK:
		preview.texture = ImageTexture.create_from_image(img)


func _kinds() -> Dictionary:
	return ProceduralArtScript.normalize_kinds({
		"textures": AppSettings.use_art_textures,
		"sprites": AppSettings.use_art_sprites,
		"models": AppSettings.use_art_models,
	})


func _on_add_all() -> void:
	_apply_section("character", false)
	_apply_section("world", false)
	_apply_section("enemy", false)
	_apply_section("weapon", false)
	_finish("Added character + world + enemy + weapon into the game (merge). Run Game or restart play to see updates.")


func _on_section_add(section: String) -> void:
	_apply_section(section, false)
	_finish("Added %s (previous kept as variant). Other sections unchanged." % section)


func _on_section_change(section: String) -> void:
	_apply_section(section, true)
	_finish("Changed %s slot only." % section)


func _apply_section(section: String, replace: bool) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		_status.text = "No active game."
		return
	ConfigScript.ensure_on_disk(path)
	match section:
		"character":
			_apply_pick(path, "character_texture", _char_tex, replace)
			_apply_pick(path, "character_sprite", _char_spr, replace)
			_apply_pick(path, "character_model", _char_mdl, replace)
			_apply_pick(path, "character_material", _char_mat, replace)
			var spr_res: String = str(_selected_item(_char_spr).get("res", ""))
			if not spr_res.is_empty():
				ConfigScript.assign_slot(path, "character", spr_res)
			if not _has_explicit_mat(_char_mat):
				_write_mat_from_tex(path, "character_material", "character_texture")
			_save_phys(path, "character_collision", _phys_char.button_pressed)
		"world":
			_apply_pick(path, "floor", _floor_opt, replace)
			_apply_pick(path, "wall", _wall_opt, replace)
			_apply_pick(path, "skybox", _sky_opt, replace)
			_apply_pick(path, "sky", _sky_opt, replace)
			_apply_pick(path, "floor_material", _floor_mat, replace)
			_apply_pick(path, "wall_material", _wall_mat, replace)
			_apply_pick(path, "skybox_material", _sky_mat, replace)
			if not _has_explicit_mat(_wall_mat):
				_write_mat_from_tex(path, "wall_material", "wall")
			if not _has_explicit_mat(_floor_mat):
				_write_mat_from_tex(path, "floor_material", "floor")
			if not _has_explicit_mat(_sky_mat):
				_write_mat_from_tex(path, "skybox_material", "skybox")
			_save_phys(path, "world_static", _phys_world.button_pressed)
		"enemy":
			_apply_pick(path, "enemy_texture", _enemy_tex, replace)
			_apply_pick(path, "enemy", _enemy_tex, replace)
			_apply_pick(path, "enemy_model", _enemy_mdl, replace)
			_apply_pick(path, "enemy_material", _enemy_mat, replace)
			_apply_enemy_anim(path)
			if not _has_explicit_mat(_enemy_mat):
				_write_mat_from_tex(path, "enemy_material", "enemy_texture")
			_save_phys(path, "enemy_collision", _phys_enemy.button_pressed)
		"weapon":
			_apply_pick(path, "weapon_texture", _wep_tex, replace)
			_apply_pick(path, "weapon_model", _wep_mdl, replace)
			_apply_pick(path, "weapon_sprite", _wep_spr, replace)
			_apply_pick(path, "weapon_material", _wep_mat, replace)
			var spr: String = str(_selected_item(_wep_spr).get("res", ""))
			if spr.is_empty():
				spr = str(_selected_item(_wep_tex).get("res", ""))
			if not spr.is_empty():
				if replace:
					ConfigScript.change_slot(path, "weapon", spr)
				else:
					ConfigScript.add_to_slot(path, "weapon", spr)
			if not _has_explicit_mat(_wep_mat):
				_write_mat_from_tex(path, "weapon_material", "weapon_texture")
			_save_phys(path, "weapon_rigid", _phys_wep.button_pressed)
		"materials":
			if _mat_slot.item_count > 0:
				_apply_pick(path, _mat_slot.get_item_text(_mat_slot.selected), _mat_opt, replace)
		"physics":
			var phys_info: Dictionary = LocalLibScript.install_physics_helpers(path)
			var sel: PackedInt32Array = _phys_list.get_selected_items()
			if not sel.is_empty() and sel[0] >= 0 and sel[0] < _phys_local_items.size():
				var row: Dictionary = _phys_local_items[sel[0]]
				if str(row.get("kind", "")) != "cs":
					var addon_abs: String = path.path_join("addons/f_asset_physics")
					DirAccess.make_dir_recursive_absolute(addon_abs)
					var dest_name: String = str(row.get("name", "extra")).to_lower().replace(" ", "_")
					LayoutScript.copy_file(str(row.get("abs", "")), addon_abs.path_join(dest_name))
			_status.text = "Physics helpers → %s (C# skipped)." % str(phys_info.get("addon", "addons/f_asset_physics"))
	_reload_all_options()


func _has_explicit_mat(opt: OptionButton) -> bool:
	var item: Dictionary = _selected_item(opt)
	return bool(item.get("local", false)) or not str(item.get("res", "")).strip_edges().is_empty()


func _write_mat_from_tex(path: String, mat_slot: String, tex_slot: String) -> void:
	var albedo: String = ConfigScript.assigned(path, tex_slot)
	if albedo.is_empty():
		return
	var mat_res: String = ConfigScript.write_material_file(path, mat_slot, albedo)
	if not mat_res.is_empty():
		ConfigScript.assign_slot(path, mat_slot, mat_res)


func _save_phys(path: String, key: String, value: bool) -> void:
	var phys: Dictionary = ConfigScript.load_physics(path)
	phys[key] = value
	ConfigScript.save_physics(path, phys)


func _apply_pick(path: String, slot: String, opt: OptionButton, replace: bool) -> void:
	var item: Dictionary = _selected_item(opt)
	var res_p: String = str(item.get("res", "")).strip_edges()
	if bool(item.get("local", false)):
		var cat: String = LayoutScript.slot_category(slot)
		if cat.is_empty():
			cat = "textures"
		var installed: Dictionary = LocalLibScript.import_file(path, str(item.get("abs", "")), cat)
		if not installed.get("ok", false):
			return
		res_p = str(installed.get("res", ""))
		item["res"] = res_p
		var items: Array = _opt_items.get(opt.get_instance_id(), [])
		if opt.selected >= 0 and opt.selected < items.size():
			items[opt.selected] = item
	if res_p.is_empty():
		return
	if replace:
		ConfigScript.change_slot(path, slot, res_p)
	else:
		ConfigScript.add_to_slot(path, slot, res_p)


func _apply_enemy_anim(path: String) -> void:
	if _enemy_anim.item_count == 0:
		return
	var clip: String = _enemy_anim.get_item_text(_enemy_anim.selected)
	ConfigScript.upsert_anim_clip(path, clip, float(_enemy_fps.value), _enemy_loop.button_pressed, true)
	ConfigScript.change_slot(path, "enemy_anim", clip)


func _generate_section(section: String) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	ProceduralArtScript.set_styles(GraphicStyleScript.from_variant(ConfigScript.load_style(path).get("graphic_styles", AppSettings.graphic_styles)))
	var kinds: Dictionary = _kinds()
	match section:
		"character":
			if bool(kinds.get("textures", true)):
				ProceduralArtScript.write_unique(path, "character", "png", "character", "skin")
			if bool(kinds.get("sprites", true)):
				ProceduralArtScript.write_unique(path, "sprite_player", "png", "character", "hero")
			if bool(kinds.get("models", true)):
				ProceduralArtScript.write_shape_model(path, "character", "character", _char_shape.get_item_text(_char_shape.selected))
			_write_mat_from_tex(path, "character_material", "character_texture")
		"world":
			if bool(kinds.get("textures", true)):
				ProceduralArtScript.write_unique(path, "floor", "png", "world", "concrete")
				ProceduralArtScript.write_unique(path, "wall", "png", "world", "brick")
				ProceduralArtScript.write_unique(path, "sky", "png", "world", "sky")
				ProceduralArtScript.write_unique(path, "skybox", "png", "background", "sky")
			_write_mat_from_tex(path, "wall_material", "wall")
			_write_mat_from_tex(path, "floor_material", "floor")
			_write_mat_from_tex(path, "skybox_material", "skybox")
		"enemy":
			if bool(kinds.get("textures", true)) or bool(kinds.get("sprites", true)):
				ProceduralArtScript.write_unique(path, "enemy", "png", "enemy", "enemy")
				ProceduralArtScript.write_unique(path, "sprite_enemy", "png", "enemy", "enemy")
			if bool(kinds.get("models", true)):
				ProceduralArtScript.write_shape_model(path, "enemy", "enemy", _char_shape.get_item_text(_char_shape.selected) if _char_shape.item_count > 0 else "capsule")
			_write_mat_from_tex(path, "enemy_material", "enemy_texture")
		"weapon":
			if bool(kinds.get("textures", true)):
				ProceduralArtScript.write_unique(path, "weapon", "png", "weapon", "metal")
			if bool(kinds.get("sprites", true)):
				ProceduralArtScript.write_unique(path, "sprite_weapon", "png", "weapon", "metal")
			if bool(kinds.get("models", true)):
				ProceduralArtScript.write_shape_model(path, "weapon", "weapon", "box")
			_write_mat_from_tex(path, "weapon_material", "weapon_texture")
		"materials":
			var slot: String = "wall_material"
			if _mat_slot.item_count > 0:
				slot = _mat_slot.get_item_text(_mat_slot.selected)
			var tex_slot: String = slot.trim_suffix("_material")
			if tex_slot == "character":
				tex_slot = "character_texture"
			elif tex_slot == "enemy":
				tex_slot = "enemy_texture"
			elif tex_slot == "weapon":
				tex_slot = "weapon_texture"
			elif tex_slot == "skybox":
				tex_slot = "skybox"
			_write_mat_from_tex(path, slot, tex_slot)
	_reload_all_options()
	_status.text = "Generated new %s variant(s). Pick in the list, then Add to game or Change." % section


func _download_section(section: String) -> void:
	_search_ctx = {"section": section}
	var q: String = "CC0 game "
	match section:
		"character":
			q += "character sprite texture"
		"world":
			q += "seamless wall floor sky texture"
		"enemy":
			q += "monster enemy sprite"
		"weapon":
			q += "weapon gun sprite texture"
	var path: String = AIOrchestrator.get_project_path()
	if not path.is_empty():
		q += GraphicStyleScript.query_suffix(GraphicStyleScript.from_variant(ConfigScript.load_style(path).get("graphic_styles", [])))
	_search_edit.text = q
	_search_list.clear()
	_search_dialog.popup_centered()
	_images.search(q)


func _on_search_go() -> void:
	var q: String = _search_edit.text.strip_edges()
	if q.is_empty():
		q = "CC0 game texture"
	if not q.to_lower().contains("cc0") and not q.to_lower().contains("public domain"):
		q += " CC0"
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
		_search_list.add_item("%s [%s]" % [str(r.get("title", "image")).left(50), str(r.get("license", ""))])


func _on_search_preview(ok: bool, _index: int, texture: Texture2D, _meta: Dictionary, error: String) -> void:
	if not ok:
		_status.text = error
		return
	var section: String = str(_search_ctx.get("section", "world"))
	match section:
		"character":
			_char_preview.texture = texture
		"enemy":
			_enemy_preview.texture = texture
		"weapon":
			_wep_preview.texture = texture
		_:
			_world_preview.texture = texture


func _on_search_download() -> void:
	var idxs: PackedInt32Array = _search_list.get_selected_items()
	if idxs.is_empty():
		_status.text = "Select a CC0 result first."
		return
	var path: String = AIOrchestrator.get_project_path()
	var section: String = str(_search_ctx.get("section", "world"))
	var cat: String = "world"
	var stem: String = "dl"
	match section:
		"character":
			cat = "character"
			stem = "character_dl"
		"enemy":
			cat = "enemy"
			stem = "enemy_dl"
		"weapon":
			cat = "weapon"
			stem = "weapon_dl"
		"world":
			cat = "world"
			stem = "world_dl"
	var fname: String = "%s_%s.png" % [stem, str(Time.get_unix_time_from_system()).replace(".", "")]
	var dest: String = LayoutScript.dest_abs(path, fname, cat)
	var err: Error = _images.download_full(idxs[0], dest)
	if err != OK:
		var tex: Texture2D = _char_preview.texture if section == "character" else (_enemy_preview.texture if section == "enemy" else (_wep_preview.texture if section == "weapon" else _world_preview.texture))
		if tex:
			LayoutScript.save_image_texture(path, fname, tex, cat)
		else:
			_status.text = "Download failed — preview a result, then retry."
			return
	_reload_all_options()
	_status.text = "Downloaded CC0 into assets/%s/. Select it, then Add or Change." % cat


func _open_add_more(section: String) -> void:
	_more_section = section
	_more_items.clear()
	_more_list.clear()
	if section == "physics":
		for row in LocalLibScript.list_for("physics"):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if str(row.get("kind", "")) == "cs":
				continue
			_more_items.append(row)
			_more_list.add_item(str(row.get("label", row.get("name", "?"))))
	else:
		for row in LocalLibScript.list_for(section):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if str(row.get("kind", "")) in ["cs", "plugin", "script"]:
				continue
			_more_items.append(row)
			_more_list.add_item(str(row.get("label", row.get("name", "?"))))
	if _more_items.is_empty():
		_status.text = "No matching F:/asset files for %s." % section
		return
	_more_dialog.popup_centered()


func _on_more_confirmed() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	if _more_section == "physics":
		var phys_info: Dictionary = LocalLibScript.install_physics_helpers(path)
		_finish("Added more physics helpers → %s" % str(phys_info.get("addon", "addons/f_asset_physics")))
		_reload_all_options()
		return
	var copied: int = 0
	var idxs: PackedInt32Array = _more_list.get_selected_items()
	if idxs.is_empty() and _more_list.item_count > 0:
		idxs = PackedInt32Array([0])
	for idx in idxs:
		if idx < 0 or idx >= _more_items.size():
			continue
		var row: Dictionary = _more_items[idx]
		var cat: String = "textures"
		match _more_section:
			"character", "enemy", "weapon":
				cat = _more_section
			"materials":
				cat = "materials"
			"world":
				cat = "world" if str(row.get("kind", "")) != "model" else "models"
				if str(row.get("kind", "")) == "material":
					cat = "materials"
		var installed: Dictionary = LocalLibScript.import_file(path, str(row.get("abs", "")), cat)
		if installed.get("ok", false):
			copied += 1
	_reload_all_options()
	_finish("Added more (%s) from F:/asset into assets/. Pick in the list, then Add to game or Change." % str(copied))


func _import_section(section: String) -> void:
	_import_ctx = {"section": section}
	var root: String = LocalLibScript.configured_root()
	if DirAccess.dir_exists_absolute(root):
		_file_dialog.current_dir = root
	_file_dialog.popup_centered_ratio(0.7)


func _on_file_picked(src: String) -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	var section: String = str(_import_ctx.get("section", "world"))
	var cat: String = LayoutScript.categorize(src.get_file())
	match section:
		"character":
			cat = "character"
		"enemy":
			cat = "enemy"
		"weapon":
			cat = "weapon"
		"world":
			if LayoutScript.MODEL_EXTS.has(src.get_extension().to_lower()):
				cat = "models"
			else:
				var nm: String = src.get_file().to_lower()
				cat = "background" if nm.contains("sky") or nm.contains("skybox") else "world"
		"materials":
			cat = "materials"
	var root_l: String = LocalLibScript.configured_root().replace("\\", "/").to_lower().rstrip("/")
	var src_l: String = src.replace("\\", "/").to_lower()
	var installed: Dictionary
	if LocalLibScript.is_allowed_root(LocalLibScript.configured_root()) and src_l.begins_with(root_l + "/"):
		installed = LocalLibScript.import_file(path, src, cat)
	else:
		installed = LayoutScript.install_asset(path, src, src.get_file(), cat, true)
	if not installed.get("ok", false):
		_status.text = "Import failed."
		return
	_reload_all_options()
	_status.text = "Imported %s — select it, then Add to game or Change." % str(installed.get("res", ""))


func _finish(msg: String) -> void:
	_status.text = msg
	applied.emit(msg)
	if library_refresh_needed():
		pass


func library_refresh_needed() -> bool:
	return true
