class_name TemplateLibrary
extends RefCounted
## Godot templates + plugins the studio can offer. Merges built-ins with StudioMemory.


static func catalog() -> Array:
	## Built-in + known open Godot templates (not commercial games).
	return [
		{
			"id": "builtin_fps_corridor",
			"name": "Corridor FPS (Studio built-in)",
			"genre_id": "fps",
			"source": "builtin",
			"builtin_genre": "fps",
			"url": "",
			"summary": "Playable Godot 4 FPS: mouse-look, hitscan, walk-bob, muzzle/impact particles, RigidBody debris, wall textures.",
			"plugins": ["godot_fps_ready"],
			"ready": true,
		},
		{
			"id": "kenney_fps",
			"name": "Kenney Starter Kit FPS (open patterns)",
			"genre_id": "fps",
			"source": "open",
			"builtin_genre": "fps",
			"url": "https://github.com/KenneyNL/Starter-Kit-FPS",
			"summary": "Adapt Kenney FPS kit patterns into Studio corridor template (CC0). Open link to study; Studio generates playable Godot clone structure.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "godotfps_template",
			"name": "GodotFPS-Template (community)",
			"genre_id": "fps",
			"source": "open",
			"builtin_genre": "fps",
			"url": "https://github.com/bukkbeek/GodotFPS-Template",
			"summary": "Community FPS starter patterns — Studio builds from corridor FPS then applies your suggestions.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "godot_demo_3d",
			"name": "Godot official 3D demos (reference)",
			"genre_id": "fps",
			"source": "docs",
			"builtin_genre": "fps",
			"url": "https://github.com/godotengine/godot-demo-projects",
			"summary": "Official demo projects for 3D movement/camera patterns. Studio uses as research + built-in FPS generation.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_tps",
			"name": "Third-person strike (Studio built-in)",
			"genre_id": "tps",
			"source": "builtin",
			"builtin_genre": "tps",
			"url": "",
			"summary": "SpringArm camera, aim-shoot, score enemies.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_platformer",
			"name": "2D Platformer (Studio built-in)",
			"genre_id": "platformer",
			"source": "builtin",
			"builtin_genre": "platformer",
			"url": "",
			"summary": "CharacterBody2D jumps, camera follow.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "kenney_platformer",
			"name": "Kenney 3D Platformer kit patterns",
			"genre_id": "platformer",
			"source": "open",
			"builtin_genre": "platformer",
			"url": "https://github.com/KenneyNL/Starter-Kit-3D-Platformer",
			"summary": "Open Kenney platformer kit → Studio generates adaptable Godot starter.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_space",
			"name": "Space shooter (Studio built-in)",
			"genre_id": "space_shooter",
			"source": "builtin",
			"builtin_genre": "space_shooter",
			"url": "",
			"summary": "Vertical waves, bullets, score.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_racing",
			"name": "Racing (Studio built-in)",
			"genre_id": "racing",
			"source": "builtin",
			"builtin_genre": "racing",
			"url": "https://github.com/KenneyNL/Starter-Kit-Racing",
			"summary": "Arcade driving starter; Kenney racing kit as reference.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_voxel",
			"name": "Voxel / Minecraft-feel (Studio built-in)",
			"genre_id": "voxel",
			"source": "builtin",
			"builtin_genre": "voxel",
			"url": "",
			"summary": "Block break/build, particles, menu, materials.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_brawler",
			"name": "Beat-em-up (Studio built-in)",
			"genre_id": "beat_em_up",
			"source": "builtin",
			"builtin_genre": "beat_em_up",
			"url": "https://github.com/quiver-dev/template-beat-em-up",
			"summary": "Side brawler patterns; Quiver template as open reference.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_fighting",
			"name": "Fighting (Studio built-in)",
			"genre_id": "fighting",
			"source": "builtin",
			"builtin_genre": "fighting",
			"url": "",
			"summary": "Versus fighter starter.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_open",
			"name": "Open world lite (Studio built-in)",
			"genre_id": "open_world",
			"source": "builtin",
			"builtin_genre": "open_world",
			"url": "",
			"summary": "Exploration sandbox starter.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_sim",
			"name": "Simulation (Studio built-in)",
			"genre_id": "simulation",
			"source": "builtin",
			"builtin_genre": "simulation",
			"url": "",
			"summary": "Systems / management lite starter.",
			"plugins": [],
			"ready": true,
		},
		{
			"id": "builtin_arena",
			"name": "Arena / twin-stick (Studio built-in)",
			"genre_id": "arena",
			"source": "builtin",
			"builtin_genre": "arena",
			"url": "",
			"summary": "Top-down arena combat.",
			"plugins": [],
			"ready": true,
		},
	]


static func plugins_catalog() -> Array:
	return [
		{
			"name": "Godot Asset Library (browse)",
			"url": "https://godotengine.org/asset-library/asset",
			"genre_id": "any",
			"notes": "Install plugins/assets inside Godot: AssetLib tab. Prefer MIT/CC0.",
		},
		{
			"name": "Kenney Game Assets (CC0)",
			"url": "https://kenney.nl/assets",
			"genre_id": "any",
			"notes": "Textures, kits, models — drop into Learn or assets/.",
		},
		{
			"name": "Godot FPS / 3D starter search",
			"url": "https://godotengine.org/asset-library/asset?filter=fps&category=&godot_version=&max_results=20",
			"genre_id": "fps",
			"notes": "AssetLib FPS filter — review license before use.",
		},
		{
			"name": "Dialogue Manager (plugin idea)",
			"url": "https://godotengine.org/asset-library/asset?filter=dialogue",
			"genre_id": "any",
			"notes": "Optional for story FPS; install via Godot AssetLib if needed.",
		},
	]


static func options_for_genre(genre_id: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for t in catalog():
		if str(t.get("genre_id", "")) != genre_id:
			continue
		var id := str(t.get("id", ""))
		seen[id] = true
		out.append(t)
	var mem = _memory()
	var pref := ""
	if mem:
		pref = mem.preferred_template_id(genre_id)
		for t in mem.learned_templates_for(genre_id):
			var id2 := str(t.get("id", ""))
			if id2.is_empty() or seen.has(id2):
				continue
			seen[id2] = true
			var merged := t.duplicate(true)
			merged["source"] = str(merged.get("source", "learned"))
			merged["ready"] = true
			if not merged.has("builtin_genre"):
				merged["builtin_genre"] = genre_id
			out.append(merged)
		if not pref.is_empty():
			for i in out.size():
				if str(out[i].get("id", "")) == pref:
					var item = out[i]
					out.remove_at(i)
					out.insert(0, item)
					break
	return out


static func find_by_id(template_id: String) -> Dictionary:
	for t in catalog():
		if str(t.get("id", "")) == template_id:
			return t
	var mem = _memory()
	if mem:
		for t in mem.templates:
			if typeof(t) == TYPE_DICTIONARY and str(t.get("id", "")) == template_id:
				return t
	return {}


static func plugins_for_genre(genre_id: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for p in plugins_catalog():
		var g := str(p.get("genre_id", "any"))
		if g == genre_id or g == "any":
			out.append(p)
			seen[str(p.get("name", ""))] = true
	var mem = _memory()
	if mem:
		for p in mem.learned_plugins_for(genre_id):
			var n := str(p.get("name", ""))
			if n.is_empty() or seen.has(n):
				continue
			out.append(p)
	return out


static func detect_genre_from_text(text: String, selected_genre_id: String = "custom") -> String:
	var GenreCatalogScript = load("res://scripts/genre_catalog.gd")
	if GenreCatalogScript:
		var g: Dictionary = GenreCatalogScript.detect(text, selected_genre_id)
		return str(g.get("id", selected_genre_id))
	return selected_genre_id


static func format_option_line(t: Dictionary, index: int) -> String:
	var src := str(t.get("source", "builtin"))
	var used := int(t.get("uses", 0)) > 0
	var star := "★ " if (index == 0 or used) else ""
	return "%s[%s] %s — %s" % [
		star,
		src,
		str(t.get("name", "Template")),
		str(t.get("summary", "")).left(90),
	]


static func _memory():
	# Access autoload safely
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root: Node = (tree as SceneTree).root
		if root and root.has_node("StudioMemory"):
			return root.get_node("StudioMemory")
	return null
