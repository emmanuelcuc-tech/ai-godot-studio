extends Control
## AI Godot Studio — describe → Create Game → Run Game / New Game / modify

const ProjectWriterScript = preload("res://scripts/project_writer.gd")
const GenreCatalogScript = preload("res://scripts/genre_catalog.gd")

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
@onready var save_settings_btn: Button = %SaveSettings

var _last_project_path: String = ""
var _pulse: float = 0.0


func _ready() -> void:
	brand.text = "AI GODOT STUDIO"
	_load_settings_into_form()
	_refresh_providers()
	_fill_genres()
	create_btn.pressed.connect(_on_create)
	run_btn.pressed.connect(_on_run)
	new_game_btn.pressed.connect(_on_new_game)
	save_btn.pressed.connect(_on_save)
	open_btn.pressed.connect(_on_open)
	folder_btn.pressed.connect(_on_folder)
	save_settings_btn.pressed.connect(_on_save_settings)
	use_cpp.toggled.connect(_on_cpp_toggled)
	use_cpp_settings.toggled.connect(_on_cpp_toggled)
	AIOrchestrator.status.connect(_on_status)
	AIOrchestrator.pipeline_finished.connect(_on_pipeline_finished)
	AIOrchestrator.session_changed.connect(_refresh_session)
	AppSettings.settings_changed.connect(_refresh_providers)
	run_btn.disabled = true
	save_btn.disabled = true
	open_btn.disabled = true
	folder_btn.disabled = true
	_refresh_session()
	_log("[b]AI Godot Studio[/b]\n1. Describe a game — ChatGPT turns it into [i]instructions + asset list[/i]\n2. [b]Create Game[/b] — Godot 4 + [i]C++ GDExtension[/i] template → search → AI plan → C++ & GDScript → textures\n3. [b]Run Game[/b] plays immediately (GDScript fallback). Build `build_cpp.ps1` for native C++.\n4. New directions + Create → modifies C++ sources and fallback scripts\n5. [b]New Game[/b] clears · [b]Save Game[/b] keeps a copy\n6. [b]Audio Studio[/b] tab — desktop mixer, IN/OUT knobs, describe / record melody / hum\n")
	var tabs: TabContainer = %Tabs
	tabs.tab_changed.connect(_on_tab_changed)
	if not AppSettings.has_any_ai_key():
		_log("[color=#F4A261]Add your ChatGPT / OpenAI key in Settings so Create Game uses AI instructions to code and pull assets.[/color]\n")
	if AppSettings.godot_executable.is_empty():
		_log("[color=#F4A261]Set Godot .exe in Settings to Run Game.[/color]\n")


func _process(delta: float) -> void:
	_pulse += delta
	var t := (sin(_pulse * 1.2) + 1.0) * 0.5
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
	use_openai.button_pressed = AppSettings.use_openai
	use_claude.button_pressed = AppSettings.use_claude
	use_gemini.button_pressed = AppSettings.use_gemini
	use_search.button_pressed = AppSettings.use_web_search
	use_cpp.set_pressed_no_signal(AppSettings.create_with_cpp)
	use_cpp_settings.set_pressed_no_signal(AppSettings.create_with_cpp)
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
	AppSettings.use_openai = use_openai.button_pressed
	AppSettings.use_claude = use_claude.button_pressed
	AppSettings.use_gemini = use_gemini.button_pressed
	AppSettings.use_web_search = use_search.button_pressed
	AppSettings.create_with_cpp = use_cpp.button_pressed
	AppSettings.save_settings()
	_refresh_providers()
	_log("[color=#3DDC97]Settings saved.[/color]\n")


func _on_cpp_toggled(pressed: bool) -> void:
	AppSettings.create_with_cpp = pressed
	use_cpp.set_pressed_no_signal(pressed)
	use_cpp_settings.set_pressed_no_signal(pressed)
	_refresh_providers()


func _compose() -> String:
	var text := prompt.text.strip_edges()
	var idx := genre_option.selected
	if idx < 0:
		idx = 0
	if idx <= 0:
		return text
	var genre := genre_option.get_item_text(idx)
	if text.is_empty():
		return "Build a playable Godot 4 %s with matching textures, sprites, and scripts." % genre
	return "%s\n\nGenre: %s" % [text, genre]


func _refresh_session() -> void:
	session_label.text = AIOrchestrator.get_session_label()
	if AIOrchestrator.has_active_session():
		session_label.text += " — Create again to modify with new text"


func _on_new_game() -> void:
	AIOrchestrator.new_game()
	_last_project_path = ""
	prompt.text = ""
	run_btn.disabled = true
	save_btn.disabled = true
	open_btn.disabled = true
	folder_btn.disabled = true
	create_btn.disabled = false
	_refresh_session()
	_log("[color=#F4A261]New Game — previous directions cleared. Describe the next game, then Create Game.[/color]\n")


func _on_create() -> void:
	var idea := _compose()
	if idea.is_empty():
		_on_status("Describe a game in the search box (or pick a genre).")
		return
	if AIOrchestrator.is_busy():
		_log("[color=#F4A261]Still creating — wait or press New Game to cancel.[/color]\n")
		return
	create_btn.disabled = true
	new_game_btn.disabled = true
	var mode := "Modifying game" if AIOrchestrator.has_active_session() else "Creating game"
	_log("\n[b]%s:[/b] %s\n" % [mode, idea])
	if AppSettings.create_with_cpp:
		_log("[color=#8FA3B8]Godot 4 + C++ GDExtension + ChatGPT plan + GDScript fallback + texture download…[/color]\n")
	else:
		_log("[color=#8FA3B8]Godot engine + ChatGPT plan (instructions/assets) + scripts + texture download…[/color]\n")
	AIOrchestrator.create_game(idea, genre_option.selected)


func _on_pipeline_finished(success: bool, result: Dictionary) -> void:
	var busy := AIOrchestrator.is_busy()
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
	_log("[color=#3DDC97]Game ready:[/color] %s\n" % _last_project_path)
	if result.has("session"):
		_log("[color=#8FA3B8]%s[/color]\n" % str(result.get("session", "")))
	var files = result.get("files", [])
	if typeof(files) == TYPE_ARRAY or typeof(files) == TYPE_PACKED_STRING_ARRAY:
		_log("[b]Files:[/b] %s\n" % ", ".join(PackedStringArray(files)))
	var summary := str(result.get("summary", ""))
	if not summary.is_empty():
		_log("[i]%s[/i]\n" % summary)
	if busy:
		_on_status("Playable now — AI still enhancing…")
	else:
		_on_status("Ready — Run Game, or type changes and Create again")


func _on_run() -> void:
	var path := _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		_on_status("Create a game first.")
		return
	if ProjectWriterScript.run_project(path) != OK:
		_log("[color=#E76F51]Set Godot .exe in Settings.[/color]\n")
	else:
		_log("[color=#3DDC97]Launching game…[/color]\n")


func _on_save() -> void:
	var path := _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		_on_status("Nothing to save yet.")
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var dest_root := ProjectSettings.globalize_path("res://generated_games")
	var name := path.get_file()
	var dest := dest_root.path_join("%s_save_%s" % [name, stamp])
	var err := _copy_dir(path, dest)
	if err != OK:
		_log("[color=#E76F51]Save failed.[/color]\n")
		return
	_log("[color=#3DDC97]Saved copy:[/color] %s\n" % dest)


func _copy_dir(src: String, dest: String) -> Error:
	DirAccess.make_dir_recursive_absolute(dest)
	var d := DirAccess.open(src)
	if d == null:
		return ERR_CANT_OPEN
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var from := src.path_join(n)
		var to := dest.path_join(n)
		if d.current_is_dir():
			var e := _copy_dir(from, to)
			if e != OK:
				return e
		else:
			var bytes := FileAccess.get_file_as_bytes(from)
			var out := FileAccess.open(to, FileAccess.WRITE)
			if out == null:
				return ERR_CANT_CREATE
			out.store_buffer(bytes)
		n = d.get_next()
	return OK


func _on_open() -> void:
	var path := _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	if ProjectWriterScript.open_in_godot(path) != OK:
		_log("[color=#E76F51]Set Godot .exe in Settings.[/color]\n")


func _on_folder() -> void:
	var path := _last_project_path if not _last_project_path.is_empty() else AIOrchestrator.get_project_path()
	if not path.is_empty():
		OS.shell_show_in_file_manager(path)


func _on_status(message: String) -> void:
	status_label.text = message
	_log("%s\n" % message)


func _on_tab_changed(tab: int) -> void:
	var tabs: TabContainer = %Tabs
	var title := tabs.get_tab_title(tab)
	if title == "Audio Studio":
		status_label.text = "Audio Studio — mixer, IN/OUT, melody & hum"
	elif title == "Settings":
		status_label.text = "Settings"
	else:
		status_label.text = "Create — pick a template"


func _log(bbcode: String) -> void:
	log_view.append_text(bbcode)
