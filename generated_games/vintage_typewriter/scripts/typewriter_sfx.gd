extends Node
class_name TypewriterSfx
## Keyboard SFX from TypingSimulator + Keymulate packs only (no Freesound).
## Packs live under assets/audio/<pack>/{press,release}/.

const AUDIO_ROOT := "res://assets/audio/"
const DEFAULT_PACK := "buckling"
const PATH_BELL := "res://assets/audio/bell.ogg"
const PATH_RETURN := "res://assets/audio/return.ogg"
const PATH_ERASE := "res://assets/audio/erase.ogg"

var pack_name: String = DEFAULT_PACK
var _press: Dictionary = {}
var _release: Dictionary = {}
var _player_press: AudioStreamPlayer
var _player_release: AudioStreamPlayer
var _player_mech: AudioStreamPlayer
var _bell: AudioStream
var _return_stream: AudioStream
var _erase_stream: AudioStream
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player_press = AudioStreamPlayer.new()
	_player_release = AudioStreamPlayer.new()
	_player_mech = AudioStreamPlayer.new()
	_player_press.volume_db = -4.0
	_player_release.volume_db = -6.0
	_player_mech.volume_db = -2.0
	add_child(_player_press)
	add_child(_player_release)
	add_child(_player_mech)
	_rng.randomize()
	_load_mechanical()
	if not load_pack(pack_name):
		load_pack(DEFAULT_PACK)


func load_pack(name: String) -> bool:
	if name.is_empty() or name.begins_with("freesound"):
		name = DEFAULT_PACK
	pack_name = name
	_press.clear()
	_release.clear()
	var base := AUDIO_ROOT + pack_name + "/"
	_load_action(_press, base + "press/", "GENERIC", true)
	_load_action(_press, base + "press/", "SPACE", false)
	_load_action(_press, base + "press/", "ENTER", false)
	_load_action(_press, base + "press/", "BACKSPACE", false)
	_load_action(_release, base + "release/", "GENERIC", false)
	_load_action(_release, base + "release/", "SPACE", false)
	_load_action(_release, base + "release/", "ENTER", false)
	_load_action(_release, base + "release/", "BACKSPACE", false)
	return has_audio()


func has_audio() -> bool:
	return _press.has("GENERIC") and (_press["GENERIC"] as Array).size() > 0


func list_packs() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(AUDIO_ROOT)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir() and not n.begins_with(".") and not n.begins_with("_"):
			if n.begins_with("freesound"):
				n = dir.get_next()
				continue
			var press := AUDIO_ROOT + n + "/press"
			if DirAccess.open(press) != null:
				out.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	out.sort()
	# Prefer buckling / alpaca near front for defaults
	return out


func play_key(press: bool = true) -> void:
	_play("GENERIC", press)


func play_space(press: bool = true) -> void:
	_play("SPACE", press)


func play_return(press: bool = true) -> void:
	if press and _return_stream:
		_play_mech(_return_stream, randf_range(0.96, 1.04))
		return
	_play("ENTER", press)


func play_backspace(press: bool = true) -> void:
	if press and _erase_stream:
		_play_mech(_erase_stream, randf_range(0.97, 1.03))
		return
	_play("BACKSPACE", press)


func play_bell() -> void:
	if _bell:
		_play_mech(_bell, randf_range(0.98, 1.03))
		return
	_play_mech(_make_bell_stream(), 1.0)


func _play_mech(stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	_player_mech.stream = stream
	_player_mech.pitch_scale = pitch
	_player_mech.play()


func _load_mechanical() -> void:
	_bell = _try_ogg(PATH_BELL)
	if _bell == null:
		_bell = _try_ogg("res://assets/audio/enter_bell.ogg")
	_return_stream = _try_ogg(PATH_RETURN)
	_erase_stream = _try_ogg(PATH_ERASE)
	if _bell == null:
		_bell = _make_bell_stream()


func _play(action: String, press: bool) -> void:
	var table: Dictionary = _press if press else _release
	if not table.has(action):
		action = "GENERIC"
	if not table.has(action):
		return
	var arr: Array = table[action]
	if arr.is_empty():
		return
	var stream: AudioStream = arr[_rng.randi_range(0, arr.size() - 1)]
	var p := _player_press if press else _player_release
	p.stream = stream
	p.pitch_scale = randf_range(0.98, 1.03)
	p.play()


func _load_action(into: Dictionary, folder: String, action: String, variants: bool) -> void:
	var streams: Array = []
	if variants:
		for i in range(5):
			var s := _try_mp3(folder + "GENERIC_R%d.mp3" % i)
			if s:
				streams.append(s)
	var s2 := _try_mp3(folder + action + ".mp3")
	if s2:
		streams.append(s2)
	if streams.size() > 0:
		into[action] = streams


func _try_ogg(path: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f:
		var data := f.get_buffer(f.get_length())
		if not data.is_empty():
			var stream: AudioStream = AudioStreamOggVorbis.load_from_buffer(data)
			if stream:
				return stream
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is AudioStream:
			return res
	return null


func _try_mp3(path: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	if data.is_empty():
		return null
	var stream := AudioStreamMP3.new()
	stream.data = data
	return stream


func _make_bell_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(sample_rate * 0.45)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 4.5)
		var tone := sin(t * TAU * 1240.0) * 0.45 + sin(t * TAU * 1860.0) * 0.22 + sin(t * TAU * 2480.0) * 0.08
		var s := clampf(tone * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		pcm[i * 2] = v & 0xFF
		pcm[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm
	return wav
