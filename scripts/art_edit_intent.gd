class_name ArtEditIntent
extends RefCounted
## Detects texture / sprite / menu / model + wall/floor/room/character/weapon slot edits.

const SLOTS: PackedStringArray = ["wall", "floor", "room", "character", "weapon"]


static func detect(text: String) -> Dictionary:
	var blob: String = text.to_lower()
	var types: Dictionary = {
		"texture": false,
		"sprite": false,
		"menu": false,
		"model": false,
	}
	var slots: Dictionary = {
		"wall": false,
		"floor": false,
		"room": false,
		"character": false,
		"weapon": false,
	}
	if blob.is_empty():
		return {
			"any": false,
			"ambiguous": false,
			"types": types,
			"slots": slots,
			"labels": [],
			"slot_labels": [],
		}

	var menu_hit: bool = _any(blob, ["menu background", "menu sprite", "title screen", "hud", " ui", "ui ", "user interface", "main menu", "pause menu"])
	if blob.contains("menu") or blob.contains("hud"):
		menu_hit = true
	var model_hit: bool = _any(blob, ["model", "mesh", "glb", "gltf", "obj ", "3d character", "3d enemy", "weapon model", "character model", "room model"])
	var sprite_hit: bool = _any(blob, ["sprite", "2d character", "2d enemy", "pixel character", "pixel enemy", "billboard"])
	if blob.contains("sprite"):
		sprite_hit = true
	var texture_hit: bool = _any(blob, [
		"texture", "material", "wall", "floor", "brick", "grass", "ground", "sky",
		"seamless", "concrete", "dirt", "stone", "asphalt", "ceiling", "backdrop", "room",
	])
	if blob.contains("background") and not menu_hit:
		texture_hit = true
	if menu_hit and blob.contains("background"):
		texture_hit = false

	types["menu"] = menu_hit
	types["model"] = model_hit
	types["sprite"] = sprite_hit
	types["texture"] = texture_hit

	slots["wall"] = _any(blob, ["wall", "brick", "corridor wall"])
	slots["floor"] = _any(blob, ["floor", "ground", "tile floor"])
	slots["room"] = _any(blob, ["room", "world", "level art", "environment", "ceiling", "sky"])
	slots["character"] = _any(blob, ["character", "hero", "player art", "player sprite", "player model", "skin"])
	slots["weapon"] = _any(blob, ["weapon", "gun", "sword", "rifle", "pistol"])

	var ambiguous: bool = false
	if _any(blob, ["character", "hero", "player art", "enemy art", "new look", "new art", "visual", "skin"]) \
			and not texture_hit and not sprite_hit and not model_hit and not menu_hit:
		ambiguous = true
	if _any(blob, ["new character", "different character", "better character", "change the character"]) \
			and not sprite_hit and not model_hit:
		ambiguous = true
	if _any(blob, ["new art", "different art", "change the look", "new texture", "new sprite", "new model"]) \
			and not _any_slot(slots):
		ambiguous = true

	var labels: PackedStringArray = PackedStringArray()
	if types["texture"]:
		labels.append("texture")
	if types["sprite"]:
		labels.append("sprite")
	if types["menu"]:
		labels.append("menu")
	if types["model"]:
		labels.append("model")
	if ambiguous and labels.is_empty():
		labels.append("ambiguous")

	var slot_labels: PackedStringArray = PackedStringArray()
	for key in SLOTS:
		if bool(slots.get(key, false)):
			slot_labels.append(key)

	return {
		"any": labels.size() > 0 or slot_labels.size() > 0,
		"ambiguous": ambiguous,
		"types": types,
		"slots": slots,
		"labels": labels,
		"slot_labels": slot_labels,
		"replace": _looks_like_replace(blob),
	}


static func introduces_new_category(detected: Dictionary, last_types: PackedStringArray) -> bool:
	var types: Dictionary = detected.get("types", {}) if typeof(detected.get("types", {})) == TYPE_DICTIONARY else {}
	for key in ["texture", "sprite", "menu", "model"]:
		if bool(types.get(key, false)) and not last_types.has(key):
			return true
	return bool(detected.get("ambiguous", false))


static func selected_labels(types: Dictionary) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for key in ["texture", "sprite", "menu", "model"]:
		if bool(types.get(key, false)):
			labels.append(key)
	return labels


static func selected_slots(slots: Dictionary) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for key in SLOTS:
		if bool(slots.get(key, false)):
			labels.append(key)
	return labels


static func to_art_kinds(types: Dictionary) -> Dictionary:
	return {
		"textures": bool(types.get("texture", false)) or bool(types.get("menu", false)),
		"sprites": bool(types.get("sprite", false)) or bool(types.get("menu", false)),
		"models": bool(types.get("model", false)),
	}


static func _looks_like_replace(blob: String) -> bool:
	return _any(blob, ["different", "new ", "replace", "swap", "change the", "another ", "updated "])


static func _any_slot(slots: Dictionary) -> bool:
	for key in SLOTS:
		if bool(slots.get(key, false)):
			return true
	return false


static func _any(blob: String, words: Array) -> bool:
	for w in words:
		if blob.contains(str(w)):
			return true
	return false
