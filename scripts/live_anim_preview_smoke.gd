extends SceneTree
## Headless check: picking an anim clip loads frames and replaces the preview texture.
## Creates a tiny demo project under generated_games/anim_preview_demo if needed.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var orch = root.get_node_or_null("AIOrchestrator")
	if orch == null:
		push_error("AIOrchestrator autoload missing")
		quit(1)
		return

	var demo: String = ProjectSettings.globalize_path("res://generated_games/anim_preview_demo")
	if not _ensure_demo(demo):
		push_error("Could not create demo project")
		quit(1)
		return

	orch.session.start(demo, "anim_preview_demo", "fps")
	print("SESSION=", orch.has_active_session(), " PATH=", orch.get_project_path())

	var PanelScript = load("res://scripts/editors/add_to_game_panel.gd")
	var panel = PanelScript.new()
	root.add_child(panel)
	await process_frame
	await process_frame

	var walk_idx: int = -1
	for i in panel._enemy_anim.item_count:
		if panel._enemy_anim.get_item_text(i) == "walk":
			walk_idx = i
			break
	print("WALK_IDX=", walk_idx, " CLIP_COUNT=", panel._enemy_anim.item_count)
	if walk_idx < 0:
		push_error("walk clip missing from enemy anim list")
		quit(2)
		return
	panel._enemy_anim.select(walk_idx)
	panel._on_enemy_anim_selected(walk_idx)
	await process_frame

	print("LIVE_ACTIVE=", panel._live_active)
	print("LIVE_FRAMES=", panel._live_frames.size())
	print("LIVE_FPS=", panel._live_fps)
	print("PREVIEW_SET=", panel._enemy_preview.texture != null)

	if not panel._live_active or panel._live_frames.size() < 2 or panel._enemy_preview.texture == null:
		push_error("Live walk preview failed")
		quit(3)
		return

	var first_tex = panel._enemy_preview.texture
	panel._process(0.13)
	panel._process(0.13)
	var later_tex = panel._enemy_preview.texture
	print("LIVE_I=", panel._live_i, " TEXTURE_CHANGED=", first_tex != later_tex)
	if first_tex == later_tex:
		push_error("Preview texture did not advance during live playback")
		quit(4)
		return

	var idle_idx: int = 0
	for i in panel._enemy_anim.item_count:
		if panel._enemy_anim.get_item_text(i) == "idle":
			idle_idx = i
			break
	panel._enemy_anim.select(idle_idx)
	panel._on_enemy_anim_selected(idle_idx)
	await process_frame
	print("IDLE_FRAMES=", panel._live_frames.size(), " IDLE_ACTIVE=", panel._live_active)
	if panel._live_frames.size() < 2:
		push_error("Idle live preview missing frames")
		quit(5)
		return

	var AnimUI = load("res://scripts/editors/animation_editor_ui.gd")
	var anim_ui = AnimUI.new()
	root.add_child(anim_ui)
	await process_frame
	await process_frame
	var found_walk: bool = false
	for i in anim_ui._list.item_count:
		if anim_ui._list.get_item_text(i).begins_with("walk"):
			anim_ui._list.select(i)
			anim_ui._on_select(i)
			found_walk = true
			break
	print("ANIM_UI_WALK=", found_walk, " FRAMES=", anim_ui._live_frames.size(), " ACTIVE=", anim_ui._live_active, " PREVIEW=", anim_ui._preview.texture != null)
	if not found_walk or anim_ui._live_frames.size() < 2 or anim_ui._preview.texture == null:
		push_error("Animation editor live preview failed")
		quit(6)
		return

	print("LIVE_ANIM_PREVIEW_SMOKE_OK")
	quit(0)


func _ensure_demo(root_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(root_path.path_join("assets/enemy"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("assets/sprites"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("scenes"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("scripts"))
	_write_text(root_path.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Anim Preview Demo\"\nrun/main_scene=\"res://scenes/main.tscn\"\n")
	_write_text(root_path.path_join("scenes/main.tscn"), "[gd_scene format=3]\n[node name=\"Main\" type=\"Node2D\"]\n")
	for i in 4:
		_write_frame_png(root_path.path_join("assets/enemy/walk_%d.png" % i), Color(0.2 + i * 0.15, 0.35, 0.85), "w%d" % i)
	for i in 3:
		_write_frame_png(root_path.path_join("assets/enemy/idle_%d.png" % i), Color(0.7, 0.25 + i * 0.15, 0.85), "i%d" % i)
	_write_frame_png(root_path.path_join("assets/enemy/enemy_tex.png"), Color(0.55, 0.2, 0.2), "E")
	var anim := {
		"mode_enabled": true,
		"animations": [
			{"name": "idle", "fps": 6.0, "loop": true, "frames": ["res://assets/enemy/idle_0.png", "res://assets/enemy/idle_1.png", "res://assets/enemy/idle_2.png"], "notes": "idle"},
			{"name": "walk", "fps": 8.0, "loop": true, "frames": ["res://assets/enemy/walk_0.png", "res://assets/enemy/walk_1.png", "res://assets/enemy/walk_2.png", "res://assets/enemy/walk_3.png"], "notes": "walk"},
			{"name": "hit", "fps": 12.0, "loop": false, "frames": [], "notes": ""},
			{"name": "death", "fps": 8.0, "loop": false, "frames": [], "notes": ""},
		],
	}
	_write_text(root_path.path_join("studio_anim.json"), JSON.stringify(anim, "\t"))
	var assets := {"assignments": {"enemy_texture": "res://assets/enemy/enemy_tex.png", "enemy_anim": "idle"}, "physics": {}}
	_write_text(root_path.path_join("studio_assets.json"), JSON.stringify(assets, "\t"))
	return true


func _write_text(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(body)


func _write_frame_png(path: String, color: Color, _label: String) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.09, 0.12, 1))
	for y in range(16, 48):
		for x in range(16, 48):
			img.set_pixel(x, y, color)
	img.save_png(path)
