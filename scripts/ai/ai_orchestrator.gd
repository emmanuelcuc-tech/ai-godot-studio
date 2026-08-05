extends Node
## Game Factory — ChatGPT/AI plans + codes Godot games from your directions.
## Flow: starter → search → AI PLAN → multi-asset / addon / open-ref fetch → AI CODE

signal status(message: String)
signal pipeline_finished(success: bool, result: Dictionary)
signal session_changed

const OpenAIClientScript = preload("res://scripts/ai/openai_client.gd")
const ClaudeClientScript = preload("res://scripts/ai/claude_client.gd")
const GeminiClientScript = preload("res://scripts/ai/gemini_client.gd")
const WebSearchClientScript = preload("res://scripts/ai/web_search_client.gd")
const ImageAssetClientScript = preload("res://scripts/ai/image_asset_client.gd")
const AssetLibClientScript = preload("res://scripts/ai/assetlib_client.gd")
const OpenRefClientScript = preload("res://scripts/ai/open_ref_client.gd")
const ResourceCatalogScript = preload("res://scripts/ai/resource_catalog.gd")
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
const GameAssetLayoutScript = preload("res://scripts/editors/game_asset_layout.gd")
const StudioGameConfigScript = preload("res://scripts/editors/studio_game_config.gd")
const ProceduralArtScript = preload("res://scripts/ai/procedural_art.gd")
const GameProjectBriefScript = preload("res://scripts/game_project_brief.gd")
const GraphicStyleScript = preload("res://scripts/graphic_style.gd")
const ArtEditIntentScript = preload("res://scripts/art_edit_intent.gd")

const MAX_TEXTURE_JOBS := 8
const RESOURCE_WAIT_SEC := 28.0
const IMAGE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

const SYSTEM_PLAN := """You are a lead Godot 4 game designer working with ChatGPT-style instructions.
From the player's directions, write a concrete BUILD PLAN the coder will follow.
Engine is ALWAYS Godot 4 with **C++ GDExtension (godot-cpp)** as the intended implementation.
Also plan a **playable GDScript 2.0 fallback** so the game runs before the native library is compiled.
Never use Unity/Unreal/GameMaker as the runtime.
List C++ classes/files (src/*.h, src/*.cpp), GDScript bootstrap, textures/sprites/models the studio already wrote under assets/, materials, plugins, and Asset Library ideas (CC0 / open / generated only — never commercial ROMs or ripped assets).
Wire wall.png / floor.png / character sprites or capsule meshes that exist on disk. Recreate feel with original art — do not copy proprietary files.
Return ONLY JSON (no markdown fences):
{
  "title":"short name",
  "instructions":["step-by-step build instructions the coder must follow"],
  "gameplay":["core loops / controls / win-lose"],
  "godot_features":["GDExtension classes, nodes, systems, scenes needed"],
  "cpp_classes":["GameApp","GamePlayer","GameWorld","GameEnemy"],
  "assets_required":[
    {"name":"wall.png","type":"texture","query":"cc0 brick wall seamless","usage":"corridor walls"},
    {"name":"floor.png","type":"texture","query":"cc0 concrete floor seamless","usage":"floors"},
    {"name":"sprite_enemy.png","type":"sprite","query":"cc0 pixel monster sprite","usage":"enemy"}
  ],
  "download_queries":[{"filename":"sky.png","query":"cc0 stormy sky"}],
  "plugins_or_addons":["Godot AssetLib search terms that match the genre"],
  "modify_notes":"if updating an existing game, what to change vs keep (update C++ sources + GDScript fallback together)"
}"""

const SYSTEM_CODE := """You are a Godot 4 + GDExtension (C++ / godot-cpp) programmer. Follow the BUILD PLAN and USER DIRECTIONS exactly.
Write or UPDATE a playable Godot 4 project whose **intended gameplay is C++**:
- src/register_types.h + src/register_types.cpp (entry symbol game_library_init)
- src/game_app.*, src/game_player.*, src/game_world.*, src/game_enemy.* matching the genre/description
- bin/game.gdextension, SConstruct and/or CMakeLists.txt, docs/CPP_BUILD.md
Also keep a **playable GDScript 2.0 fallback** (scripts/*.gd + scenes/main.tscn) so Run Game works without a compiler.
Optional scenes/main_cpp.tscn may use native class names GamePlayer / GameWorld after the extension is built.
Use assets already on disk via category folders:
assets/character/, assets/enemy/, assets/weapon/, assets/world/, assets/ui/, assets/effects/, assets/background/, assets/materials/, assets/models/, assets/sprites/, assets/textures/
Also keep root aliases like assets/wall.png when present. Wire StandardMaterial3D.albedo_texture or Sprite2D.texture. Honor res://studio_display.json, studio_effects.json, studio_controls.json, studio_anim.json and scripts/studio_runtime.gd autoload.
Match feel with original/CC0/generated art already on disk — never commercial ROMs or ripped assets. Always load assets/wall.png, assets/floor.png, assets/character/* and assets/enemy/* when those files exist. Keep a visible mesh or sprite for the player (capsule/box + texture is fine).
Study refs/<name>/ open Godot samples (README + scripts) for genre patterns. Do not copy proprietary assets.
If addons/ contains a plugin.cfg, you may enable it in project.godot [editor_plugins] only when safe; gameplay must still run without it.
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
List several matching textures/sprites, materials, plugins, and Asset Library ideas (CC0 / open only — never commercial ROMs or ripped assets).
Return ONLY JSON (no markdown fences):
{
  "title":"short name",
  "instructions":["step-by-step build instructions the coder must follow"],
  "gameplay":["core loops / controls / win-lose"],
  "godot_features":["nodes, systems, scenes needed"],
  "assets_required":[
    {"name":"wall.png","type":"texture","query":"cc0 brick wall seamless","usage":"corridor walls"},
    {"name":"floor.png","type":"texture","query":"cc0 concrete floor seamless","usage":"floors"},
    {"name":"sprite_player.png","type":"sprite","query":"cc0 pixel hero sprite","usage":"player"}
  ],
  "download_queries":[{"filename":"sky.png","query":"cc0 sky background"}],
  "plugins_or_addons":["Godot AssetLib search terms that match the genre"],
  "modify_notes":"if updating an existing game, what to change vs keep"
}"""

const SYSTEM_CODE_GDSCRIPT := """You are a Godot 4 programmer. Follow the BUILD PLAN and USER DIRECTIONS exactly.
Write or UPDATE a playable Godot 4 project in GDScript 2.0 only.
Use assets already on disk via category folders:
assets/character/, assets/enemy/, assets/weapon/, assets/world/, assets/ui/, assets/effects/, assets/background/, assets/materials/, assets/models/, assets/sprites/, assets/textures/
Also keep root aliases like assets/wall.png when present. Wire StandardMaterial3D.albedo_texture or Sprite2D.texture. Honor res://studio_display.json, studio_effects.json, studio_controls.json, studio_anim.json and scripts/studio_runtime.gd autoload.
Match feel with original/CC0/generated art already on disk — never commercial ROMs or ripped assets. Always load assets/wall.png, assets/floor.png, assets/character/* and assets/enemy/* when those files exist. Keep a visible mesh or sprite for the player.
Study refs/<name>/ open Godot samples for genre patterns. Gameplay must run even if addons/ is empty.
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
var assetlib
var openrefs
var session = GameSessionScript.new()

var _busy: bool = false
var _awaiting: String = ""
var _description: String = ""
var _genre_id: String = "fps"
var _genre: Dictionary = {}
var _inspiration: Dictionary = {}
var _art_kinds: Dictionary = {"textures": true, "sprites": true, "models": true}
var _graphic_styles: PackedStringArray = PackedStringArray(["3d", "detailed"])
var _art_slots: PackedStringArray = PackedStringArray()
var _base: Dictionary = {}
var _research: String = ""
var _asset_research: String = ""
var _plan: Dictionary = {}
var _plan_raw: String = ""
var _notes: PackedStringArray = []
var _modify: bool = false
var _awaiting_tex: bool = false
var _tex_index: int = 0
var _pending_downloads: Array = []
var _download_active: bool = false
var _tex_filename: String = "wall.png"
var _tex_query: String = ""
var _tex_category: String = "textures"
var _queued_names: Dictionary = {}
var _downloaded_assets: Array = []
var _addon_busy: bool = false
var _ref_busy: bool = false
var _addon_listed: Array = []
var _addon_installed: Dictionary = {}
var _ref_result: Dictionary = {}
var _ref_summary: String = ""
var _waiting_resources: bool = false
var _want_ai_after_resources: bool = false
var _res_gen: int = 0
var _resource_timer: Timer
var _game_project: Dictionary = {}
var _pending_url_jobs: Array = []
var _url_active: bool = false


func _ready() -> void:
	openai = OpenAIClientScript.new()
	claude = ClaudeClientScript.new()
	gemini = GeminiClientScript.new()
	search = WebSearchClientScript.new()
	images = ImageAssetClientScript.new()
	assetlib = AssetLibClientScript.new()
	openrefs = OpenRefClientScript.new()
	openai.attach(self)
	claude.attach(self)
	gemini.attach(self)
	search.attach(self)
	images.attach(self)
	assetlib.attach(self)
	openrefs.attach(self)
	openai.reply.connect(_on_ai)
	claude.reply.connect(_on_ai)
	gemini.reply.connect(_on_ai)
	search.reply.connect(_on_search)
	images.search_done.connect(_on_images_found)
	images.preview_ready.connect(_on_image_ready)
	assetlib.status.connect(func(m: String): status.emit(m))
	assetlib.finished.connect(_on_addon_finished)
	openrefs.status.connect(func(m: String): status.emit(m))
	openrefs.finished.connect(_on_ref_finished)
	session.changed.connect(func(): session_changed.emit())
	_resource_timer = Timer.new()
	_resource_timer.one_shot = true
	_resource_timer.timeout.connect(_on_resource_timeout)
	add_child(_resource_timer)


func is_busy() -> bool:
	return _busy


func has_active_session() -> bool:
	return session.active


func get_session_label() -> String:
	return session.label()


func get_project_path() -> String:
	return session.project_path


func new_game() -> void:
	_res_gen += 1
	_busy = false
	_awaiting = ""
	_awaiting_tex = false
	_download_active = false
	_pending_downloads.clear()
	_queued_names.clear()
	_downloaded_assets.clear()
	_addon_busy = false
	_ref_busy = false
	_waiting_resources = false
	_want_ai_after_resources = false
	_addon_listed.clear()
	_addon_installed = {}
	_ref_result = {}
	_ref_summary = ""
	_plan = {}
	_plan_raw = ""
	_game_project = {}
	_pending_url_jobs.clear()
	_url_active = false
	if openrefs:
		openrefs.cancel()
	if _resource_timer:
		_resource_timer.stop()
	session.clear()
	status.emit("New Game — describe what to make, then Create Game.")
	session_changed.emit()


func apply_art_edit(options: Dictionary = {}) -> void:
	if not session.active or session.project_path.is_empty():
		status.emit("Create a game first.")
		pipeline_finished.emit(false, {"ok": false, "error": "No active game"})
		return
	if _busy:
		status.emit("Still creating — wait or press New Game.")
		return
	_art_kinds = ProceduralArtScript.normalize_kinds({
		"textures": options.get("textures", true),
		"sprites": options.get("sprites", false),
		"models": options.get("models", false),
	})
	_graphic_styles = GraphicStyleScript.from_variant(options.get("graphic_styles", []))
	if _graphic_styles.is_empty():
		_graphic_styles = GraphicStyleScript.from_variant(StudioGameConfigScript.load_style(session.project_path).get("graphic_styles", []))
	if _graphic_styles.is_empty():
		_graphic_styles = GraphicStyleScript.defaults_for_genre(_genre_id)
	ProceduralArtScript.set_styles(_graphic_styles)
	StudioGameConfigScript.set_graphic_styles(session.project_path, _graphic_styles)
	StudioGameConfigScript.set_art_kinds(session.project_path, _art_kinds)
	_art_slots = PackedStringArray()
	var slot_opt: Variant = options.get("art_slots", [])
	if typeof(slot_opt) == TYPE_PACKED_STRING_ARRAY:
		_art_slots = slot_opt
	elif typeof(slot_opt) == TYPE_ARRAY:
		for item in slot_opt:
			_art_slots.append(str(item))
	if _art_slots.is_empty():
		status.emit("Pick Wall / Floor / Room / Character / Weapon first.")
		pipeline_finished.emit(false, {"ok": false, "error": "No art slots"})
		return
	var note: String = str(options.get("description", "")).strip_edges()
	if not note.is_empty():
		_description = note
	status.emit("Updating art slots (%s) in style %s…" % [", ".join(_art_slots), GraphicStyleScript.label(_graphic_styles)])
	_refresh_art_slots(_art_slots, true)
	_notes.append("Art edit applied: %s / %s" % [", ".join(_art_slots), GraphicStyleScript.label(_graphic_styles)])
	session_changed.emit()
	pipeline_finished.emit(true, {
		"ok": true,
		"art_edit": true,
		"path": session.project_path,
		"summary": "Art slots updated: %s" % ", ".join(_art_slots),
		"session": session.label(),
	})


func create_game(description: String, genre_index: int = 0, options: Dictionary = {}) -> void:
	if _busy:
		status.emit("Already creating… press New Game to cancel.")
		return
	var text := description.strip_edges()
	if text.is_empty() and genre_index <= 0:
		status.emit("Type a game description in the search box.")
		pipeline_finished.emit(false, {"ok": false, "error": "Empty description"})
		return

	_res_gen += 1
	_busy = true
	_notes.clear()
	_research = ""
	_asset_research = ""
	_plan = {}
	_plan_raw = ""
	_pending_downloads.clear()
	_queued_names.clear()
	_downloaded_assets.clear()
	_download_active = false
	_pending_url_jobs.clear()
	_url_active = false
	_addon_busy = false
	_ref_busy = false
	_waiting_resources = false
	_want_ai_after_resources = false
	_addon_listed.clear()
	_addon_installed = {}
	_ref_result = {}
	_ref_summary = ""
	_game_project = {}
	if openrefs:
		openrefs.cancel()
	if _resource_timer:
		_resource_timer.stop()
	_modify = session.active
	_art_kinds = ProceduralArtScript.normalize_kinds({
		"textures": options.get("textures", AppSettings.use_art_textures),
		"sprites": options.get("sprites", AppSettings.use_art_sprites),
		"models": options.get("models", AppSettings.use_art_models),
	})
	_graphic_styles = GraphicStyleScript.from_variant(options.get("graphic_styles", AppSettings.graphic_styles))
	_art_slots = PackedStringArray()
	var slot_opt: Variant = options.get("art_slots", [])
	if typeof(slot_opt) == TYPE_PACKED_STRING_ARRAY:
		_art_slots = slot_opt
	elif typeof(slot_opt) == TYPE_ARRAY:
		for item in slot_opt:
			_art_slots.append(str(item))
	var gp_parse: Dictionary = GameProjectBriefScript.try_parse_text(text)
	if str(gp_parse.get("kind", "")) == "gameproject":
		_game_project = gp_parse.get("data", {}) if typeof(gp_parse.get("data", {})) == TYPE_DICTIONARY else {}
		text = GameProjectBriefScript.directions_text(_game_project)
		if text.is_empty():
			text = str(_game_project.get("title", "Studio game"))
		var gp_genre: String = str(_game_project.get("genre", "")).strip_edges()
		if not gp_genre.is_empty():
			var mapped: int = GenreCatalogScript.index_for_text(gp_genre)
			if mapped > 0:
				genre_index = mapped
		_notes.append("GameProject JSON applied.")
	elif str(gp_parse.get("kind", "")) == "skipped":
		_notes.append(str(gp_parse.get("reason", "skipped — not a game spec")))
	elif str(gp_parse.get("kind", "")) == "site_only":
		_notes.append("Ignored npm site config.")
		var site_name: String = str(gp_parse.get("name", "")).strip_edges()
		if not site_name.is_empty() and site_name.to_lower() != "untitled" and text.begins_with("{"):
			text = site_name
	elif str(gp_parse.get("kind", "")) == "name_only":
		var only_name: String = str(gp_parse.get("name", "")).strip_edges()
		if not only_name.is_empty() and text.begins_with("{"):
			text = only_name
	_description = text
	_genre_id = GenreCatalogScript.id_at(genre_index)
	_inspiration = GameInspirationsScript.detect(_description)
	_genre = GenreCatalogScript.detect(_description, _genre_id)
	_genre_id = str(_genre.get("id", _genre_id))
	if _modify:
		status.emit("Editing existing game from new directions…")
		_notes.append("EDIT — merge new directions into the same project (not a new game).")
	if not _inspiration.is_empty() and not _modify:
		_genre_id = str(_inspiration.get("genre_id", _genre_id))
		_description = GameInspirationsScript.enrich_prompt(_description, _inspiration)
	if _genre_id.is_empty() or _genre_id == "custom":
		_genre_id = "fps"
		_genre = GenreCatalogScript.by_id("fps")
	if _description.is_empty():
		_description = "Build a playable Godot 4 %s" % str(_genre.get("name", _genre_id))
	if _graphic_styles.is_empty():
		if _modify and not session.project_path.is_empty():
			_graphic_styles = GraphicStyleScript.from_variant(StudioGameConfigScript.load_style(session.project_path).get("graphic_styles", []))
		else:
			_graphic_styles = GraphicStyleScript.defaults_for_genre(_genre_id)
	ProceduralArtScript.set_styles(_graphic_styles)
	if _modify and _art_slots.is_empty():
		var detected_slots: Dictionary = ArtEditIntentScript.detect(_description)
		_art_slots = ArtEditIntentScript.selected_slots(detected_slots.get("slots", {}))

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
		var gp_title: String = str(_game_project.get("title", ""))
		_base = GenreTemplatesScript.build(_genre_id, gp_title)
		if _base.is_empty() or not _base.has("files"):
			_base = GenreTemplatesScript.build("fps", gp_title)
			_genre_id = "fps"
		var pname: String = GameProjectBriefScript.sanitize_project_name(gp_title)
		if not pname.is_empty():
			_base["project_name"] = pname

	var starter := _build_and_write_starter()
	if not starter.get("ok", false):
		_busy = false
		pipeline_finished.emit(false, starter)
		return

	_start_texture_download()
	_queue_gameproject_urls()

	if not AppSettings.has_any_ai_key():
		status.emit("Game created (offline). Fetching open assets in the background…")
		_busy = false
		pipeline_finished.emit(true, starter)
		_begin_resource_enrichment(false)
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
	files = StudioGameConfigScript.inject_into_files(files)
	var engine_line: String = "Godot 4 + C++ GDExtension (GDScript fallback until native lib is built)" if AppSettings.create_with_cpp else "Godot 4"
	files.append({
		"path": "PLAYER_BRIEF.md",
		"content": "# Game brief (player directions)\n\n%s\n\nGenre: %s\nEngine: %s\n" % [_description, _genre_id, engine_line],
	})
	files.append({
		"path": "docs/RESOURCES.md",
		"content": _resources_stub_markdown(),
	})
	files.append({
		"path": "docs/PLUGINS.md",
		"content": _plugins_stub_markdown(),
	})
	if not str(_game_project.get("setup_instructions", "")).strip_edges().is_empty():
		files.append({
			"path": "docs/SETUP.md",
			"content": "# Setup\n\n%s\n" % str(_game_project.get("setup_instructions", "")),
		})
	var structure_files: Array = GameProjectBriefScript.parse_structure_files(_game_project.get("project_structure", null))
	for sf in structure_files:
		if typeof(sf) != TYPE_DICTIONARY:
			continue
		var rel: String = str(sf.get("path", ""))
		if rel.is_empty():
			continue
		files.append({"path": rel, "content": str(sf.get("content", ""))})
		_notes.append("GameProject file → %s" % rel)
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
	if not session.project_path.is_empty():
		GameAssetLayoutScript.ensure_layout(session.project_path)
		StudioGameConfigScript.ensure_on_disk(session.project_path)
		StudioGameConfigScript.set_art_kinds(session.project_path, _art_kinds)
		StudioGameConfigScript.set_graphic_styles(session.project_path, _graphic_styles)
		ProceduralArtScript.set_styles(_graphic_styles)
		var art_written: Array = ProceduralArtScript.write_starter_art(session.project_path, _genre_id, _art_kinds)
		for a in art_written:
			if typeof(a) == TYPE_DICTIONARY:
				_downloaded_assets.append(a)
		_notes.append("Starter art on disk (%s files). Style: %s" % [str(art_written.size()), GraphicStyleScript.label(_graphic_styles)])
		if _modify and not _art_slots.is_empty():
			_refresh_art_slots(_art_slots, true)
		_write_gameproject_snapshot(str(written.get("summary", "")))
		status.emit("Wrote visible starter art (textures/sprites/models as chosen).")
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
	var jobs: Array = ResourceCatalogScript.texture_jobs(_genre_id, _description)
	var hint: String = ImageAssetClientScript.detect_texture_query(_description)
	if not hint.is_empty() and not jobs.is_empty():
		var first: Dictionary = jobs[0]
		first["query"] = hint
		jobs[0] = first
	var force_char: bool = _wants_character_improve(_description)
	for job in jobs:
		if typeof(job) != TYPE_DICTIONARY:
			continue
		var fname: String = str(job.get("filename", ""))
		var cat: String = str(job.get("category", GameAssetLayoutScript.categorize(fname, str(job.get("query", "")), str(job.get("usage", "")))))
		if not _job_matches_art_kinds(fname, cat):
			continue
		var force: bool = force_char and (cat == "character" or fname.contains("player") or fname.contains("character"))
		_queue_texture_download(fname, str(job.get("query", "")), force, cat)
	if force_char and not session.project_path.is_empty():
		if bool(_art_kinds.get("sprites", true)) or bool(_art_kinds.get("textures", true)):
			ProceduralArtScript.write_named(session.project_path, "sprite_player.png", "character", "hero", true)
			ProceduralArtScript.write_named(session.project_path, "character.png", "character", "skin", true)
			StudioGameConfigScript.assign_slot(session.project_path, "character", "res://assets/character/sprite_player.png")
			StudioGameConfigScript.assign_slot(session.project_path, "character_texture", "res://assets/character/character.png")
		if bool(_art_kinds.get("models", true)):
			ProceduralArtScript.write_character_model(session.project_path, _genre_id, true)
			StudioGameConfigScript.assign_slot(session.project_path, "character_model", "res://assets/character/character.obj")
		status.emit("Updated character texture/model from your edit directions.")


func _job_matches_art_kinds(filename: String, category: String) -> bool:
	var blob: String = "%s %s" % [filename.to_lower(), category.to_lower()]
	var is_sprite: bool = blob.contains("sprite") or category == "character" or category == "enemy" or category == "ui" or category == "weapon"
	var is_model: bool = blob.ends_with(".glb") or blob.ends_with(".gltf") or blob.ends_with(".obj") or category == "models"
	if is_model:
		return bool(_art_kinds.get("models", true))
	if is_sprite and not bool(_art_kinds.get("sprites", true)) and not bool(_art_kinds.get("textures", true)):
		return false
	if is_sprite:
		return bool(_art_kinds.get("sprites", true)) or bool(_art_kinds.get("textures", true))
	return bool(_art_kinds.get("textures", true))


func _wants_character_improve(text: String) -> bool:
	var q: String = text.to_lower()
	if not (q.contains("character") or q.contains("player") or q.contains("hero") or q.contains("skin")):
		return false
	return q.contains("texture") or q.contains("sprite") or q.contains("model") or q.contains("better") or q.contains("improve") or q.contains("add")


func _art_job_allowed(filename: String, category: String, query: String = "") -> bool:
	var blob: String = "%s %s %s" % [filename.to_lower(), category.to_lower(), query.to_lower()]
	var ext: String = filename.get_extension().to_lower()
	if ext in ["glb", "gltf", "obj", "fbx"] or category == "models" or blob.contains("model"):
		return bool(_art_kinds.get("models", true))
	if category in ["character", "enemy", "weapon", "sprites", "ui"] or blob.contains("sprite") or filename.begins_with("sprite_"):
		return bool(_art_kinds.get("sprites", true))
	return bool(_art_kinds.get("textures", true))


func _queue_gameproject_urls() -> void:
	var urls = _game_project.get("texture_urls", [])
	if typeof(urls) != TYPE_ARRAY:
		return
	var i: int = 0
	for u in urls:
		var url: String = str(u).strip_edges()
		if url.is_empty():
			continue
		var fname: String = url.get_file()
		if fname.is_empty() or not ResourceCatalogScript.is_image_filename(fname):
			fname = "import_%s.png" % str(i)
		if not _art_job_allowed(fname, GameAssetLayoutScript.categorize(fname, url), url):
			i += 1
			continue
		_pending_url_jobs.append({
			"url": url,
			"filename": ResourceCatalogScript.sanitize_filename(fname),
			"category": GameAssetLayoutScript.categorize(fname, url),
		})
		i += 1
	if not _url_active:
		_pump_url_jobs()


func _pump_url_jobs() -> void:
	if _pending_url_jobs.is_empty():
		_url_active = false
		_maybe_finish_resources()
		return
	if images == null:
		_url_active = false
		return
	_url_active = true
	var job: Dictionary = _pending_url_jobs.pop_front()
	var dest: String = GameAssetLayoutScript.dest_abs(session.project_path, str(job.get("filename", "tex.png")), str(job.get("category", "textures")))
	_tex_filename = str(job.get("filename", "tex.png"))
	_tex_category = str(job.get("category", "textures"))
	_tex_query = str(job.get("url", ""))
	status.emit("Downloading GameProject texture…")
	if images.download_url(str(job.get("url", "")), dest) != OK:
		_url_active = false
		_pump_url_jobs()


func _write_gameproject_snapshot(summary: String) -> void:
	if session.project_path.is_empty():
		return
	var gp: Dictionary = _game_project.duplicate(true) if not _game_project.is_empty() else {}
	if gp.is_empty():
		gp = {
			"title": session.project_name,
			"genre": _genre_id,
			"description": _description,
			"summary": summary,
		}
	var local_tex: Array = []
	for item in GameAssetLayoutScript.list_all(session.project_path):
		if typeof(item) == TYPE_DICTIONARY and str(item.get("kind", "")) == "image":
			local_tex.append(str(item.get("rel", "")))
	var snap: Dictionary = GameProjectBriefScript.snapshot(gp, {
		"title": session.project_name,
		"genre": _genre_id,
		"description": _description,
		"summary": summary,
		"local_textures": local_tex,
	})
	var f: FileAccess = FileAccess.open(session.project_path.path_join("studio_gameproject.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snap, "\t"))


func _refresh_art_slots(slots: PackedStringArray, force: bool = true) -> void:
	if session.project_path.is_empty():
		return
	ProceduralArtScript.set_styles(_graphic_styles)
	var hint: String = _description.left(80) if not _description.is_empty() else _genre_id
	for slot in slots:
		match str(slot):
			"wall":
				if bool(_art_kinds.get("textures", true)):
					ProceduralArtScript.write_named(session.project_path, "wall.png", "world", "brick", true)
					_queue_texture_download("wall.png", "%s brick wall seamless texture CC0" % hint, force, "world")
					StudioGameConfigScript.assign_slot(session.project_path, "wall", "res://assets/world/wall.png")
			"floor":
				if bool(_art_kinds.get("textures", true)):
					ProceduralArtScript.write_named(session.project_path, "floor.png", "world", "concrete", true)
					_queue_texture_download("floor.png", "%s floor seamless texture CC0" % hint, force, "world")
					StudioGameConfigScript.assign_slot(session.project_path, "floor", "res://assets/world/floor.png")
			"room":
				if bool(_art_kinds.get("textures", true)):
					ProceduralArtScript.write_named(session.project_path, "wall.png", "world", "brick", true)
					ProceduralArtScript.write_named(session.project_path, "floor.png", "world", "concrete", true)
					ProceduralArtScript.write_named(session.project_path, "ceiling.png", "world", "metal", true)
					ProceduralArtScript.write_named(session.project_path, "sky.png", "background", "sky", true)
					_queue_texture_download("wall.png", "%s room wall seamless texture CC0" % hint, force, "world")
					_queue_texture_download("floor.png", "%s room floor seamless texture CC0" % hint, force, "world")
					_queue_texture_download("sky.png", "%s sky backdrop CC0" % hint, force, "background")
					StudioGameConfigScript.assign_slot(session.project_path, "room", "res://assets/world/wall.png")
					StudioGameConfigScript.assign_slot(session.project_path, "wall", "res://assets/world/wall.png")
					StudioGameConfigScript.assign_slot(session.project_path, "floor", "res://assets/world/floor.png")
					StudioGameConfigScript.assign_slot(session.project_path, "sky", "res://assets/background/sky.png")
				if bool(_art_kinds.get("models", true)):
					ProceduralArtScript.write_room_model(session.project_path, true)
					StudioGameConfigScript.assign_slot(session.project_path, "room_model", "res://assets/models/room.obj")
			"character":
				if bool(_art_kinds.get("textures", true)):
					ProceduralArtScript.write_named(session.project_path, "character.png", "character", "skin", true)
					_queue_texture_download("character.png", "%s character skin texture CC0" % hint, force, "character")
					StudioGameConfigScript.assign_slot(session.project_path, "character_texture", "res://assets/character/character.png")
				if bool(_art_kinds.get("sprites", true)):
					ProceduralArtScript.write_named(session.project_path, "sprite_player.png", "character", "hero", true)
					_queue_texture_download("sprite_player.png", "%s hero character sprite CC0" % hint, force, "character")
					StudioGameConfigScript.assign_slot(session.project_path, "character", "res://assets/character/sprite_player.png")
				if bool(_art_kinds.get("models", true)):
					ProceduralArtScript.write_character_model(session.project_path, _genre_id, true)
					StudioGameConfigScript.assign_slot(session.project_path, "character_model", "res://assets/character/character.obj")
			"weapon":
				if bool(_art_kinds.get("textures", true)) or bool(_art_kinds.get("sprites", true)):
					ProceduralArtScript.write_named(session.project_path, "weapon.png", "weapon", "metal", true)
					_queue_texture_download("weapon.png", "%s weapon texture CC0" % hint, force, "weapon")
					StudioGameConfigScript.assign_slot(session.project_path, "weapon", "res://assets/weapon/weapon.png")
					StudioGameConfigScript.assign_slot(session.project_path, "weapon_texture", "res://assets/weapon/weapon.png")
				if bool(_art_kinds.get("models", true)):
					ProceduralArtScript.write_weapon_model(session.project_path, true)
					StudioGameConfigScript.assign_slot(session.project_path, "weapon_model", "res://assets/weapon/weapon.obj")
			_:
				pass


func _queue_texture_download(filename: String, query: String, force: bool = false, category: String = "") -> void:
	var fname: String = ResourceCatalogScript.sanitize_filename(filename if not filename.is_empty() else "wall.png")
	var q: String = query.strip_edges()
	var suffix: String = GraphicStyleScript.query_suffix(_graphic_styles)
	if not suffix.is_empty() and not q.to_lower().contains(suffix.strip_edges().left(12).to_lower()):
		q += suffix
	if q.is_empty():
		return
	var cat: String = category if not category.is_empty() else GameAssetLayoutScript.categorize(fname, q)
	var key: String = fname.to_lower()
	if _queued_names.has(key):
		return
	if _queued_names.size() >= MAX_TEXTURE_JOBS:
		return
	if not session.project_path.is_empty():
		var existing: String = GameAssetLayoutScript.find_existing(session.project_path, fname)
		if not force and not existing.is_empty():
			_queued_names[key] = true
			_downloaded_assets.append({
				"filename": fname,
				"query": q,
				"license": "on disk",
				"source": "existing",
				"category": cat,
				"path": existing,
			})
			return
	_queued_names[key] = true
	_pending_downloads.append({"filename": fname, "query": q, "category": cat})
	if not _download_active:
		_pump_downloads()


func _pump_downloads() -> void:
	if _pending_downloads.is_empty():
		_download_active = false
		_awaiting_tex = false
		_maybe_finish_resources()
		return
	_download_active = true
	var job: Dictionary = _pending_downloads.pop_front()
	_awaiting_tex = true
	_tex_filename = str(job.get("filename", "wall.png"))
	if _tex_filename.is_empty():
		_tex_filename = "wall.png"
	_tex_query = str(job.get("query", "CC0 texture"))
	_tex_category = str(job.get("category", GameAssetLayoutScript.categorize(_tex_filename, _tex_query)))
	status.emit("Downloading asset: %s …" % _tex_filename)
	images.search(_tex_query)


func _on_images_found(ok: bool, _results: Array, _error: String) -> void:
	if not _awaiting_tex:
		return
	if not ok or images.result_count() <= 0:
		_write_procedural_fallback(_tex_filename, _tex_category)
		_awaiting_tex = false
		_pump_downloads()
		return
	_tex_index = 0
	images.load_preview(0)


func _on_image_ready(ok: bool, index: int, texture: Texture2D, meta: Dictionary, _error: String) -> void:
	if _url_active and str(meta.get("source", "")) == "direct":
		_url_active = false
		if ok and not session.project_path.is_empty():
			var dest: String = GameAssetLayoutScript.dest_abs(session.project_path, _tex_filename, _tex_category)
			var cache: String = str(meta.get("cache_path", ""))
			if not cache.is_empty():
				GameAssetLayoutScript.copy_file(cache, dest)
				GameAssetLayoutScript.copy_file(cache, GameAssetLayoutScript.root_alias_abs(session.project_path, _tex_filename))
			elif texture is ImageTexture:
				var img: Image = (texture as ImageTexture).get_image()
				if img:
					img.save_png(dest)
					img.save_png(GameAssetLayoutScript.root_alias_abs(session.project_path, _tex_filename))
			var slot: String = _slot_for_filename(_tex_filename)
			if not slot.is_empty():
				StudioGameConfigScript.assign_slot(session.project_path, slot, GameAssetLayoutScript.dest_res(_tex_filename, _tex_category))
			_downloaded_assets.append({
				"filename": _tex_filename,
				"query": _tex_query,
				"license": str(meta.get("license", "provided")),
				"source": "gameproject_url",
				"category": _tex_category,
				"path": dest,
			})
			_notes.append("GameProject URL → assets/%s/%s" % [_tex_category, _tex_filename])
		_pump_url_jobs()
		return
	if not _awaiting_tex or index != _tex_index:
		return
	_awaiting_tex = false
	if not ok or texture == null:
		_write_procedural_fallback(_tex_filename, _tex_category)
		_pump_downloads()
		return
	if not session.project_path.is_empty():
		GameAssetLayoutScript.ensure_layout(session.project_path)
		var cat: String = _tex_category if not _tex_category.is_empty() else GameAssetLayoutScript.categorize(_tex_filename, _tex_query)
		var dest: String = GameAssetLayoutScript.dest_abs(session.project_path, _tex_filename, cat)
		var cache: String = str(meta.get("cache_path", ""))
		var saved: bool = false
		if str(meta.get("source", "")) == "procedural" or cache.is_empty():
			if texture is ImageTexture:
				var img: Image = (texture as ImageTexture).get_image()
				if img:
					img.save_png(dest)
					img.save_png(GameAssetLayoutScript.root_alias_abs(session.project_path, dest.get_file()))
					saved = true
		else:
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(cache)
			if not bytes.is_empty():
				saved = GameAssetLayoutScript.copy_bytes(dest, bytes)
				GameAssetLayoutScript.copy_bytes(GameAssetLayoutScript.root_alias_abs(session.project_path, _tex_filename), bytes)
		if saved:
			_downloaded_assets.append({
				"filename": _tex_filename,
				"query": _tex_query,
				"license": str(meta.get("license", "cc0")),
				"source": str(meta.get("source", "openverse")),
				"title": str(meta.get("title", "")),
				"page": str(meta.get("page", "")),
				"category": cat,
				"path": dest,
			})
			_notes.append("Asset → assets/%s/%s" % [cat, _tex_filename])
			status.emit("Asset saved: assets/%s/%s" % [cat, _tex_filename])
			var slot: String = _slot_for_filename(_tex_filename)
			if not slot.is_empty():
				StudioGameConfigScript.assign_slot(session.project_path, slot, GameAssetLayoutScript.dest_res(_tex_filename, cat))
		elif not saved:
			_write_procedural_fallback(_tex_filename, cat)
	_pump_downloads()


func _write_procedural_fallback(filename: String, category: String) -> void:
	if session.project_path.is_empty() or filename.is_empty():
		return
	if filename.get_extension().to_lower() in ["glb", "gltf", "obj"]:
		ProceduralArtScript.write_character_model(session.project_path, _genre_id)
		return
	var row: Dictionary = ProceduralArtScript.write_named(session.project_path, filename, category, filename.get_basename())
	if row.is_empty():
		return
	_downloaded_assets.append(row)
	var slot: String = _slot_for_filename(filename)
	if not slot.is_empty():
		StudioGameConfigScript.assign_slot(session.project_path, slot, str(row.get("res", GameAssetLayoutScript.dest_res(filename, category))))
	status.emit("Generated fallback art: %s" % filename)


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

%s

GODOT / TUTORIAL RESEARCH:
%s

ASSET / TEXTURE RESEARCH:
%s

Write the BUILD PLAN JSON now — instructions the coder must follow, plus required textures/sprites/addons.
Match download_queries and assets_required to the graphic style.
If C++ mode: list src/*.cpp classes to implement or update, plus GDScript fallback files.
""" % [
		_description,
		"MODIFY existing game" if _modify or session.active else "CREATE new game",
		"%s — %s" % [_genre_id, str(_genre.get("inspiration_notes", ""))],
		engine_req,
		GraphicStyleScript.prompt_block(_graphic_styles),
		_research.left(3500),
		_asset_research.left(2500),
	]
	_awaiting = "plan"
	if not _dispatch_ai(SYSTEM_PLAN if AppSettings.create_with_cpp else SYSTEM_PLAN_GDSCRIPT, user):
		_begin_resource_enrichment(true)


func _begin_ai_code() -> void:
	status.emit("ChatGPT writing Godot C++ / GDScript from plan + directions…" if AppSettings.create_with_cpp else "ChatGPT writing Godot scripts from plan + directions…")
	var files_blob: String = ""
	if session.active:
		var live: Array = ProjectWriterScript.read_project_files(session.project_path)
		for f2 in live:
			var rel: String = str(f2.get("path", ""))
			if rel.begins_with("refs/") or rel.begins_with("addons/") or rel.begins_with(".studio_cache/"):
				continue
			files_blob += "\n----- %s -----\n%s\n" % [rel, str(f2.get("content", ""))]
	else:
		for f in _base.get("files", []):
			if typeof(f) != TYPE_DICTIONARY:
				continue
			files_blob += "\n----- %s -----\n%s\n" % [str(f.get("path", "")), str(f.get("content", ""))]

	var plan_text: String = _plan_raw if not _plan_raw.is_empty() else JSON.stringify(_plan)
	var engine_line: String = "Godot 4 + C++ GDExtension (update src/ C++ AND scripts/ GDScript fallback)" if AppSettings.create_with_cpp else "Godot 4 GDScript"
	var user: String = """PLAYER DIRECTIONS (highest priority — implement these):
%s

BUILD PLAN FROM CHATGPT (follow these instructions):
%s

GENRE: %s
MODE: %s
PROJECT NAME: %s
ENGINE: %s

%s

GODOT RESEARCH:
%s

ASSET RESEARCH:
%s

ASSETS ON DISK (use these paths):
%s

OPEN GODOT SAMPLE REFS (patterns only, MIT/CC0):
%s

PLUGIN / ADDON NOTES:
%s

CURRENT FILES:
%s

Write/update the Godot 4 project JSON now.
If ENGINE includes C++, update src/*.h / src/*.cpp gameplay to match new directions (merge, do not drop GDExtension glue).
Keep scripts/*.gd + scenes/main.tscn playable without a compiled .dll/.so.
Wire StandardMaterial3D / Sprite2D to assets/*.png listed above when present.
Honor graphic style for materials, sprites, and meshes.
Include download_queries for any extra CC0 textures still needed.
""" % [
		_description,
		plan_text.left(6000),
		_genre_id,
		"MODIFY — merge into current files" if _modify or session.active else "CREATE from template + plan",
		session.project_name if session.active else str(_base.get("project_name", "ai_game")),
		engine_line,
		GraphicStyleScript.prompt_block(_graphic_styles),
		_research.left(2500),
		_asset_research.left(1800),
		_asset_inventory_text(),
		_ref_summary.left(4500) if not _ref_summary.is_empty() else "(none fetched)",
		_plugin_prompt_text(),
		files_blob.left(22000),
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
		status.emit("Plan AI failed (%s) — fetching assets then coding from directions…" % error)
		_plan_raw = ""
		_plan = {}
		_begin_resource_enrichment(true)
		return
	_plan_raw = text
	_plan = GameGeneratorScript.parse_plan_json(text)
	_write_plan_docs()
	_queue_plan_assets()
	status.emit("Build plan ready — downloading matching assets, plugins, and open samples…")
	_begin_resource_enrichment(true)


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
		var fname: String = str(a.get("name", "")).get_file()
		var query: String = str(a.get("query", ""))
		if fname.is_empty() or query.is_empty():
			continue
		var ext: String = fname.get_extension().to_lower()
		if not IMAGE_EXTS.has(ext):
			fname = fname.get_basename() + ".png"
		_queue_texture_download(fname, query + " CC0", true, GameAssetLayoutScript.categorize(fname, query, str(a.get("usage", ""))))
	var extra = _plan.get("download_queries", [])
	if typeof(extra) == TYPE_ARRAY:
		for q in extra:
			if typeof(q) != TYPE_DICTIONARY:
				continue
			var fname2: String = str(q.get("filename", q.get("name", ""))).get_file()
			var query2: String = str(q.get("query", ""))
			if query2.is_empty():
				continue
			_queue_texture_download(fname2, query2 + " CC0", true, GameAssetLayoutScript.categorize(fname2, query2))


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
	if written.get("ok", false) and not session.project_path.is_empty():
		GameAssetLayoutScript.ensure_layout(session.project_path)
		StudioGameConfigScript.ensure_on_disk(session.project_path)
		StudioGameConfigScript.set_graphic_styles(session.project_path, _graphic_styles)
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
		_write_resource_docs()
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
			var fname: String = str(q.get("filename", q.get("name", "wall.png"))).get_file()
			var query: String = str(q.get("query", ""))
			if query.is_empty():
				continue
			if fname.is_empty():
				fname = "wall.png"
			var ext: String = fname.get_extension().to_lower()
			if not IMAGE_EXTS.has(ext):
				fname = fname.get_basename() + ".png"
			_queue_texture_download(fname, query + " CC0", false, GameAssetLayoutScript.categorize(fname, query))
		elif typeof(q) == TYPE_STRING and not str(q).is_empty():
			_queue_texture_download("extra_tex.png", str(q) + " CC0", false)


func _begin_resource_enrichment(then_ai: bool) -> void:
	_want_ai_after_resources = then_ai
	_waiting_resources = true
	if session.project_path.is_empty():
		_finish_resources_and_continue()
		return
	_write_resource_docs()
	var extra_terms: PackedStringArray = PackedStringArray(["physics"])
	var plugins = _plan.get("plugins_or_addons", [])
	if typeof(plugins) == TYPE_ARRAY:
		for p in plugins:
			var term: String = str(p).strip_edges()
			if not term.is_empty():
				extra_terms.append(term)
				if extra_terms.size() >= 3:
					break
	_addon_busy = true
	_ref_busy = true
	if assetlib.search_and_maybe_install(session.project_path, _genre_id, extra_terms) != OK:
		_addon_busy = false
	if openrefs.fetch_for_genre(session.project_path, _genre_id) != OK:
		_ref_busy = false
	if _resource_timer:
		_resource_timer.start(RESOURCE_WAIT_SEC)
	_maybe_finish_resources()


func _on_addon_finished(_ok: bool, result: Dictionary) -> void:
	_addon_busy = false
	if session.project_path.is_empty():
		return
	_addon_listed = result.get("listed", []) if typeof(result.get("listed", [])) == TYPE_ARRAY else []
	var installed = result.get("installed", {})
	_addon_installed = installed if typeof(installed) == TYPE_DICTIONARY else {}
	if not _addon_installed.is_empty():
		_notes.append("Addon → addons/ (%s)" % str(_addon_installed.get("title", "plugin")))
		var title_l: String = str(_addon_installed.get("title", "")).to_lower()
		if title_l.contains("physics") or title_l.contains("jolt") or title_l.contains("rigid"):
			var phys: Dictionary = StudioGameConfigScript.load_physics(session.project_path)
			phys["addon"] = str(_addon_installed.get("title", ""))
			StudioGameConfigScript.save_physics(session.project_path, phys)
	_write_resource_docs()
	_maybe_finish_resources()


func _on_ref_finished(_ok: bool, result: Dictionary) -> void:
	_ref_busy = false
	if session.project_path.is_empty():
		return
	_ref_result = result if typeof(result) == TYPE_DICTIONARY else {}
	_ref_summary = str(_ref_result.get("summary", ""))
	if not str(_ref_result.get("title", "")).is_empty():
		_notes.append("Ref → refs/%s/" % str(_ref_result.get("id", "sample")))
	_write_resource_docs()
	_maybe_finish_resources()


func _on_resource_timeout() -> void:
	if not _waiting_resources:
		return
	status.emit("Resource wait timed out — continuing with what landed (downloads may finish in background).")
	_finish_resources_and_continue()


func _resources_idle() -> bool:
	var tex_idle: bool = (not _download_active) and (not _awaiting_tex) and _pending_downloads.is_empty()
	var url_idle: bool = (not _url_active) and _pending_url_jobs.is_empty()
	return tex_idle and url_idle and (not _addon_busy) and (not _ref_busy)


func _maybe_finish_resources() -> void:
	if not _waiting_resources:
		return
	if _resources_idle():
		_finish_resources_and_continue()


func _finish_resources_and_continue() -> void:
	if not _waiting_resources:
		return
	_waiting_resources = false
	if _resource_timer:
		_resource_timer.stop()
	_write_resource_docs()
	if _want_ai_after_resources and AppSettings.has_any_ai_key():
		_want_ai_after_resources = false
		status.emit("Assets ready — ChatGPT coding the Godot game…")
		_begin_ai_code()
	else:
		_want_ai_after_resources = false
		status.emit("Open assets / plugin notes updated. Run Game anytime.")


func _slot_for_filename(filename: String) -> String:
	var n: String = filename.get_file().to_lower()
	if n.begins_with("wall"):
		return "wall"
	if n.begins_with("floor") or n.begins_with("ground"):
		return "floor"
	if n.begins_with("sky") or n.contains("background"):
		return "sky"
	if n.contains("player") or n.contains("character") or n.contains("hero"):
		if n.get_extension() in ["glb", "gltf", "obj"]:
			return "character_model"
		return "character"
	if n.contains("enemy") or n.contains("monster"):
		return "enemy"
	if n.contains("weapon") or n.contains("gun"):
		return "weapon"
	if n.contains("menu"):
		return "menu_background"
	return ""


func _asset_inventory_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not session.project_path.is_empty():
		var listed: Array = GameAssetLayoutScript.list_all(session.project_path)
		for item in listed:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			lines.append("- %s [%s]" % [str(item.get("res", "")), str(item.get("category", ""))])
	if lines.is_empty():
		for a in _downloaded_assets:
			if typeof(a) == TYPE_DICTIONARY:
				lines.append("- res://assets/%s/%s (%s)" % [
					str(a.get("category", "textures")),
					str(a.get("filename", "")),
					str(a.get("query", "")),
				])
	if lines.is_empty():
		lines.append("(none on disk yet — still use assets/world/wall.png, assets/character/, etc. when they appear)")
	return "\n".join(lines)


func _plugin_prompt_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not _addon_installed.is_empty():
		lines.append("Installed addon: %s (%s) — files under addons/" % [
			str(_addon_installed.get("title", "")),
			str(_addon_installed.get("license", "")),
		])
	if _addon_listed.is_empty():
		lines.append("See docs/PLUGINS.md for AssetLib / Kenney links. Do not fetch commercial packs.")
	else:
		lines.append("AssetLib candidates (recorded, not all installed):")
		var count: int = mini(5, _addon_listed.size())
		for i in range(count):
			var row: Dictionary = _addon_listed[i]
			lines.append("- %s [%s] %s" % [str(row.get("title", "")), str(row.get("cost", "")), str(row.get("page", ""))])
	return "\n".join(lines)


func _resources_stub_markdown() -> String:
	return """# Resources / engine
- **Game engine:** Godot 4 (your installed executable)
- **Gameplay code:** %s
- Studio genre template: %s
- ChatGPT / Claude / Gemini write C++ + GDScript when API keys are set
- Create downloads several CC0 textures/sprites into `assets/` (Openverse / Wikimedia / procedural fallback)
- Open Godot samples may land in `refs/` for the coder to study
- Kenney / AssetLib links are listed in `docs/PLUGINS.md` (CC0 / MIT only — never commercial ROMs or ripped assets)
- Directions are applied as AI instructions on Create / Modify
""" % [
		"C++ GDExtension in src/ (intended) + GDScript fallback in scripts/" if AppSettings.create_with_cpp else "GDScript in scripts/",
		_genre_id,
	]


func _plugins_stub_markdown() -> String:
	return """# Plugins / kits

Studio will search the Godot Asset Library and record MIT/CC0 options here.
Small addon zips may be unpacked into `addons/` only when the archive contains `plugin.cfg` or an `addons/` folder.
Kenney CC0 kits are linked (download from kenney.nl — not auto-mirrored unless a stable open URL is used).

Never install commercial ROMs, WADs, or ripped game assets.
"""


func _write_resource_docs() -> void:
	if session.project_path.is_empty():
		return
	var res_lines: PackedStringArray = PackedStringArray([
		"# Resources",
		"",
		"- **Engine:** Godot 4",
		"- **Genre template:** %s" % _genre_id,
		"- **Gameplay code:** %s" % ("C++ GDExtension + GDScript fallback" if AppSettings.create_with_cpp else "GDScript"),
		"- **Legal:** CC0 / MIT / Apache / BSD / original only — never commercial ROMs, WADs, or ripped assets.",
		"",
		"## Textures & sprites (`assets/<category>/`)",
	])
	if _downloaded_assets.is_empty():
		res_lines.append("- (still downloading, or procedural fallback will be used)")
	for a in _downloaded_assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		res_lines.append("- **assets/%s/%s** — query `%s` — license `%s` — source `%s`%s" % [
			str(a.get("category", "textures")),
			str(a.get("filename", "")),
			str(a.get("query", "")),
			str(a.get("license", "")),
			str(a.get("source", "")),
			(" — %s" % str(a.get("title", ""))) if not str(a.get("title", "")).is_empty() else "",
		])
	if not session.project_path.is_empty():
		res_lines.append("")
		res_lines.append("### Files currently on disk")
		var listed: Array = GameAssetLayoutScript.list_all(session.project_path)
		if listed.is_empty():
			res_lines.append("- (none yet)")
		else:
			for item in listed:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				res_lines.append("- `%s`" % str(item.get("rel", "")))
	res_lines.append("")
	res_lines.append("## Open Godot sample (`refs/`)")
	if _ref_result.is_empty() or str(_ref_result.get("title", "")).is_empty():
		res_lines.append("- None fetched yet (or fetch still running / timed out).")
	else:
		res_lines.append("- **%s** (%s)" % [str(_ref_result.get("title", "")), str(_ref_result.get("license", ""))])
		res_lines.append("- Source: %s" % str(_ref_result.get("page", "")))
		for fpath in _ref_result.get("files", []):
			res_lines.append("- `%s`" % str(fpath))
	res_lines.append("")
	res_lines.append("## Kenney / CC0 kits (manual download)")
	for k in ResourceCatalogScript.kenney_links(_genre_id):
		if typeof(k) != TYPE_DICTIONARY:
			continue
		res_lines.append("- [%s](%s) — %s — %s" % [
			str(k.get("title", "")), str(k.get("url", "")), str(k.get("license", "CC0")), str(k.get("note", "")),
		])

	var plug_lines: PackedStringArray = PackedStringArray([
		"# Plugins / Asset Library",
		"",
		"Auto-install only happens for small MIT/CC0/Apache/BSD addon zips that look like Godot addons (`plugin.cfg` or `addons/`).",
		"Installers (`.exe` / `.msi`) are never run. GPL hits are listed but not auto-installed.",
		"",
	])
	if not _addon_installed.is_empty():
		plug_lines.append("## Installed")
		plug_lines.append("- **%s** (%s) — %s" % [
			str(_addon_installed.get("title", "")),
			str(_addon_installed.get("license", "")),
			str(_addon_installed.get("url", "")),
		])
		plug_lines.append("- Unpacked into `addons/` (%s files)." % str(_addon_installed.get("count", 0)))
		plug_lines.append("")
	plug_lines.append("## Asset Library search results")
	if _addon_listed.is_empty():
		plug_lines.append("- None yet (search skipped, timed out, or no hits).")
	else:
		for row in _addon_listed:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			plug_lines.append("- [%s](%s) — license `%s` — %s — Godot %s" % [
				str(row.get("title", "")),
				str(row.get("page", "")),
				str(row.get("cost", "")),
				str(row.get("author", "")),
				str(row.get("godot_version", "")),
			])
	plug_lines.append("")
	plug_lines.append("## Kenney CC0 (not auto-vendored unless a stable open zip URL is used)")
	for k2 in ResourceCatalogScript.kenney_links(_genre_id):
		if typeof(k2) != TYPE_DICTIONARY:
			continue
		plug_lines.append("- [%s](%s) (%s)" % [str(k2.get("title", "")), str(k2.get("url", "")), str(k2.get("license", "CC0"))])
	plug_lines.append("")
	plug_lines.append("Browse more: https://godotengine.org/asset-library/asset")

	ProjectWriterScript.write_project({
		"ok": true,
		"project_name": session.project_name,
		"files": [
			{"path": "docs/RESOURCES.md", "content": "\n".join(res_lines) + "\n"},
			{"path": "docs/PLUGINS.md", "content": "\n".join(plug_lines) + "\n"},
		],
	}, session.project_path)
