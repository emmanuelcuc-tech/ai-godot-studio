class_name OfflineEnhancer
extends RefCounted
## When no API keys: apply keyword-driven upgrades to the current project files.

const ArtPipelineScript = preload("res://scripts/art_pipeline.gd")
const StudioGameConfigScript = preload("res://scripts/editors/studio_game_config.gd")


static func apply(files: Array, direction: String, genre_id: String) -> Array:
	var q := direction.to_lower()
	var out: Array = files.duplicate(true)
	var by_path := {}
	for f in out:
		if typeof(f) == TYPE_DICTIONARY:
			by_path[str(f.get("path", ""))] = f

	# Always stamp iteration note
	var log_path := "ITERATION_LOG.md"
	var prev := ""
	if by_path.has(log_path):
		prev = str(by_path[log_path].get("content", ""))
	var entry := "\n## %s\nUser: %s\nGenre: %s\n" % [
		Time.get_datetime_string_from_system(), direction.left(500), genre_id
	]
	_upsert(out, by_path, log_path, prev + entry)

	if q.contains("menu") or q.contains("title") or q.contains("ui"):
		_add_simple_menu(out, by_path)

	if genre_id == "voxel" or q.contains("minecraft") or q.contains("particle") or q.contains("break"):
		_ensure_voxel_break_fx_hint(out, by_path, q)

	if q.contains("shader") or q.contains("glow") or q.contains("outline"):
		_add_simple_shader(out, by_path)

	if q.contains("anim") or q.contains("blender") or q.contains("gltf") or q.contains("material") or q.contains("sprite") or q.contains("texture") or q.contains("brick") or q.contains("wall"):
		_upsert(out, by_path, "docs/ANIMATION_NOTES.md",
			"# Animation & art notes\nUse Blender → glTF (.glb) → Godot AnimationPlayer when available.\nElse shooter fallback: camera walk-bob + muzzle/impact GPUParticles3D.\nSprites: SpriteFrames / AtlasTexture.\nMaterials: StandardMaterial3D + assets/wall.png from Asset Browser.\nUser asked: %s\n" % direction.left(300))

	if q.contains("brick") or q.contains("wall") or q.contains("texture") or q.contains("material"):
		_upsert(out, by_path, "docs/TEXTURE_NOTES.md",
			"# Texture / material\nCopy selected browser image to assets/wall.png.\nAssign StandardMaterial3D.albedo_texture on walls/floors.\nSources: Openverse CC0, Wikimedia Commons, Kenney — not commercial game rips.\nUser: %s\n" % direction.left(300))

	if genre_id == "fps" or q.contains("shoot") or q.contains("bullet") or q.contains("muzzle"):
		_upsert(out, by_path, "docs/SHOOTER_FX.md",
			"# Shooter FX\n- Walk bob animation\n- GPUParticles3D muzzle + impact\n- RigidBody3D debris (real physics)\n- Godot CharacterBody3D + RayCast hitscan\nUser: %s\n" % direction.left(200))

	if q.contains("physic") or q.contains("rigid"):
		_upsert(out, by_path, "docs/PHYSICS_NOTES.md",
			"# Physics\nPrefer RigidBody3D debris on break; CharacterBody3D for player.\nUser asked: %s\n" % direction.left(300))

	# Always include Blender + Godot art tool guides
	out = ArtPipelineScript.write_guides_into_files(out)
	out = StudioGameConfigScript.inject_into_files(out)

	return out


static func _upsert(out: Array, by_path: Dictionary, path: String, content: String) -> void:
	if by_path.has(path):
		by_path[path]["content"] = content
	else:
		var f := {"path": path, "content": content}
		out.append(f)
		by_path[path] = f


static func _add_simple_menu(out: Array, by_path: Dictionary) -> void:
	var menu_gd := """extends Control
func _ready() -> void:
	$VBox/Play.pressed.connect(func(): get_tree().change_scene_to_file(\"res://scenes/main.tscn\"))
	$VBox/Quit.pressed.connect(func(): get_tree().quit())
	if FileAccess.file_exists(\"res://studio_display.json\"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(\"res://studio_display.json\"))
		if typeof(d) == TYPE_DICTIONARY:
			var p: String = str(d.get(\"menu_background\", \"\"))
			if not p.is_empty() and (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
				var tex = load(p)
				if tex is Texture2D:
					var tr := TextureRect.new()
					tr.set_anchors_preset(Control.PRESET_FULL_RECT)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					tr.texture = tex
					tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
					add_child(tr)
					move_child(tr, 0)
"""
	var menu_tscn := """[gd_scene load_steps=2 format=3]
[ext_resource type=\"Script\" path=\"res://scripts/menu.gd\" id=\"1\"]
[node name=\"Menu\" type=\"Control\"]
layout_mode=3
anchors_preset=15
anchor_right=1
anchor_bottom=1
script=ExtResource(\"1\")
[node name=\"BG\" type=\"ColorRect\" parent=\".\"]
layout_mode=1
anchors_preset=15
anchor_right=1
anchor_bottom=1
color=Color(0.05,0.07,0.1,1)
[node name=\"VBox\" type=\"VBoxContainer\" parent=\".\"]
layout_mode=1
anchors_preset=8
anchor_left=0.5
anchor_top=0.5
anchor_right=0.5
anchor_bottom=0.5
offset_left=-120.0
offset_top=-80.0
offset_right=120.0
offset_bottom=80.0
[node name=\"Title\" type=\"Label\" parent=\"VBox\"]
layout_mode=2
theme_override_font_sizes/font_size=28
text=\"GAME\"
horizontal_alignment=1
[node name=\"Play\" type=\"Button\" parent=\"VBox\"]
layout_mode=2
text=\"Play\"
[node name=\"Quit\" type=\"Button\" parent=\"VBox\"]
layout_mode=2
text=\"Quit\"
"""
	_upsert(out, by_path, "scripts/menu.gd", menu_gd)
	_upsert(out, by_path, "scenes/menu.tscn", menu_tscn)
	if by_path.has("project.godot"):
		var pg: String = str(by_path["project.godot"].get("content", ""))
		if pg.contains("run/main_scene="):
			pg = pg.replace("run/main_scene=\"res://scenes/main.tscn\"", "run/main_scene=\"res://scenes/menu.tscn\"")
		else:
			pg += "\nrun/main_scene=\"res://scenes/menu.tscn\"\n"
		by_path["project.godot"]["content"] = pg


static func _add_simple_shader(out: Array, by_path: Dictionary) -> void:
	var shader := """shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.3, 0.9, 0.5, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c + glow_color * 0.15 * c.a;
}
"""
	_upsert(out, by_path, "shaders/soft_glow.gdshader", shader)
	_upsert(out, by_path, "docs/SHADER_NOTES.md",
		"# Shader\nAttached soft_glow.gdshader for UI/sprites. Assign ShaderMaterial in editor or code.\n")


static func _ensure_voxel_break_fx_hint(out: Array, by_path: Dictionary, q: String) -> void:
	_upsert(out, by_path, "docs/BREAK_FX.md",
		"# Block break FX\nUse GPUParticles3D burst + optional RigidBody3D chips on break.\\nUser direction: %s\\n" % q.left(200))
