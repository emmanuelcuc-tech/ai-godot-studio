extends RefCounted
## Animation table loader. Prefer studio_anim.json; this file is rewritten by the studio Animation tab.

static func data() -> Dictionary:
	if not FileAccess.file_exists("res://studio_anim.json"):
		return {"mode_enabled": false, "animations": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://studio_anim.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"mode_enabled": false, "animations": []}
	return parsed


static func animations() -> Array:
	var d: Dictionary = data()
	var anims: Variant = d.get("animations", [])
	return anims if typeof(anims) == TYPE_ARRAY else []


static func find_anim(anim_name: String) -> Dictionary:
	for a in animations():
		if typeof(a) == TYPE_DICTIONARY and str(a.get("name", "")) == anim_name:
			return a
	return {}
