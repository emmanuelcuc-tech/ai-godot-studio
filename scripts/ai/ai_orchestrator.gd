extends Node
## Game Factory — ChatGPT/AI plans + codes Godot games from your directions.
## Flow: starter template → web research → AI PLAN (instructions/assets) → AI CODE → download textures

signal status(message: String)
signal pipeline_finished(success: bool, result: Dictionary)
signal session_changed

const OpenAIClientScript = preload("res://scripts/ai/openai_client.gd")
const ClaudeClientScript = preload("res://scripts/ai/claude_client.gd")
const GeminiClientScript = preload("res://scripts/ai/gemini_client.gd")
const WebSearchClientScript = preload("res://scripts/ai/web_search_client.gd")
const ImageAssetClientScript = preload("res://scripts/ai/image_asset_client.gd")
const GenreCatalogScript = preload("res://scripts/genre_catalog.gd")
const GenreTemplatesScript = preload("res://scripts/templates/genre_templates.gd")
const GameGeneratorScript = preload("res://scripts/game_generator.gd")
const ProjectWriterScript = preload("res://scripts/project_writer.gd")
const GameInspirationsScript = preload("res://scripts/game_inspirations.gd")
const GameSessionScript = preload("res://scripts/game_session.gd")
const OfflineEnhancerScript = preload("res://scripts/offline_enhancer.gd")
const ArtPipelineScript = preload("res://scripts/art_pipeline.gd")
const CppGdextensionScript = preload("res://scripts/templates/cpp_gdextension.gd")
const CppBuilderScript = preload("res://scripts/cpp_builder.gd")

const SYSTEM_PLAN := """You are a lead Godot 4 game designer working with ChatGPT-style instructions.
From the player's directions, write a concrete BUILD PLAN the coder will follow.
Engine is ALWAYS Godot 4 with **C++ GDExtension (godot-cpp)** as the intended implementation.
Also plan a **playable GDScript 2.0 fallback** so the game runs before the native library is compiled.
Never use Unity/Unreal/GameMaker as the runtime.
List C++ classes/files (src/*.h, src/*.cpp), GDScript bootstrap, textures, sprites, materials, plugins, and Asset Library ideas that MATCH the described game (CC0 / open only — never commercial ROMs or ripped assets).
Return ONLY JSON (no markdown fences):
{
  "title":"short name",
  "instructions":["step-by-step build instructions the coder must follow"],
  "gameplay":["core loops / controls / win-lose"],
  "godot_features":["GDExtension classes, nodes, systems, scenes needed"],
  "cpp_classes":["GameApp","GamePlayer","GameWorld","GameEnemy"],
  "assets_required":[
    {"name":"wall.png","type":"texture","query":"cc0 brick wall seamless","usage":"corridor walls"}
  ],
  "plugins_or_addons":["optional Godot AssetLib ideas"],
  "modify_notes":"if updating an existing game, what to change vs keep (update C++ sources + GDScript fallback together)"
}"""

const SYSTEM_CODE := """You are a Godot 4 + GDExtension (C++ / godot-cpp) programmer. Follow the BUILD PLAN and USER DIRECTIONS exactly.
Write or UPDATE a playable Godot 4 project whose **intended gameplay is C++**:
- src/register_types.h + src/register_types.cpp (entry symbol game_library_init)
- src/game_app.*, src/game_player.*, src/game_world.*, src/game_enemy.* matching the genre/description
- bin/game.gdextension, SConstruct and/or CMakeLists.txt, docs/CPP_BUILD.md
Also keep a **playable GDScript 2.0 fallback** (scripts/*.gd + scenes/main.tscn) so Run Game works without a compiler.
Optional scenes/main_cpp.tscn may use native class names GamePlayer / GameWorld after the extension is built.
Use assets already on disk (assets/wall.png, assets/floor.png, etc.) via StandardMaterial3D.albedo_texture or Sprite2D.texture.
Match feel of the described game with original/CC0 art — never commercial ROMs or ripped assets.
Include collisions, materials, particles, simple FX when the plan asks (especially shooters).
Return ONLY JSON (no markdown fences):
{
  "project_name":"snake_case",
  "summary":"what changed",
  "howto":["how to play"],
  "files":[{"path":"relative/path","content":"full file text"}],
  "download_queries":[{"filename":"wall.png","query":"cc0 brick wall seamless"}]
}
Under 28 files. Always playable via GDScript fallback. If CURRENT FILES are provided, MERGE updates — keep working systems unless directions say replace them.
On MODIFY, update existing C++ sources in src/ (not only GDScript).
Always include project.godot and a main scene that runs. Do not dump godot-cpp submodule files into the JSON."""

const SYSTEM_PLAN_GDSCRIPT := """You are a lead Godot 4 game designer working with ChatGPT-style instructions.
From the player's directions, write a concrete BUILD PLAN the coder will follow.
Engine is ALWAYS Godot 4 (GDScript 2.0) — never Unity/Unreal/GameMaker as the runtime.
List textures, sprites, materials, plugins, and Asset Library ideas that MATCH the described game (CC0 / open only — never commercial ROMs or ripped assets).
Return ONLY JSON (no markdown fences):
{
  "title":"short name",
  "instructions":["step-by-step build instructions the coder must follow"],
  "gameplay":["core loops / controls / win-lose"],
  "godot_features":["nodes, systems, scenes needed"],
  "assets_required":[
    {"name":"wall.png","type":"texture","query":"cc0 brick wall seamless","usage":"corridor walls"}
  ],
  "plugins_or_addons":["optional Godot AssetLib ideas"],
  "modify_notes":"if updating an existing game, what to change vs keep"
}"""

const SYSTEM_CODE_GDSCRIPT := """You are a Godot 4 programmer. Follow the BUILD PLAN and USER DIRECTIONS exactly.
Write or UPDATE a playable Godot 4 project in GDScript 2.0 only.
Use assets already on disk (assets/wall.png, assets/floor.png, etc.) via StandardMaterial3D.albedo_texture or Sprite2D.texture.
Match feel of the described game with original/CC0 art — never commercial ROMs or ripped assets.
Include collisions, materials, particles, simple FX when the plan asks (especially shooters).
Return ONLY JSON (no markdown fences):
{
  "project_name":"snake_case",
  "summary":"what changed",
  "howto":["how to play"],
  "files":[{"path":"relative/path","content":"full file text"}],
  "download_queries":[{"filename":"wall.png","query":"cc0 brick wall seamless"}]
}
Under 20 files. Always playable. If CURRENT FILES are provided, MERGE updates — keep working systems unless directions say replace them.
Always include project.godot and a main scene that runs."""

var openai
var claude
var gemini
var search
var images
var session = GameSessionScript.new()

var _busy := false
var _awaiting := ""
var _description := ""
var _genre_id := "fps"
var _genre: Dictionary = {}
var _inspiration: Dictionary = {}
var _base: Dictionary = {}
var _research := ""
var _asset_research := ""
var _plan: Dictionary = {}
var _plan_raw := ""
var _notes: PackedStringArray = []
var _modify := false
var _awaiting_tex := false
var _tex_index := 0
var _pending_downloads: Array = []
var _download_active := false


func _ready() -> void:
	openai = OpenAIClientScript.new()
	claude = ClaudeClientScript.new()
	gemini = GeminiClientScript.new()
	search = WebSearchClientScript.new()
	images = ImageAssetClientScript.new()
	openai.attach(self)
	claude.attach(self)
	gemini.attach(self)
	search.attach(self)
	images.attach(self)
	openai.reply.connect(_on_ai)
	claude.reply.connect(_on_ai)
	gemini.reply.connect(_on_ai)
	search.reply.connect(_on_search)
	images.search_done.connect(_on_images_found)
	images.preview_ready.connect(_on_image_ready)
	session.changed.connect(func(): session_changed.emit())


func is_busy() -> bool:
	return _busy


func has_active_session() -> bool:
	return session.active


func get_session_label() -> String:
	return session.label()


func get_project_path() -> String:
	return session.project_path


func new_game() -> void:
	_busy = false
	_awaiting = ""
	_awaiting_tex = false
	_download_active = false
	_pending_downloads.clear()
	_plan = {}
	_plan_raw = ""
	session.clear()
	status.emit("New Game — describe what to make, then Create Game.")
	session_changed.emit()


func create_game(description: String, genre_index: int = 0) -> void:
	if _busy:
		status.emit("Already creating… press New Game to cancel.")
		return
	var text := description.strip_edges()
	if text.is_empty() and genre_index <= 0:
		status.emit("Type a game description in the search box.")
		pipeline_finished.emit(false, {"ok": false, "error": "Empty description"})
		return

	_busy = true
	_notes.clear()
	_research = ""
	_asset_research = ""
	_plan = {}
	_plan_raw = ""
	_pending_downloads.clear()
	_download_active = false
	_modify = session.active
	_description = text
	_genre_id = GenreCatalogScript.id_at(genre_index)
	_inspiration = GameInspirationsScript.detect(_description)
	_genre = GenreCatalogScript.detect(_description, _genre_id)
	_genre_id = str(_genre.get("id", _genre_id))
	if not _inspiration.is_empty() and not _modify:
		_genre_id = str(_inspiration.get("genre_id", _genre_id))
		_description = GameInspirationsScript.enrich_prompt(_description, _inspiration)
	if _genre_id.is_empty() or _genre_id == "custom":
		_genre_id = "fps"
		_genre = GenreCatalogScript.by_id("fps")
	if _description.is_empty():
		_description = "Build a playable Godot 4 %s" % str(_genre.get("name", _genre_id))

	if _modify:
		_notes.append("MODIFY — ChatGPT will follow new directions on the active game.")
		status.emit("ChatGPT modifying game from new directions…")
		var existing: Array = ProjectWriterScript.read_project_files(session.project_path)
		_base = {
			"ok": true,
			"project_name": session.project_name,
			"summary": "Modified from new directions",
			"howto": [],
			"files": existing if not existing.is_empty() else GenreTemplatesScript.build(_genre_id).get("files", []),
		}
	else:
		_notes.append("CREATE — Godot template + C++ GDExtension + ChatGPT plan + code + assets" if AppSettings.create_with_cpp else "CREATE — Godot template + ChatGPT plan + code + assets")
		status.emit("Loading Godot %s template…" % str(_genre.get("name", _genre_id)))
		_base = GenreTemplatesScript.build(_genre_id)
		if _base.is_empty() or not _base.has("files"):
			_base = GenreTemplatesScript.build("fps")
			_genre_id = "fps"

	var starter := _build_and_write_starter()
	if not starter.get("ok", false):
		_busy = false
		pipeline_finished.emit(false, starter)
		return

	_start_texture_download()

	if not AppSettings.has_any_ai_key():
		status.emit("Game created (offline). Add ChatGPT key in Settings for AI coding.")
		_busy = false
		pipeline_finished.emit(true, starter)
		return

	# Playable now; ChatGPT plan → code continues
	pipeline_finished.emit(true, starter)
	if AppSettings.use_web_search:
		_awaiting = "search_godot"
		status.emit("Searching Godot tutorials, assets, engines docs…")
		var q: String = "Godot 4 %s tutorial GDExtension C++ godot-cpp gdscript template CC0 textures sprites %s" % [
			str(_genre.get("name", _genre_id)), _description.left(80)
		]
		if search.search(q) != OK:
			_begin_asset_search()
	else:
		_begin_ai_plan()


func _build_and_write_starter() -> Dictionary:
	var built: Dictionary = _base.duplicate(true)
	var files: Array = built.get("files", []).duplicate()
	files = OfflineEnhancerScript.apply(files, _description, _genre_id)
	files = ArtPipelineScript.write_guides_into_files(files)
	if AppSettings.create_with_cpp:
		files = _ensure_cpp_scaffold(files)
	var engine_line: String = "Godot 4 + C++ GDExtension (GDScript fallback until native lib is built)" if AppSettings.create_with_cpp else "Godot 4"
	files.append({
		"path": "PLAYER_BRIEF.md",
		"content": "# Game brief (player directions)\n\n%s\n\nGenre: %s\nEngine: %s\n" % [_description, _genre_id, engine_line],
	})
	files.append({
		"path": "docs/RESOURCES.md",
		"content": """# Resources / engine
- **Game engine:** Godot 4 (your installed executable)
- **Gameplay code:** %s
- Studio genre template: %s
- ChatGPT / Claude / Gemini write C++ + GDScript when API keys are set
- CC0 textures via Openverse; kits: Kenney, OpenGameArt, Godot Asset Library
- Directions are applied as AI instructions on Create / Modify
""" % [
			"C++ GDExtension in src/ (intended) + GDScript fallback in scripts/" if AppSettings.create_with_cpp else "GDScript in scripts/",
			_genre_id,
		],
	})
	built["files"] = files
	built["ok"] = true
	built["summary"] = "Playable %s from: %s" % [_genre_id, _description.left(100)]
	var force: String = session.project_path if _modify else ""
	var written: Dictionary = ProjectWriterScript.write_project(built, force)
	if not written.get("ok", false):
		status.emit("Write failed: %s" % str(written.get("error", "?")))
		return written
	if not session.active:
		session.start(str(written.get("path", "")), str(written.get("project_name", "")), _genre_id)
	else:
		session.bump(_description)
	if AppSettings.create_with_cpp:
		_note_cpp_build(not _modify)
	written["session"] = session.label()
	written["summary"] = built.get("summary", "")
	written["howto"] = built.get("howto", ["Run Game", "WASD / mouse as shown in HUD"])
	written["notes"] = "\n".join(_notes)
	session_changed.emit()
	if Engine.get_main_loop() is SceneTree:
		var root = (Engine.get_main_loop() as SceneTree).root
		if root.has_node("StudioMemory"):
			root.get_node("StudioMemory").record_pipeline_success(
				_genre_id, _genre_id, {"id": _genre_id, "name": str(_genre.get("name", "")), "genre_id": _genre_id},
				_description, str(built.get("summary", ""))
			)
	return written


func _ensure_cpp_scaffold(files: Array) -> Array:
	for f in files:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		if str(f.get("path", "")).begins_with("src/"):
			return files
	_notes.append("C++ GDExtension scaffold (src/, SConstruct, bin/game.gdextension) + GDScript fallback")
	return CppGdextensionScript.overlay(files, _genre_id, _description)


func _note_cpp_build(start_build: bool) -> void:
	if session.project_path.is_empty():
		return
	if start_build:
		var result: Dictionary = CppBuilderScript.try_start_build(session.project_path)
		_notes.append(str(result.get("message", "C++ build status written.")))
		status.emit(str(result.get("message", "C++ scaffolding ready.")))
		return
	var info: Dictionary = CppBuilderScript.detect()
	var status_path: String = session.project_path.path_join("docs/CPP_STATUS.md")
	DirAccess.make_dir_recursive_absolute(status_path.get_base_dir())
	var f: FileAccess = FileAccess.open(status_path, FileAccess.WRITE)
	if f:
		f.store_string(CppBuilderScript.status_markdown(info))
	_notes.append("C++ sources updated — rebuild with build_cpp.ps1 / build_cpp.sh to refresh the native extension.")


func _start_texture_download() -> void:
	var q := ImageAssetClientScript.detect_texture_query(_description)
	if q.is_empty():
		match _genre_id:
			"fps", "tps":
				q = "brick wall seamless texture"
			"voxel":
				q = "grass dirt block texture"
			"platformer":
				q = "pixel tileset platformer"
			"space_shooter":
				q = "space starfield texture"
			_:
				q = "game texture seamless CC0"
	_queue_texture_download("wall.png", q + " CC0")


func _queue_texture_download(filename: String, query: String) -> void:
	_pending_downloads.append({"filename": filename, "query": query})
	if not _download_active:
		_pump_downloads()


func _pump_downloads() -> void:
	if _pending_downloads.is_empty():
		_download_active = false
		_awaiting_tex = false
		return
	_download_active = true
	var job: Dictionary = _pending_downloads.pop_front()
	_awaiting_tex = true
	_tex_filename = str(job.get("filename", "wall.png"))
	if _tex_filename.is_empty():
		_tex_filename = "wall.png"
	var q: String = str(job.get("query", "CC0 texture"))
	status.emit("Downloading asset: %s …" % _tex_filename)
	images.search(q)


var _tex_filename := "wall.png"


func _on_images_found(ok: bool, _results: Array, _error: String) -> void:
	if not _awaiting_tex:
		return
	if not ok or images.result_count() <= 0:
		_awaiting_tex = false
		_pump_downloads()
		return
	_tex_index = 0
	images.load_preview(0)


func _on_image_ready(ok: bool, index: int, texture: Texture2D, meta: Dictionary, _error: String) -> void:
	if not _awaiting_tex or index != _tex_index:
		return
	_awaiting_tex = false
	if ok and texture != null and not session.project_path.is_empty():
		var dest_dir: String = session.project_path.path_join("assets")
		DirAccess.make_dir_recursive_absolute(dest_dir)
		var dest: String = dest_dir.path_join(_tex_filename)
		var cache: String = str(meta.get("cache_path", ""))
		var saved := false
		if str(meta.get("source", "")) == "procedural" or cache.is_empty():
			if texture is ImageTexture:
				var img: Image = (texture as ImageTexture).get_image()
				if img:
					img.save_png(dest)
					saved = true
		else:
			var bytes := FileAccess.get_file_as_bytes(cache)
			if not bytes.is_empty():
				var f := FileAccess.open(dest, FileAccess.WRITE)
				if f:
					f.store_buffer(bytes)
					saved = true
		if saved:
			_notes.append("Asset → assets/%s" % _tex_filename)
			status.emit("Asset saved: assets/%s" % _tex_filename)
	_pump_downloads()


func _begin_asset_search() -> void:
	_awaiting = "search_assets"
	status.emit("Searching CC0 textures / sprites / Godot AssetLib…")
	var q := "Kenney CC0 %s sprites textures OpenGameArt Godot Asset Library" % str(_genre.get("name", _genre_id))
	if search.search(q) != OK:
		_begin_ai_plan()


func _on_search(ok: bool, text: String, error: String) -> void:
	if _awaiting == "search_godot":
		_research = text if ok else error
		_notes.append("Godot/web research done.")
		_begin_asset_search()
		return
	if _awaiting == "search_assets":
		_asset_research = text if ok else error
		_notes.append("Asset research done.")
		_begin_ai_plan()


func _begin_ai_plan() -> void:
	status.emit("ChatGPT writing build plan (instructions + assets)…")
	var engine_req: String = "Godot 4 + C++ GDExtension (godot-cpp). Also specify GDScript fallback bootstrap." if AppSettings.create_with_cpp else "Godot 4 (GDScript 2.0)"
	var user := """PLAYER DIRECTIONS (follow exactly):
%s

MODE: %s
GENRE: %s
ENGINE REQUIRED: %s

GODOT / TUTORIAL RESEARCH:
%s

ASSET / TEXTURE RESEARCH:
%s

Write the BUILD PLAN JSON now — instructions the coder must follow, plus required textures/sprites/addons.
If C++ mode: list src/*.cpp classes to implement or update, plus GDScript fallback files.
""" % [
		_description,
		"MODIFY existing game" if _modify or session.active else "CREATE new game",
		"%s — %s" % [_genre_id, str(_genre.get("inspiration_notes", ""))],
		engine_req,
		_research.left(3500),
		_asset_research.left(2500),
	]
	_awaiting = "plan"
	if not _dispatch_ai(SYSTEM_PLAN if AppSettings.create_with_cpp else SYSTEM_PLAN_GDSCRIPT, user):
		_begin_ai_code()


func _begin_ai_code() -> void:
	status.emit("ChatGPT writing Godot C++ / GDScript from plan + directions…" if AppSettings.create_with_cpp else "ChatGPT writing Godot scripts from plan + directions…")
	var files_blob := ""
	if session.active:
		var live: Array = ProjectWriterScript.read_project_files(session.project_path)
		for f2 in live:
			files_blob += "\n----- %s -----\n%s\n" % [str(f2.get("path", "")), str(f2.get("content", ""))]
	else:
		for f in _base.get("files", []):
			if typeof(f) != TYPE_DICTIONARY:
				continue
			files_blob += "\n----- %s -----\n%s\n" % [str(f.get("path", "")), str(f.get("content", ""))]

	var plan_text := _plan_raw if not _plan_raw.is_empty() else JSON.stringify(_plan)
	var engine_line: String = "Godot 4 + C++ GDExtension (update src/ C++ AND scripts/ GDScript fallback)" if AppSettings.create_with_cpp else "Godot 4 GDScript"
	var user := """PLAYER DIRECTIONS (highest priority — implement these):
%s

BUILD PLAN FROM CHATGPT (follow these instructions):
%s

GENRE: %s
MODE: %s
PROJECT NAME: %s
ENGINE: %s

GODOT RESEARCH:
%s

ASSET RESEARCH:
%s

CURRENT FILES:
%s

Write/update the Godot 4 project JSON now.
If ENGINE includes C++, update src/*.h / src/*.cpp gameplay to match new directions (merge, do not drop GDExtension glue).
Keep scripts/*.gd + scenes/main.tscn playable without a compiled .dll/.so.
Use assets/wall.png (and other assets/*.png listed) for materials/sprites when present.
Include download_queries for any extra CC0 textures still needed.
""" % [
		_description,
		plan_text.left(6000),
		_genre_id,
		"MODIFY — merge into current files" if _modify or session.active else "CREATE from template + plan",
		session.project_name if session.active else str(_base.get("project_name", "ai_game")),
		engine_line,
		_research.left(3000),
		_asset_research.left(2000),
		files_blob.left(26000),
	]
	_awaiting = "code"
	if not _dispatch_ai(SYSTEM_CODE if AppSettings.create_with_cpp else SYSTEM_CODE_GDSCRIPT, user):
		_busy = false
		status.emit("No AI key — starter game ready. Run Game.")


func _dispatch_ai(system_prompt: String, user_prompt: String) -> bool:
	# Prefer ChatGPT / OpenAI first, then Claude, then Gemini
	if AppSettings.use_openai and not AppSettings.openai_api_key.is_empty():
		var err: Error = openai.chat(system_prompt, user_prompt)
		if err == ERR_BUSY:
			status.emit("ChatGPT busy — retrying with next AI…")
		else:
			_notes.append("Using ChatGPT / OpenAI")
			return true
	if AppSettings.use_claude and not AppSettings.claude_api_key.is_empty():
		var err_c: Error = claude.chat(system_prompt, user_prompt)
		if err_c != ERR_BUSY:
			_notes.append("Using Claude")
			return true
	if AppSettings.use_gemini and not AppSettings.gemini_api_key.is_empty():
		var err_g: Error = gemini.chat(system_prompt, user_prompt)
		if err_g != ERR_BUSY:
			_notes.append("Using Gemini")
			return true
	return false


func _on_ai(ok: bool, text: String, error: String) -> void:
	if _awaiting == "plan":
		_handle_plan_reply(ok, text, error)
		return
	if _awaiting == "code":
		_handle_code_reply(ok, text, error)


func _handle_plan_reply(ok: bool, text: String, error: String) -> void:
	if not ok:
		status.emit("Plan AI failed (%s) — coding from directions anyway…" % error)
		_plan_raw = ""
		_plan = {}
		_begin_ai_code()
		return
	_plan_raw = text
	_plan = GameGeneratorScript.parse_plan_json(text)
	_write_plan_docs()
	_queue_plan_assets()
	status.emit("Build plan ready — ChatGPT coding the Godot game…")
	_begin_ai_code()


func _write_plan_docs() -> void:
	if session.project_path.is_empty():
		return
	var instructions: Array = _plan.get("instructions", [])
	var assets: Array = _plan.get("assets_required", [])
	var gameplay: Array = _plan.get("gameplay", [])
	var features: Array = _plan.get("godot_features", [])
	var body := "# AI Build Plan (ChatGPT)\n\n"
	body += "## Title\n%s\n\n" % str(_plan.get("title", session.project_name))
	body += "## Player directions\n%s\n\n" % _description
	body += "## Engine\n%s\n\n" % ("Godot 4 + C++ GDExtension (godot-cpp) with GDScript fallback" if AppSettings.create_with_cpp else "Godot 4 (GDScript 2.0)")
	body += "## Instructions\n"
	for i in instructions:
		body += "- %s\n" % str(i)
	body += "\n## Gameplay\n"
	for g in gameplay:
		body += "- %s\n" % str(g)
	body += "\n## Godot features / nodes\n"
	for f in features:
		body += "- %s\n" % str(f)
	body += "\n## Assets required\n"
	for a in assets:
		if typeof(a) == TYPE_DICTIONARY:
			body += "- **%s** (%s): query `%s` — %s\n" % [
				str(a.get("name", "")), str(a.get("type", "")),
				str(a.get("query", "")), str(a.get("usage", "")),
			]
		else:
			body += "- %s\n" % str(a)
	body += "\n## Modify notes\n%s\n" % str(_plan.get("modify_notes", ""))
	var instr_md := "# Coder instructions\n\n"
	for step in instructions:
		instr_md += "- %s\n" % str(step)
	var docs := [
		{"path": "docs/AI_PLAN.md", "content": body},
		{"path": "docs/AI_INSTRUCTIONS.md", "content": instr_md},
	]
	ProjectWriterScript.write_project({
		"ok": true,
		"project_name": session.project_name,
		"files": docs,
	}, session.project_path)
	_notes.append("Wrote docs/AI_PLAN.md + AI_INSTRUCTIONS.md")


func _queue_plan_assets() -> void:
	var assets: Array = _plan.get("assets_required", [])
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var fname := str(a.get("name", "")).get_file()
		var query := str(a.get("query", ""))
		if fname.is_empty() or query.is_empty():
			continue
		if not fname.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			fname = fname.get_basename() + ".png"
		_queue_texture_download(fname, query + " CC0")


func _handle_code_reply(ok: bool, text: String, error: String) -> void:
	if not ok:
		status.emit("AI code failed (%s) — starter game still playable." % error)
		_busy = false
		_awaiting = ""
		return
	var parsed: Dictionary = GameGeneratorScript.parse_project_json(text)
	if not parsed.get("ok", false):
		status.emit("AI JSON invalid — starter game still playable.")
		_busy = false
		_awaiting = ""
		return
	parsed["project_name"] = session.project_name
	parsed["revision"] = session.revision + 1
	var files = parsed.get("files", [])
	if typeof(files) == TYPE_ARRAY:
		files = ArtPipelineScript.write_guides_into_files(files)
		# Keep plan docs
		if not _plan.is_empty():
			files.append({
				"path": "PLAYER_BRIEF.md",
				"content": "# Game brief (player directions)\n\n%s\n\nGenre: %s\nEngine: %s\n" % [
					_description, _genre_id,
					"Godot 4 + C++ GDExtension" if AppSettings.create_with_cpp else "Godot 4",
				],
			})
		parsed["files"] = files
	var written: Dictionary = ProjectWriterScript.write_project(parsed, session.project_path)
	if written.get("ok", false) and AppSettings.create_with_cpp:
		_repair_cpp_glue()
	_busy = false
	_awaiting = ""
	if written.get("ok", false):
		session.bump(_description)
		written["session"] = session.label()
		if AppSettings.create_with_cpp:
			written["notes"] = "ChatGPT updated Godot C++ / GDScript from your directions.\n" + "\n".join(_notes)
		else:
			written["notes"] = "ChatGPT updated Godot scripts from your directions.\n" + "\n".join(_notes)
		written["summary"] = str(parsed.get("summary", written.get("summary", "")))
		_queue_ai_download_queries(parsed)
		status.emit("Game built by ChatGPT — Run Game (or type changes + Create to modify)")
		session_changed.emit()
		pipeline_finished.emit(true, written)
	else:
		status.emit("AI write failed — starter still on disk.")
		pipeline_finished.emit(false, written)


func _repair_cpp_glue() -> void:
	if session.project_path.is_empty():
		return
	var pg_path: String = session.project_path.path_join("project.godot")
	if FileAccess.file_exists(pg_path):
		var pg: String = FileAccess.get_file_as_string(pg_path)
		var patched: String = CppGdextensionScript.ensure_project_autoload(pg)
		if patched != pg:
			var f: FileAccess = FileAccess.open(pg_path, FileAccess.WRITE)
			if f:
				f.store_string(patched)
	var bridge_path: String = session.project_path.path_join("scripts/cpp_bridge.gd")
	var gdext_path: String = session.project_path.path_join("bin/game.gdextension")
	if FileAccess.file_exists(bridge_path) and FileAccess.file_exists(gdext_path):
		return
	var glued: Array = CppGdextensionScript.overlay([], _genre_id, _description)
	var repair_files: Array = []
	for f2 in glued:
		if typeof(f2) != TYPE_DICTIONARY:
			continue
		var rel: String = str(f2.get("path", ""))
		if rel == "scripts/cpp_bridge.gd" or rel == "bin/game.gdextension" or rel == "SConstruct" or rel == "docs/CPP_BUILD.md":
			if not FileAccess.file_exists(session.project_path.path_join(rel)):
				repair_files.append(f2)
	if not repair_files.is_empty():
		ProjectWriterScript.write_project({
			"ok": true,
			"project_name": session.project_name,
			"files": repair_files,
		}, session.project_path)


func _queue_ai_download_queries(parsed: Dictionary) -> void:
	var queries = parsed.get("download_queries", [])
	if typeof(queries) != TYPE_ARRAY:
		return
	for q in queries:
		if typeof(q) == TYPE_DICTIONARY:
			var fname := str(q.get("filename", q.get("name", "wall.png"))).get_file()
			var query := str(q.get("query", ""))
			if query.is_empty():
				continue
			if fname.is_empty():
				fname = "wall.png"
			if not fname.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
				fname = fname.get_basename() + ".png"
			_queue_texture_download(fname, query + " CC0")
		elif typeof(q) == TYPE_STRING and not str(q).is_empty():
			_queue_texture_download("extra_tex.png", str(q) + " CC0")
