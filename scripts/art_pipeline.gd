class_name ArtPipeline
extends RefCounted
## Blender + Godot tools for animation, materials, textures, sprites.


static func godot_tools_guide() -> String:
	return """# Godot tools — animation, materials, textures, sprites

## Animation
- **AnimationPlayer**: keyframe properties (position, rotation, modulate, sprite frame)
- **AnimationTree** + AnimationNodeStateMachine: idle/walk/attack blends
- **SpriteFrames** (Sprite2D / AnimatedSprite2D): 2D frame animations from sprite sheets
- Import **glTF** with animations → AnimationPlayer auto-created on the scene

## Materials / textures
- **StandardMaterial3D** / **ORMMaterial3D**: albedo, roughness, metallic, emission, normal
- Assign textures on material slots; use imported PNG/JPG/WebP
- **CanvasItemMaterial** / shaders for 2D sprites
- **ShaderMaterial** + `.gdshader` for custom looks

## Sprites
- Sprite2D / AnimatedSprite2D / TextureRect
- AtlasTexture for sheets; set region rects
- Learn-tab PNGs → copy to `assets/` and reference in scenes

## Recommended import
Prefer **glTF 2.0 (.glb/.gltf)** from Blender into Godot (meshes + materials + animations).
"""


static func blender_export_guide() -> String:
	return """# Blender → Godot pipeline

## Install
1. Install Blender: https://www.blender.org/download/
2. Set Blender path in Studio Settings (or rely on auto-detect)
3. Use **Open Blender** from the Learn / Create tools row

## Model & animate in Blender
1. Model mesh; UV unwrap; paint or assign Principled BSDF textures
2. Rig with Armature; create Actions (idle, walk, attack)
3. Name actions clearly (Godot keeps action names as AnimationPlayer clips)

## Export (best path)
File → Export → **glTF 2.0 (.glb)**
- Include: Meshes, Materials, Animations, Skinning
- Transform: +Y Up
- Remember: Godot imports .glb/.gltf natively

## Optional
- FBX works but glTF is preferred for Godot 4
- Keep texture files next to export or embed in .glb
- For 2D: export spritesheets / PNGs; use Godot SpriteFrames

## Then in this Studio
1. Drop `.glb` / `.gltf` / `.png` into **Learn**
2. **Apply changes** — AI wires AnimationPlayer / materials into your game
3. Or copy assets into `generated_games/<project>/assets/` and reference paths
"""


static func pipeline_prompt_block() -> String:
	return """ART / ANIMATION TOOLCHAIN (use these):
- Blender for 3D meshes, rigs, Actions → export glTF 2.0 (.glb) for Godot
- Godot AnimationPlayer / AnimationTree / SpriteFrames for playback
- Godot StandardMaterial3D + imported textures; optional .gdshader
- Sprites: PNG/WebP → Sprite2D / AnimatedSprite2D / AtlasTexture
- When user provides .glb/.gltf/.fbx from Learn, reference those paths under assets/
- Write docs/BLENDER_GODOT.md into the project with export steps when 3D anim is needed
- Prefer procedural materials if no mesh yet; leave clear TODOs to swap glTF later
"""


static func write_guides_into_files(files: Array) -> Array:
	var by: Dictionary = {}
	for f in files:
		if typeof(f) == TYPE_DICTIONARY:
			by[str(f.get("path", ""))] = f
	_put(files, by, "docs/GODOT_ART_TOOLS.md", godot_tools_guide())
	_put(files, by, "docs/BLENDER_GODOT.md", blender_export_guide())
	return files


static func _put(files: Array, by: Dictionary, path: String, content: String) -> void:
	if by.has(path):
		by[path]["content"] = content
	else:
		var f: Dictionary = {"path": path, "content": content}
		files.append(f)
		by[path] = f


static func guess_blender_path() -> String:
	var candidates: PackedStringArray = [
		"C:/Program Files/Blender Foundation/Blender 4.4/blender.exe",
		"C:/Program Files/Blender Foundation/Blender 4.3/blender.exe",
		"C:/Program Files/Blender Foundation/Blender 4.2/blender.exe",
		"C:/Program Files/Blender Foundation/Blender 4.1/blender.exe",
		"C:/Program Files/Blender Foundation/Blender 4.0/blender.exe",
		"C:/Program Files/Blender Foundation/Blender 3.6/blender.exe",
		"C:/Program Files (x86)/Blender Foundation/Blender/blender.exe",
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	# Scan Blender Foundation folder
	var base := "C:/Program Files/Blender Foundation"
	var d := DirAccess.open(base)
	if d:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if d.current_is_dir() and n.begins_with("Blender"):
				var exe := base.path_join(n).path_join("blender.exe")
				if FileAccess.file_exists(exe):
					return exe
			n = d.get_next()
	return ""


static func open_blender(exe_path: String) -> Error:
	var exe := exe_path
	if exe.is_empty() or not FileAccess.file_exists(exe):
		exe = guess_blender_path()
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return ERR_FILE_NOT_FOUND
	return OS.create_process(exe, PackedStringArray())


static func run_python(exe_path: String, script_path: String, extra_args: PackedStringArray = PackedStringArray()) -> int:
	var exe := exe_path
	if exe.is_empty() or not FileAccess.file_exists(exe):
		exe = guess_blender_path()
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(script_path):
		return ERR_FILE_NOT_FOUND
	var args := PackedStringArray(["--background", "--python", script_path, "--"])
	args.append_array(extra_args)
	var output: Array = []
	return OS.execute(exe, args, output, true, false)


static func open_blender_docs() -> void:
	OS.shell_open("https://docs.blender.org/manual/en/latest/")
	OS.shell_open("https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html")
