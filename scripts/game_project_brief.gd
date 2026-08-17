class_name GameProjectBrief
extends RefCounted
## Parse GameProject-like JSON from the Create box or a loaded file.
## Ignores User-role schemas and npm site configs.


static func try_parse_text(text: String) -> Dictionary:
	var raw: String = text.strip_edges()
	if raw.is_empty():
		return {"ok": false, "kind": "empty"}
	var json_text: String = _extract_json_object(raw)
	if json_text.is_empty():
		return {"ok": false, "kind": "plain"}
	var cleaned: String = strip_jsonc(json_text)
	var parsed: Variant = JSON.parse_string(cleaned)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "kind": "plain"}
	return classify(parsed)


static func try_parse_file(abs_path: String) -> Dictionary:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return {"ok": false, "kind": "missing", "error": "File not found"}
	var text: String = FileAccess.get_file_as_string(abs_path)
	var result: Dictionary = try_parse_text(text)
	result["source_path"] = abs_path
	return result


static func classify(data: Dictionary) -> Dictionary:
	if _looks_like_user_schema(data):
		return {
			"ok": false,
			"kind": "skipped",
			"reason": "skipped — not a game spec",
			"data": data,
		}
	var has_game_fields: bool = _has_game_fields(data)
	if not has_game_fields:
		var name: String = str(data.get("name", "")).strip_edges()
		if data.has("site") or name == "untitled":
			return {
				"ok": false,
				"kind": "site_only",
				"reason": "No game spec (ignored npm site metadata).",
				"name": name,
				"data": data,
			}
		if not name.is_empty() and not data.has("properties"):
			return {
				"ok": true,
				"kind": "name_only",
				"name": name,
				"data": data,
			}
		return {"ok": false, "kind": "skipped", "reason": "skipped — not a game spec", "data": data}
	var gp: Dictionary = _pick_game_fields(data)
	return {
		"ok": true,
		"kind": "gameproject",
		"data": gp,
		"title": str(gp.get("title", "")),
		"genre": str(gp.get("genre", "")),
		"description": str(gp.get("description", "")),
		"art_style": str(gp.get("art_style", "")),
		"summary": str(gp.get("summary", "")),
		"setup_instructions": str(gp.get("setup_instructions", "")),
		"texture_urls": gp.get("texture_urls", []),
		"project_structure": gp.get("project_structure", null),
	}


static func directions_text(gp: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var desc: String = str(gp.get("description", "")).strip_edges()
	if not desc.is_empty():
		parts.append(desc)
	var art: String = str(gp.get("art_style", "")).strip_edges()
	if not art.is_empty():
		parts.append("Art style: %s" % art)
	var summary: String = str(gp.get("summary", "")).strip_edges()
	if not summary.is_empty():
		parts.append("Design summary: %s" % summary)
	var genre: String = str(gp.get("genre", "")).strip_edges()
	if not genre.is_empty():
		parts.append("Genre: %s" % genre)
	return "\n\n".join(parts)


static func sanitize_project_name(title: String) -> String:
	var n: String = title.strip_edges().to_lower().replace(" ", "_")
	n = n.validate_filename()
	while n.contains("__"):
		n = n.replace("__", "_")
	n = n.trim_prefix("_").trim_suffix("_")
	if n.is_empty() or n == "untitled" or n == "untitled_game":
		return ""
	return n.left(48)


static func parse_structure_files(raw: Variant) -> Array:
	var files: Array = []
	var data: Variant = raw
	if typeof(data) == TYPE_STRING:
		var text: String = str(data).strip_edges()
		if text.is_empty():
			return files
		var parsed: Variant = JSON.parse_string(strip_jsonc(text))
		if parsed == null:
			return files
		data = parsed
	if typeof(data) == TYPE_ARRAY:
		for row in data:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var rel: String = _safe_rel(str(row.get("path", row.get("file", row.get("name", "")))))
			if rel.is_empty():
				continue
			files.append({"path": rel, "content": str(row.get("content", row.get("text", "")))})
		return files
	if typeof(data) != TYPE_DICTIONARY:
		return files
	if data.has("files") and typeof(data.get("files")) == TYPE_ARRAY:
		return parse_structure_files(data.get("files"))
	_walk_tree("", data, files)
	return files


static func snapshot(gp: Dictionary, extras: Dictionary = {}) -> Dictionary:
	var urls: Array = []
	var tex = gp.get("texture_urls", [])
	if typeof(tex) == TYPE_ARRAY:
		for u in tex:
			urls.append(str(u))
	var out: Dictionary = {
		"title": str(gp.get("title", extras.get("title", ""))),
		"genre": str(gp.get("genre", extras.get("genre", ""))),
		"description": str(gp.get("description", extras.get("description", ""))),
		"art_style": str(gp.get("art_style", "")),
		"status": "completed",
		"summary": str(gp.get("summary", extras.get("summary", ""))),
		"setup_instructions": str(gp.get("setup_instructions", "")),
		"texture_urls": urls,
		"project_structure": gp.get("project_structure", extras.get("project_structure", "")),
	}
	if extras.has("local_textures"):
		out["local_textures"] = extras.get("local_textures", [])
	return out


static func export_from_project(project_path: String, title: String, genre: String, description: String, summary: String) -> Dictionary:
	var structure: Array = []
	if not project_path.is_empty():
		var Writer = load("res://scripts/project_writer.gd")
		if Writer:
			structure = Writer.read_project_files(project_path, 8000)
	var textures: Array = []
	if not project_path.is_empty():
		var Layout = load("res://scripts/editors/game_asset_layout.gd")
		if Layout:
			for item in Layout.list_all(project_path):
				if typeof(item) != TYPE_DICTIONARY:
					continue
				if str(item.get("kind", "")) == "image":
					textures.append(str(item.get("rel", "")))
	return {
		"title": title,
		"genre": genre,
		"description": description,
		"art_style": "",
		"status": "completed",
		"summary": summary,
		"setup_instructions": "",
		"texture_urls": [],
		"local_textures": textures,
		"project_structure": JSON.stringify(structure),
	}


static func strip_jsonc(text: String) -> String:
	var src: String = text.replace("\r\n", "\n")
	var out := ""
	var i: int = 0
	var in_str: bool = false
	var escape: bool = false
	while i < src.length():
		var ch: String = src[i]
		if in_str:
			out += ch
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				in_str = false
			i += 1
			continue
		if ch == "\"":
			in_str = true
			out += ch
			i += 1
			continue
		if ch == "/" and i + 1 < src.length() and src[i + 1] == "/":
			while i < src.length() and src[i] != "\n":
				i += 1
			continue
		if ch == "/" and i + 1 < src.length() and src[i + 1] == "*":
			i += 2
			while i + 1 < src.length() and not (src[i] == "*" and src[i + 1] == "/"):
				i += 1
			i = mini(i + 2, src.length())
			continue
		out += ch
		i += 1
	return out


static func pretty_prompt(gp: Dictionary) -> String:
	var slim: Dictionary = _pick_game_fields(gp)
	return JSON.stringify(slim, "\t")


static func _pick_game_fields(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["title", "genre", "description", "art_style", "status", "summary", "setup_instructions", "texture_urls", "project_structure"]:
		if data.has(key):
			out[key] = data[key]
	if not out.has("title"):
		var name: String = str(data.get("name", "")).strip_edges()
		if not name.is_empty() and name.to_lower() != "untitled":
			out["title"] = name
	return out


static func _has_game_fields(data: Dictionary) -> bool:
	if not str(data.get("description", "")).strip_edges().is_empty():
		return true
	if not str(data.get("title", "")).strip_edges().is_empty() and not str(data.get("genre", "")).strip_edges().is_empty():
		return true
	if data.has("texture_urls") and typeof(data.get("texture_urls")) == TYPE_ARRAY and data["texture_urls"].size() > 0:
		return true
	if data.has("project_structure") and not str(data.get("project_structure", "")).is_empty():
		return true
	if data.has("art_style") and not str(data.get("description", data.get("summary", ""))).strip_edges().is_empty():
		return true
	return false


static func _looks_like_user_schema(data: Dictionary) -> bool:
	if str(data.get("name", "")).strip_edges().to_lower() == "user" and data.has("properties"):
		return true
	var props = data.get("properties", {})
	if typeof(props) == TYPE_DICTIONARY and props.has("role") and data.has("required") and not _has_game_fields(data):
		return true
	return false


static func _extract_json_object(text: String) -> String:
	var t: String = text.strip_edges()
	if t.begins_with("```"):
		var nl: int = t.find("\n")
		if nl >= 0:
			t = t.substr(nl + 1)
		t = t.trim_suffix("```").strip_edges()
	var start: int = t.find("{")
	var end: int = t.rfind("}")
	if start < 0 or end <= start:
		return ""
	return t.substr(start, end - start + 1)


static func _safe_rel(path: String) -> String:
	var rel: String = path.replace("\\", "/").strip_edges().trim_prefix("res://").lstrip("/")
	if rel.is_empty() or rel.contains(".."):
		return ""
	if rel.begins_with("/") or rel.contains(":"):
		return ""
	return rel


static func _walk_tree(prefix: String, node: Variant, files: Array) -> void:
	if typeof(node) == TYPE_STRING:
		var rel: String = _safe_rel(prefix)
		if not rel.is_empty():
			files.append({"path": rel, "content": str(node)})
		return
	if typeof(node) != TYPE_DICTIONARY:
		return
	if node.has("content") and (node.has("path") or not prefix.is_empty()):
		var rel2: String = _safe_rel(str(node.get("path", prefix)))
		if not rel2.is_empty():
			files.append({"path": rel2, "content": str(node.get("content", ""))})
		return
	for key in node.keys():
		var child_path: String = str(key) if prefix.is_empty() else "%s/%s" % [prefix, str(key)]
		_walk_tree(child_path, node[key], files)
