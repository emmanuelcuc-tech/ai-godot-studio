extends Node
## Learns, adapts, and saves studio knowledge: templates, plugins, assets, preferences.

signal memory_changed

const PATH := "user://studio_memory.json"
const MAX_HISTORY := 80
const MAX_ASSETS := 60
const MAX_TEMPLATES := 40

## Preferred template id per genre_id
var preferred_templates: Dictionary = {}
## Learned / bookmarked templates: [{id,name,genre_id,source,url,notes,uses}]
var templates: Array = []
## Plugin recommendations remembered: [{name,url,genre_id,notes,uses}]
var plugins: Array = []
## Asset search hits the user liked: [{query,title,path,kind,uses}]
var assets: Array = []
## Free-form lessons from Apply / Learn
var lessons: PackedStringArray = []
## Recent user directions (adapt wording / genre detection)
var directions: PackedStringArray = []


func _ready() -> void:
	load_memory()


func load_memory() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	preferred_templates = data.get("preferred_templates", {})
	if typeof(preferred_templates) != TYPE_DICTIONARY:
		preferred_templates = {}
	templates = data.get("templates", [])
	plugins = data.get("plugins", [])
	assets = data.get("assets", [])
	if typeof(templates) != TYPE_ARRAY:
		templates = []
	if typeof(plugins) != TYPE_ARRAY:
		plugins = []
	if typeof(assets) != TYPE_ARRAY:
		assets = []
	lessons = PackedStringArray(data.get("lessons", []))
	directions = PackedStringArray(data.get("directions", []))


func save_memory() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"preferred_templates": preferred_templates,
		"templates": templates,
		"plugins": plugins,
		"assets": assets,
		"lessons": Array(lessons),
		"directions": Array(directions),
		"updated_at": Time.get_datetime_string_from_system(),
	}, "\t"))
	memory_changed.emit()


func remember_direction(text: String, genre_id: String) -> void:
	var line := "%s | %s | %s" % [Time.get_datetime_string_from_system(), genre_id, text.left(240)]
	directions.append(line)
	while directions.size() > MAX_HISTORY:
		directions.remove_at(0)
	save_memory()


func remember_lesson(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	lessons.append(text.left(500))
	while lessons.size() > MAX_HISTORY:
		lessons.remove_at(0)
	save_memory()


func remember_template_use(tmpl: Dictionary) -> void:
	var id := str(tmpl.get("id", ""))
	if id.is_empty():
		return
	var genre := str(tmpl.get("genre_id", ""))
	preferred_templates[genre] = id
	var found := false
	for i in templates.size():
		var t: Dictionary = templates[i]
		if str(t.get("id", "")) == id:
			t["uses"] = int(t.get("uses", 0)) + 1
			t["last_used"] = Time.get_datetime_string_from_system()
			t["notes"] = str(tmpl.get("notes", t.get("notes", "")))
			templates[i] = t
			found = true
			break
	if not found:
		var entry := tmpl.duplicate(true)
		entry["uses"] = 1
		entry["last_used"] = Time.get_datetime_string_from_system()
		templates.append(entry)
	while templates.size() > MAX_TEMPLATES:
		templates.remove_at(0)
	save_memory()


func remember_plugin(plugin: Dictionary) -> void:
	var name := str(plugin.get("name", ""))
	if name.is_empty():
		return
	for i in plugins.size():
		var p: Dictionary = plugins[i]
		if str(p.get("name", "")) == name:
			p["uses"] = int(p.get("uses", 0)) + 1
			plugins[i] = p
			save_memory()
			return
	var entry := plugin.duplicate(true)
	entry["uses"] = 1
	plugins.append(entry)
	while plugins.size() > MAX_TEMPLATES:
		plugins.remove_at(0)
	save_memory()


func remember_asset(asset: Dictionary) -> void:
	var key := str(asset.get("path", asset.get("title", "")))
	if key.is_empty():
		return
	for i in assets.size():
		var a: Dictionary = assets[i]
		if str(a.get("path", a.get("title", ""))) == key:
			a["uses"] = int(a.get("uses", 0)) + 1
			assets[i] = a
			save_memory()
			return
	var entry := asset.duplicate(true)
	entry["uses"] = 1
	assets.append(entry)
	while assets.size() > MAX_ASSETS:
		assets.remove_at(0)
	save_memory()


func preferred_template_id(genre_id: String) -> String:
	return str(preferred_templates.get(genre_id, ""))


func learned_templates_for(genre_id: String) -> Array:
	var out: Array = []
	for t in templates:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if genre_id.is_empty() or str(t.get("genre_id", "")) == genre_id or str(t.get("genre_id", "")) == "any":
			out.append(t)
	return out


func learned_plugins_for(genre_id: String) -> Array:
	var out: Array = []
	for p in plugins:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var g := str(p.get("genre_id", "any"))
		if genre_id.is_empty() or g == genre_id or g == "any":
			out.append(p)
	return out


func context_for_ai(genre_id: String = "") -> String:
	var parts: PackedStringArray = []
	parts.append("## Studio memory (saved learnings — prefer these)")
	var pref := preferred_template_id(genre_id)
	if not pref.is_empty():
		parts.append("Preferred template for %s: %s" % [genre_id, pref])
	var tmpls := learned_templates_for(genre_id)
	if not tmpls.is_empty():
		parts.append("Known templates:")
		for t in tmpls.slice(0, mini(8, tmpls.size())):
			parts.append("- %s (%s) uses=%s %s" % [
				str(t.get("name", "")), str(t.get("id", "")),
				str(t.get("uses", 0)), str(t.get("url", "")),
			])
	var plugs := learned_plugins_for(genre_id)
	if not plugs.is_empty():
		parts.append("Remembered plugins / AssetLib:")
		for p in plugs.slice(0, mini(6, plugs.size())):
			parts.append("- %s → %s" % [str(p.get("name", "")), str(p.get("url", ""))])
	if not assets.is_empty():
		parts.append("Remembered assets:")
		for a in assets.slice(maxi(0, assets.size() - 6), assets.size()):
			parts.append("- [%s] %s (%s)" % [
				str(a.get("kind", "")), str(a.get("title", "")), str(a.get("path", "")),
			])
	if lessons.size() > 0:
		parts.append("Lessons:")
		for i in range(maxi(0, lessons.size() - 5), lessons.size()):
			parts.append("- %s" % lessons[i])
	if directions.size() > 0:
		parts.append("Recent directions:")
		for i in range(maxi(0, directions.size() - 4), directions.size()):
			parts.append("- %s" % directions[i])
	return "\n".join(parts)


func record_pipeline_success(genre_id: String, template_id: String, template_meta: Dictionary, direction: String, summary: String) -> void:
	remember_direction(direction, genre_id)
	if not template_id.is_empty():
		var meta := template_meta.duplicate(true) if not template_meta.is_empty() else {
			"id": template_id,
			"name": template_id,
			"genre_id": genre_id,
			"source": "studio",
		}
		meta["id"] = template_id
		meta["genre_id"] = genre_id
		remember_template_use(meta)
	if not summary.is_empty():
		remember_lesson("Applied (%s): %s" % [genre_id, summary.left(300)])
