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

	quit(0)
