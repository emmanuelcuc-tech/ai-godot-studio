extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Insp = load("res://scripts/game_inspirations.gd")
	var Catalog = load("res://scripts/genre_catalog.gd")
	var Templates = load("res://scripts/templates/genre_templates.gd")
	var Writer = load("res://scripts/project_writer.gd")

	for phrase in ["make doom", "I want minecraft", "doom-like corridor", "block game like minecraft"]:
		var insp: Dictionary = Insp.detect(phrase)
		var g: Dictionary = Catalog.detect(phrase, "custom")
		print("PHRASE=", phrase, " INSP=", insp.get("display", "none"), " GENRE=", g.get("id", ""), "/", g.get("name", ""))

	var Cpp = load("res://scripts/templates/cpp_gdextension.gd")
	var Builder = load("res://scripts/cpp_builder.gd")

	for id in ["fps", "voxel"]:
		var built: Dictionary = Templates.build(id)
		var written: Dictionary = Writer.write_project(built)
		print("WRITE_", id, "=", written.get("ok", false), " ", written.get("path", ""))

	var fps: Dictionary = Templates.build("fps")
	var cpp_files: Array = Cpp.overlay(fps.get("files", []), "fps", "corridor shooter with brick walls")
	var paths: PackedStringArray = PackedStringArray()
	for f in cpp_files:
		if typeof(f) == TYPE_DICTIONARY:
			paths.append(str(f.get("path", "")))
	for need in Cpp.expected_paths():
		print("CPP_HAS_", need, "=", paths.has(need))
	var cpp_project: Dictionary = {
		"ok": true,
		"project_name": "cpp_smoke_fps",
		"summary": "C++ scaffold smoke",
		"howto": ["Run Game"],
		"files": cpp_files,
	}
	var cpp_written: Dictionary = Writer.write_project(cpp_project)
	print("WRITE_CPP=", cpp_written.get("ok", false), " ", cpp_written.get("path", ""))
	var info: Dictionary = Builder.detect()
	print("CPP_TOOL_PYTHON=", info.get("python", ""))
	print("CPP_TOOL_READY=", info.get("ready", false))

	if not _test_audio_studio_mixer():
		quit(1)
		return
	quit(0)


func _test_audio_studio_mixer() -> bool:
	var MB = load("res://scripts/audio_studio/mixer_bus.gd")
	if MB == null:
		print("MIXER_FAIL=load mixer_bus.gd")
		return false
	if not is_equal_approx(float(MB.UNITY), 0.8):
		print("MIXER_FAIL=unity")
		return false
	var vols: Dictionary = MB.defaults()
	if not is_equal_approx(float(vols.get("master", 0.0)), 0.8):
		print("MIXER_FAIL=default master")
		return false
	if not is_equal_approx(float(MB.to_gain("output", vols)), 1.0):
		print("MIXER_FAIL=unity output gain")
		return false
	vols["input"] = 0.5
	if not is_equal_approx(float(MB.effective("input", vols)), 0.5):
		print("MIXER_FAIL=master * input / unity")
		return false
	vols["master"] = 1.0
	if not is_equal_approx(float(MB.effective("input", vols)), 0.5 * 1.0 / 0.8):
		print("MIXER_FAIL=master boost")
		return false
	if not is_equal_approx(float(MB.from_gain(1.0)), 0.8):
		print("MIXER_FAIL=from_gain")
		return false
	if MB.describe_to_song("  neon glass  ") != "neon glass":
		print("MIXER_FAIL=describe_to_song")
		return false
	if not is_equal_approx(float(MB.hz_to_midi(440.0)), 69.0):
		print("MIXER_FAIL=A4 midi")
		return false
	if not is_equal_approx(float(MB.midi_to_hz(69.0)), 440.0):
		print("MIXER_FAIL=midi A4 hz")
		return false
	var hue0 := float(MB.neon_hue(0.0, 0.2))
	var hue_slow := float(MB.neon_hue(1.0, 0.2))
	var hue_fast := float(MB.neon_hue(1.0, 8.0))
	if absf(hue_slow - hue0) >= absf(hue_fast - hue0):
		print("MIXER_FAIL=neon speed")
		return false
	var half := float(MB.volume_from_fader_y(50.0, 100.0, 0.0))
	if not is_equal_approx(half, 0.625):
		print("MIXER_FAIL=fader y")
		return false
	var melody: Array = MB.quantize_melody([
		{"t": 0.0, "amp": 0.4, "freq": 440.0},
		{"t": 0.2, "amp": 0.4, "freq": 440.0},
		{"t": 0.4, "amp": 0.0, "freq": 0.0},
	], 0.08)
	if melody.is_empty():
		print("MIXER_FAIL=quantize melody")
		return false
	var hum: Dictionary = MB.hum_instrument([{"t": 0.0, "amp": 0.5, "freq": 440.0}])
	if int(hum.get("midi", 0)) != 69:
		print("MIXER_FAIL=hum midi")
		return false
	print("MIXER_OK=true VERSION=", MB.final_label())
	print("MIXER_NEON_SLOW=", hue_slow, " FAST=", hue_fast)
	print("MIXER_MELODY_NOTES=", melody.size())
	return true
