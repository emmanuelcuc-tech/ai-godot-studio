class_name OfflineTemplates
extends RefCounted
## Dispatches to genre templates + tutor fallback.

const GenreCatalogScript = preload("res://scripts/genre_catalog.gd")
const GenreTemplatesScript = preload("res://scripts/templates/genre_templates.gd")


static func guess_kind(request: String) -> String:
	var g: Dictionary = GenreCatalogScript.detect(request, "custom")
	return str(g.get("id", "arena"))


static func build(kind: String) -> Dictionary:
	return GenreTemplatesScript.build(kind)


static func build_for_request(request: String, selected_genre_id: String = "custom") -> Dictionary:
	var g: Dictionary = GenreCatalogScript.detect(request, selected_genre_id)
	var id := str(g.get("id", "arena"))
	var built: Dictionary = GenreTemplatesScript.build(id)
	# Stamp request into summary
	built["summary"] = "%s | Request: %s" % [built.get("summary", ""), request.left(200)]
	built["genre_id"] = id
	built["genre_name"] = g.get("name", id)
	return built


static func tutor_fallback(question: String) -> String:
	return """Learn mode tip for: %s

Drop .gd / .tscn / .md template files into Learn so Create can modify them.
Genre Create uses open Godot templates (Kenney FPS/Racing, Quiver beat-em-up, Godot docs).
HakkoAI (https://www.hakko.ai/) is a gameplay companion — use it for genre feel; this studio builds Godot projects.
Commercial sources like Doom engine code are never copied — mechanics are recreated in GDScript.
""" % question
