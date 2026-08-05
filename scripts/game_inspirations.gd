class_name GameInspirations
extends RefCounted
## Famous game names → Godot *recreations* (spiritual remakes), never the original games.
## "make Doom" = build an original corridor FPS recreation in Godot, not id Software's Doom.

const TITLES: Array = [
	{
		"id": "doom",
		"aliases": [
			"doom", "doom 1993", "doom 2", "doom-like", "doomlike", "doomsday",
			"doom recreation", "doom remake", "doom clone", "recreation of doom",
			"make a doom", "like doom",
		],
		"display": "Doom recreation",
		"genre_id": "fps",
		"art_style": """Match Doom's FEEL and ART STYLE with original assets (not ROM/WAD art):
- Low, wide corridors; flat/simple wall geometry; dim lighting
- Limited dirty palette: rust red, brown metal, olive, near-black floors
- Chunkier enemies (simple silhouettes), bright muzzle flash, stark HUD/crosshair
- Slightly low-res look via large texel-feel colors (procedural StandardMaterial3D, no ripped textures)
- Atmosphere: tense, industrial + hellish contrast — original shapes/colors only""",
		"brief": """Build an ORIGINAL Godot recreation with the same FEEL and ART STYLE as Doom — not the original ROM/WAD and not a ROM hack.

Gameplay fantasy: dark tech-base / hell corridors, mouse-look FPS, hitscan, aggressive enemies, health pickups, maze urgency.

Art: recreate the *look* (palette, chunky forms, dim corridors) with new procedural/CC0 materials — never commercial Doom graphics or modified commercial ROMs.

100% new GDScript + scenes.""",
		"search_templates": "Godot 4 FPS corridor shooter recreation open source Kenney Starter-Kit-FPS github",
		"search_assets": "Kenney FPS kit CC0 industrial textures OpenGameArt retro FPS style original",
		"open_refs": [
			"https://github.com/KenneyNL/Starter-Kit-FPS",
			"https://github.com/bukkbeek/GodotFPS-Template",
			"https://docs.godotengine.org/en/stable/tutorials/3d/first_person_controller.html",
		],
	},
	{
		"id": "minecraft",
		"aliases": [
			"minecraft", "mine craft", "voxel", "block game", "blocky sandbox", "minetest",
			"like minecraft", "minecraft recreation", "minecraft remake", "minecraft clone",
			"recreation of minecraft",
		],
		"display": "Minecraft recreation",
		"genre_id": "voxel",
		"art_style": """Match Minecraft's FEEL and ART STYLE with original/CC0 voxels (not Mojang assets):
- Chunk cubes, bright grass/dirt/stone palette, flat face colors
- First-person blocky world, simple sky, readable hotbar
- No official Minecraft textures, skins, or trademarked logos""",
		"brief": """Build an ORIGINAL Godot recreation with the same FEEL and ART STYLE as Minecraft — not the game files and not a modified commercial package.

Gameplay: break/place cubes, hotbar, generated hills, explore/build.

Art: chunky blocks + bright earth tones via original code/CC0 (Kenney voxel). Never Mojang assets or ROM-like dumps.""",
		"search_templates": "Godot 4 voxel block building sandbox recreation open source github CC0",
		"search_assets": "Kenney voxel pack CC0 block textures OpenGameArt",
		"open_refs": [
			"https://github.com/Zylann/godot_voxel",
			"https://www.minetest.net/",
			"https://kenney.nl/assets/voxel-pack",
			"https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html",
		],
	},
	{
		"id": "quake",
		"aliases": ["quake", "quake-like", "arena fps", "quake recreation"],
		"display": "Quake recreation",
		"genre_id": "fps",
		"brief": "ORIGINAL Godot arena FPS recreation (Quake fantasy): speed, vertical maps, projectiles optional. New code only.",
		"search_templates": "Godot 4 arena FPS open source template github",
		"search_assets": "Kenney FPS CC0",
		"open_refs": ["https://github.com/KenneyNL/Starter-Kit-FPS"],
	},
	{
		"id": "mario",
		"aliases": ["mario", "super mario", "mario-like", "mario recreation"],
		"display": "Mario-style recreation",
		"genre_id": "platformer",
		"brief": "ORIGINAL side-scroller recreation (Mario fantasy): precise jumps, platforms, coins, flag. No Nintendo assets.",
		"search_templates": "Godot 4 2D platformer tutorial official Kenney",
		"search_assets": "Kenney platformer pack CC0",
		"open_refs": ["https://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html"],
	},
	{
		"id": "streets_of_rage",
		"aliases": ["streets of rage", "double dragon", "golden axe", "final fight", "brawler recreation"],
		"display": "Beat-em-up recreation",
		"genre_id": "beat_em_up",
		"brief": "ORIGINAL side-plane brawler recreation. Quiver open template patterns. New art/code only.",
		"search_templates": "Godot 4 beat em up Quiver template github",
		"search_assets": "OpenGameArt beat em up sprites CC0",
		"open_refs": ["https://github.com/quiver-dev/template-beat-em-up"],
	},
	{
		"id": "gta",
		"aliases": ["gta", "grand theft", "open world crime", "gta recreation"],
		"display": "Open-world recreation",
		"genre_id": "open_world",
		"brief": "ORIGINAL open-world sandbox recreation. Explore, landmarks, simple goals. No Rockstar assets.",
		"search_templates": "Godot 4 open world exploration template github",
		"search_assets": "Kenney nature kit CC0",
		"open_refs": ["https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html"],
	},
]


static func detect(request: String) -> Dictionary:
	var q := request.to_lower()
	var best: Dictionary = {}
	var best_len := 0
	for t in TITLES:
		for alias in t["aliases"]:
			var a := str(alias)
			if q.contains(a) and a.length() >= best_len:
				best = t
				best_len = a.length()
	return best


static func enrich_prompt(request: String, inspiration: Dictionary) -> String:
	if inspiration.is_empty():
		return request
	var ref_lines: PackedStringArray = []
	for r in inspiration.get("open_refs", []):
		ref_lines.append("- %s" % str(r))
	return """GOAL: Original Godot recreation with the SAME FEEL + ART STYLE — not the commercial game, not a ROM, not a ROM hack.

TITLE FANTASY: %s (%s)
USER SAID: %s

Match gameplay feel AND visual style (palette, shapes, mood) using NEW procedural/CC0 art only.
Do not modify, patch, or redistribute any commercial ROM/ISO/WAD.

PIPELINE:
1) Load Godot genre template: %s
2) Study Learn files (your sprites/code) if present
3) Search open kits & CC0 art in that style
4) AI modifies template into the recreation

RECREATION BRIEF:
%s

ART STYLE TARGET:
%s

OPEN REFS (patterns only):
%s

Name projects like corridor_fps / blockcraft — not trademarked product titles.
""" % [
		str(inspiration.get("display", "")),
		str(inspiration.get("id", "")),
		request,
		str(inspiration.get("genre_id", "")),
		str(inspiration.get("brief", "")),
		str(inspiration.get("art_style", "Match the referenced game's mood with original colors/shapes.")),
		"\n".join(ref_lines),
	]
