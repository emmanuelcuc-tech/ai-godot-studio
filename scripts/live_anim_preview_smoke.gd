extends SceneTree
## Headless check: live pose preview + click-drag pull warps the image.


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

	var PosePreviewScript = load("res://scripts/editors/pose_preview.gd")
	var pose = PosePreviewScript.new()
	pose.custom_minimum_size = Vector2(320, 240)
	pose.size = Vector2(320, 240)
	root.add_child(pose)
	await process_frame

	# Load walk frames
	var frames: Array = []
	for i in 4:
		var img := Image.new()
		if img.load(demo.path_join("assets/enemy/walk_%d.png" % i)) == OK:
			frames.append(ImageTexture.create_from_image(img))
	pose.set_frames(frames, 8.0, true, true)
	await process_frame
	print("FRAMES=", pose.frames.size(), " TEX=", pose.texture != null)

	# Simulate click + pull down on the image (manipulate pose in real time).
	pose._begin_drag(Vector2(160, 80))
	pose._drag_to(Vector2(160, 140))
	pose._drag_to(Vector2(155, 170))
	pose._end_drag()
	await process_frame
	var pulls: Array = pose.get_pull_points()
	print("PULL_POINTS=", pulls.size())
	if pulls.is_empty():
		push_error("Expected pose pull points after drag")
		quit(2)
		return
	var dy: float = float(pulls[0].get("dy", 0.0))
	print("PULL_DY=", dy)
	if dy <= 0.0:
		push_error("Expected downward pull (positive dy)")
		quit(3)
		return

	# Horizontal scrub should advance frame
	var before: int = pose.frame_index
	pose._begin_drag(Vector2(160, 120))
	pose._drag_to(Vector2(160 + 30, 120))
	pose._end_drag()
	print("SCRUB_BEFORE=", before, " AFTER=", pose.frame_index)
	if pose.frame_index == before and frames.size() > 1:
		push_error("Expected frame scrub on horizontal drag")
		quit(4)
		return

	# Persist via ConfigScript
	var ConfigScript = load("res://scripts/editors/studio_game_config.gd")
	ConfigScript.set_anim_pose_pull(demo, "walk", pose.get_pull_points())
	var loaded: Dictionary = ConfigScript.load_anim(demo)
	var ok_persist := false
	for a in loaded.get("animations", []):
		if typeof(a) == TYPE_DICTIONARY and str(a.get("name", "")) == "walk":
			var pp: Variant = a.get("pose_pull", [])
			ok_persist = typeof(pp) == TYPE_ARRAY and pp.size() > 0
			break
	print("PERSIST_OK=", ok_persist)
	if not ok_persist:
		push_error("pose_pull not persisted")
		quit(5)
		return

	# Panel integration
	var PanelScript = load("res://scripts/editors/add_to_game_panel.gd")
	var panel = PanelScript.new()
	root.add_child(panel)
	await process_frame
	await process_frame
	var walk_idx := -1
	for i in panel._enemy_anim.item_count:
		if panel._enemy_anim.get_item_text(i) == "walk":
			walk_idx = i
			break
	panel._enemy_anim.select(walk_idx)
	panel._on_enemy_anim_selected(walk_idx)
	await process_frame
	print("PANEL_POSE=", panel._enemy_preview != null, " PULLS=", panel._enemy_preview.get_pull_points().size())

	print("POSE_PULL_SMOKE_OK")
	quit(0)


func _ensure_demo(root_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(root_path.path_join("assets/enemy"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("scenes"))
	_write_text(root_path.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Anim Preview Demo\"\nrun/main_scene=\"res://scenes/main.tscn\"\n")
	_write_text(root_path.path_join("scenes/main.tscn"), "[gd_scene format=3]\n[node name=\"Main\" type=\"Node2D\"]\n")
	for i in 4:
		_write_frame_png(root_path.path_join("assets/enemy/walk_%d.png" % i), Color(0.2 + i * 0.15, 0.35, 0.85))
	for i in 3:
		_write_frame_png(root_path.path_join("assets/enemy/idle_%d.png" % i), Color(0.7, 0.25 + i * 0.15, 0.85))
	_write_frame_png(root_path.path_join("assets/enemy/enemy_tex.png"), Color(0.55, 0.2, 0.2))
	var anim := {
		"mode_enabled": true,
		"animations": [
			{"name": "idle", "fps": 6.0, "loop": true, "frames": ["res://assets/enemy/idle_0.png", "res://assets/enemy/idle_1.png", "res://assets/enemy/idle_2.png"], "notes": "idle", "pose_pull": []},
			{"name": "walk", "fps": 8.0, "loop": true, "frames": ["res://assets/enemy/walk_0.png", "res://assets/enemy/walk_1.png", "res://assets/enemy/walk_2.png", "res://assets/enemy/walk_3.png"], "notes": "walk", "pose_pull": []},
			{"name": "hit", "fps": 12.0, "loop": false, "frames": [], "notes": "", "pose_pull": []},
			{"name": "death", "fps": 8.0, "loop": false, "frames": [], "notes": "", "pose_pull": []},
		],
	}
	_write_text(root_path.path_join("studio_anim.json"), JSON.stringify(anim, "\t"))
	_write_text(root_path.path_join("studio_assets.json"), JSON.stringify({"assignments": {"enemy_texture": "res://assets/enemy/enemy_tex.png", "enemy_anim": "idle"}, "physics": {}}, "\t"))
	return true


func _write_text(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(body)


func _write_frame_png(path: String, color: Color) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.09, 0.12, 1))
	for y in range(16, 48):
		for x in range(16, 48):
			img.set_pixel(x, y, color)
	img.save_png(path)
