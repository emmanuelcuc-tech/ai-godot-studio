class_name GenreCatalog
extends RefCounted
## Genre definitions: Godot rules, open template sources, asset search queries.
## Commercial game source (Doom, etc.) is never copied — only open Godot analogs.

const GENRES: Array = [
	{
		"id": "fps",
		"name": "First Person Shooter",
		"keywords": ["doom", "fps", "first person", "quake", "wolfenstein", "hitscan", "raycast"],
		"godot_nodes": ["CharacterBody3D", "Camera3D", "RayCast3D", "GPUParticles3D"],
		"rules": [
			"Use CharacterBody3D + Camera3D as child for mouse-look FPS control",
			"Fire with RayCast3D or PhysicsRayQueryParameters3D hitscan",
			"Walk-bob camera animation when no skeletal/glTF anim is available",
			"Muzzle + impact GPUParticles3D; RigidBody3D debris chips on wall/enemy hits",
			"Wall/floor StandardMaterial3D — use assets/wall.png from Asset Browser when user picks brick/stone textures",
			"Separate Player, Weapon, Enemy, HUD into scenes",
			"Clamp pitch; yaw on body; capture mouse with Input.MOUSE_MODE_CAPTURED",
		],
		"open_templates": [
			"https://github.com/KenneyNL/Starter-Kit-FPS",
			"https://github.com/bukkbeek/GodotFPS-Template",
			"https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html",
		],
		"asset_queries": [
			"Kenney FPS kit CC0 Godot",
			"Openverse CC0 brick wall seamless texture",
			"OpenGameArt first person shooter textures",
			"Godot 4 FPS weapon pack CC0",
		],
		"inspiration_notes": "Doom recreation: original corridor FPS (maze, hitscan, enemies, pickups) — spiritual remake in Godot, not the commercial Doom game. Godot is the shooter engine: physics, particles, materials, animations.",
	},
	{
		"id": "tps",
		"name": "Third Person Shooter",
		"keywords": ["third person", "tps", "gears", "cover shooter", "over shoulder"],
		"godot_nodes": ["CharacterBody3D", "SpringArm3D", "Camera3D", "AnimationPlayer"],
		"rules": [
			"Camera on SpringArm3D behind player",
			"Aim reticle in center; shoot along camera forward",
			"Blend move animation with strafe relative to camera yaw",
		],
		"open_templates": [
			"https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html",
			"https://github.com/godotengine/godot-demo-projects",
		],
		"asset_queries": ["Kenney character pack CC0", "OpenGameArt third person shooter"],
		"inspiration_notes": "Over-the-shoulder aim, cover optional, enemy AI with line of sight.",
	},
	{
		"id": "platformer",
		"name": "Platformer",
		"keywords": ["platform", "jump", "mario", "celeste", "metroidvania"],
		"godot_nodes": ["CharacterBody2D", "TileMapLayer", "AnimationPlayer", "Camera2D"],
		"rules": [
			"CharacterBody2D with coyote time and jump buffer",
			"move_and_slide(); is_on_floor() for jumps",
			"Camera2D follow with limits; TileMapLayer for solids",
		],
		"open_templates": [
			"https://github.com/KenneyNL/Starter-Kit-3D-Platformer",
			"https://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html",
		],
		"asset_queries": ["Kenney platformer pack CC0", "OpenGameArt 2D tileset platformer"],
		"inspiration_notes": "Precise jumps, hazards, collectibles, checkpoints.",
	},
	{
		"id": "space_shooter",
		"name": "Space Shooter",
		"keywords": ["space", "shmup", "invader", "galaga", "bullet hell", "starfox"],
		"godot_nodes": ["Area2D", "CharacterBody2D", "Timer", "GPUParticles2D"],
		"rules": [
			"Player ship clamped to playfield; auto or manual fire",
			"Object pooling for bullets preferred",
			"Waves via Timer; score and lives HUD",
		],
		"open_templates": [
			"https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html",
		],
		"asset_queries": ["Kenney space shooter pack CC0", "OpenGameArt spaceship sprites"],
		"inspiration_notes": "Vertical or horizontal scroll; powerups; boss wave.",
	},
	{
		"id": "racing",
		"name": "Racing",
		"keywords": ["race", "racing", "car", "kart", "track", "drift"],
		"godot_nodes": ["VehicleBody3D", "CharacterBody3D", "Path3D", "GridMap"],
		"rules": [
			"Arcade: CharacterBody3D with accel/steer/friction OR VehicleBody3D",
			"Lap detection with Area3D checkpoints",
			"Reset when off-track",
		],
		"open_templates": [
			"https://github.com/KenneyNL/Starter-Kit-Racing",
			"https://docs.godotengine.org/en/stable/tutorials/physics/using_kinematic_body_2d.html",
		],
		"asset_queries": ["Kenney racing kit CC0", "OpenGameArt race track textures"],
		"inspiration_notes": "Lap timer, AI opponents optional, boost pads.",
	},
	{
		"id": "simulation",
		"name": "Simulation",
		"keywords": ["sim", "simulation", "tycoon", "farm", "city", "management", "idle"],
		"godot_nodes": ["Control", "Timer", "Resource", "GridContainer"],
		"rules": [
			"Separate data (resources) from UI",
			"Tick economy on Timer; save state optional",
			"Clear feedback loops: gather → spend → upgrade",
		],
		"open_templates": [
			"https://docs.godotengine.org/en/stable/tutorials/ui/index.html",
		],
		"asset_queries": ["Kenney UI pack CC0", "OpenGameArt simulation icons"],
		"inspiration_notes": "Resource counters, build buttons, upgrade costs.",
	},
	{
		"id": "open_world",
		"name": "Open World",
		"keywords": ["open world", "sandbox", "exploration", "rpg", "zelda", "gta"],
		"godot_nodes": ["CharacterBody3D", "GridMap", "NavigationRegion3D", "WorldEnvironment"],
		"rules": [
			"Large playable bounds; streaming optional later",
			"Quest markers as Area3D; simple inventory",
			"Day/night or zone themes via WorldEnvironment",
		],
		"open_templates": [
			"https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html",
			"https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html",
		],
		"asset_queries": ["Kenney nature kit CC0", "OpenGameArt open world terrain"],
		"inspiration_notes": "Explore zones, NPCs, collectibles, map edges wrap or fence.",
	},
	{
		"id": "beat_em_up",
		"name": "Beat Em Up",
		"keywords": ["beat em up", "brawler", "streets of rage", "double dragon", "golden axe"],
		"godot_nodes": ["CharacterBody2D", "Area2D", "AnimationPlayer", "Camera2D"],
		"rules": [
			"Side plane movement X + limited Y depth",
			"Attack hitboxes as Area2D timed with animation",
			"Enemy waves; combo counter optional",
		],
		"open_templates": [
			"https://github.com/quiver-dev/template-beat-em-up",
			"https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html",
		],
		"asset_queries": ["OpenGameArt beat em up sprites", "Kenney character sprites CC0"],
		"inspiration_notes": "Walk right, fight groups, grab/throw optional.",
	},
	{
		"id": "fighting",
		"name": "Fighting",
		"keywords": ["fighting", "versus", "street fighter", "tekken", "1v1", "combo"],
		"godot_nodes": ["CharacterBody2D", "AnimationPlayer", "Area2D", "ProgressBar"],
		"rules": [
			"Two fighters facing; round timer; health bars",
			"Attack / block / special with recovery frames",
			"Hitstun and knockback; round win on health 0",
		],
		"open_templates": [
			"https://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html",
		],
		"asset_queries": ["OpenGameArt fighting game sprites", "Kenney character pack"],
		"inspiration_notes": "P1 WASD+J/K, P2 arrows/numpad or simple AI opponent.",
	},
	{
		"id": "voxel",
		"name": "Voxel / Minecraft recreation",
		"keywords": ["minecraft", "voxel", "block", "minetest", "cube world", "build"],
		"godot_nodes": ["CharacterBody3D", "Camera3D", "MeshInstance3D", "GridMap", "RayCast3D"],
		"rules": [
			"First-person in a block grid world (Dictionary or 3D array of cell types)",
			"RayCast from camera to break/place cubes on mouse buttons",
			"Hotbar selects block type; simple inventory counts",
			"Generate a finite chunk of terrain (hills + flat) with MeshInstance3D boxes or MultiMesh",
		],
		"open_templates": [
			"https://github.com/Zylann/godot_voxel",
			"https://kenney.nl/assets/voxel-pack",
			"https://www.minetest.net/",
			"https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html",
		],
		"asset_queries": [
			"Kenney voxel pack CC0",
			"OpenGameArt block textures CC0",
			"Godot 4 voxel sandbox tutorial",
		],
		"inspiration_notes": "Minecraft recreation: break/place blocks in an original Godot voxel sandbox — not Mojang's game.",
	},
	{
		"id": "arena",
		"name": "Arena / Twin Stick",
		"keywords": ["arena", "twin stick", "survivor", "vampire", "horde"],
		"godot_nodes": ["CharacterBody2D", "Area2D", "Timer"],
		"rules": ["Top-down move", "Auto or aim shoot", "Spawn waves"],
		"open_templates": ["https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html"],
		"asset_queries": ["Kenney abstract pack CC0"],
		"inspiration_notes": "Survive waves, score, pickups.",
	},
]

static func list_names() -> PackedStringArray:
	var out: PackedStringArray = ["Custom / describe freely"]
	for g in GENRES:
		out.append(str(g["name"]))
	return out


static func id_at(index: int) -> String:
	if index <= 0:
		return "custom"
	var i := index - 1
	if i < 0 or i >= GENRES.size():
		return "custom"
	return str(GENRES[i]["id"])


static func by_id(genre_id: String) -> Dictionary:
	for g in GENRES:
		if str(g["id"]) == genre_id:
			return g
	return {}


static func detect(request: String, selected_id: String = "custom") -> Dictionary:
	# Famous titles (Minecraft, Doom, …) use the same pipeline via GameInspirations.
	var Insp = load("res://scripts/game_inspirations.gd")
	var inspiration: Dictionary = Insp.detect(request) if Insp else {}
	if not inspiration.is_empty():
		var g: Dictionary = by_id(str(inspiration.get("genre_id", "")))
		if g.is_empty():
			g = by_id("fps")
		g = g.duplicate(true)
		g["inspiration"] = inspiration
		g["inspiration_notes"] = str(inspiration.get("brief", g.get("inspiration_notes", "")))
		var refs: Array = inspiration.get("open_refs", [])
		if refs.size() > 0:
			g["open_templates"] = refs
		var aq: Array = g.get("asset_queries", []).duplicate()
		if inspiration.has("search_assets"):
			aq.push_front(str(inspiration.get("search_assets")))
			g["asset_queries"] = aq
		g["name"] = "%s (%s)" % [str(g.get("name", "")), str(inspiration.get("display", ""))]
		return g

	if selected_id != "custom" and not selected_id.is_empty():
		var sel := by_id(selected_id)
		if not sel.is_empty():
			return sel
	var q := request.to_lower()
	var best: Dictionary = {}
	var best_score := 0
	for g2 in GENRES:
		var score := 0
		for kw in g2["keywords"]:
			if q.contains(str(kw)):
				score += 2
		if score > best_score:
			best_score = score
			best = g2
	if best.is_empty():
		return by_id("platformer")
	return best


static func instruction_pack(genre: Dictionary, user_request: String, references: String, research: String) -> String:
	var rules := ""
	for r in genre.get("rules", []):
		rules += "- %s\n" % str(r)
	var templates := ""
	for t in genre.get("open_templates", []):
		templates += "- %s\n" % str(t)
	var assets := ""
	for a in genre.get("asset_queries", []):
		assets += "- %s\n" % str(a)
	return """GENRE: %s (%s)

USER REQUEST:
%s

GODOT 4 RULES FOR THIS GENRE:
%s
PREFERRED NODES: %s

OPEN-SOURCE TEMPLATES / DOCS TO FOLLOW (adapt patterns, do not pirate commercial games):
%s
INSPIRATION NOTES:
%s

ASSET SEARCH QUERIES (Kenney / OpenGameArt / CC0 only):
%s

LEARNED REFERENCE FILES FROM USER:
%s

WEB / AI RESEARCH:
%s

HakkoAI-style game knowledge: think about real genre feel (pacing, camera, feedback) then implement in Godot.
Cursor/agent coding style: small modular scripts, clear node paths, playable main scene.

ART TOOLS: Blender for 3D meshes/rigs/Actions → export glTF (.glb); Godot AnimationPlayer / SpriteFrames / StandardMaterial3D for playback and materials. Prefer Learn-tab .glb/.png assets when present.

LEGAL: Build recreations / spiritual remakes only. Never paste proprietary game source, ROMs, or commercial WADs.
""" % [
		str(genre.get("name", "")),
		str(genre.get("id", "")),
		user_request,
		rules,
		", ".join(PackedStringArray(genre.get("godot_nodes", []))),
		templates,
		str(genre.get("inspiration_notes", "")),
		assets,
		references if not references.is_empty() else "(none)",
		research if not research.is_empty() else "(none)",
	]
