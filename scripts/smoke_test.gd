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

	for id in ["fps", "voxel"]:
		var built: Dictionary = Templates.build(id)
		var written: Dictionary = Writer.write_project(built)
		print("WRITE_", id, "=", written.get("ok", false), " ", written.get("path", ""))

	quit(0)
