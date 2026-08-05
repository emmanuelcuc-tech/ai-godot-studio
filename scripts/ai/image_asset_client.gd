class_name ImageAssetClient
extends RefCounted
## Searches CC0 / open image sources for textures & materials (bricks, walls, etc.).
## Prefers Openverse + Wikimedia Commons — not Google scrapes of commercial game art.

signal search_done(ok: bool, results: Array, error: String)
signal preview_ready(ok: bool, index: int, texture: Texture2D, meta: Dictionary, error: String)

const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")
const CACHE_DIR := "user://texture_browser_cache"

var _search_http
var _fetch_http
var _mode := ""
var _query := ""
var _results: Array = []
var _pending_index := -1
var _pending_meta: Dictionary = {}


func attach(host: Node) -> void:
	_search_http = AIHTTPClientScript.new()
	_fetch_http = AIHTTPClientScript.new()
	_search_http.attach(host)
	_fetch_http.attach(host)
	_search_http.completed.connect(_on_search_http)
	_fetch_http.completed_bytes.connect(_on_fetch_bytes)


func results() -> Array:
	return _results


func result_count() -> int:
	return _results.size()


func get_result(index: int) -> Dictionary:
	if index < 0 or index >= _results.size():
		return {}
	return _results[index]


static func detect_texture_query(user_text: String) -> String:
	var q := user_text.to_lower()
	var wants := q.contains("texture") or q.contains("material") or q.contains("brick") \
		or q.contains("wall") or q.contains("floor") or q.contains("tile") \
		or q.contains("metal") or q.contains("stone") or q.contains("wood") \
		or q.contains("concrete") or q.contains("dirt") or q.contains("grass")
	if not wants:
		return ""
	# Pull subject words for search
	var subject := "seamless game texture"
	for word in ["brick", "stone", "metal", "wood", "concrete", "dirt", "grass", "tile", "rust", "plaster", "asphalt"]:
		if q.contains(word):
			subject = "%s wall texture seamless" % word
			break
	if q.contains("floor") and not subject.contains("wall"):
		subject = subject.replace("wall", "floor")
	if q.contains("material") and not q.contains("texture"):
		subject += " material"
	return subject + " CC0"


static func is_texture_request(user_text: String) -> bool:
	return not detect_texture_query(user_text).is_empty()


func search(query: String) -> Error:
	_query = query.strip_edges()
	if _query.is_empty():
		_query = "brick wall texture seamless"
	_results.clear()
	_mode = "openverse"
	var url := "https://api.openverse.org/v1/images/?q=%s&license=cc0,pdm&page_size=16" % _query.uri_encode()
	var headers := PackedStringArray([
		"User-Agent: AI-Godot-Studio/1.0 (texture browser; educational)",
		"Accept: application/json",
	])
	return _search_http.get_url(url, headers)


func load_preview(index: int) -> Error:
	if index < 0 or index >= _results.size():
		preview_ready.emit(false, index, null, {}, "No result at index")
		return ERR_INVALID_PARAMETER
	var item: Dictionary = _results[index]
	# Procedural / local
	if str(item.get("source", "")) == "procedural":
		var tex: Texture2D = _make_procedural(str(item.get("kind", "brick")))
		preview_ready.emit(true, index, tex, item, "")
		return OK
	var url := str(item.get("thumb", item.get("url", "")))
	if url.is_empty():
		preview_ready.emit(false, index, null, item, "No image URL")
		return ERR_INVALID_DATA
	_pending_index = index
	_pending_meta = item
	var headers := PackedStringArray([
		"User-Agent: AI-Godot-Studio/1.0 (texture browser)",
	])
	return _fetch_http.get_bytes(url, headers)


func download_full(index: int, dest_abs: String) -> Error:
	## Sync-friendly: if we already have cache for this result, copy it.
	var item := get_result(index)
	if item.is_empty():
		return ERR_INVALID_PARAMETER
	if str(item.get("source", "")) == "procedural":
		var img: Image = _procedural_image(str(item.get("kind", "brick")))
		return img.save_png(dest_abs)
	var cache := str(item.get("cache_path", ""))
	if not cache.is_empty() and FileAccess.file_exists(cache):
		return _copy_file(cache, dest_abs)
	# Use URL — caller should have previewed first so cache exists; else fail soft
	var url := str(item.get("url", item.get("thumb", "")))
	if url.is_empty():
		return ERR_INVALID_DATA
	_pending_index = index
	_pending_meta = item.duplicate()
	_pending_meta["save_as"] = dest_abs
	var headers := PackedStringArray(["User-Agent: AI-Godot-Studio/1.0 (texture browser)"])
	return _fetch_http.get_bytes(url, headers)


func _on_search_http(ok: bool, text: String, _meta: Dictionary) -> void:
	if _mode == "openverse":
		if ok:
			_parse_openverse(text)
			if _results.size() >= 4:
				_append_procedural_fallbacks()
				search_done.emit(true, _results, "")
				return
		# Fallback Wikimedia
		_mode = "wikimedia"
		var wq := _query if not _query.is_empty() else "brick texture"
		var url := "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=%s&gsrnamespace=6&gsrlimit=12&prop=imageinfo&iiprop=url|mime|size&iiurlwidth=512&format=json" % wq.uri_encode()
		var headers := PackedStringArray([
			"User-Agent: AI-Godot-Studio/1.0 (https://godotengine.org/; texture research)",
			"Accept: application/json",
		])
		if _search_http.get_url(url, headers) != OK:
			_results = _procedural_only()
			search_done.emit(true, _results, "Network search failed — showing procedural textures")
		return
	if _mode == "wikimedia":
		if ok:
			_parse_wikimedia(text)
		_append_procedural_fallbacks()
		if _results.is_empty():
			_results = _procedural_only()
		search_done.emit(true, _results, "" if ok else "Partial results (procedural included)")
		return


func _on_fetch_bytes(ok: bool, bytes: PackedByteArray, error: String, _meta: Dictionary) -> void:
	var idx := _pending_index
	var item := _pending_meta.duplicate()
	_pending_index = -1
	var save_as := str(item.get("save_as", ""))
	item.erase("save_as")
	if not ok or bytes.is_empty():
		preview_ready.emit(false, idx, null, item, error if not error.is_empty() else "Download failed")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var ext := "png"
	var mime_hint := str(item.get("mime", "")).to_lower()
	if mime_hint.contains("jpeg") or mime_hint.contains("jpg"):
		ext = "jpg"
	elif mime_hint.contains("webp"):
		ext = "webp"
	var cache_rel := "%s/tex_%s.%s" % [CACHE_DIR, str(idx), ext]
	var cache_abs := ProjectSettings.globalize_path(cache_rel)
	var f := FileAccess.open(cache_abs, FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)
	item["cache_path"] = cache_abs
	if idx >= 0 and idx < _results.size():
		_results[idx]["cache_path"] = cache_abs

	if not save_as.is_empty():
		_copy_file(cache_abs, save_as)

	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		err = img.load_jpg_from_buffer(bytes)
	if err != OK:
		err = img.load_webp_from_buffer(bytes)
	if err != OK:
		# Try load from cache path
		err = img.load(cache_abs)
	if err != OK:
		preview_ready.emit(false, idx, null, item, "Could not decode image")
		return
	var tex := ImageTexture.create_from_image(img)
	preview_ready.emit(true, idx, tex, item, "")


func _parse_openverse(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	for row in data.get("results", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var url := str(row.get("url", ""))
		var thumb := str(row.get("thumbnail", url))
		if url.is_empty():
			continue
		_results.append({
			"title": str(row.get("title", "Openverse image")),
			"url": url,
			"thumb": thumb if not thumb.is_empty() else url,
			"license": str(row.get("license", "cc0")),
			"source": "openverse",
			"page": str(row.get("foreign_landing_url", "")),
			"mime": str(row.get("filetype", "image/jpeg")),
			"creator": str(row.get("creator", "")),
		})


func _parse_wikimedia(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var query = data.get("query", {})
	if typeof(query) != TYPE_DICTIONARY:
		return
	var pages = query.get("pages", {})
	if typeof(pages) != TYPE_DICTIONARY:
		return
	for _k in pages.keys():
		var page = pages[_k]
		if typeof(page) != TYPE_DICTIONARY:
			continue
		var infos = page.get("imageinfo", [])
		if typeof(infos) != TYPE_ARRAY or infos.is_empty():
			continue
		var info = infos[0]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var url := str(info.get("url", ""))
		var thumb := str(info.get("thumburl", url))
		if url.is_empty():
			continue
		_results.append({
			"title": str(page.get("title", "Commons file")),
			"url": url,
			"thumb": thumb if not thumb.is_empty() else url,
			"license": "wikimedia",
			"source": "wikimedia",
			"page": "https://commons.wikimedia.org/wiki/" + str(page.get("title", "")).uri_encode(),
			"mime": str(info.get("mime", "image/jpeg")),
			"creator": "",
		})


func _append_procedural_fallbacks() -> void:
	for kind in ["brick", "stone", "metal", "concrete"]:
		_results.append({
			"title": "Procedural %s (always available)" % kind,
			"url": "",
			"thumb": "",
			"license": "generated",
			"source": "procedural",
			"kind": kind,
			"page": "",
			"mime": "image/png",
			"creator": "AI Godot Studio",
		})


func _procedural_only() -> Array:
	_results.clear()
	_append_procedural_fallbacks()
	return _results


func _make_procedural(kind: String) -> Texture2D:
	return ImageTexture.create_from_image(_procedural_image(kind))


func _procedural_image(kind: String) -> Image:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	match kind:
		"brick":
			_fill_bricks(img, Color(0.55, 0.22, 0.16), Color(0.35, 0.32, 0.28))
		"stone":
			_fill_noise(img, Color(0.45, 0.44, 0.42), 0.18)
		"metal":
			_fill_noise(img, Color(0.55, 0.58, 0.62), 0.08)
			for y in range(0, h, 8):
				for x in w:
					img.set_pixel(x, y, Color(0.4, 0.42, 0.45))
		_:
			_fill_noise(img, Color(0.4, 0.4, 0.38), 0.12)
	return img


func _fill_bricks(img: Image, brick: Color, mortar: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	img.fill(mortar)
	var bw := 64
	var bh := 28
	var row := 0
	var y := 2
	while y < h:
		var offset := (row % 2) * int(bw / 2.0)
		var x := -offset
		while x < w:
			var x0 := maxi(x + 2, 0)
			var y0 := y
			var x1 := mini(x + bw - 2, w)
			var y1 := mini(y + bh - 2, h)
			var shade := brick.darkened(randf() * 0.12)
			for py in range(y0, y1):
				for px in range(x0, x1):
					img.set_pixel(px, py, shade)
			x += bw
		y += bh
		row += 1


func _fill_noise(img: Image, base: Color, amp: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var n := (sin(x * 0.17 + y * 0.11) + cos(x * 0.07 - y * 0.13)) * 0.25
			img.set_pixel(x, y, Color(
				clampf(base.r + n * amp, 0, 1),
				clampf(base.g + n * amp, 0, 1),
				clampf(base.b + n * amp * 0.8, 0, 1)
			))


func _copy_file(src: String, dest: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(src)
	if bytes.is_empty():
		return ERR_FILE_CANT_OPEN
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return ERR_FILE_CANT_WRITE
	out.store_buffer(bytes)
	return OK
