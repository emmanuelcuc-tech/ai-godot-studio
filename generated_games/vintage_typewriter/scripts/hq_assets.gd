class_name HQAssets
extends RefCounted
## Procedural HQ textures: 4K paper + Underwood cream/chrome keys.
## Prefers sliced ref sprites under res://assets/keys/ when present.

const PAPER_DIR := "user://tw_assets/paper"
const KEY_DIR := "user://tw_assets/keys"
const PAPER_4K := 4096
const PAPER_2K := 2048
const KEY_2K := 2048
const KEY_1K := 1024

## Packaged ref sprites (from Copilot / Underwood photos)
const REF_KEY_REST := "res://assets/keys/key_rest_ref.png"
const REF_KEY_PRESS := "res://assets/keys/key_press_ref.png"
const REF_STRIKER := "res://assets/keys/striker_h.png"
const REF_SLUG := "res://assets/keys/slug_h.png"
const REF_SPACE_FALLBACK := "res://assets/keys/key_rest_ref.png"

const PAPER_PRESETS := {
	"white": Color(0.97, 0.97, 0.95),
	"tinted_yellow": Color(0.96, 0.92, 0.78),
	"vintage": Color(0.93, 0.86, 0.70),
	"green": Color(0.78, 0.90, 0.78),
	"blue": Color(0.78, 0.86, 0.96),
	"red": Color(0.94, 0.78, 0.78),
	"yellow": Color(0.98, 0.94, 0.55),
	"black": Color(0.08, 0.08, 0.09),
}


static func ensure_assets(hq: bool = true) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PAPER_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KEY_DIR))
	var paper_size := PAPER_4K if hq else PAPER_2K
	var key_size := KEY_2K if hq else KEY_1K
	var papers: Dictionary = {}
	for id in PAPER_PRESETS.keys():
		var path := PAPER_DIR.path_join("%s_%d.png" % [id, paper_size])
		if not FileAccess.file_exists(path):
			_write_paper(path, PAPER_PRESETS[id], paper_size)
		papers[id] = path
	## Versioned cream/chrome bake so old black keycaps are replaced
	var key_path := KEY_DIR.path_join("keycap_cream_%d.png" % key_size)
	var key_press := KEY_DIR.path_join("keycap_cream_pressed_%d.png" % key_size)
	var space_path := KEY_DIR.path_join("spacebar_cream_%d.png" % key_size)
	var striker_path := KEY_DIR.path_join("striker_%d.png" % key_size)
	if not FileAccess.file_exists(key_path):
		if not _bake_from_ref(REF_KEY_REST, key_path, key_size, key_size, true):
			_write_keycap(key_path, key_size, false)
	if not FileAccess.file_exists(key_press):
		if not _bake_from_ref(REF_KEY_PRESS, key_press, key_size, key_size, true):
			_write_keycap(key_press, key_size, true)
	if not FileAccess.file_exists(space_path):
		_write_spacebar(space_path, key_size)
	if not FileAccess.file_exists(striker_path):
		if not _bake_from_ref(REF_STRIKER, striker_path, key_size, key_size, false):
			if not _bake_from_ref(REF_SLUG, striker_path, key_size, key_size, false):
				_write_striker(striker_path, key_size)
	return {
		"papers": papers,
		"key": key_path,
		"key_pressed": key_press,
		"space": space_path,
		"striker": striker_path,
		"paper_px": paper_size,
		"key_px": key_size,
	}


static func load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _bake_from_ref(res_path: String, out_path: String, w: int, h: int, circular_mask: bool) -> bool:
	if not ResourceLoader.exists(res_path) and not FileAccess.file_exists(res_path):
		## Also try absolute via ProjectSettings when .import not yet scanned
		var abs := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else res_path
		if not FileAccess.file_exists(abs):
			return false
		var img0 := Image.new()
		if img0.load(abs) != OK:
			return false
		return _finish_bake(img0, out_path, w, h, circular_mask)
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var r := load(res_path)
		if r is Texture2D:
			tex = r
	if tex == null:
		var abs2 := ProjectSettings.globalize_path(res_path)
		var img1 := Image.new()
		if img1.load(abs2) != OK:
			return false
		return _finish_bake(img1, out_path, w, h, circular_mask)
	var img := tex.get_image()
	if img == null:
		return false
	return _finish_bake(img, out_path, w, h, circular_mask)


static func _finish_bake(img: Image, out_path: String, w: int, h: int, circular_mask: bool) -> bool:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	if circular_mask:
		_apply_round_key_mask(img)
	img.save_png(out_path)
	return true


static func _apply_round_key_mask(img: Image) -> void:
	var n := img.get_width()
	var cx := n * 0.5
	var cy := n * 0.5
	var r := n * 0.48
	for y in n:
		for x in n:
			var dx := (float(x) - cx) / r
			var dy := (float(y) - cy) / r
			var d := sqrt(dx * dx + dy * dy)
			var c := img.get_pixel(x, y)
			if d > 1.0:
				c.a = 0.0
			elif d > 0.94:
				c.a *= clampf(1.0 - (d - 0.94) / 0.06, 0.0, 1.0)
				## Soft chrome rim lift
				c = c.lerp(Color(0.78, 0.76, 0.70, c.a), (d - 0.94) / 0.06 * 0.55)
			img.set_pixel(x, y, c)


static func _write_paper(path: String, base: Color, size: int) -> void:
	# Bake at 512 then upscale to 2K/4K for HQ output without multi-second waits.
	var src_n := 512
	var img := Image.create(src_n, src_n, false, Image.FORMAT_RGBA8)
	var fiber := 0.035 if base.v > 0.3 else 0.02
	for y in src_n:
		for x in src_n:
			var n := _hash_noise(x, y, 17.0)
			var m := _hash_noise(x * 3, y * 2, 9.0)
			var line := 0.0
			if int(y) % 8 == 0:
				line = 0.035
			var c := base.lightened((n - 0.5) * fiber).darkened(m * 0.04 + line)
			var u := float(x) / float(src_n)
			var v := float(y) / float(src_n)
			var edge := minf(u, 1.0 - u) * minf(v, 1.0 - v)
			c = c.darkened(clampf(0.08 - edge * 0.4, 0.0, 0.08))
			img.set_pixel(x, y, c)
	if size != src_n:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


static func _write_keycap(path: String, size: int, pressed: bool) -> void:
	## Underwood cream face + chrome rim (matches P1020390)
	var src_n := 256
	var img := Image.create(src_n, src_n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := src_n * 0.5
	var cy := src_n * 0.5
	var r := src_n * 0.46
	for y in src_n:
		for x in src_n:
			var dx := (float(x) - cx) / r
			var dy := (float(y) - cy) / r
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0:
				continue
			var rim := smoothstep(0.88, 1.0, d)
			var bowl := smoothstep(0.0, 0.72, d)
			## Cream / ivory key face
			var cream := Color(0.92, 0.88, 0.78)
			cream = cream.darkened(bowl * 0.10 + (0.06 if pressed else 0.0))
			var highlight := (1.0 - d) * 0.18 if dy < -0.12 else 0.0
			cream = cream.lightened(highlight * 0.35)
			## Chrome / nickel rim
			var chrome := Color(0.72, 0.71, 0.66).lightened(highlight * 0.4).darkened(rim * 0.15)
			var c := cream.lerp(chrome, rim * 0.95)
			var a := 1.0 if d < 0.97 else clampf(1.0 - (d - 0.97) / 0.03, 0.0, 1.0)
			c.a = a
			img.set_pixel(x, y, c)
	if size != src_n:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


static func _write_spacebar(path: String, size: int) -> void:
	var src_w := 512
	var src_h := 160
	var img := Image.create(src_w, src_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in src_h:
		for x in src_w:
			var u := float(x) / float(src_w)
			var v := float(y) / float(src_h)
			var edge_x := minf(u, 1.0 - u)
			var edge_y := minf(v, 1.0 - v)
			if edge_x < 0.02 or edge_y < 0.10:
				var a := clampf(minf(edge_x / 0.02, edge_y / 0.10), 0.0, 1.0)
				img.set_pixel(x, y, Color(0.68, 0.66, 0.60, a))
				continue
			## Slightly darker cream bar with chrome edge
			var c := Color(0.86, 0.82, 0.72).lightened((1.0 - v) * 0.10).darkened(v * 0.06)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.resize(size, int(size * 0.32), Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


static func _write_striker(path: String, size: int) -> void:
	var src_n := 256
	var img := Image.create(src_n, src_n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in src_n:
		for x in src_n:
			var u := float(x) / float(src_n)
			var v := float(y) / float(src_n)
			## Typebar stem + slug head
			var in_stem := absf(u - 0.5) < 0.06 and v > 0.35
			var in_head := (u - 0.5) * (u - 0.5) / 0.12 + (v - 0.28) * (v - 0.28) / 0.10 < 1.0
			if not in_stem and not in_head:
				continue
			var metal := Color(0.45, 0.38, 0.28).lightened((1.0 - v) * 0.25)
			metal.a = 1.0
			img.set_pixel(x, y, metal)
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


static func _hash_noise(x: int, y: int, scale: float) -> float:
	var n := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return fposmod(n, 1.0) * (0.7 + 0.3 * sin((float(x) + float(y)) / scale))


static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
