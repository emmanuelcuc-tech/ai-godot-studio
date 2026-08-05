class_name ProjectWriter
extends RefCounted
## Writes / merges generated Godot project files; can read a project back for iteration.


static func write_project(project: Dictionary, force_path: String = "") -> Dictionary:
	if not project.get("ok", true) and not project.has("files"):
		return {"ok": false, "error": project.get("error", "Invalid project")}
	var name: String = str(project.get("project_name", "ai_game"))
	var root: String = force_path if not force_path.is_empty() else _resolve_output_root().path_join(name)
	var err: Error = _ensure_dir(root)
	if err != OK:
		return {"ok": false, "error": "Cannot create folder: %s" % root}
	var written: PackedStringArray = []
	for f in project.get("files", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var rel: String = str(f.get("path", "")).replace("\\", "/").lstrip("/")
		if rel.is_empty() or rel.contains(".."):
			continue
		var content: String = str(f.get("content", ""))
		if content.begins_with("[binary asset on disk:"):
			continue
		if content.contains("...[truncated]..."):
			continue
		var ext: String = rel.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp", "wav", "ogg", "mp3", "import", "dll", "so", "dylib", "glb", "gltf", "bin"]:
			continue
		var full: String = root.path_join(rel)
		_ensure_dir(full.get_base_dir())
		var file: FileAccess = FileAccess.open(full, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": "Cannot write %s" % full, "path": root}
		file.store_string(content)
		written.append(rel)
	var existing: PackedStringArray = _list_rel_files(root)
	for p in existing:
		if not written.has(p):
			written.append(p)
	var manifest := {
		"project_name": name,
		"summary": project.get("summary", ""),
		"howto": project.get("howto", []),
		"files": written,
		"revision": project.get("revision", 1),
		"updated_at": Time.get_datetime_string_from_system(),
	}
	var man: FileAccess = FileAccess.open(root.path_join("studio_manifest.json"), FileAccess.WRITE)
	if man:
		man.store_string(JSON.stringify(manifest, "\t"))
	var Layout = load("res://scripts/editors/game_asset_layout.gd")
	if Layout:
		Layout.ensure_layout(root)
	return {
		"ok": true,
		"path": root,
		"project_name": name,
		"files": written,
		"summary": project.get("summary", ""),
		"howto": project.get("howto", []),
		"revision": project.get("revision", 1),
	}


static func read_project_files(root: String, max_chars_each: int = 14000) -> Array:
	var files: Array = []
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return files
	for rel in _list_rel_files(root):
		if rel == "studio_manifest.json":
			continue
		var full: String = root.path_join(rel)
		var ext: String = rel.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp", "wav", "ogg", "mp3", "import", "dll", "so", "dylib", "lib", "exp", "pdb", "ilk", "obj", "o", "a"]:
			files.append({
				"path": rel,
				"content": "[binary asset on disk: %s — keep path; do not remove]" % rel,
			})
			continue
		var body: String = FileAccess.get_file_as_string(full)
		if body.length() > max_chars_each:
			body = body.left(max_chars_each) + "\n...[truncated]..."
		files.append({"path": rel, "content": body})
	return files


static func _list_rel_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_walk(root, root, out)
	return out


static func _walk(root: String, dir_path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			if n in [".godot", "godot-cpp", ".scons_cache", ".sconf_temp", "__pycache__", "build"]:
				n = d.get_next()
				continue
			_walk(root, full, out)
		else:
			var rel: String = full.substr(root.length()).lstrip("/").lstrip("\\").replace("\\", "/")
			out.append(rel)
		n = d.get_next()


static func _resolve_output_root() -> String:
	var configured: String = AppSettings.output_folder
	if configured.begins_with("user://") or configured.begins_with("res://"):
		var abs_path: String = ProjectSettings.globalize_path(configured)
		_ensure_dir(abs_path)
		return abs_path
	if configured.is_empty():
		var fallback: String = ProjectSettings.globalize_path("res://generated_games")
		_ensure_dir(fallback)
		return fallback
	_ensure_dir(configured)
	return configured


static func _ensure_dir(path: String) -> Error:
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)


static func open_in_godot(project_path: String) -> Error:
	var exe: String = AppSettings.godot_executable
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return ERR_FILE_NOT_FOUND
	return OS.create_process(exe, PackedStringArray(["--path", project_path, "-e"]))


static func run_project(project_path: String) -> Error:
	var exe: String = AppSettings.godot_executable
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return ERR_FILE_NOT_FOUND
	return OS.create_process(exe, PackedStringArray(["--path", project_path]))
