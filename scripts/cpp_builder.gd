class_name CppBuilder
extends RefCounted
## Detects a C++ toolchain and can kick off a GDExtension build (non-blocking).


static func detect() -> Dictionary:
	var info: Dictionary = {
		"os": OS.get_name(),
		"python": _first_existing(["python", "python3", "py"]),
		"git": _which("git"),
		"scons": _first_existing(["scons"]),
		"clang": _first_existing(["clang++", "clang"]),
		"gcc": _first_existing(["g++", "c++"]),
		"msvc": "",
		"vs_path": _find_vs_path(),
		"ready": false,
		"notes": PackedStringArray(),
	}
	if not str(info["vs_path"]).is_empty():
		info["msvc"] = str(info["vs_path"])
	var has_compiler: bool = not str(info["msvc"]).is_empty() \
		or not str(info["clang"]).is_empty() \
		or not str(info["gcc"]).is_empty()
	var has_python: bool = not str(info["python"]).is_empty()
	info["ready"] = has_python and has_compiler
	var notes: PackedStringArray = info["notes"]
	if not has_python:
		notes.append("Python not found — install Python 3 and `pip install scons`.")
	if not has_compiler:
		notes.append("No C++ compiler found — install Visual Studio Build Tools (MSVC) or LLVM clang.")
	if str(info["git"]).is_empty():
		notes.append("Git not found — needed to clone godot-cpp (or vendor it yourself).")
	if str(info["scons"]).is_empty() and has_python:
		notes.append("SCons not on PATH — build script uses `python -m SCons` after `pip install scons`.")
	if bool(info["ready"]):
		notes.append("Toolchain looks usable. First GDExtension build compiles godot-cpp (several minutes).")
	info["notes"] = notes
	return info


static func status_markdown(info: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"# C++ / GDExtension toolchain",
		"",
		"- OS: `%s`" % str(info.get("os", "")),
		"- Python: `%s`" % _dash(info.get("python", "")),
		"- Git: `%s`" % _dash(info.get("git", "")),
		"- SCons: `%s`" % _dash(info.get("scons", "")),
		"- MSVC / VS: `%s`" % _dash(info.get("msvc", "")),
		"- clang: `%s`" % _dash(info.get("clang", "")),
		"- g++: `%s`" % _dash(info.get("gcc", "")),
		"- Auto-build ready: **%s**" % ("yes" if info.get("ready", false) else "no"),
		"",
		"## Notes",
	])
	for n in info.get("notes", []):
		lines.append("- %s" % str(n))
	lines.append("")
	lines.append("Run `build_cpp.ps1` (Windows) or `./build_cpp.sh` (macOS/Linux) inside the generated game folder.")
	lines.append("Until the `.dll` / `.so` exists, **Run Game** uses the GDScript fallback.")
	lines.append("")
	return "\n".join(lines)


static func try_start_build(project_path: String) -> Dictionary:
	var info: Dictionary = detect()
	if project_path.is_empty() or not DirAccess.dir_exists_absolute(project_path):
		return {"ok": false, "started": false, "info": info, "error": "Missing project path"}
	var status_path: String = project_path.path_join("docs/CPP_STATUS.md")
	_write_text(status_path, status_markdown(info))
	if not bool(info.get("ready", false)):
		return {
			"ok": true,
			"started": false,
			"info": info,
			"message": "C++ scaffolding written. Compiler not ready — use GDScript fallback. See docs/CPP_BUILD.md",
		}
	var script_ps1: String = project_path.path_join("build_cpp.ps1")
	var script_sh: String = project_path.path_join("build_cpp.sh")
	var pid: int = -1
	if OS.get_name() == "Windows" and FileAccess.file_exists(script_ps1):
		pid = OS.create_process("powershell", PackedStringArray([
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_ps1,
		]))
	elif FileAccess.file_exists(script_sh):
		pid = OS.create_process("/bin/bash", PackedStringArray([script_sh]))
	if pid <= 0:
		return {
			"ok": true,
			"started": false,
			"info": info,
			"message": "Could not spawn build process — run build_cpp.ps1 / build_cpp.sh manually.",
		}
	_write_text(project_path.path_join("docs/CPP_BUILD_STARTED.md"),
		"# GDExtension build started\n\nPID: %s\n\nThis compiles godot-cpp + the game extension. When finished, restart Run Game to load native classes (`GamePlayer`, `GameWorld`, `GameApp`).\n" % str(pid))
	return {
		"ok": true,
		"started": true,
		"pid": pid,
		"info": info,
		"message": "Started C++ GDExtension build (pid %s). Game is playable now via GDScript fallback." % str(pid),
	}


static func _dash(value: Variant) -> String:
	var s: String = str(value)
	return s if not s.is_empty() else "(not found)"


static func _write_text(path: String, body: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(body)


static func _first_existing(names: Array) -> String:
	for n in names:
		var found: String = _which(str(n))
		if not found.is_empty():
			return found
	return ""


static func _which(cmd: String) -> String:
	if cmd.is_empty():
		return ""
	var output: Array = []
	var tool: String = "where" if OS.get_name() == "Windows" else "which"
	var code: int = OS.execute(tool, PackedStringArray([cmd]), output, true, true)
	if code != 0:
		return ""
	var text: String = "\n".join(PackedStringArray(output)).strip_edges()
	if text.is_empty():
		return ""
	return text.split("\n")[0].strip_edges()


static func _find_vs_path() -> String:
	if OS.get_name() != "Windows":
		return ""
	var vswhere: String = "C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
	if not FileAccess.file_exists(vswhere):
		return ""
	var output: Array = []
	var code: int = OS.execute(vswhere, PackedStringArray([
		"-latest", "-products", "*", "-requires",
		"Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
		"-property", "installationPath",
	]), output, true, true)
	if code != 0:
		return ""
	return "\n".join(PackedStringArray(output)).strip_edges()
