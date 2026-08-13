extends RefCounted
class_name ScratchDrive
## Temporary scratch "drive" for unsaved stems / probe / mix work files.
## Prefer F:\AudioStemStudioTemp when writable; else %TEMP% or project .scratch.
## Cleared on start and on exit (saved exports live outside this folder).


static func resolve_root() -> String:
	var preferred := "F:/AudioStemStudioTemp"
	if _drive_usable("F:/"):
		if _ensure_dir(preferred):
			return preferred.replace("/", "\\")
	var temp_base := OS.get_environment("TEMP")
	if temp_base == "":
		temp_base = OS.get_environment("TMP")
	if temp_base != "":
		var temp_scratch := temp_base.path_join("AudioStemStudioScratch")
		if _ensure_dir(temp_scratch):
			return temp_scratch
	var project_scratch := ProjectSettings.globalize_path("res://.scratch")
	_ensure_dir(project_scratch)
	return project_scratch


static func clear_contents(root: String) -> void:
	if root == "" or not DirAccess.dir_exists_absolute(root):
		return
	# Safety: never wipe a drive root or known app install folder.
	var norm := root.replace("\\", "/").rstrip("/")
	var lower := norm.to_lower()
	if lower.length() <= 3:
		return
	if lower.ends_with("/audiostemstudio") and not lower.ends_with("/audiostemstudiotemp"):
		return
	_remove_children(root)


## Wipe active scratch + known leftover session roots from older builds.
## Keeps preferred/active roots; never touches F:/AudioStemStudio (install) or templates.
static func clear_previous_sessions(active_root: String = "") -> void:
	var roots: Array[String] = []
	if active_root != "":
		roots.append(active_root)
	roots.append("F:/AudioStemStudioTemp")
	var temp_base := OS.get_environment("TEMP")
	if temp_base == "":
		temp_base = OS.get_environment("TMP")
	if temp_base != "":
		roots.append(temp_base.path_join("AudioStemStudioScratch"))
		_clear_temp_prefix_matches(temp_base, "AudioStemStudio")
	var project_scratch := ProjectSettings.globalize_path("res://.scratch")
	roots.append(project_scratch)
	# Pre-scratch work_dir lived under Godot user data.
	roots.append(OS.get_user_data_dir().path_join("audio_stem_studio"))
	var seen: Dictionary = {}
	for r in roots:
		var key := r.replace("\\", "/").to_lower()
		if seen.has(key):
			continue
		seen[key] = true
		clear_contents(r)
	# Recreate only the active scratch root (and F: preferred when that is active).
	if active_root != "":
		_ensure_dir(active_root)
	elif _drive_usable("F:/"):
		_ensure_dir("F:/AudioStemStudioTemp")


static func _drive_usable(root: String) -> bool:
	var d := DirAccess.open(root)
	if d == null:
		return false
	# Probe write via the intended temp folder (not the drive root itself).
	var probe_parent := root.path_join("AudioStemStudioTemp")
	var probe := probe_parent.path_join(".write_probe")
	var err := DirAccess.make_dir_recursive_absolute(probe)
	if err != OK and not DirAccess.dir_exists_absolute(probe):
		return false
	DirAccess.remove_absolute(probe)
	return true


static func _ensure_dir(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK


static func _clear_temp_prefix_matches(temp_base: String, prefix: String) -> void:
	var d := DirAccess.open(temp_base)
	if d == null:
		return
	var matches: Array[String] = []
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name != "." and name != ".." and name.begins_with(prefix):
			matches.append(temp_base.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	for child in matches:
		if DirAccess.dir_exists_absolute(child):
			clear_contents(child)
			DirAccess.remove_absolute(child)
		elif FileAccess.file_exists(child):
			DirAccess.remove_absolute(child)


static func _remove_children(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name == "." or name == "..":
			name = d.get_next()
			continue
		var child := path.path_join(name)
		if d.current_is_dir():
			_remove_children(child)
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
		name = d.get_next()
	d.list_dir_end()
