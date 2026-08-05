extends Control
## AI Godot Studio — describe → Create Game → Run Game / New Game / modify

const ProjectWriterScript = preload("res://scripts/project_writer.gd")
const GenreCatalogScript = preload("res://scripts/genre_catalog.gd")
const GameProjectBriefScript = preload("res://scripts/game_project_brief.gd")
const GraphicStyleScript = preload("res://scripts/graphic_style.gd")
const StudioGameConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const ArtEditIntentScript = preload("res://scripts/art_edit_intent.gd")

@onready var brand: Label = %Brand
@onready var prompt: TextEdit = %Prompt
@onready var status_label: Label = %Status
@onready var log_view: RichTextLabel = %LogView
@onready var providers_label: Label = %Providers
@onready var create_btn: Button = %CreateBtn
@onready var run_btn: Button = %RunBtn
@onready var new_game_btn: Button = %NewGameBtn
@onready var save_btn: Button = %SaveBtn
@onready var open_btn: Button = %OpenBtn
@onready var folder_btn: Button = %FolderBtn
@onready var session_label: Label = %SessionLabel
@onready var genre_option: OptionButton = %GenreOption
@onready var bg: ColorRect = %Backdrop
@onready var openai_key: LineEdit = %OpenAIKey
@onready var claude_key: LineEdit = %ClaudeKey
@onready var gemini_key: LineEdit = %GeminiKey
@onready var tavily_key: LineEdit = %TavilyKey
@onready var godot_path: LineEdit = %GodotPath
@onready var blender_path: LineEdit = %BlenderPath
@onready var use_openai: CheckButton = %UseOpenAI
@onready var use_claude: CheckButton = %UseClaude
@onready var use_gemini: CheckButton = %UseGemini
@onready var use_search: CheckButton = %UseSearch
@onready var use_cpp: CheckButton = %UseCpp
@onready var use_cpp_settings: CheckButton = %UseCppSettings
@onready var art_textures: CheckButton = %ArtTextures
@onready var art_sprites: CheckButton = %ArtSprites
@onready var art_models: CheckButton = %ArtModels
@onready var load_json_btn: Button = %LoadJsonBtn
@onready var style_realistic: CheckBox = %StyleRealistic
@onready var style_cartoon: CheckBox = %StyleCartoon
@onready var style_pixel: CheckBox = %StylePixel
@onready var style_2d: CheckBox = %Style2D
@onready var style_3d: CheckBox = %Style3D
@onready var style_minimal: CheckBox = %StyleMinimal
@onready var style_detailed: CheckBox = %StyleDetailed
@onready var art_edit_label: Label = %ArtEditLabel
@onready var art_slot_row: HBoxContainer = %ArtSlotRow
@onready var slot_wall: CheckBox = %SlotWall
@onready var slot_floor: CheckBox = %SlotFloor
@onready var slot_room: CheckBox = %SlotRoom
@onready var slot_character: CheckBox = %SlotCharacter
@onready var slot_weapon: CheckBox = %SlotWeapon
@onready var art_edit_kind_row: HBoxContainer = %ArtEditKindRow
@onready var edit_as_texture: CheckBox = %EditAsTexture
@onready var edit_as_sprite: CheckBox = %EditAsSprite
@onready var edit_as_model: CheckBox = %EditAsModel
@onready var make_art_edit_btn: Button = %MakeArtEditBtn
@onready var save_settings_btn: Button = %SaveSettings
@onready var tabs: TabContainer = %Tabs
@onready var library_tab: Control = %Library
@onready var scripts_tab: Control = %Scripts
@onready var animation_tab: Control = %Animation
@onready var controls_tab: Control = %Controls
@onready var effects_tab: Control = %Effects
@onready var edit_game_tab: Control = %EditGame
@onready var open_edit_game_btn: Button = %OpenEditGameBtn
@onready var local_asset_folder: LineEdit = %LocalAssetFolder

var _last_project_path: String = ""
var _pulse: float = 0.0
var _json_dialog: FileDialog
var _style_user_set: bool = false


func _ready() -> void:
	brand.text = "AI GODOT STUDIO"
	tabs.set_tab_title(0, "Create")
	tabs.set_tab_title(1, "Edit Game")
	tabs.set_tab_title(2, "Library / Assets")
	tabs.set_tab_title(3, "Scripts")
	tabs.set_tab_title(4, "Animation")
	tabs.set_tab_title(5, "Controls / Display")
	tabs.set_tab_title(6, "Effects")
	tabs.set_tab_title(7, "Settings")
	tabs.tab_changed.connect(_on_tab_changed)
	open_edit_game_btn.pressed.connect(_on_open_edit_game)
	_load_settings_into_form()
	_refresh_providers()
	_fill_genres()
	genre_option.item_selected.connect(_on_genre_selected)
	create_btn.pressed.connect(_on_create)
	run_btn.pressed.connect(_on_run)
	new_game_btn.pressed.connect(_on_new_game)
	save_btn.pressed.connect(_on_save)
	open_btn.pressed.connect(_on_open)
	folder_btn.pressed.connect(_on_folder)
	save_settings_btn.pressed.connect(_on_save_settings)
	use_cpp.toggled.connect(_on_cpp_toggled)
	use_cpp_settings.toggled.connect(_on_cpp_toggled)
	art_textures.toggled.connect(_on_art_kind_toggled)
	art_sprites.toggled.connect(_on_art_kind_toggled)
	art_models.toggled.connect(_on_art_kind_toggled)
	for box in [style_realistic, style_cartoon, style_pixel, style_2d, style_3d, style_minimal, style_detailed]:
		box.toggled.connect(_on_style_toggled)
	make_art_edit_btn.pressed.connect(_on_make_art_edit)
	_json_dialog = FileDialog.new()
	_json_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_json_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_json_dialog.filters = PackedStringArray(["*.json ; JSON", "*.jsonc ; JSONC", "*.txt ; Text/JSON"])
	_json_dialog.file_selected.connect(_on_json_picked)
	add_child(_json_dialog)
	load_json_btn.pressed.connect(_on_load_json)
	AIOrchestrator.status.connect(_on_status)
	AIOrchestrator.pipeline_finished.connect(_on_pipeline_finished)
	AIOrchestrator.session_changed.connect(_refresh_session)
	AppSettings.settings_changed.connect(_refresh_providers)
	run_btn.disabled = true
	save_btn.disabled = true
	open_btn.disabled = true
	folder_btn.disabled = true
	_refresh_session()
	_refresh_editors()
	if not _style_user_set:
		_apply_styles_to_checks(GraphicStyleScript.defaults_for_genre(GenreCatalogScript.id_at(genre_option.selected)))
	_log("[b]AI Godot Studio[/b]\n1. Pick [b]Graphic style[/b] (Realistic / Cartoon / Pixel / 2D / 3D / Minimal / Detailed) plus Textures/Sprites/Models\n2. Describe a game or paste GameProject JSON, then Create — starter art + useful files from F:/asset\n3. [b]Run Game[/b] — session stays. Type art changes + Create to edit the same project\n4. After testing, open [b]Edit Game[/b] to add more from F:/asset (Character → World → Enemy → Weapon → Materials → Physics).\n")
	if not AppSettings.has_any_ai_key():
		_log("[color=#F4A261]Add your ChatGPT / OpenAI key in Settings so Create Game uses AI instructions to code and pull assets.[/color]\n")
	if AppSettings.godot_executable.is_empty():
		_log("[color=#F4A261]Set Godot .exe in Settings to Run Game.[/color]\n")


func _process(delta: float) -> void:
	_pulse += delta
	var t: float = (sin(_pulse * 1.2) + 1.0) * 0.5
	bg.color = Color(0.04 + t * 0.015, 0.06 + t * 0.02, 0.09 + t * 0.01, 1.0)


func _fill_genres() -> void:
	genre_option.clear()
	for g in GenreCatalogScript.list_names():
		genre_option.add_item(g)
	genre_option.select(1) # FPS default


func _load_settings_into_form() -> void:
	openai_key.text = AppSettings.openai_api_key
	claude_key.text = AppSettings.claude_api_key
	gemini_key.text = AppSettings.gemini_api_key
	tavily_key.text = AppSettings.tavily_api_key
	godot_path.text = AppSettings.godot_executable
	blender_path.text = AppSettings.blender_executable
	local_asset_folder.text = AppSettings.local_asset_folder if not AppSettings.local_asset_folder.is_empty() else "F:/asset"
	use_openai.button_pressed = AppSettings.use_openai
	use_claude.button_pressed = AppSettings.use_claude
	use_gemini.button_pressed = AppSettings.use_gemini
	use_search.button_pressed = AppSettings.use_web_search
	use_cpp.set_pressed_no_signal(AppSettings.create_with_cpp)
	use_cpp_settings.set_pressed_no_signal(AppSettings.create_with_cpp)
	art_textures.set_pressed_no_signal(AppSettings.use_art_textures)
	art_sprites.set_pressed_no_signal(AppSettings.use_art_sprites)
	art_models.set_pressed_no_signal(AppSettings.use_art_models)
	_apply_styles_to_checks(GraphicStyleScript.normalize(AppSettings.graphic_styles))
	openai_key.secret = true
	claude_key.secret = true
	gemini_key.secret = true
	tavily_key.secret = true


func _refresh_providers() -> void:
	providers_label.text = "Active: " + ", ".join(AppSettings.available_providers())


func _on_save_settings() -> void:
	AppSettings.openai_api_key = openai_key.text.strip_edges()
	AppSettings.claude_api_key = claude_key.text.strip_edges()
	AppSettings.gemini_api_key = gemini_key.text.strip_edges()
	AppSettings.tavily_api_key = tavily_key.text.strip_edges()
	AppSettings.godot_executable = godot_path.text.strip_edges()
	AppSettings.blender_executable = blender_path.text.strip_edges()
	AppSettings.local_asset_folder = local_asset_folder.text.strip_edges().replace("\\", "/")
	if AppSettings.local_asset_folder.is_empty():
		AppSettings.local_asset_folder = "F:/asset"
		local_asset_folder.text = "F:/asset"
	AppSettings.use_openai = use_openai.button_pressed
	AppSettings.use_claude = use_claude.button_pressed
	AppSettings.use_gemini = use_gemini.button_pressed
	AppSettings.use_web_search = use_search.button_pressed
	AppSettings.create_with_cpp = use_cpp.button_pressed
	_sync_art_kinds_to_settings(false)
	_sync_styles_to_settings(false)
	AppSettings.save_settings()
	_refresh_providers()
	_log("[color=#3DDC97]Settings saved.[/color]\n")


func _on_cpp_toggled(pressed: bool) -> void:
	AppSettings.create_with_cpp = pressed
	use_cpp.set_pressed_no_signal(pressed)
	use_cpp_settings.set_pressed_no_signal(pressed)
	_refresh_providers()


func _on_art_kind_toggled(_pressed: bool) -> void:
	_sync_art_kinds_to_settings(true)


func _sync_art_kinds_to_settings(save_now: bool) -> void:
	AppSettings.use_art_textures = art_textures.button_pressed
	AppSettings.use_art_sprites = art_sprites.button_pressed
	AppSettings.use_art_models = art_models.button_pressed
	if not AppSettings.use_art_textures and not AppSettings.use_art_sprites and not AppSettings.use_art_models:
		AppSettings.use_art_textures = true
		AppSettings.use_art_sprites = true
		AppSettings.use_art_models = true
		art_textures.set_pressed_no_signal(true)
		art_sprites.set_pressed_no_signal(true)
		art_models.set_pressed_no_signal(true)
	if save_now:
		AppSettings.save_settings()
	_refresh_providers()


func _compose() -> String:
	var text: String = prompt.text.strip_edges()
	var parsed: Dictionary = GameProjectBriefScript.try_parse_text(text)
	if str(parsed.get("kind", "")) == "gameproject":
		return text
	var idx: int = genre_option.selected
	if idx < 0:
		idx = 0
	if idx <= 0:
		return text
	var genre: String = genre_option.get_item_text(idx)
	if text.is_empty():
		return "Build a playable Godot 4 %s with matching textures, sprites, and scripts." % genre
	return "%s\n\nGenre: %s" % [text, genre]


func _art_options() -> Dictionary:
	var styles: PackedStringArray = _selected_styles()
	var style_arr: Array = []
	for s in styles:
		style_arr.append(s)
	return {
		"textures": art_textures.button_pressed,
		"sprites": art_sprites.button_pressed,
		"models": art_models.button_pressed,
		"graphic_styles": style_arr,
		"art_slots": _selected_art_slots_arr(),
	}


func _on_genre_selected(idx: int) -> void:
	if _style_user_set and AIOrchestrator.has_active_session():
		return
	if _style_user_set:
		return
	_apply_styles_to_checks(GraphicStyleScript.defaults_for_genre(GenreCatalogScript.id_at(idx)))


func _on_style_toggled(_pressed: bool) -> void:
	_style_user_set = true
	if style_pixel.button_pressed and not style_2d.button_pressed:
		style_2d.set_pressed_no_signal(true)
	if style_minimal.button_pressed and style_detailed.button_pressed:
		if style_minimal.has_focus():
			style_detailed.set_pressed_no_signal(false)
		elif style_detailed.has_focus():
			style_minimal.set_pressed_no_signal(false)
		else:
			style_detailed.set_pressed_no_signal(false)
	_sync_styles_to_settings(true)


func _selected_styles() -> PackedStringArray:
	var raw: PackedStringArray = PackedStringArray()
	if style_realistic.button_pressed:
		raw.append("realistic")
	if style_cartoon.button_pressed:
		raw.append("cartoon")
	if style_pixel.button_pressed:
		raw.append("pixel")
	if style_2d.button_pressed:
		raw.append("2d")
	if style_3d.button_pressed:
		raw.append("3d")
	if style_minimal.button_pressed:
		raw.append("minimal")
	if style_detailed.button_pressed:
		raw.append("detailed")
	return GraphicStyleScript.normalize(raw)


func _apply_styles_to_checks(styles: PackedStringArray) -> void:
	var s: PackedStringArray = GraphicStyleScript.normalize(styles)
	style_realistic.set_pressed_no_signal(s.has("realistic"))
	style_cartoon.set_pressed_no_signal(s.has("cartoon"))
	style_pixel.set_pressed_no_signal(s.has("pixel"))
	style_2d.set_pressed_no_signal(s.has("2d"))
	style_3d.set_pressed_no_signal(s.has("3d"))
	style_minimal.set_pressed_no_signal(s.has("minimal"))
	style_detailed.set_pressed_no_signal(s.has("detailed"))


func _sync_styles_to_settings(save_now: bool) -> void:
	AppSettings.graphic_styles = _selected_styles()
	if save_now:
		AppSettings.save_settings()


func _selected_art_slots() -> PackedStringArray:
	var slots: PackedStringArray = PackedStringArray()
	if slot_wall.button_pressed:
		slots.append("wall")
	if slot_floor.button_pressed:
		slots.append("floor")
	if slot_room.button_pressed:
		slots.append("room")
	if slot_character.button_pressed:
		slots.append("character")
	if slot_weapon.button_pressed:
		slots.append("weapon")
	return slots


func _selected_art_slots_arr() -> Array:
	var arr: Array = []
	for s in _selected_art_slots():
		arr.append(s)
	return arr


func _edit_kind_options() -> Dictionary:
	return {
		"textures": edit_as_texture.button_pressed,
		"sprites": edit_as_sprite.button_pressed,
		"models": edit_as_model.button_pressed,
	}


func _set_art_edit_visible(show: bool) -> void:
	art_edit_label.visible = show
	art_slot_row.visible = show
	art_edit_kind_row.visible = show
	make_art_edit_btn.visible = show


func _on_make_art_edit() -> void:
	if not AIOrchestrator.has_active_session():
		_log("[color=#F4A261]Create a game first, then edit art slots.[/color]\n")
		return
	var slots: PackedStringArray = _selected_art_slots()
	if slots.is_empty():
		_log("[color=#F4A261]Check Wall / Floor / Room / Character / Weapon, then Make this edit.[/color]\n")
		return
	var kinds: Dictionary = _edit_kind_options()
	if not bool(kinds.get("textures", false)) and not bool(kinds.get("sprites", false)) and not bool(kinds.get("models", false)):
		kinds["textures"] = true
		edit_as_texture.set_pressed_no_signal(true)
	_sync_styles_to_settings(false)
	var opts: Dictionary = _art_options()
	opts["textures"] = bool(kinds.get("textures", true))
	opts["sprites"] = bool(kinds.get("sprites", false))
	opts["models"] = bool(kinds.get("models", false))
	opts["art_slots"] = _selected_art_slots_arr()
	opts["description"] = prompt.text.strip_edges()
	_log("[color=#8FA3B8]Art edit (%s · %s) matching graphic style %s…[/color]\n" % [
		", ".join(slots),
		GraphicStyleScript.label(_selected_styles()),
		"texture" if opts["textures"] else "",
	])
	AIOrchestrator.apply_art_edit(opts)


func _on_load_json() -> void:
	var desktop: String = OS.get_environment("USERPROFILE").path_join("Desktop")
	if DirAccess.dir_exists_absolute(desktop):
		_json_dialog.current_dir = desktop
	_json_dialog.popup_centered_ratio(0.7)


func _on_json_picked(path: String) -> void:
	var parsed: Dictionary = GameProjectBriefScript.try_parse_file(path)
	var kind: String = str(parsed.get("kind", ""))
	if kind == "gameproject":
		var gp: Dictionary = parsed.get("data", {}) if typeof(parsed.get("data", {})) == TYPE_DICTIONARY else {}
		prompt.text = GameProjectBriefScript.pretty_prompt(gp)
		var gidx: int = GenreCatalogScript.index_for_text(str(gp.get("genre", "")))
		if gidx > 0:
			genre_option.select(gidx)
		_log("[color=#3DDC97]Loaded GameProject JSON.[/color] Title: %s\n" % str(gp.get("title", "(none)")))
		_on_status("GameProject loaded — press Create Game")
		return
	if kind == "site_only":
		var nm: String = str(parsed.get("name", "")).strip_edges()
		_log("[color=#F4A261]%s[/color]\n" % str(parsed.get("reason", "Ignored npm site config.")))
		if not nm.is_empty() and nm.to_lower() != "untitled" and prompt.text.strip_edges().is_empty():
			prompt.text = nm
			_log("Using name as a starting title: %s\n" % nm)
		else:
			_log("Type a game description (untitled / site metadata is not a game spec).\n")
		return
	if kind == "name_only":
		var only: String = str(parsed.get("name", "")).strip_edges()
		if not only.is_empty() and prompt.text.strip_edges().is_empty():
			prompt.text = only
		_log("Loaded name only — add a description, then Create.\n")
		return
	_log("[color=#F4A261]%s[/color]\n" % str(parsed.get("reason", "skipped — not a game spec")))


func _refresh_session() -> void:
	session_label.text = AIOrchestrator.get_session_label()
	if AIOrchestrator.has_active_session():
		session_label.text += " — Tested? Type changes and press Create Game to edit."
		create_btn.text = "Update Game"
		create_btn.tooltip_text = "Edits the current game (same folder). Use the Edit Game tab to add more from F:/asset. New Game starts over."
		prompt.placeholder_text = "Type edits after testing, then Create…"
		_set_art_edit_visible(true)
	else:
		create_btn.text = "Create Game"
		create_btn.tooltip_text = "Creates a new playable Godot game from your description."
		prompt.placeholder_text = "Describe a game, or paste GameProject JSON…"
		_set_art_edit_visible(false)


func _on_new_game() -> void:
	AIOrchestrator.new_game()
	_last_project_path = ""
	prompt.text = ""
	prompt.placeholder_text = "Describe a game, or paste GameProject JSON…"
	run_btn.disabled = true
	save_btn.disabled = true
	open_btn.disabled = true
	folder_btn.disabled = true
	create_btn.disabled = false
	_style_user_set = false
	_apply_styles_to_checks(GraphicStyleScript.defaults_for_genre(GenreCatalogScript.id_at(genre_option.selected)))
	_refresh_session()
	_refresh_editors()
	_log("[color=#F4A261]New Game — previous directions cleared. Describe the next game, then Create Game.[/color]\n")


func _on_create() -> void:
	var raw: String = prompt.text.strip_edges()
	var parsed: Dictionary = GameProjectBriefScript.try_parse_text(raw)
	var kind: String = str(parsed.get("kind", ""))
	if kind == "skipped":
		_log("[color=#F4A261]%s[/color]\n" % str(parsed.get("reason", "skipped — not a game spec")))
		return
	if kind == "site_only":
		_log("[color=#F4A261]%s Type a game description.[/color]\n" % str(parsed.get("reason", "Ignored npm site config.")))
		return
	var idea: String = raw if kind == "gameproject" else _compose()
	if idea.is_empty():
		_on_status("Describe a game in the search box (or pick a genre).")
		return
	if AIOrchestrator.is_busy():
		_log("[color=#F4A261]Still working — applying your new text on the same game…[/color]\n")
	create_btn.disabled = true
	new_game_btn.disabled = true
	_sync_art_kinds_to_settings(false)
	_sync_styles_to_settings(false)
	var editing: bool = AIOrchestrator.has_active_session()
	var mode: String = "Editing existing game from new directions" if editing else "Creating game"
	_log("\n[b]%s:[/b] %s\n" % [mode, idea.left(400)])
	_log("[color=#8FA3B8]Graphic style: %s[/color]\n" % GraphicStyleScript.label(_selected_styles()))
	if kind == "gameproject":
		_log("[color=#8FA3B8]Using GameProject JSON (title/genre/description/art).[/color]\n")
	if editing:
		var detected: Dictionary = ArtEditIntentScript.detect(idea)
		if bool(detected.get("any", false)) and _selected_art_slots().is_empty():
			_precheck_slots(detected)
			_log("[color=#F4A261]Art change detected — check Wall / Floor / Room / Character / Weapon + Texture/Sprite/Model, then Make this edit (or Create to update the whole game).[/color]\n")
		_log("[color=#F4A261]Editing existing game from new directions…[/color]\n")
	if AppSettings.create_with_cpp:
		_log("[color=#8FA3B8]Godot 4 + C++ GDExtension + ChatGPT plan + GDScript fallback + multi-asset / plugin / sample download…[/color]\n")
	else:
		_log("[color=#8FA3B8]Godot engine + ChatGPT plan + scripts + multi-asset / plugin / sample download…[/color]\n")
	AIOrchestrator.create_game(idea, genre_option.selected, _art_options())


func _on_pipeline_finished(success: bool, result: Dictionary) -> void:
	var busy: bool = AIOrchestrator.is_busy()
	create_btn.disabled = busy
	new_game_btn.disabled = false
	if not success:
		_log("[color=#E76F51]Failed: %s[/color]\n" % str(result.get("error", "unknown")))
		_on_status("Failed")
		return
	_last_project_path = str(result.get("path", AIOrchestrator.get_project_path()))
	run_btn.disabled = _last_project_path.is_empty()
	save_btn.disabled = run_btn.disabled
	open_btn.disabled = run_btn.disabled
	folder_btn.disabled = run_btn.disabled
	_refresh_session()
	_refresh_editors()
	if not bool(result.get("art_edit", false)):
		prompt.placeholder_text = "Type more description or comments, then Update Game…"
	create_btn.disabled = false
	var proj: String = _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if not proj.is_empty():
		var style_data: Dictionary = StudioGameConfigScript.load_style(proj)
		_apply_styles_to_checks(GraphicStyleScript.from_variant(style_data.get("graphic_styles", _selected_styles())))
		_style_user_set = true
	_log("[color=#3DDC97]Game ready:[/color] %s\n" % _last_project_path)
	_log("[color=#8FA3B8]After Run Game, type more description or comments and press Update Game — the same project keeps improving. New Game is the only full reset.[/color]\n")
	if result.has("session"):
		_log("[color=#8FA3B8]%s[/color]\n" % str(result.get("session", "")))
	var files = result.get("files", [])
	if typeof(files) == TYPE_ARRAY or typeof(files) == TYPE_PACKED_STRING_ARRAY:
		_log("[b]Files:[/b] %s\n" % ", ".join(PackedStringArray(files)))
	var summary: String = str(result.get("summary", ""))
	if not summary.is_empty():
		_log("[i]%s[/i]\n" % summary)
	if busy:
		_on_status("Playable now — AI still enhancing…")
	else:
		_on_status("Ready — Run Game, or type changes and Create again")


func _on_run() -> void:
	var path: String = _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		_on_status("Create a game first.")
		return
	if ProjectWriterScript.run_project(path) != OK:
		_log("[color=#E76F51]Set Godot .exe in Settings.[/color]\n")
	else:
		_log("[color=#3DDC97]Launching game…[/color]\n")
		_log("[color=#8FA3B8]Tested? Type changes and press Create Game to edit the same game.[/color]\n")
		_on_status("Tested? Type changes and press Create Game to edit.")
		_refresh_session()


func _on_save() -> void:
	var path: String = _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		_on_status("Nothing to save yet.")
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var dest_root: String = ProjectSettings.globalize_path("res://generated_games")
	var name: String = path.get_file()
	var dest: String = dest_root.path_join("%s_save_%s" % [name, stamp])
	var err: Error = _copy_dir(path, dest)
	if err != OK:
		_log("[color=#E76F51]Save failed.[/color]\n")
		return
	_log("[color=#3DDC97]Saved copy:[/color] %s\n" % dest)


func _copy_dir(src: String, dest: String) -> Error:
	DirAccess.make_dir_recursive_absolute(dest)
	var d: DirAccess = DirAccess.open(src)
	if d == null:
		return ERR_CANT_OPEN
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var from: String = src.path_join(n)
		var to: String = dest.path_join(n)
		if d.current_is_dir():
			var e: Error = _copy_dir(from, to)
			if e != OK:
				return e
		else:
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(from)
			var out: FileAccess = FileAccess.open(to, FileAccess.WRITE)
			if out == null:
				return ERR_CANT_CREATE
			out.store_buffer(bytes)
		n = d.get_next()
	return OK


func _on_open() -> void:
	var path: String = _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	if ProjectWriterScript.open_in_godot(path) != OK:
		_log("[color=#E76F51]Set Godot .exe in Settings.[/color]\n")


func _on_folder() -> void:
	var path: String = _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if not path.is_empty():
		OS.shell_show_in_file_manager(path)


func _on_tab_changed(_idx: int) -> void:
	_refresh_editors()


func _on_open_edit_game() -> void:
	tabs.current_tab = 1
	_refresh_editors()


func _refresh_editors() -> void:
	for node in [edit_game_tab, library_tab, scripts_tab, animation_tab, controls_tab, effects_tab]:
		if node and node.has_method("refresh"):
			node.refresh()


func _on_status(message: String) -> void:
	status_label.text = message
	_log("%s\n" % message)


func _log(bbcode: String) -> void:
	log_view.append_text(bbcode)


func _precheck_slots(detected: Dictionary) -> void:
	var slots: Dictionary = detected.get("slots", {}) if typeof(detected.get("slots", {})) == TYPE_DICTIONARY else {}
	slot_wall.set_pressed_no_signal(bool(slots.get("wall", false)))
	slot_floor.set_pressed_no_signal(bool(slots.get("floor", false)))
	slot_room.set_pressed_no_signal(bool(slots.get("room", false)))
	slot_character.set_pressed_no_signal(bool(slots.get("character", false)))
	slot_weapon.set_pressed_no_signal(bool(slots.get("weapon", false)))
	var types: Dictionary = detected.get("types", {}) if typeof(detected.get("types", {})) == TYPE_DICTIONARY else {}
	if bool(types.get("texture", false)) or bool(types.get("menu", false)):
		edit_as_texture.set_pressed_no_signal(true)
	if bool(types.get("sprite", false)):
		edit_as_sprite.set_pressed_no_signal(true)
	if bool(types.get("model", false)):
		edit_as_model.set_pressed_no_signal(true)
