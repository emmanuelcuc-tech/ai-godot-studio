extends RefCounted
## Graphic category / style tags for Create and art edits.

const ALL: PackedStringArray = ["realistic", "cartoon", "pixel", "2d", "3d", "minimal", "detailed"]


static func defaults_for_genre(genre_id: String) -> PackedStringArray:
	match genre_id:
		"fps", "tps", "racing", "voxel", "open_world":
			return PackedStringArray(["3d", "detailed"])
		"simulation":
			return PackedStringArray(["3d", "minimal"])
		"platformer", "space_shooter", "beat_em_up", "fighting", "arena":
			return PackedStringArray(["2d", "pixel"])
		_:
			return PackedStringArray(["3d", "detailed"])


static func normalize(styles: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for s in styles:
		var key: String = str(s).strip_edges().to_lower().replace(" ", "")
		if key == "twod":
			key = "2d"
		if key == "threed":
			key = "3d"
		if not ALL.has(key) or seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	if out.has("pixel") and not out.has("2d"):
		out.append("2d")
	if out.has("realistic") and not out.has("3d") and not out.has("2d"):
		out.append("3d")
	if out.has("minimal") and out.has("detailed"):
		out.remove_at(out.find("detailed"))
	if out.is_empty():
		out.append("3d")
		out.append("detailed")
	return out


static func from_variant(v: Variant) -> PackedStringArray:
	var raw: PackedStringArray = PackedStringArray()
	if typeof(v) == TYPE_PACKED_STRING_ARRAY:
		raw = v
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			raw.append(str(item))
	elif typeof(v) == TYPE_STRING:
		for part in str(v).split(",", false):
			raw.append(part.strip_edges())
	return normalize(raw)


static func query_suffix(styles: PackedStringArray) -> String:
	var s: PackedStringArray = normalize(styles)
	var bits: PackedStringArray = PackedStringArray()
	if s.has("pixel"):
		bits.append("pixel art 2D chunky tiles sprite")
	if s.has("cartoon"):
		bits.append("cartoon stylized bright saturated")
	if s.has("realistic"):
		bits.append("photorealistic seamless PBR texture")
	if s.has("2d") and not s.has("pixel"):
		bits.append("2D game art")
	if s.has("3d") and not s.has("realistic"):
		bits.append("3D game texture")
	if s.has("minimal"):
		bits.append("flat simple minimal colors")
	if s.has("detailed"):
		bits.append("high detail rich texture")
	if bits.is_empty():
		return ""
	return " " + " ".join(bits)


static func prompt_block(styles: PackedStringArray) -> String:
	var s: PackedStringArray = normalize(styles)
	var lines: PackedStringArray = PackedStringArray([
		"GRAPHIC STYLE (honor exactly): %s" % ", ".join(s),
	])
	if s.has("pixel") or (s.has("2d") and not s.has("3d")):
		lines.append("- Prefer Sprite2D / pixel tiles / chunky 2D art over photo textures.")
	if s.has("3d") and s.has("realistic"):
		lines.append("- Prefer photo-like CC0 wall/floor textures and simple realistic StandardMaterial3D.")
	if s.has("3d") and s.has("cartoon"):
		lines.append("- Bright saturated textures, simple rounded capsule/box meshes.")
	if s.has("cartoon") and s.has("2d"):
		lines.append("- Bold cartoon 2D sprites, clean outlines if possible.")
	if s.has("minimal"):
		lines.append("- Flat colors, few details, uncluttered HUD.")
	if s.has("detailed"):
		lines.append("- Richer textures, more sprite/mesh detail where cheap.")
	return "\n".join(lines)


static func label(styles: PackedStringArray) -> String:
	return "/".join(normalize(styles))
