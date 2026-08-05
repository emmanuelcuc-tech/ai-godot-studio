class_name ResourceCatalog
extends RefCounted
## Genre-matched CC0 texture queries, Kenney kit links, AssetLib terms, and open Godot refs.
## Legal: CC0 / MIT / Apache / BSD / Unlicense only — never commercial ROMs, WADs, or ripped art.

const IMAGE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

const RIP_MARKERS: PackedStringArray = [
	"commercial rom", "pirated", "cracked rom", "nintendo rom", "doom wad",
	"iwad", "pwad", "pk3 rip", "iso dump", "game dump", "ripped sprites",
]


static func is_image_filename(name: String) -> bool:
	var ext: String = name.get_extension().to_lower()
	return IMAGE_EXTS.has(ext)


static func looks_like_rip(text: String) -> bool:
	var q: String = text.to_lower()
	for marker in RIP_MARKERS:
		if q.contains(marker):
			return true
	return false


static func license_ok_for_install(license: String) -> bool:
	var lic: String = license.to_lower().strip_edges()
	if lic.is_empty():
		return false
	if lic.contains("gpl") and not lic.contains("mit"):
		return false
	for ok in ["cc0", "pdm", "public domain", "unlicense", "mit", "apache", "bsd", "isc", "zlib", "wtfpl"]:
		if lic.contains(ok):
			return true
	return false


static func texture_jobs(genre_id: String, description: String) -> Array:
	var jobs: Array = []
	var desc: String = description.to_lower()
	var subject: String = _subject_from_description(desc)
	match genre_id:
		"fps", "tps":
			jobs = [
				{"filename": "wall.png", "query": "%s brick wall seamless texture CC0" % subject, "usage": "corridor / room walls"},
				{"filename": "floor.png", "query": "%s concrete floor seamless texture CC0" % subject, "usage": "floors"},
				{"filename": "ceiling.png", "query": "dark metal ceiling seamless texture CC0", "usage": "ceilings"},
				{"filename": "sky.png", "query": "stormy industrial sky CC0", "usage": "sky / backdrop"},
				{"filename": "sprite_enemy.png", "query": "pixel monster enemy sprite CC0 game", "usage": "enemy billboard / sprite"},
				{"filename": "sprite_pickup.png", "query": "pixel health pack icon sprite CC0", "usage": "pickup sprite"},
			]
		"platformer":
			jobs = [
				{"filename": "ground.png", "query": "pixel grass dirt ground tileset CC0", "usage": "platforms / ground"},
				{"filename": "sky.png", "query": "pixel blue sky clouds background CC0", "usage": "backdrop"},
				{"filename": "sprite_player.png", "query": "pixel platformer hero character sprite CC0", "usage": "player sprite"},
				{"filename": "sprite_enemy.png", "query": "pixel slime enemy sprite CC0", "usage": "enemy sprite"},
				{"filename": "sprite_coin.png", "query": "pixel coin collectible sprite CC0", "usage": "collectible"},
				{"filename": "wall.png", "query": "pixel brick tileset platformer CC0", "usage": "solid tiles"},
			]
		"space_shooter":
			jobs = [
				{"filename": "sky.png", "query": "space starfield texture CC0", "usage": "starfield background"},
				{"filename": "sprite_player.png", "query": "pixel spaceship top down sprite CC0", "usage": "player ship"},
				{"filename": "sprite_enemy.png", "query": "pixel alien spaceship sprite CC0", "usage": "enemy ship"},
				{"filename": "sprite_bullet.png", "query": "pixel laser bullet sprite CC0", "usage": "projectiles"},
				{"filename": "wall.png", "query": "asteroid rock texture CC0", "usage": "hazards / rocks"},
			]
		"racing":
			jobs = [
				{"filename": "floor.png", "query": "asphalt road texture seamless CC0", "usage": "track surface"},
				{"filename": "wall.png", "query": "race barrier concrete texture CC0", "usage": "barriers"},
				{"filename": "sky.png", "query": "clear sky texture CC0", "usage": "skybox"},
				{"filename": "grass.png", "query": "grass texture seamless CC0", "usage": "off-track"},
				{"filename": "sprite_player.png", "query": "pixel race car top down sprite CC0", "usage": "player vehicle"},
			]
		"voxel":
			jobs = [
				{"filename": "grass.png", "query": "minecraft style grass block top texture CC0", "usage": "grass blocks"},
				{"filename": "dirt.png", "query": "dirt block texture seamless CC0", "usage": "dirt blocks"},
				{"filename": "stone.png", "query": "stone block texture seamless CC0", "usage": "stone blocks"},
				{"filename": "sky.png", "query": "bright blue sky clouds CC0", "usage": "sky"},
				{"filename": "wall.png", "query": "wood plank block texture CC0", "usage": "wood blocks"},
				{"filename": "floor.png", "query": "grass dirt ground texture CC0", "usage": "ground"},
			]
		"beat_em_up", "fighting":
			jobs = [
				{"filename": "background.png", "query": "pixel city street side view background CC0", "usage": "stage backdrop"},
				{"filename": "floor.png", "query": "pixel sidewalk pavement texture CC0", "usage": "ground plane"},
				{"filename": "sprite_player.png", "query": "pixel brawler fighter sprite CC0", "usage": "player"},
				{"filename": "sprite_enemy.png", "query": "pixel thug enemy sprite CC0", "usage": "enemy"},
				{"filename": "wall.png", "query": "pixel brick wall texture CC0", "usage": "stage walls"},
			]
		"open_world", "simulation":
			jobs = [
				{"filename": "grass.png", "query": "grass terrain texture seamless CC0", "usage": "ground"},
				{"filename": "dirt.png", "query": "dirt path texture seamless CC0", "usage": "paths"},
				{"filename": "sky.png", "query": "daytime sky texture CC0", "usage": "sky"},
				{"filename": "wall.png", "query": "wood house wall texture CC0", "usage": "buildings"},
				{"filename": "sprite_player.png", "query": "pixel rpg character sprite CC0", "usage": "player / NPC"},
				{"filename": "floor.png", "query": "stone tile floor texture CC0", "usage": "interiors"},
			]
		_:
			jobs = [
				{"filename": "wall.png", "query": "game texture seamless CC0 %s" % subject, "usage": "primary texture"},
				{"filename": "floor.png", "query": "ground texture seamless CC0", "usage": "ground"},
				{"filename": "sky.png", "query": "sky background CC0", "usage": "background"},
				{"filename": "sprite_player.png", "query": "pixel game character sprite CC0", "usage": "player sprite"},
				{"filename": "sprite_enemy.png", "query": "pixel game enemy sprite CC0", "usage": "enemy sprite"},
			]
	if desc.contains("lava") or desc.contains("hell"):
		jobs.append({"filename": "lava.png", "query": "lava rock seamless texture CC0", "usage": "hazard / hell floor"})
	if desc.contains("snow") or desc.contains("ice"):
		jobs.append({"filename": "snow.png", "query": "snow ice seamless texture CC0", "usage": "snow terrain"})
	if desc.contains("water") or desc.contains("ocean"):
		jobs.append({"filename": "water.png", "query": "water surface texture CC0", "usage": "water"})
	var Layout = load("res://scripts/editors/game_asset_layout.gd")
	for i in jobs.size():
		if typeof(jobs[i]) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = jobs[i]
		if str(job.get("category", "")).is_empty():
			job["category"] = Layout.categorize(str(job.get("filename", "")), str(job.get("query", "")), str(job.get("usage", "")))
			jobs[i] = job
	return jobs


static func kenney_links(genre_id: String) -> Array:
	var common: Array = [
		{"title": "Kenney Prototype Textures", "url": "https://kenney.nl/assets/prototype-textures", "license": "CC0", "note": "Seamless debug/prototype PBR-style textures"},
		{"title": "Kenney Input Prompts", "url": "https://kenney.nl/assets/input-prompts", "license": "CC0", "note": "UI button prompts"},
	]
	var extra: Array = []
	match genre_id:
		"fps", "tps":
			extra = [
				{"title": "Kenney FPS Starter Kit (Godot, MIT + CC0 art)", "url": "https://github.com/KenneyNL/Starter-Kit-FPS", "license": "MIT/CC0", "note": "Open Godot 4 FPS template"},
				{"title": "Kenney Modular Dungeon Kit", "url": "https://kenney.nl/assets/modular-dungeon-kit", "license": "CC0", "note": "Dungeon meshes / kits"},
			]
		"platformer":
			extra = [
				{"title": "Kenney Platformer Kit", "url": "https://kenney.nl/assets/platformer-kit", "license": "CC0", "note": "3D platformer kit"},
				{"title": "Kenney New Platformer Pack", "url": "https://kenney.nl/assets/new-platformer-pack", "license": "CC0", "note": "2D platformer sprites"},
				{"title": "Kenney 3D Platformer Starter", "url": "https://github.com/KenneyNL/Starter-Kit-3D-Platformer", "license": "MIT/CC0", "note": "Open Godot starter"},
			]
		"space_shooter":
			extra = [
				{"title": "Kenney Space Shooter Redux", "url": "https://kenney.nl/assets/space-shooter-redux", "license": "CC0", "note": "Classic shmup sprites"},
			]
		"racing":
			extra = [
				{"title": "Kenney Racing Kit", "url": "https://kenney.nl/assets/racing-kit", "license": "CC0", "note": "Low-poly race meshes"},
				{"title": "Kenney Racing Starter", "url": "https://github.com/KenneyNL/Starter-Kit-Racing", "license": "MIT/CC0", "note": "Open Godot racing starter"},
			]
		"voxel":
			extra = [
				{"title": "Kenney Voxel Pack", "url": "https://kenney.nl/assets/voxel-pack", "license": "CC0", "note": "Blocky voxel textures/models"},
			]
		"open_world", "simulation":
			extra = [
				{"title": "Kenney Nature Kit", "url": "https://kenney.nl/assets/nature-kit", "license": "CC0", "note": "Trees / terrain kits"},
				{"title": "Kenney UI Pack", "url": "https://kenney.nl/assets/ui-pack", "license": "CC0", "note": "UI chrome"},
			]
		"beat_em_up", "fighting", "arena":
			extra = [
				{"title": "Kenney Tiny Dungeon", "url": "https://kenney.nl/assets/tiny-dungeon", "license": "CC0", "note": "Tiny character sprites"},
				{"title": "Kenney Abstract Platformer", "url": "https://kenney.nl/assets/abstract-platformer", "license": "CC0", "note": "Simple geometric sprites"},
			]
	return common + extra


static func assetlib_queries(genre_id: String) -> PackedStringArray:
	match genre_id:
		"fps", "tps":
			return PackedStringArray(["fps controller", "first person", "hitscan"])
		"platformer":
			return PackedStringArray(["platformer", "coyote jump"])
		"space_shooter":
			return PackedStringArray(["space shooter", "shmup"])
		"racing":
			return PackedStringArray(["vehicle", "racing"])
		"voxel":
			return PackedStringArray(["voxel", "gridmap"])
		"beat_em_up":
			return PackedStringArray(["beat em up", "brawler"])
		"fighting":
			return PackedStringArray(["fighting", "hitbox"])
		"open_world":
			return PackedStringArray(["exploration", "third person controller"])
		"simulation":
			return PackedStringArray(["inventory", "ui toolkit"])
		_:
			return PackedStringArray(["controller", "godot 4 addon"])


static func open_refs(genre_id: String) -> Array:
	## Small MIT/CC0 Godot 4 samples. Prefer raw README + scripts over huge zips.
	match genre_id:
		"fps", "tps":
			return [{
				"id": "kenney_fps",
				"title": "Kenney Starter Kit FPS",
				"license": "MIT (code) / CC0 (art)",
				"repo": "KenneyNL/Starter-Kit-FPS",
				"branch": "main",
				"page": "https://github.com/KenneyNL/Starter-Kit-FPS",
				"files": [
					"README.md",
					"scripts/player.gd",
					"scripts/enemy.gd",
					"scripts/weapon.gd",
					"scripts/hud.gd",
				],
			}]
		"platformer":
			return [{
				"id": "godot_2d_dodge",
				"title": "Godot Dodge the Creeps (official demo patterns)",
				"license": "MIT",
				"repo": "godotengine/godot-demo-projects",
				"branch": "master",
				"page": "https://github.com/godotengine/godot-demo-projects/tree/master/2d/dodge_the_creeps",
				"files": [
					"2d/dodge_the_creeps/README.md",
					"2d/dodge_the_creeps/player.gd",
					"2d/dodge_the_creeps/mob.gd",
					"2d/dodge_the_creeps/main.gd",
					"2d/dodge_the_creeps/hud.gd",
				],
			}, {
				"id": "kenney_3d_platformer",
				"title": "Kenney Starter Kit 3D Platformer",
				"license": "MIT/CC0",
				"repo": "KenneyNL/Starter-Kit-3D-Platformer",
				"branch": "main",
				"page": "https://github.com/KenneyNL/Starter-Kit-3D-Platformer",
				"files": ["README.md", "scripts/player.gd"],
			}]
		"space_shooter", "arena":
			return [{
				"id": "godot_first_2d",
				"title": "Godot Your First 2D Game patterns (demo project)",
				"license": "MIT",
				"repo": "godotengine/godot-demo-projects",
				"branch": "master",
				"page": "https://github.com/godotengine/godot-demo-projects/tree/master/2d/dodge_the_creeps",
				"files": [
					"2d/dodge_the_creeps/README.md",
					"2d/dodge_the_creeps/player.gd",
					"2d/dodge_the_creeps/mob.gd",
					"2d/dodge_the_creeps/main.gd",
				],
			}]
		"racing":
			return [{
				"id": "kenney_racing",
				"title": "Kenney Starter Kit Racing",
				"license": "MIT/CC0",
				"repo": "KenneyNL/Starter-Kit-Racing",
				"branch": "main",
				"page": "https://github.com/KenneyNL/Starter-Kit-Racing",
				"files": ["README.md"],
			}]
		"beat_em_up":
			return [{
				"id": "quiver_brawler",
				"title": "Quiver Beat-em-up template",
				"license": "MIT (verify in repo)",
				"repo": "quiver-dev/template-beat-em-up",
				"branch": "main",
				"page": "https://github.com/quiver-dev/template-beat-em-up",
				"files": ["README.md"],
			}]
		"voxel":
			return [{
				"id": "godot_3d_intro",
				"title": "Godot 3D voxels / GridMap demo notes",
				"license": "MIT",
				"repo": "godotengine/godot-demo-projects",
				"branch": "master",
				"page": "https://github.com/godotengine/godot-demo-projects/tree/master/3d/gridmap",
				"files": [
					"3d/gridmap/README.md",
					"3d/gridmap/grid_map.gd",
				],
			}]
		_:
			return [{
				"id": "godot_2d_dodge",
				"title": "Godot Dodge the Creeps",
				"license": "MIT",
				"repo": "godotengine/godot-demo-projects",
				"branch": "master",
				"page": "https://github.com/godotengine/godot-demo-projects/tree/master/2d/dodge_the_creeps",
				"files": [
					"2d/dodge_the_creeps/README.md",
					"2d/dodge_the_creeps/player.gd",
					"2d/dodge_the_creeps/main.gd",
				],
			}]


static func sanitize_filename(name: String) -> String:
	var base: String = name.get_file().strip_edges().to_lower().replace(" ", "_")
	base = base.validate_filename()
	if base.is_empty():
		return "asset.png"
	if not is_image_filename(base):
		base = base.get_basename() + ".png"
	return base


static func _subject_from_description(desc: String) -> String:
	for word in ["brick", "stone", "metal", "wood", "concrete", "dirt", "grass", "rust", "hell", "sci-fi", "scifi", "space", "ice", "lava"]:
		if desc.contains(word):
			return word
	return "industrial"
