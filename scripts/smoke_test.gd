extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Insp = load("res://scripts/game_inspirations.gd")
	var Catalog = load("res://scripts/genre_catalog.gd")
	var Templates = load("res://scripts/templates/genre_templates.gd")
	var Writer = load("res://scripts/project_writer.gd")

	for phrase in ["make doom", "I want minecraft", "doom-like corridor", "block game like minecraft"]:
		var insp: Dictionary = Insp.detect(phrase)
		var g: Dictionary = Catalog.detect(phrase, "custom")
		print("PHRASE=", phrase, " INSP=", insp.get("display", "none"), " GENRE=", g.get("id", ""), "/", g.get("name", ""))

	var Cpp = load("res://scripts/templates/cpp_gdextension.gd")
	var Builder = load("res://scripts/cpp_builder.gd")

	var Layout = load("res://scripts/editors/game_asset_layout.gd")
	var Cfg = load("res://scripts/editors/studio_game_config.gd")
	for id in ["fps", "voxel"]:
		var built: Dictionary = Templates.build(id)
		var written: Dictionary = Writer.write_project(built)
		print("WRITE_", id, "=", written.get("ok", false), " ", written.get("path", ""))
		var proj_path: String = str(written.get("path", ""))
		if not proj_path.is_empty():
			Layout.ensure_layout(proj_path)
			Cfg.ensure_on_disk(proj_path)
			if id == "fps":
				print("LAYOUT_CHAR=", DirAccess.dir_exists_absolute(proj_path.path_join("assets/character")))
				print("LAYOUT_ENEMY=", DirAccess.dir_exists_absolute(proj_path.path_join("assets/enemy")))
				print("LAYOUT_WEAPON=", DirAccess.dir_exists_absolute(proj_path.path_join("assets/weapon")))
				print("HAS_RUNTIME=", FileAccess.file_exists(proj_path.path_join("scripts/studio_runtime.gd")))
				print("HAS_DISPLAY=", FileAccess.file_exists(proj_path.path_join("studio_display.json")))
				print("HAS_EFFECTS=", FileAccess.file_exists(proj_path.path_join("studio_effects.json")))
				print("CAT_WALL=", Layout.categorize("wall.png", "brick wall", "corridor"))
				print("CAT_PLAYER=", Layout.categorize("sprite_player.png", "hero", "player"))
				var Art = load("res://scripts/ai/procedural_art.gd")
				Art.write_starter_art(proj_path, "fps", {"textures": true, "sprites": true, "models": true})
				print("HAS_WALL_PNG=", FileAccess.file_exists(proj_path.path_join("assets/world/wall.png")))
				print("HAS_FLOOR_PNG=", FileAccess.file_exists(proj_path.path_join("assets/floor.png")) or FileAccess.file_exists(proj_path.path_join("assets/world/floor.png")))
				print("HAS_PLAYER_SPR=", FileAccess.file_exists(proj_path.path_join("assets/character/sprite_player.png")))
				print("HAS_ENEMY_SPR=", FileAccess.file_exists(proj_path.path_join("assets/enemy/sprite_enemy.png")))
				print("HAS_CHAR_OBJ=", FileAccess.file_exists(proj_path.path_join("assets/character/character.obj")))
				var world_gd: String = FileAccess.get_file_as_string(proj_path.path_join("scripts/world.gd"))
				print("WORLD_REFS_WALL=", world_gd.contains("wall.png"))
				Cfg.set_art_kinds(proj_path, {"textures": true, "sprites": true, "models": true})
				print("HAS_ASSETS_JSON=", FileAccess.file_exists(proj_path.path_join("studio_assets.json")))
				print("HAS_PHYSICS_MD=", FileAccess.file_exists(proj_path.path_join("docs/PHYSICS.md")))
				print("HAS_SKYBOX=", FileAccess.file_exists(proj_path.path_join("assets/background/skybox.png")) or FileAccess.file_exists(proj_path.path_join("assets/world/sky.png")))
				print("HAS_WALL_MAT=", FileAccess.file_exists(proj_path.path_join("assets/materials/wall.tres")))
				print("HAS_ENEMY_OBJ=", FileAccess.file_exists(proj_path.path_join("assets/enemy/enemy_capsule.obj")) or FileAccess.file_exists(proj_path.path_join("assets/enemy/enemy.obj")))
				print("SLOT_SKYBOX=", Layout.slot_filename("skybox"))
				print("SLOT_CHAR_MAT=", Layout.slot_filename("character_material"))
				Cfg.add_to_slot(proj_path, "wall", "res://assets/world/wall.png")
				print("VARIANT_WALL=", Cfg.list_variants(proj_path, "wall").size() >= 0)
				var assets_json: Dictionary = Cfg.load_assets(proj_path)
				print("HAS_SKYBOX_SLOT=", str(assets_json.get("assignments", {})).contains("skybox") if typeof(assets_json.get("assignments", {})) == TYPE_DICTIONARY else false)
				print("PHYS_ENGINE=", str(Cfg.load_physics(proj_path).get("engine", "")))
				var PanelScr = load("res://scripts/editors/add_to_game_panel.gd")
				print("HAS_ADD_PANEL=", PanelScr != null)
				var pg: String = FileAccess.get_file_as_string(proj_path.path_join("project.godot"))
				print("PG_JOLT=", pg.contains("Jolt") or pg.contains("physics_engine"))
				var GS = load("res://scripts/graphic_style.gd")
				print("STYLE_FPS=", ",".join(GS.defaults_for_genre("fps")))
				print("STYLE_PLAT=", ",".join(GS.defaults_for_genre("platformer")))
				print("STYLE_Q=", GS.query_suffix(PackedStringArray(["3d", "cartoon"])))
				Cfg.set_graphic_styles(proj_path, PackedStringArray(["2d", "pixel"]))
				print("HAS_STYLE_JSON=", FileAccess.file_exists(proj_path.path_join("studio_style.json")))
				var st: Dictionary = Cfg.load_style(proj_path)
				print("STYLE_SAVED=", str(st.get("graphic_styles", [])))
				var disp: Dictionary = Cfg.load_display(proj_path)
				print("DISPLAY_STYLES=", str(disp.get("graphic_styles", [])))

	var fps: Dictionary = Templates.build("fps")
	var cpp_files: Array = Cpp.overlay(fps.get("files", []), "fps", "corridor shooter with brick walls")
	var paths: PackedStringArray = PackedStringArray()
	for f in cpp_files:
		if typeof(f) == TYPE_DICTIONARY:
			paths.append(str(f.get("path", "")))
	for need in Cpp.expected_paths():
		print("CPP_HAS_", need, "=", paths.has(need))
	var cpp_project: Dictionary = {
		"ok": true,
		"project_name": "cpp_smoke_fps",
		"summary": "C++ scaffold smoke",
		"howto": ["Run Game"],
		"files": cpp_files,
	}
	var cpp_written: Dictionary = Writer.write_project(cpp_project)
	print("WRITE_CPP=", cpp_written.get("ok", false), " ", cpp_written.get("path", ""))
	var info: Dictionary = Builder.detect()
	print("CPP_TOOL_PYTHON=", info.get("python", ""))
	print("CPP_TOOL_READY=", info.get("ready", false))

	var Art = load("res://scripts/ai/procedural_art.gd")
	var fps_art_path: String = ""
	for id2 in ["fps"]:
		var built2: Dictionary = Templates.build(id2)
		var written2: Dictionary = Writer.write_project(built2)
		fps_art_path = str(written2.get("path", ""))
		if not fps_art_path.is_empty():
			var kinds: Dictionary = {"textures": true, "sprites": true, "models": true}
			Art.write_starter_art(fps_art_path, "fps", kinds)
			print("ART_WALL=", FileAccess.file_exists(fps_art_path.path_join("assets/wall.png")))
			print("ART_FLOOR=", FileAccess.file_exists(fps_art_path.path_join("assets/floor.png")))
			print("ART_CHAR_PNG=", FileAccess.file_exists(fps_art_path.path_join("assets/character/sprite_player.png")))
			print("ART_CHAR_TEX=", FileAccess.file_exists(fps_art_path.path_join("assets/character/character.png")))
			print("ART_CHAR_OBJ=", FileAccess.file_exists(fps_art_path.path_join("assets/character/character.obj")))
			print("ART_ENEMY=", FileAccess.file_exists(fps_art_path.path_join("assets/enemy/sprite_enemy.png")))
			var world_gd: String = FileAccess.get_file_as_string(fps_art_path.path_join("scripts/world.gd"))
			print("WORLD_LOADS_WALL=", world_gd.contains("wall.png"))
			var player_gd: String = FileAccess.get_file_as_string(fps_art_path.path_join("scripts/player.gd"))
			print("PLAYER_HAS_BODY=", player_gd.contains("StudioBody") or player_gd.contains("sprite_player"))

	var ResCat = load("res://scripts/ai/resource_catalog.gd")
	var ZipUtil = load("res://scripts/ai/zip_addon_util.gd")
	var jobs: Array = ResCat.texture_jobs("fps", "doom-like brick corridors")
	print("TEX_JOBS=", jobs.size())
	if jobs.size() > 0 and typeof(jobs[0]) == TYPE_DICTIONARY:
		print("TEX0=", str(jobs[0].get("filename", "")))
	var refs: Array = ResCat.open_refs("fps")
	var ref0: String = "none"
	if refs.size() > 0 and typeof(refs[0]) == TYPE_DICTIONARY:
		ref0 = str(refs[0].get("id", ""))
	print("REF0=", ref0)
	print("RIP_WAD=", ResCat.looks_like_rip("cool doom wad dump"))
	print("LIC_MIT=", ResCat.license_ok_for_install("MIT"))
	print("LIC_GPL=", ResCat.license_ok_for_install("GPLv3"))

	var zip_path: String = ProjectSettings.globalize_path("user://smoke_addon.zip")
	var zp: ZIPPacker = ZIPPacker.new()
	var zerr: Error = zp.open(zip_path)
	print("ZIP_PACK_OPEN=", zerr)
	if zerr == OK:
		zp.start_file("addons/smoke_plug/plugin.cfg")
		zp.write_file("[plugin]\nname=\"Smoke\"\nscript=\"smoke.gd\"\n".to_utf8_buffer())
		zp.close_file()
		zp.start_file("addons/smoke_plug/smoke.gd")
		zp.write_file("extends EditorPlugin\n".to_utf8_buffer())
		zp.close_file()
		zp.close()
	var insp: Dictionary = ZipUtil.inspect(zip_path)
	print("ZIP_IS_ADDON=", insp.get("is_addon", false))
	var out_root: String = ProjectSettings.globalize_path("user://smoke_unzip")
	DirAccess.make_dir_recursive_absolute(out_root)
	var extracted: Dictionary = ZipUtil.extract_addon(zip_path, out_root)
	print("ZIP_EXTRACT_OK=", extracted.get("ok", false))
	print("ZIP_HAS_CFG=", FileAccess.file_exists(out_root.path_join("addons/smoke_plug/plugin.cfg")))

	var junk_zip: String = ProjectSettings.globalize_path("user://smoke_junk.zip")
	var zp2: ZIPPacker = ZIPPacker.new()
	if zp2.open(junk_zip) == OK:
		zp2.start_file("readme.txt")
		zp2.write_file("not an addon\n".to_utf8_buffer())
		zp2.close_file()
		zp2.close()
	var junk_info: Dictionary = ZipUtil.inspect(junk_zip)
	print("JUNK_IS_ADDON=", junk_info.get("is_addon", true))

	var GP = load("res://scripts/game_project_brief.gd")
	var gp_ok: Dictionary = GP.try_parse_text("""{"title":"Brick FPS","genre":"shooter","description":"Dark corridors","art_style":"low poly","texture_urls":["https://example.com/wall.png"]}""")
	print("GP_KIND=", gp_ok.get("kind", ""))
	print("GP_TITLE=", gp_ok.get("title", ""))
	var gp_user: Dictionary = GP.try_parse_file("C:/Users/kortn/Desktop/User.jsonc.txt")
	print("GP_USER_KIND=", gp_user.get("kind", ""), " REASON=", gp_user.get("reason", ""))
	var gp_site: Dictionary = GP.try_parse_file("C:/Users/kortn/Desktop/config.jsonc.txt")
	print("GP_SITE_KIND=", gp_site.get("kind", ""))
	var struct_files: Array = GP.parse_structure_files([{"path": "docs/HELLO.md", "content": "hi"}, {"path": "../evil.gd", "content": "no"}])
	print("GP_STRUCT_COUNT=", struct_files.size())
	print("GP_STRUCT0=", str(struct_files[0].get("path", "")) if struct_files.size() > 0 else "")

	quit(0)
