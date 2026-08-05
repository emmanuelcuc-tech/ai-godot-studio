class_name OpenRefClient
extends RefCounted
## Fetch small MIT/CC0 Godot 4 sample sources into refs/<name>/ for the AI coder.
## Prefers raw README + key scripts. Skips commercial rips.

signal status(message: String)
signal finished(ok: bool, result: Dictionary)

const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")
const ResourceCatalogScript = preload("res://scripts/ai/resource_catalog.gd")

var _http
var _project_root: String = ""
var _ref: Dictionary = {}
var _queue: PackedStringArray = PackedStringArray()
var _saved: PackedStringArray = PackedStringArray()
var _blobs: PackedStringArray = PackedStringArray()
var _active: bool = false
var _pending_rel: String = ""


func attach(host: Node) -> void:
	_http = AIHTTPClientScript.new()
	_http.attach(host)
	if _http._http:
		_http._http.timeout = 20
	_http.completed.connect(_on_http)


func cancel() -> void:
	_active = false
	_queue = PackedStringArray()
	_pending_rel = ""


func fetch_for_genre(project_root: String, genre_id: String) -> Error:
	_project_root = project_root
	_saved = PackedStringArray()
	_blobs = PackedStringArray()
	_queue = PackedStringArray()
	_pending_rel = ""
	var refs: Array = ResourceCatalogScript.open_refs(genre_id)
	_ref = {}
	for r in refs:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if ResourceCatalogScript.looks_like_rip(str(r.get("title", "")) + " " + str(r.get("page", ""))):
			continue
		_ref = r
		break
	if _ref.is_empty():
		finished.emit(true, {"ok": true, "summary": "", "files": []})
		return OK
	var files: Array = _ref.get("files", [])
	for f in files:
		_queue.append(str(f))
	if _queue.is_empty():
		_queue.append("README.md")
	_active = true
	status.emit("Fetching open Godot sample: %s…" % str(_ref.get("title", "")))
	return _pump()


func _pump() -> Error:
	if not _active:
		return OK
	if _queue.is_empty():
		_active = false
		var summary: String = _build_summary()
		_write_index(summary)
		status.emit("Open sample saved under refs/%s/" % str(_ref.get("id", "sample")))
		finished.emit(true, {
			"ok": true,
			"id": str(_ref.get("id", "")),
			"title": str(_ref.get("title", "")),
			"license": str(_ref.get("license", "")),
			"page": str(_ref.get("page", "")),
			"files": _saved,
			"summary": summary,
		})
		return OK
	_pending_rel = _queue[0]
	_queue.remove_at(0)
	var repo: String = str(_ref.get("repo", ""))
	var branch: String = str(_ref.get("branch", "main"))
	var url: String = "https://raw.githubusercontent.com/%s/%s/%s" % [repo, branch, _pending_rel]
	var err: Error = _http.get_url(url, PackedStringArray([
		"User-Agent: AI-Godot-Studio/1.0 (open ref fetch)",
		"Accept: text/plain",
	]))
	if err != OK:
		_pending_rel = ""
		return _pump()
	return err


func _on_http(ok: bool, text: String, _meta: Dictionary) -> void:
	if not _active:
		return
	var rel: String = _pending_rel
	_pending_rel = ""
	if ok and not text.is_empty() and not text.strip_edges().begins_with("404"):
		_store_file(rel, text)
	_pump()


func _store_file(rel: String, body: String) -> void:
	var safe_rel: String = rel.replace("\\", "/").lstrip("/").get_file()
	if safe_rel.is_empty() or safe_rel.contains(".."):
		return
	var dest_dir: String = _project_root.path_join("refs").path_join(str(_ref.get("id", "sample")))
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var dest: String = dest_dir.path_join(safe_rel)
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return
	var clipped: String = body if body.length() <= 20000 else body.left(20000) + "\n...[truncated]...\n"
	f.store_string(clipped)
	_saved.append("refs/%s/%s" % [_ref.get("id", "sample"), safe_rel])
	var lower: String = safe_rel.to_lower()
	if lower.ends_with(".md") or lower.ends_with(".gd") or lower.ends_with(".tscn"):
		_blobs.append("----- %s -----\n%s\n" % [safe_rel, clipped.left(3500)])


func _write_index(summary: String) -> void:
	var dest_dir: String = _project_root.path_join("refs").path_join(str(_ref.get("id", "sample")))
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var f: FileAccess = FileAccess.open(dest_dir.path_join("REF.md"), FileAccess.WRITE)
	if f:
		f.store_string(summary)


func _build_summary() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"# Open Godot reference",
		"",
		"- **Title:** %s" % str(_ref.get("title", "")),
		"- **License:** %s" % str(_ref.get("license", "")),
		"- **Source:** %s" % str(_ref.get("page", "")),
		"- **Repo:** %s" % str(_ref.get("repo", "")),
		"",
		"Use patterns (movement, nodes, feedback) — do not copy proprietary assets. Skip anything that looks like a commercial rip.",
		"",
		"## Files fetched",
	])
	for p in _saved:
		lines.append("- `%s`" % p)
	if _blobs.is_empty():
		lines.append("")
		lines.append("(No script/README body captured — see source URL.)")
	else:
		lines.append("")
		lines.append("## Excerpts for the coder")
		lines.append("")
		lines.append("\n".join(_blobs).left(8000))
	return "\n".join(lines)
