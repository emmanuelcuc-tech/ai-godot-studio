class_name GameGenerator
extends RefCounted
## Extracts a Godot project file map from AI JSON (with fence stripping).


static func parse_project_json(raw: String) -> Dictionary:
	var cleaned := raw.strip_edges()
	if cleaned.begins_with("```"):
		var first_nl := cleaned.find("\n")
		if first_nl != -1:
			cleaned = cleaned.substr(first_nl + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)
		cleaned = cleaned.strip_edges()
	var start := cleaned.find("{")
	var end := cleaned.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return {"ok": false, "error": "No JSON object found"}
	cleaned = cleaned.substr(start, end - start + 1)
	var data = JSON.parse_string(cleaned)
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "JSON parse failed"}
	var files: Array = data.get("files", [])
	if files.is_empty():
		return {"ok": false, "error": "No files in response"}
	var normalized: Array = []
	for f in files:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var path := str(f.get("path", "")).replace("\\", "/").lstrip("/")
		var content := str(f.get("content", ""))
		if path.is_empty() or content.is_empty():
			continue
		if path.contains(".."):
			continue
		normalized.append({"path": path, "content": content})
	if normalized.is_empty():
		return {"ok": false, "error": "All files invalid"}
	var name := str(data.get("project_name", "ai_game")).to_snake_case()
	if name.is_empty():
		name = "ai_game"
	return {
		"ok": true,
		"project_name": name,
		"summary": str(data.get("summary", "")),
		"howto": data.get("howto", []),
		"files": normalized,
		"download_queries": data.get("download_queries", []),
	}


static func parse_plan_json(raw: String) -> Dictionary:
	var cleaned := raw.strip_edges()
	if cleaned.begins_with("```"):
		var first_nl := cleaned.find("\n")
		if first_nl != -1:
			cleaned = cleaned.substr(first_nl + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)
		cleaned = cleaned.strip_edges()
	var start := cleaned.find("{")
	var end := cleaned.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return {}
	cleaned = cleaned.substr(start, end - start + 1)
	var data = JSON.parse_string(cleaned)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
