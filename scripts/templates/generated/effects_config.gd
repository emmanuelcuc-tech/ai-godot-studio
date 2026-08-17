extends RefCounted
## VFX toggles/intensity. Rewritten by the studio Effects tab; also readable as studio_effects.json.

static func data() -> Dictionary:
	if not FileAccess.file_exists("res://studio_effects.json"):
		return {
			"muzzle_flash": true,
			"muzzle_intensity": 1.0,
			"bullet_trail": true,
			"bullet_intensity": 1.0,
			"enemy_death": true,
			"enemy_death_intensity": 1.0,
			"destroy_fx": true,
			"destroy_intensity": 1.0,
		}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://studio_effects.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func enabled(key: String, fallback: bool = true) -> bool:
	return bool(data().get(key, fallback))


static func intensity(key: String, fallback: float = 1.0) -> float:
	return float(data().get(key, fallback))
