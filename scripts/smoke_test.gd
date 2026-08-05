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

	for id in ["fps", "voxel"]:
		var built: Dictionary = Templates.build(id)
		var written: Dictionary = Writer.write_project(built)
		print("WRITE_", id, "=", written.get("ok", false), " ", written.get("path", ""))

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

	quit(0)
