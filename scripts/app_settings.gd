extends Node
## Persists API keys and studio preferences in user://settings.cfg

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const ArtPipelineScript = preload("res://scripts/art_pipeline.gd")

var openai_api_key: String = ""
var claude_api_key: String = ""
var gemini_api_key: String = ""
var tavily_api_key: String = ""
var openai_model: String = "gpt-4o-mini"
var claude_model: String = "claude-sonnet-4-5"
var gemini_model: String = "gemini-2.0-flash"
var use_openai: bool = true
var use_claude: bool = true
var use_gemini: bool = true
var use_web_search: bool = true
var create_with_cpp: bool = true
var use_art_textures: bool = true
var use_art_sprites: bool = true
var use_art_models: bool = true
var graphic_styles: PackedStringArray = PackedStringArray(["3d", "detailed"])
var godot_executable: String = ""
var blender_executable: String = ""
var output_folder: String = "res://generated_games"
var local_asset_folder: String = "F:/asset"


func _ready() -> void:
	_load_from_env()
	load_settings()
	if godot_executable.is_empty():
		godot_executable = _guess_godot_path()
	if blender_executable.is_empty():
		blender_executable = ArtPipelineScript.guess_blender_path()


func _load_from_env() -> void:
	var o := OS.get_environment("OPENAI_API_KEY")
	var c := OS.get_environment("ANTHROPIC_API_KEY")
	var g := OS.get_environment("GEMINI_API_KEY")
	var t := OS.get_environment("TAVILY_API_KEY")
	if not o.is_empty():
		openai_api_key = o
	if not c.is_empty():
		claude_api_key = c
	if not g.is_empty():
		gemini_api_key = g
	if not t.is_empty():
		tavily_api_key = t


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	openai_api_key = str(cfg.get_value("keys", "openai", openai_api_key))
	claude_api_key = str(cfg.get_value("keys", "claude", claude_api_key))
	gemini_api_key = str(cfg.get_value("keys", "gemini", gemini_api_key))
	tavily_api_key = str(cfg.get_value("keys", "tavily", tavily_api_key))
	openai_model = str(cfg.get_value("models", "openai", openai_model))
	claude_model = str(cfg.get_value("models", "claude", claude_model))
	gemini_model = str(cfg.get_value("models", "gemini", gemini_model))
	use_openai = bool(cfg.get_value("providers", "openai", use_openai))
	use_claude = bool(cfg.get_value("providers", "claude", use_claude))
	use_gemini = bool(cfg.get_value("providers", "gemini", use_gemini))
	use_web_search = bool(cfg.get_value("providers", "web_search", use_web_search))
	create_with_cpp = bool(cfg.get_value("providers", "create_with_cpp", create_with_cpp))
	use_art_textures = bool(cfg.get_value("art", "textures", use_art_textures))
	use_art_sprites = bool(cfg.get_value("art", "sprites", use_art_sprites))
	use_art_models = bool(cfg.get_value("art", "models", use_art_models))
	graphic_styles = PackedStringArray(str(cfg.get_value("art", "graphic_styles", ",".join(graphic_styles))).split(",", false))
	godot_executable = str(cfg.get_value("paths", "godot", godot_executable))
	blender_executable = str(cfg.get_value("paths", "blender", blender_executable))
	output_folder = str(cfg.get_value("paths", "output", output_folder))
	local_asset_folder = str(cfg.get_value("paths", "local_asset_folder", local_asset_folder)).replace("\\", "/")
	if local_asset_folder.is_empty():
		local_asset_folder = "F:/asset"
	# Prefer project-local generated_games so users can see files in the repo.
	if output_folder.begins_with("user://"):
		output_folder = "res://generated_games"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "openai", openai_api_key)
	cfg.set_value("keys", "claude", claude_api_key)
	cfg.set_value("keys", "gemini", gemini_api_key)
	cfg.set_value("keys", "tavily", tavily_api_key)
	cfg.set_value("models", "openai", openai_model)
	cfg.set_value("models", "claude", claude_model)
	cfg.set_value("models", "gemini", gemini_model)
	cfg.set_value("providers", "openai", use_openai)
	cfg.set_value("providers", "claude", use_claude)
	cfg.set_value("providers", "gemini", use_gemini)
	cfg.set_value("providers", "web_search", use_web_search)
	cfg.set_value("providers", "create_with_cpp", create_with_cpp)
	cfg.set_value("art", "textures", use_art_textures)
	cfg.set_value("art", "sprites", use_art_sprites)
	cfg.set_value("art", "models", use_art_models)
	cfg.set_value("art", "graphic_styles", ",".join(graphic_styles))
	cfg.set_value("paths", "godot", godot_executable)
	cfg.set_value("paths", "blender", blender_executable)
	cfg.set_value("paths", "output", output_folder)
	cfg.set_value("paths", "local_asset_folder", local_asset_folder)
	cfg.save(CONFIG_PATH)
	settings_changed.emit()


func has_any_ai_key() -> bool:
	return (use_openai and not openai_api_key.is_empty()) \
		or (use_claude and not claude_api_key.is_empty()) \
		or (use_gemini and not gemini_api_key.is_empty())


func available_providers() -> PackedStringArray:
	var list: PackedStringArray = []
	if use_openai and not openai_api_key.is_empty():
		list.append("ChatGPT / OpenAI")
	if use_claude and not claude_api_key.is_empty():
		list.append("Claude / Anthropic")
	if use_gemini and not gemini_api_key.is_empty():
		list.append("Gemini / Google")
	if use_web_search:
		list.append("Web Search")
	if create_with_cpp:
		list.append("C++ / GDExtension")
	if not local_asset_folder.is_empty():
		list.append("Local: " + local_asset_folder)
	var art_bits: PackedStringArray = PackedStringArray()
	if use_art_textures:
		art_bits.append("textures")
	if use_art_sprites:
		art_bits.append("sprites")
	if use_art_models:
		art_bits.append("models")
	if not art_bits.is_empty():
		list.append("Art: " + "/".join(art_bits))
	if list.is_empty():
		list.append("Offline templates")
	return list


func _guess_godot_path() -> String:
	var candidates: PackedStringArray = [
		"C:/Users/kortn/Downloads/Godot_v4.7.1-stable_win64.exe",
		"C:/Users/kortn/Downloads/Godot_v4.7.1-stable_win64.exe.zip",
	]
	# Prefer loose exe next to common download names
	var downloads := OS.get_environment("USERPROFILE") + "/Downloads"
	var dir := DirAccess.open(downloads)
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("Godot_v4") and name.ends_with(".exe") and not name.contains("console"):
				return downloads.path_join(name)
			name = dir.get_next()
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return ""
