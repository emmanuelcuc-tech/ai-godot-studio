class_name AssetLibClient
extends RefCounted
## Official Godot Asset Library API — search + optional MIT/CC0 addon zip install.
## https://godotengine.org/asset-library/api

signal status(message: String)
signal finished(ok: bool, result: Dictionary)

const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")
const ResourceCatalogScript = preload("res://scripts/ai/resource_catalog.gd")
const ZipAddonUtilScript = preload("res://scripts/ai/zip_addon_util.gd")

const API := "https://godotengine.org/asset-library/api"
const MAX_ZIP_BYTES := 8 * 1024 * 1024

var _http
var _dl
var _mode: String = ""
var _project_root: String = ""
var _hits: Array = []
var _pick: Dictionary = {}
var _listed: Array = []


func attach(host: Node) -> void:
	_http = AIHTTPClientScript.new()
	_dl = AIHTTPClientScript.new()
	_http.attach(host)
	_dl.attach(host)
	if _http._http:
		_http._http.timeout = 25
	if _dl._http:
		_dl._http.timeout = 40
	_http.completed.connect(_on_http)
	_dl.completed.connect(_on_download)


func search_and_maybe_install(project_root: String, genre_id: String, extra_terms: PackedStringArray = PackedStringArray()) -> Error:
	_project_root = project_root
	_hits.clear()
	_listed.clear()
	_pick = {}
	var terms: PackedStringArray = ResourceCatalogScript.assetlib_queries(genre_id)
	for t in extra_terms:
		if not str(t).strip_edges().is_empty():
			terms.append(str(t).strip_edges())
	var filter: String = terms[0] if terms.size() > 0 else "godot 4"
	_mode = "search"
	status.emit("Searching Godot Asset Library for '%s'…" % filter)
	var url: String = "%s/asset?type=addon&godot_version=4.0&max_results=8&sort=rating&filter=%s&support=official+featured+community" % [
		API, filter.uri_encode()
	]
	return _http.get_url(url, PackedStringArray([
		"User-Agent: AI-Godot-Studio/1.0 (assetlib; educational)",
		"Accept: application/json",
	]))


func _on_http(ok: bool, text: String, _meta: Dictionary) -> void:
	if _mode == "search":
		if not ok:
			status.emit("Asset Library search skipped (%s)." % text.left(120))
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		_parse_search(text)
		if _pick.is_empty():
			status.emit("Asset Library: recorded plugin links (none auto-installed).")
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		_mode = "detail"
		var id: String = str(_pick.get("asset_id", ""))
		status.emit("Fetching AssetLib details: %s…" % str(_pick.get("title", id)))
		var url: String = "%s/asset/%s" % [API, id]
		if _http.get_url(url, PackedStringArray([
			"User-Agent: AI-Godot-Studio/1.0 (assetlib)",
			"Accept: application/json",
		])) != OK:
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
		return
	if _mode == "detail":
		if not ok:
			status.emit("AssetLib detail failed — links still recorded.")
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		var download_url: String = str(data.get("download_url", ""))
		var license: String = str(data.get("cost", _pick.get("cost", "")))
		var title: String = str(data.get("title", _pick.get("title", "")))
		_pick["download_url"] = download_url
		_pick["cost"] = license
		_pick["browse_url"] = str(data.get("browse_url", ""))
		_pick["description"] = str(data.get("description", "")).left(400)
		if download_url.is_empty() or not ResourceCatalogScript.license_ok_for_install(license):
			status.emit("AssetLib: %s listed only (license/url not auto-installable)." % title)
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		if ResourceCatalogScript.looks_like_rip(title + " " + str(data.get("description", ""))):
			status.emit("Skipped AssetLib hit that looks like a commercial rip.")
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		if not _url_looks_safe(download_url):
			status.emit("AssetLib zip host not on allow-list — recorded link only.")
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
			return
		_mode = "zip"
		var dest: String = _project_root.path_join(".studio_cache").path_join("assetlib_%s.zip" % str(_pick.get("asset_id", "addon")))
		status.emit("Downloading open addon zip: %s…" % title)
		if _dl.download_file(download_url, dest, PackedStringArray([
			"User-Agent: AI-Godot-Studio/1.0 (assetlib zip)",
		])) != OK:
			finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})


func _on_download(ok: bool, text: String, _meta: Dictionary) -> void:
	if _mode != "zip":
		return
	if not ok:
		status.emit("Addon zip download failed — plugin link kept in docs.")
		finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
		return
	var zip_path: String = text if FileAccess.file_exists(text) else str(_meta.get("file", ""))
	if zip_path.is_empty() or not FileAccess.file_exists(zip_path):
		finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
		return
	var sz: int = FileAccess.get_file_as_bytes(zip_path).size()
	if sz <= 0 or sz > MAX_ZIP_BYTES:
		status.emit("Addon zip skipped (empty or over 8 MB).")
		DirAccess.remove_absolute(zip_path)
		finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
		return
	var extracted: Dictionary = ZipAddonUtilScript.extract_addon(zip_path, _project_root)
	if not extracted.get("ok", false):
		status.emit("Addon zip not installed: %s" % str(extracted.get("error", "unknown")))
		finished.emit(true, {"ok": true, "listed": _listed, "installed": {}})
		return
	status.emit("Installed open addon into addons/ (%s files)." % str(extracted.get("count", 0)))
	finished.emit(true, {
		"ok": true,
		"listed": _listed,
		"installed": {
			"title": str(_pick.get("title", "")),
			"license": str(_pick.get("cost", "")),
			"url": str(_pick.get("browse_url", _pick.get("download_url", ""))),
			"files": extracted.get("files", []),
			"count": extracted.get("count", 0),
		},
	})


func _parse_search(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	for row in data.get("result", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var title: String = str(row.get("title", ""))
		var cost: String = str(row.get("cost", ""))
		var asset_id: String = str(row.get("asset_id", ""))
		if title.is_empty() or asset_id.is_empty():
			continue
		if ResourceCatalogScript.looks_like_rip(title):
			continue
		var item: Dictionary = {
			"asset_id": asset_id,
			"title": title,
			"author": str(row.get("author", "")),
			"cost": cost,
			"category": str(row.get("category", "")),
			"godot_version": str(row.get("godot_version", "")),
			"support_level": str(row.get("support_level", "")),
			"page": "https://godotengine.org/asset-library/asset/%s" % asset_id,
		}
		_listed.append(item)
		if _pick.is_empty() and ResourceCatalogScript.license_ok_for_install(cost):
			_pick = item


func _url_looks_safe(url: String) -> bool:
	var u: String = url.to_lower()
	if not (u.begins_with("https://github.com/") or u.begins_with("https://gitlab.com/") \
			or u.begins_with("https://bitbucket.org/") or u.begins_with("https://godotengine.org/") \
			or u.begins_with("https://downloads.tuxfamily.org/") or u.contains("githubusercontent.com")):
		return false
	if u.ends_with(".exe") or u.ends_with(".msi") or u.ends_with(".sh") or u.ends_with(".bat"):
		return false
	return true
