extends Node
class_name AudioBackend
## Spawns Python tools + ffmpeg for probe/separate/export.

signal progress(message: String)
signal probe_finished(result: Dictionary)
signal separate_finished(result: Dictionary)
signal export_finished(result: Dictionary)

var python_exe: String = ""
var tools_dir: String = ""
var work_dir: String = ""
var _thread: Thread
var _busy := false
var _job_queue: Array = []

func _ready() -> void:
	tools_dir = ProjectSettings.globalize_path("res://tools")
	# Prefer caller-provided scratch; fall back to resolved scratch drive.
	if work_dir == "":
		work_dir = ScratchDrive.resolve_root()
	DirAccess.make_dir_recursive_absolute(work_dir)
	python_exe = _find_python()


func set_work_dir(path: String) -> void:
	if path == "":
		return
	work_dir = path
	DirAccess.make_dir_recursive_absolute(work_dir)


func wait_for_idle() -> void:
	## Join worker thread so scratch files can be deleted safely on quit.
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_busy = false


func is_busy() -> bool:
	return _busy or not _job_queue.is_empty()


func _find_python() -> String:
	var env_py := OS.get_environment("AUDIO_STEM_PYTHON")
	if env_py != "" and FileAccess.file_exists(env_py):
		return env_py
	# Preferred stem-split venv (kept on F: when C: is low on space).
	var preferred := "F:/AudioStemStudio/python/Scripts/python.exe"
	if FileAccess.file_exists(preferred):
		return preferred
	# Use `where` only — calling missing exes via OS.execute floods the log.
	if OS.has_feature("windows"):
		var where_out: Array = []
		if OS.execute("where", ["python"], where_out, true, false) == 0:
			for line_v in where_out:
				var line := str(line_v).strip_edges()
				if line == "" or line.to_lower().contains("windowsapps"):
					continue
				if line.to_lower().ends_with("python.exe"):
					return line
		where_out.clear()
		if OS.execute("where", ["py"], where_out, true, false) == 0:
			for line_v2 in where_out:
				var line2 := str(line_v2).strip_edges()
				if line2 != "" and line2.to_lower().ends_with("py.exe"):
					return "py"
	return "python"


func _python_cmd(script: String, args: PackedStringArray) -> PackedStringArray:
	var cmd: PackedStringArray = []
	if python_exe.begins_with("py "):
		cmd.append("py")
		cmd.append("-3")
	else:
		cmd.append(python_exe)
	cmd.append(tools_dir.path_join(script))
	for a in args:
		cmd.append(a)
	return cmd


func run_probe_async(path: String) -> void:
	_enqueue_job({"kind": "probe", "path": path})


func run_separate_async(path: String, fallback_only: bool = false) -> void:
	_enqueue_job({"kind": "separate", "path": path, "fallback_only": fallback_only})


func run_export_stem_async(opts: Dictionary) -> void:
	var job := opts.duplicate(true)
	job["kind"] = "export_stem"
	_enqueue_job(job)


func run_surround_export_async(opts: Dictionary) -> void:
	var job := opts.duplicate(true)
	job["kind"] = "export_surround"
	_enqueue_job(job)


func _enqueue_job(job: Dictionary) -> void:
	_job_queue.append(job)
	_kick_queue()


func _kick_queue() -> void:
	if _busy or _job_queue.is_empty():
		return
	var job: Dictionary = _job_queue.pop_front()
	var kind := str(job.get("kind", ""))
	match kind:
		"probe":
			var probe_path := str(job.get("path", ""))
			_run_async(_make_probe_job(probe_path))
		"separate":
			var sep_path := str(job.get("path", ""))
			var fallback_only := bool(job.get("fallback_only", false))
			_run_async(_make_separate_job(sep_path, fallback_only))
		"export_stem":
			_run_async(_make_export_stem_job(job.duplicate(true)))
		"export_surround":
			_run_async(_make_export_surround_job(job.duplicate(true)))
		_:
			progress.emit("Unknown job: %s" % kind)


func _make_probe_job(path: String) -> Callable:
	return func():
		var json_out := work_dir.path_join("probe.json")
		var args: PackedStringArray = [path, "--json-out", json_out]
		var result := _exec_tool("probe_media.py", args)
		var data := _read_json(json_out)
		if data.is_empty():
			data = result
		call_deferred("_emit_probe", data)


func _make_separate_job(path: String, fallback_only: bool) -> Callable:
	return func():
		var out_dir := work_dir.path_join("stems_%d" % Time.get_unix_time_from_system())
		DirAccess.make_dir_recursive_absolute(out_dir)
		var json_out := out_dir.path_join("manifest.json")
		var args: PackedStringArray = [path, "--out-dir", out_dir, "--json-out", json_out]
		if fallback_only:
			args.append("--fallback-only")
		progress_deferred("Separating stems (audio-separator)…")
		var exec_result := _exec_tool("separate_tracks.py", args)
		var data := _read_json(json_out)
		if data.is_empty():
			var detail := str(exec_result.get("stdout", "")).strip_edges()
			var err := "No manifest produced. Is Python/audio-separator installed?"
			if int(exec_result.get("exit_code", 0)) != 0 and detail != "":
				err = "Separate tool failed (exit %s). %s" % [
					str(exec_result.get("exit_code")),
					detail.substr(0, mini(280, detail.length())),
				]
			data = {
				"ok": false,
				"error": err,
				"install_hint": "pip install audio-separator",
			}
		call_deferred("_emit_separate", data)


func _make_export_stem_job(opts: Dictionary) -> Callable:
	return func():
		var args: PackedStringArray = [
			"--input", str(opts.get("input", "")),
			"--output", str(opts.get("output", "")),
			"--format", str(opts.get("format", "wav")),
			"--bitrate", str(int(opts.get("bitrate", 256))),
			"--gain-db", str(float(opts.get("gain_db", 0.0))),
			"--volume", str(float(opts.get("volume", 100.0))),
			"--pan", str(float(opts.get("pan", 0.0))),
			"--reverb-amount", str(float(opts.get("reverb_amount", 0.0))),
		]
		if opts.get("mix", false):
			args.append("--mix")
			for p in opts.get("inputs", []):
				args.append("--input")
				args.append(str(p))
		var result: Dictionary = _exec_tool("export_stem.py", args)
		var data: Dictionary = result
		var stdout_json: Variant = result.get("stdout_json", null)
		if typeof(stdout_json) == TYPE_DICTIONARY:
			data = stdout_json as Dictionary
		call_deferred("_emit_export", data)


func _make_export_surround_job(opts: Dictionary) -> Callable:
	return func():
		var gains_path := work_dir.path_join("gains.json")
		var gains: Dictionary = opts.get("gains", {}) as Dictionary
		var f := FileAccess.open(gains_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(gains))
			f.close()
		var args: PackedStringArray = [
			"--input", str(opts.get("input", "")),
			"--output", str(opts.get("output", "")),
			"--layout", str(opts.get("layout", "stereo")),
			"--gains-json", JSON.stringify(gains),
			"--format", str(opts.get("format", "wav")),
			"--bitrate", str(int(opts.get("bitrate", 256))),
			"--mode", str(opts.get("mode", "direct")),
		]
		var result: Dictionary = _exec_tool("surround_mix.py", args)
		var data: Dictionary = result
		var stdout_json: Variant = result.get("stdout_json", null)
		if typeof(stdout_json) == TYPE_DICTIONARY:
			data = stdout_json as Dictionary
		call_deferred("_emit_export", data)


func _emit_probe(data: Dictionary) -> void:
	_busy = false
	probe_finished.emit(data)
	_kick_queue()


func _emit_separate(data: Dictionary) -> void:
	_busy = false
	separate_finished.emit(data)
	_kick_queue()


func _emit_export(data: Dictionary) -> void:
	_busy = false
	export_finished.emit(data)
	_kick_queue()


func progress_deferred(msg: String) -> void:
	call_deferred("_emit_progress", msg)


func _emit_progress(msg: String) -> void:
	progress.emit(msg)


func _run_async(fn: Callable) -> void:
	if _busy:
		progress.emit("Busy — wait for current job.")
		return
	_busy = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(fn)


func _exec_tool(script: String, args: PackedStringArray) -> Dictionary:
	var cmd := _python_cmd(script, args)
	var exe := cmd[0]
	var rest: PackedStringArray = cmd.slice(1)
	var output: Array = []
	progress_deferred("Running %s…" % script)
	var code := OS.execute(exe, rest, output, true, false)
	var joined := ""
	for line in output:
		joined += str(line) + "\n"
	var parsed := {}
	# Try last JSON object in output
	var start := joined.rfind("{")
	if start >= 0:
		var json := JSON.new()
		if json.parse(joined.substr(start)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			parsed = json.data
	return {
		"ok": code == 0,
		"exit_code": code,
		"stdout": joined,
		"stdout_json": parsed,
	}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(txt) != OK:
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}


func apply_latency_ms(ms: int) -> float:
	## Map latency spinbox to AudioServer mix rate buffer suggestion.
	## Godot exposes output latency; we also try to set mix/callback comfort via Engine.
	ms = clampi(ms, 16, 250)
	# Soft hint: larger physics/audio comfort — store estimated
	var estimated := float(ms)
	# AudioServer.get_output_latency() is read-only runtime; we expose target
	return estimated


func get_reported_latency_ms() -> float:
	return AudioServer.get_output_latency() * 1000.0
